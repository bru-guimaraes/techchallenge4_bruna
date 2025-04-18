import tensorflow as tf

def carregar_modelo(caminho_modelo="model/modelo_lstm.keras"):
    try:
        return tf.keras.models.load_model(caminho_modelo)
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o modelo em '{caminho_modelo}': {e}")
