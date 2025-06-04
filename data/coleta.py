import pandas as pd
import boto3
import os
import time
import requests
import yfinance as yf
from dotenv import load_dotenv

# Carrega variáveis do .env
load_dotenv()

# Variáveis AWS
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")
AWS_DEFAULT_REGION = os.getenv("AWS_DEFAULT_REGION")

# Variáveis gerais
TICKER = "AAPL"
BUCKET = "bdadostchallengebruna"
ARQUIVO_LOCAL = f"data/{TICKER}_fechamento.parquet"
ARQUIVO_S3 = f"acoes/{TICKER}_fechamento.parquet"

# Alpha Vantage
ALPHA_VANTAGE_API_KEY = os.getenv("ALPHA_VANTAGE_API_KEY")
ALPHA_VANTAGE_URL = f"https://www.alphavantage.co/query?function=TIME_SERIES_DAILY_ADJUSTED&symbol={TICKER}&apikey={ALPHA_VANTAGE_API_KEY}&outputsize=full"

# Função de fallback yfinance
def coleta_yfinance():
    print(f"📥 Tentando coletar via yfinance para {TICKER}...")
    try:
        df = yf.download(TICKER, period="5y", interval="1d")
        if df.empty:
            raise ValueError("Sem dados no yfinance.")
        print("✅ Coleta via yfinance bem-sucedida.")
        return df[['Close']].dropna()
    except Exception as e:
        print(f"⚠ Erro no yfinance: {e}")
        return None

# Função de fallback Alpha Vantage
def coleta_alpha_vantage():
    print(f"📥 Tentando coletar via Alpha Vantage para {TICKER}...")
    try:
        response = requests.get(ALPHA_VANTAGE_URL)
        data = response.json()

        if "Time Series (Daily)" not in data:
            raise ValueError("Sem dados no Alpha Vantage.")

        ts = data["Time Series (Daily)"]
        df = pd.DataFrame.from_dict(ts, orient="index")
        df.index = pd.to_datetime(df.index)
        df = df.rename(columns={"4. close": "Close"})
        df["Close"] = df["Close"].astype(float)
        print("✅ Coleta via Alpha Vantage bem-sucedida.")
        return df[["Close"]].sort_index()
    except Exception as e:
        print(f"⚠ Erro no Alpha Vantage: {e}")
        return None

# Função de fallback mock
def gera_mock():
    print("⚠ Utilizando MOCK como fallback...")
    df = pd.DataFrame({
        'Close': [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20] * 30
    }, index=pd.date_range(start='2015-01-01', periods=330, freq='D'))
    return df

# Pipeline de coleta com fonte registrada
fonte_dados = None

df = coleta_yfinance()
if df is not None:
    fonte_dados = "yfinance"
else:
    df = coleta_alpha_vantage()
    if df is not None:
        fonte_dados = "alpha"
    else:
        df = gera_mock()
        fonte_dados = "mock"

# Grava fonte para ser usada no treino
os.makedirs("data", exist_ok=True)
with open("data/fonte_dados.txt", "w") as f:
    f.write(fonte_dados)

# Salva localmente o dataset
df.to_parquet(ARQUIVO_LOCAL, index=True)
print(f"✅ Arquivo local salvo em {ARQUIVO_LOCAL}")

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

    try:
        s3.delete_object(Bucket=BUCKET, Key=ARQUIVO_S3)
        print(f"🗑️ Arquivo anterior deletado de s3://{BUCKET}/{ARQUIVO_S3}")
    except s3.exceptions.ClientError as e:
        if e.response['Error']['Code'] != 'NoSuchKey':
            raise e

    s3.upload_file(ARQUIVO_LOCAL, BUCKET, ARQUIVO_S3)
    print(f"✅ Arquivo enviado com sucesso para s3://{BUCKET}/{ARQUIVO_S3}")

    os.remove(ARQUIVO_LOCAL)
    print(f"🧹 Arquivo local {ARQUIVO_LOCAL} removido após upload.")

except Exception as e:
    raise RuntimeError(f"❌ Falha ao enviar para o S3: {e}")
