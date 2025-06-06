# app/main.py

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, constr
from typing import List
import numpy as np
import time
from app.model_loader import carregar_modelo, carregar_scaler

app = FastAPI()

# ------------------------------------------------------------
# 1) Carrega modelo e scaler treinados (janelas de 30)
# ------------------------------------------------------------
try:
    modelo = carregar_modelo()
    scaler = carregar_scaler()
except Exception as e:
    raise RuntimeError(f"❌ Erro ao inicializar a aplicação: {e}")

# ------------------------------------------------------------
# 2) Middleware para log de tempo de resposta
# ------------------------------------------------------------
@app.middleware("http")
async def log_request_time(request: Request, call_next):
    inicio = time.time()
    resposta = await call_next(request)
    duracao = time.time() - inicio
    print(f"⏱️ {request.method} {request.url.path} demorou {duracao:.3f}s")
    return resposta

# ------------------------------------------------------------
# 3) Schema de entrada: agora inclui ticker e historico (30 floats)
# ------------------------------------------------------------
class PrevisaoRequest(BaseModel):
    ticker: constr(strip_whitespace=True, min_length=1)  # string não vazia
    historico: List[float]

# ------------------------------------------------------------
# 4) Função auxiliar: detecta tendência em 30 preços
# ------------------------------------------------------------
def detectar_tendencia(prices: List[float]) -> str:
    """
    Recebe uma lista de exatamente 30 floats (preços).
    Retorna: "alta", "queda", "volátil" ou "neutro".
    """
    arr = np.array(prices, dtype=float)
    if len(arr) < 30:
        return "insuficientes"

    primeiro = arr[0]
    ultimo = arr[-1]
    if primeiro <= 0:
        return "volátil"

    diff_pct = (ultimo - primeiro) / primeiro * 100  # variação em %
    if diff_pct >= 1.0:
        return "alta"
    elif diff_pct <= -1.0:
        return "queda"

    media = np.mean(arr)
    std = np.std(arr)
    if media <= 0:
        return "volátil"

    coef_var = std / media * 100  # coeficiente de variação em %
    if coef_var > 1.5:
        return "volátil"
    else:
        return "neutro"

# ------------------------------------------------------------
# 5) Endpoint /prever
# ------------------------------------------------------------
@app.post("/prever")
def prever(request: PrevisaoRequest):
    WINDOW_SIZE = 30

    # 5.1) Valida que ticker não seja vazio (já garantido pelo Pydantic) e que tenhamos 30 valores
    if len(request.historico) < WINDOW_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"É necessário fornecer pelo menos {WINDOW_SIZE} valores em 'historico'."
        )

    try:
        # 5.2) Extrair exatamente os últimos 30 preços
        seq_raw = request.historico[-WINDOW_SIZE:]  # lista de 30 floats

        # 5.3) Detectar tendência
        tendencia = detectar_tendencia(seq_raw)

        # 5.4) Preparar array para o modelo: (1, 30, 1)
        seq_arr = np.array(seq_raw, dtype=float).reshape(1, WINDOW_SIZE, 1)

        # 5.5) Previsão (normalizada) e desserialização
        pred_norm = modelo.predict(seq_arr)[0][0]
        pred = scaler.inverse_transform([[pred_norm]])[0][0]

        # 5.6) Último preço informado
        ultimo_preco = seq_raw[-1]

        # 5.7) Montar resposta com ticker, último preço, tendência e previsão
        return JSONResponse(
            content={
                "ticker": request.ticker.upper(),
                "ultimo_preco": f"US$ {ultimo_preco:.2f}",
                "preco_previsto": f"US$ {pred:.2f}",
                "tendencia": tendencia,
                "explicacao": (
                    f"Para o ticker '{request.ticker.upper()}', usamos os últimos "
                    f"{WINDOW_SIZE} valores para estimar o próximo preço. "
                    f"Classificado como '{tendencia}'."
                )
            }
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao realizar previsão: {e}")
