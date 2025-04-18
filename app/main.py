from fastapi import FastAPI
from app.model_loader import carregar_modelo
from app.schemas import PrevisaoRequest
import numpy as np

app = FastAPI()
modelo = carregar_modelo()

@app.post("/prever")
def prever(request: PrevisaoRequest):
    entrada = np.array(request.historico).reshape(1, len(request.historico), 1)
    pred = modelo.predict(entrada)
    return {"previsao": float(pred[0][0])}
