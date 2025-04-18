import tensorflow as tf
import joblib
import os

CAMINHO_MODELO = "model/modelo_lstm.keras"
CAMINHO_SCALER = "model/scaler.gz"

def carregar_modelo():
    try:
        modelo = tf.keras.models.load_model(CAMINHO_MODELO)
        print(f"✅ Modelo carregado de {CAMINHO_MODELO}")
        return modelo
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o modelo em '{CAMINHO_MODELO}': {e}")

def carregar_scaler():
    try:
        scaler = joblib.load(CAMINHO_SCALER)
        print(f"✅ Scaler carregado de {CAMINHO_SCALER}")
        return scaler
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o scaler em '{CAMINHO_SCALER}': {e}")
