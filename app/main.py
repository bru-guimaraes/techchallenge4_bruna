# app/main.py

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List
import numpy as np
import time
from app.model_loader import carregar_modelo, carregar_scaler

app = FastAPI()

ATIVO = "AAPL"
WINDOW_SIZE = 30

# Carrega modelo e scaler
try:
    modelo = carregar_modelo()
    scaler = carregar_scaler()
except Exception as e:
    raise RuntimeError(f"❌ Erro ao inicializar a aplicação: {e}")

# Obter limites do scaler para validação de escala
DATA_MIN = scaler.data_min_[0]
DATA_MAX = scaler.data_max_[0]

# Middleware de log
@app.middleware("http")
async def log_request_time(request: Request, call_next):
    inicio = time.time()
    resp = await call_next(request)
    print(f"⏱️ {request.method} {request.url.path} demorou {time.time() - inicio:.3f}s")
    return resp

# Schema de entrada
class PrevisaoRequest(BaseModel):
    historico: List[float]

# 1) Detecta tendência no histórico
def detectar_tendencia_historico(prices: List[float]) -> str:
    arr = np.array(prices, dtype=float)
    primeiro, ultimo = arr[0], arr[-1]
    diff_pct = (ultimo - primeiro) / primeiro * 100 if primeiro > 0 else 0.0
    if diff_pct >= 1.0:
        return "alta"
    if diff_pct <= -1.0:
        return "queda"
    coef_var = np.std(arr) / np.mean(arr) * 100 if np.mean(arr) > 0 else float("inf")
    return "volátil" if coef_var > 1.5 else "neutro"

# 2) Detecta tendência prevista (comparação previsão x último preço)
def detectar_tendencia_prevista(predito: float, ultimo: float) -> str:
    diff_pct = (predito - ultimo) / ultimo * 100 if ultimo > 0 else 0.0
    if diff_pct >= 1.0:
        return "alta"
    if diff_pct <= -1.0:
        return "queda"
    return "estável"

@app.post("/prever")
def prever(request: PrevisaoRequest):
    # 1) Valida quantidade
    if len(request.historico) < WINDOW_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"É necessário fornecer pelo menos {WINDOW_SIZE} valores em 'historico'."
        )

    seq_raw = request.historico[-WINDOW_SIZE:]

    # 2) Valida escala
    for i, p in enumerate(seq_raw):
        if p < DATA_MIN or p > DATA_MAX:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"historico[{i}] = {p:.2f} está fora do range "
                    f"[{DATA_MIN:.2f}, {DATA_MAX:.2f}]."
                )
            )

    # 3) Tendência no histórico
    tendencia_historico = detectar_tendencia_historico(seq_raw)

    # 4) Previsão
    seq_arr = np.array(seq_raw, dtype=float).reshape(1, WINDOW_SIZE, 1)
    pred_norm = modelo.predict(seq_arr)[0][0]
    pred = scaler.inverse_transform([[pred_norm]])[0][0]
    ultimo_preco = seq_raw[-1]

    # 5) Tendência prevista
    tendencia_prevista = detectar_tendencia_prevista(pred, ultimo_preco)

    # 6) Monta resposta
    return JSONResponse(
        content={
            "ticker": ATIVO,
            "ultimo_preco": f"US$ {ultimo_preco:.2f}",
            "preco_previsto": f"US$ {pred:.2f}",
            "tendencia_historico": tendencia_historico,
            "tendencia_prevista": tendencia_prevista,
            "explicacao": (
                f"Histórico classificado como '{tendencia_historico}'. "
                f"A previsão é '{tendencia_prevista}' em relação ao último preço."
            )
        }
    )
