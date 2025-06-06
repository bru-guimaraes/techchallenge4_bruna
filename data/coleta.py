import os
import pandas as pd
import yfinance as yf
from alpha_vantage.timeseries import TimeSeries

# Ativo a ser coletado
ATIVO = "AAPL"
ARQUIVO_LOCAL = f"data/{ATIVO}_fechamento.parquet"
ARQUIVO_S3 = f"acoes/{ATIVO}_fechamento.parquet"

# Carrega variáveis de ambiente
USE_S3 = os.getenv("USE_S3", "false").lower() == "true"
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")
BUCKET = os.getenv("BUCKET_NAME", "bdadostchallengebruna")
ALPHAVANTAGE_API_KEY = os.getenv("ALPHAVANTAGE_API_KEY")

df = None

# 1️⃣ Primeiro tenta via yfinance
try:
    print(f"📥 Tentando coletar via yfinance para {ATIVO}...")
    df = yf.download(ATIVO, period="1y", interval="1d")
    if df.empty:
        raise ValueError("Sem dados no yfinance.")
    df.reset_index(inplace=True)
    print("✅ Dados coletados via yfinance.")
except Exception as e:
    print(f"⚠ Erro no yfinance: {e}")
    df = None

# 2️⃣ Se falhar, tenta via Alpha Vantage, só se a chave estiver configurada
if df is None:
    if ALPHAVANTAGE_API_KEY:
        print(f"📥 Tentando coletar via Alpha Vantage para {ATIVO} com chave API presente...")
        try:
            ts = TimeSeries(key=ALPHAVANTAGE_API_KEY, output_format='pandas')
            data, meta = ts.get_daily(symbol=ATIVO, outputsize='compact')
            data.reset_index(inplace=True)
            # Padroniza colunas para ficar igual yfinance
            data.rename(columns={
                "date": "Date",
                "1. open": "Open",
                "2. high": "High",
                "3. low": "Low",
                "4. close": "Close",
                "5. volume": "Volume"
            }, inplace=True)
            df = data
            print("✅ Dados coletados via Alpha Vantage.")
        except Exception as e:
            print(f"⚠ Erro no Alpha Vantage: {e}")
            df = None
    else:
        print("⚠ ALPHAVANTAGE_API_KEY não definida, pulando Alpha Vantage.")

# 3️⃣ Se tudo falhar, usa mock
if df is None:
    print("⚠ Utilizando MOCK como fallback...")
    df = pd.DataFrame({
        'Date': pd.date_range(end=pd.Timestamp.today(), periods=10),
        'Open': range(10),
        'High': range(10),
        'Low': range(10),
        'Close': range(10),
        'Volume': range(10)
    })
    print("🚩 Fonte final de dados utilizada: mock.")

# Salva localmente
os.makedirs("data", exist_ok=True)
df.to_parquet(ARQUIVO_LOCAL, index=False)
print(f"✅ Arquivo local salvo em {ARQUIVO_LOCAL}")

# Upload ao S3 só se USE_S3=true
if USE_S3:
    import boto3
    import botocore.exceptions

    if not AWS_ACCESS_KEY_ID or not AWS_SECRET_ACCESS_KEY:
        raise EnvironmentError("❌ Credenciais AWS ausentes ou mal definidas no .env.")

    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        aws_session_token=AWS_SESSION_TOKEN
    )
    s3 = session.client("s3")

    try:
        print("☁️ Enviando para o S3...")
        s3.upload_file(ARQUIVO_LOCAL, BUCKET, ARQUIVO_S3)
        print(f"✅ Arquivo enviado com sucesso para s3://{BUCKET}/{ARQUIVO_S3}")
    except Exception as e:
        raise RuntimeError(f"❌ Falha ao enviar para o S3: {e}")

    os.remove(ARQUIVO_LOCAL)
    print(f"🧹 Arquivo local {ARQUIVO_LOCAL} removido após upload.")
