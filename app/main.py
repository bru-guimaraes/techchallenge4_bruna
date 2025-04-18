from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from typing import List
import numpy as np
import time
from app.model_loader import carregar_modelo, carregar_scaler

app = FastAPI()

# Carrega modelo e scaler
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

# Schema de entrada
class PrevisaoRequest(BaseModel):
    historico: List[float]

@app.post("/prever")
def prever_valor(request: PrevisaoRequest):
    if len(request.historico) != 60:
        raise HTTPException(status_code=400, detail="A lista deve conter exatamente 60 valores de fechamento.")

    try:
        dados = np.array(request.historico).reshape(-1, 1)
        dados_normalizados = scaler.transform(dados)
        entrada = dados_normalizados.reshape(1, 60, 1)
        previsao_normalizada = modelo.predict(entrada)
        previsao = scaler.inverse_transform(previsao_normalizada)

        return {
            "previsao_normalizada": float(previsao_normalizada[0][0]),
            "previsao": float(previsao[0][0])
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro durante a previsão: {str(e)}")
