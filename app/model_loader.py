# app/model_loader.py

import os
import boto3
import joblib
from tensorflow.keras.models import load_model

def carregar_modelo():
    """
    1) Se definidas as vars BUCKET_NAME e MODEL_KEY, baixa do S3 para /app/modelos/model_lstm_<fonte>.h5
    2) Caso contrário, espera encontrar o arquivo local em /app/modelos/model_lstm_<fonte>.h5
    """
    bucket = os.getenv("BUCKET_NAME")
    model_key = os.getenv("MODEL_KEY")  # normalmente algo como "modelos/model_lstm_<fonte>.h5"
    local_dir = "/app/modelos"
    os.makedirs(local_dir, exist_ok=True)

    # Extrair nome do arquivo (última parte do key) ou referencia fixa se você não usar MODEL_KEY
    if model_key:
        filename = os.path.basename(model_key)
    else:
        # Fallback para um nome padrão (sem S3). Ajuste se necessário.
        # Por exemplo, se 'fonte_dados.txt' contiver "alpha", seu arquivo deve ser "model_lstm_alpha.h5"
        fonte = "padrao"  # ou leia de data/fonte_dados.txt, se quiser usar essa lógica
        filename = f"model_lstm_{fonte}.h5"

    local_model_path = os.path.join(local_dir, filename)

    # 1) Se BUCKET_NAME e MODEL_KEY estiverem definidos, tenta baixar do S3
    if bucket and model_key:
        s3 = boto3.client("s3")
        try:
            print(f"☁️ Baixando modelo do S3: s3://{bucket}/{model_key} → {local_model_path}")
            s3.download_file(bucket, model_key, local_model_path)
            print("✅ Download concluído.")
        except Exception as e:
            raise RuntimeError(f"❌ Erro ao baixar o modelo do S3: {e}")

    # 2) Agora verifica se o arquivo local existe
    if not os.path.isfile(local_model_path):
        raise RuntimeError(f"❌ Modelo não encontrado em '{local_model_path}'. "
                           "Verifique se MODEL_KEY/BUCKET_NAME estão corretos ou se o arquivo foi copiado para /app/modelos/.")

    # 3) Carrega o modelo com Keras
    try:
        model = load_model(local_model_path)
        print(f"✅ Modelo carregado com sucesso de '{local_model_path}'")
        return model
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o modelo de '{local_model_path}': {e}")


def carregar_scaler():
    """
    1) Se definidas as vars BUCKET_NAME e SCALER_KEY, baixa do S3 para /app/modelos/scaler_<fonte>.gz
    2) Caso contrário, espera encontrar o arquivo local em /app/modelos/scaler_<fonte>.gz
    """
    bucket = os.getenv("BUCKET_NAME")
    scaler_key = os.getenv("SCALER_KEY")  # normalmente algo como "modelos/scaler_<fonte>.gz"
    local_dir = "/app/modelos"
    os.makedirs(local_dir, exist_ok=True)

    if scaler_key:
        filename = os.path.basename(scaler_key)
    else:
        fonte = "padrao"  # ou leia de data/fonte_dados.txt, se você quiser
        filename = f"scaler_{fonte}.gz"

    local_scaler_path = os.path.join(local_dir, filename)

    # 1) Se BUCKET_NAME e SCALER_KEY estiverem definidos, tenta baixar do S3
    if bucket and scaler_key:
        s3 = boto3.client("s3")
        try:
            print(f"☁️ Baixando scaler do S3: s3://{bucket}/{scaler_key} → {local_scaler_path}")
            s3.download_file(bucket, scaler_key, local_scaler_path)
            print("✅ Download do scaler concluído.")
        except Exception as e:
            raise RuntimeError(f"❌ Erro ao baixar o scaler do S3: {e}")

    # 2) Verifica se o arquivo local existe
    if not os.path.isfile(local_scaler_path):
        raise RuntimeError(f"❌ Scaler não encontrado em '{local_scaler_path}'. "
                           "Verifique se SCALER_KEY/BUCKET_NAME estão corretos ou se o arquivo foi copiado para /app/modelos/.")

    # 3) Carrega o scaler com joblib
    try:
        scaler = joblib.load(local_scaler_path)
        print(f"✅ Scaler carregado com sucesso de '{local_scaler_path}'")
        return scaler
    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar o scaler de '{local_scaler_path}': {e}")
