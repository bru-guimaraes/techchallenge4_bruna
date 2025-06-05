import os
import tempfile
import boto3
import tensorflow as tf
from dotenv import load_dotenv
import botocore
import joblib

# Carrega variáveis de ambiente
load_dotenv()

BUCKET_NAME = os.getenv("BUCKET_NAME")
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")
AWS_DEFAULT_REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")

# Lê a fonte de dados atual (definida no full_deploy)
try:
    with open("data/fonte_dados.txt", "r") as f:
        fonte_dados = f.read().strip()
except:
    fonte_dados = "indefinida"  # fallback

# Define o caminho dos arquivos com base na fonte
modelo_filename = f"model_lstm_{fonte_dados}.h5"
scaler_filename = f"scaler_{fonte_dados}.gz"
MODEL_KEY = f"modelos/{modelo_filename}"
SCALER_KEY = f"modelos/{scaler_filename}"

# Cliente S3
s3_client = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    aws_session_token=AWS_SESSION_TOKEN,
    region_name=AWS_DEFAULT_REGION
)

def carregar_modelo():
    print("☁️ Baixando modelo do S3...")

    with tempfile.NamedTemporaryFile(delete=False, suffix=".h5") as tmp:
        caminho_temp = tmp.name

    try:
        s3_client.download_file(BUCKET_NAME, MODEL_KEY, caminho_temp)
        print(f"✅ Download concluído: {caminho_temp}")

        tamanho = os.path.getsize(caminho_temp)
        print(f"📏 Tamanho do arquivo baixado: {tamanho} bytes")

        with open(caminho_temp, "rb") as f:
            cabecalho = f.read(8)
            print(f"🔎 Primeiros bytes do arquivo: {cabecalho}")

        modelo = tf.keras.models.load_model(caminho_temp)
        print("✅ Modelo carregado com sucesso!")
        return modelo

    except botocore.exceptions.BotoCoreError as boto_err:
        raise RuntimeError(f"Erro boto3: {boto_err}")

    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar modelo: {e}")

    finally:
        if os.path.exists(caminho_temp):
            os.remove(caminho_temp)

def carregar_scaler():
    print("☁️ Baixando scaler do S3...")

    with tempfile.NamedTemporaryFile(delete=False, suffix=".gz") as tmp:
        caminho_temp = tmp.name

    try:
        s3_client.download_file(BUCKET_NAME, SCALER_KEY, caminho_temp)
        print(f"✅ Download scaler concluído: {caminho_temp}")

        scaler = joblib.load(caminho_temp)
        print("✅ Scaler carregado com sucesso!")
        return scaler

    except Exception as e:
        raise RuntimeError(f"❌ Erro ao carregar scaler: {e}")

    finally:
        if os.path.exists(caminho_temp):
            os.remove(caminho_temp)
