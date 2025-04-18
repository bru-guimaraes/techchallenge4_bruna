import yfinance as yf
import pandas as pd
import boto3
import os
from dotenv import load_dotenv

# Carrega variáveis do .env
load_dotenv()

# Verifica se as credenciais foram carregadas corretamente
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")
AWS_DEFAULT_REGION = os.getenv("AWS_DEFAULT_REGION")

if not all([AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION]):
    raise EnvironmentError("❌ Credenciais AWS ausentes ou mal definidas no .env.")

# Configurações
TICKER = "AAPL"
START = "2015-01-01"
END = "2024-12-31"
BUCKET = "bdadostchallengebruna"
ARQUIVO_LOCAL = f"data/{TICKER}_fechamento.parquet"
ARQUIVO_S3 = f"acoes/{TICKER}_fechamento.parquet"

try:
    print("📥 Coletando dados do Yahoo Finance...")
    df = yf.download(TICKER, start=START, end=END)

    if df.empty:
        raise ValueError(f"Nenhum dado retornado para o ticker {TICKER}. Verifique o código ou o intervalo de datas.")

    df[['Close']].dropna().to_parquet(ARQUIVO_LOCAL, index=True)
    print(f"✅ Arquivo local salvo em {ARQUIVO_LOCAL}")

except Exception as e:
    raise RuntimeError(f"❌ Erro durante a coleta ou o salvamento dos dados: {e}")

# Envia para o S3
print("☁️ Enviando para o S3...")

try:
    s3 = boto3.client(
        's3',
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        aws_session_token=AWS_SESSION_TOKEN,
        region_name=AWS_DEFAULT_REGION
    )

    # Tenta deletar o arquivo anterior se existir
    try:
        s3.delete_object(Bucket=BUCKET, Key=ARQUIVO_S3)
        print(f"🗑️ Arquivo anterior deletado de s3://{BUCKET}/{ARQUIVO_S3}")
    except s3.exceptions.ClientError as e:
        if e.response['Error']['Code'] != 'NoSuchKey':
            raise e

    s3.upload_file(ARQUIVO_LOCAL, BUCKET, ARQUIVO_S3)
    print(f"✅ Arquivo enviado com sucesso para s3://{BUCKET}/{ARQUIVO_S3}")

    # Remove o arquivo local após o upload
    os.remove(ARQUIVO_LOCAL)
    print(f"🧹 Arquivo local {ARQUIVO_LOCAL} removido após upload.")

except Exception as e:
    raise RuntimeError(f"❌ Falha ao enviar para o S3: {e}")
