# projeto_lstm_acoes/app/model_loader.py

import os
import boto3
import joblib
from tensorflow.keras.models import load_model

def carregar_modelo():
    """
    1) Se definidas BUCKET_NAME e MODEL_KEY, baixa do S3 para /app/model/<nome_do_arquivo>
    2) Caso contrário, busca ‘/app/model/modelo_lstm.keras’ (nome local exato)
    """
    bucket = os.getenv("BUCKET_NAME")
    model_key = os.getenv("MODEL_KEY")  # ex.: "model/modelo_lstm_padrao.keras"
    local_dir = "/app/model"
    os.makedirs(local_dir, exist_ok=True)

    if model_key:
        filename = os.path.basename(model_key)  # “modelo_lstm_padrao.keras” se vier do S3
    else:
        # fallback local: usa exatamente o arquivo que existe no repositório
        filename = "modelo_lstm.keras"

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

    # Verifica se o arquivo localizado existe
    if not os.path.isfile(local_model_path):
        raise RuntimeError(f"❌ Modelo não encontrado em '{local_model_path}'. "
                           "Verifique MODEL_KEY/BUCKET_NAME ou copie ‘modelo_lstm.keras’ para /app/model/.")

    # Carrega o modelo com Keras
    try:
        model = load_model(local_model_path)
        print(f"✅ Modelo carregado com sucesso de '{local_model_path}'")
        return model
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o modelo de '{local_model_path}': {e}")


def carregar_scaler():
    """
    1) Se definidas BUCKET_NAME e SCALER_KEY, baixa do S3 para /app/model/<nome_do_scaler>
    2) Caso contrário, busca ‘/app/model/scaler.gz’ (nome local exato)
    """
    bucket = os.getenv("BUCKET_NAME")
    scaler_key = os.getenv("SCALER_KEY")  # ex.: "model/scaler_padrao.gz"
    local_dir = "/app/model"
    os.makedirs(local_dir, exist_ok=True)

    if scaler_key:
        filename = os.path.basename(scaler_key)  # “scaler_padrao.gz” se vier do S3
    else:
        # fallback local: usa exatamente o arquivo presente no repositório
        filename = "scaler.gz"

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
                           "Verifique SCALER_KEY/BUCKET_NAME ou copie ‘scaler.gz’ para /app/model/.")

    # Carrega o scaler com joblib
    try:
        scaler = joblib.load(local_scaler_path)
        print(f"✅ Scaler carregado com sucesso de '{local_scaler_path}'")
        return scaler
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o scaler de '{local_scaler_path}': {e}")
