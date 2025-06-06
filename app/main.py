# app/main.py

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List
import numpy as np
import time
from app.model_loader import carregar_modelo, carregar_scaler

app = FastAPI()

# Carrega modelo e scaler treinados para “AAPL” (ou outro ativo fixo)
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
    # Valida que 60 valores estejam presentes
    if len(request.historico) < 60:
        raise HTTPException(
            status_code=400,
            detail="É necessário fornecer ao menos 60 valores em 'historico'."
        )

    try:
        # Usa somente os últimos 60 pontos de historico
        entrada = np.array(request.historico[-60:]).reshape(1, 60, 1)
        predicao_normalizada = modelo.predict(entrada)[0][0]
        predicao = scaler.inverse_transform([[predicao_normalizada]])[0][0]

        return JSONResponse(
            content={
                "preco_previsto": f"US$ {predicao:.2f}",
                "explicacao": "Valor estimado de fechamento da ação para o próximo dia com base nos dados fornecidos"
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao realizar previsão: {e}")
