# app/main.py

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List
import numpy as np
import time
from app.model_loader import carregar_modelo, carregar_scaler

app = FastAPI()

# Carrega o modelo e o scaler treinados (janelas de 30)
try:
    modelo = carregar_modelo()
    scaler = carregar_scaler()
except Exception as e:
    raise RuntimeError(f"❌ Erro ao inicializar a aplicação: {e}")

# Middleware de log de tempo de resposta
@app.middleware("http")
async def log_request_time(request: Request, call_next):
    inicio = time.time()
    resposta = await call_next(request)
    duracao = time.time() - inicio
    print(f"⏱️ {request.method} {request.url.path} demorou {duracao:.3f}s")
    return resposta

# Schema de entrada: apenas “historico”
class PrevisaoRequest(BaseModel):
    historico: List[float]

@app.post("/prever")
def prever(request: PrevisaoRequest):
    WINDOW_SIZE = 30

    # 1) Valida que existam pelo menos 30 valores
    if len(request.historico) < WINDOW_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"É necessário fornecer ao menos {WINDOW_SIZE} valores em 'historico'."
        )

    try:
        # 2) Fatiar apenas os últimos 30 pontos e reshape → (1, 30, 1)
        seq = np.array(request.historico[-WINDOW_SIZE:], dtype=float).reshape(1, WINDOW_SIZE, 1)

        # 3) Predição normalizada
        predicao_normalizada = modelo.predict(seq)[0][0]

        # 4) Desnormalizar
        predicao = scaler.inverse_transform([[predicao_normalizada]])[0][0]

        return JSONResponse(
            content={
                "preco_previsto": f"US$ {predicao:.2f}",
                "explicacao": (
                    f"Valor estimado de fechamento da ação para o próximo dia, "
                    f"usando os últimos {WINDOW_SIZE} valores"
                )
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao realizar previsão: {e}")
