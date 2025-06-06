# projeto_lstm_acoes/app/model_loader.py

import os
import boto3
import joblib
from tensorflow.keras.models import load_model

def carregar_modelo():
    """
    1) Se definidas as vars BUCKET_NAME e MODEL_KEY, baixa do S3 para /app/model/modelo_lstm_<fonte>.keras
    2) Caso contrário, espera encontrar o arquivo local em /app/model/modelo_lstm_<fonte>.keras
    """
    bucket = os.getenv("BUCKET_NAME")
    model_key = os.getenv("MODEL_KEY")  # ex.: "model/modelo_lstm_padrao.keras"
    local_dir = "/app/model"
    os.makedirs(local_dir, exist_ok=True)

    if model_key:
        filename = os.path.basename(model_key)   # ex.: "modelo_lstm_padrao.keras"
    else:
        # Fallback para um nome padrão; ajuste conforme seu "fonte_dados.txt" se precisar dinâmico
        fonte = "padrao"
        filename = f"modelo_lstm_{fonte}.keras"

    local_model_path = os.path.join(local_dir, filename)

    # Se BUCKET_NAME e MODEL_KEY estiverem definidos, baixa do S3
    if bucket and model_key:
        s3 = boto3.client("s3")
        try:
            print(f"☁️ Baixando modelo do S3: s3://{bucket}/{model_key} → {local_model_path}")
            s3.download_file(bucket, model_key, local_model_path)
            print("✅ Download concluído.")
        except Exception as e:
            raise RuntimeError(f"❌ Erro ao baixar o modelo do S3: {e}")

    # Verifica se o arquivo local existe
    if not os.path.isfile(local_model_path):
        raise RuntimeError(f"❌ Modelo não encontrado em '{local_model_path}'. "
                           "Verifique MODEL_KEY/BUCKET_NAME ou copie o .keras para /app/model/.")

    # Carrega o modelo com Keras
    try:
        model = load_model(local_model_path)
        print(f"✅ Modelo carregado com sucesso de '{local_model_path}'")
        return model
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o modelo de '{local_model_path}': {e}")


def carregar_scaler():
    """
    1) Se definidas as vars BUCKET_NAME e SCALER_KEY, baixa do S3 para /app/model/scaler_<fonte>.gz
    2) Caso contrário, espera encontrar o arquivo local em /app/model/scaler_<fonte>.gz
    """
    bucket = os.getenv("BUCKET_NAME")
    scaler_key = os.getenv("SCALER_KEY")  # ex.: "model/scaler_padrao.gz"
    local_dir = "/app/model"
    os.makedirs(local_dir, exist_ok=True)

    if scaler_key:
        filename = os.path.basename(scaler_key)  # ex.: "scaler_padrao.gz"
    else:
        fonte = "padrao"
        filename = f"scaler_{fonte}.gz"

    local_scaler_path = os.path.join(local_dir, filename)

    # Se BUCKET_NAME e SCALER_KEY estiverem definidos, baixa do S3
    if bucket and scaler_key:
        s3 = boto3.client("s3")
        try:
            print(f"☁️ Baixando scaler do S3: s3://{bucket}/{scaler_key} → {local_scaler_path}")
            s3.download_file(bucket, scaler_key, local_scaler_path)
            print("✅ Download do scaler concluído.")
        except Exception as e:
            raise RuntimeError(f"❌ Erro ao baixar o scaler do S3: {e}")

    # Verifica se o arquivo local existe
    if not os.path.isfile(local_scaler_path):
        raise RuntimeError(f"❌ Scaler não encontrado em '{local_scaler_path}'. "
                           "Verifique SCALER_KEY/BUCKET_NAME ou copie o .gz para /app/model/.")

    # Carrega o scaler com joblib
    try:
        scaler = joblib.load(local_scaler_path)
        print(f"✅ Scaler carregado com sucesso de '{local_scaler_path}'")
        return scaler
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o scaler de '{local_scaler_path}': {e}")
