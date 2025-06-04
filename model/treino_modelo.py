import pandas as pd
import numpy as np
import boto3
import io
import joblib
import sys
import os
from dotenv import load_dotenv
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense

# Permite importar do utils
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from utils.preprocessamento import normalizar_dados, criar_janelas

# Carrega variáveis de ambiente
load_dotenv()

AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")
AWS_DEFAULT_REGION = os.getenv("AWS_DEFAULT_REGION")
BUCKET = "bdadostchallengebruna"

# Carrega a fonte de dados utilizada
try:
    with open("data/fonte_dados.txt", "r") as f:
        fonte_dados = f.read().strip()
except Exception:
    fonte_dados = "indefinida"

# Define os nomes de arquivos com base na fonte
modelo_filename = f"model_lstm_{fonte_dados}.h5"
scaler_filename = f"scaler_{fonte_dados}.gz"

# Ticker (mantemos o mesmo para consistência)
TICKER = "AAPL"
ARQUIVO_S3 = f"acoes/{TICKER}_fechamento.parquet"

if not all([AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION]):
    raise EnvironmentError("❌ Credenciais AWS ausentes ou mal definidas no .env.")

# Cliente S3
s3 = boto3.client(
    's3',
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    aws_session_token=AWS_SESSION_TOKEN,
    region_name=AWS_DEFAULT_REGION
)

# Busca os dados no S3
print("☁️ Lendo dados do S3...")
try:
    obj = s3.get_object(Bucket=BUCKET, Key=ARQUIVO_S3)
    df = pd.read_parquet(io.BytesIO(obj['Body'].read()))
except Exception as e:
    raise RuntimeError(f"Erro ao acessar dados do S3: {e}")

# Pré-processamento
print("🔄 Normalizando dados...")
dados_normalizados, scaler = normalizar_dados(df[['Close']].values)
X, y = criar_janelas(dados_normalizados, look_back=60)
X = X.reshape((X.shape[0], X.shape[1], 1))

# Treinamento
print("🧠 Treinando modelo LSTM...")
model = Sequential()
model.add(LSTM(50, return_sequences=True, input_shape=(X.shape[1], 1)))
model.add(LSTM(50))
model.add(Dense(1))
model.compile(optimizer='adam', loss='mean_squared_error')
model.fit(X, y, epochs=20, batch_size=32)

# Salva localmente
os.makedirs("model", exist_ok=True)
model.save(f"model/{modelo_filename}")
joblib.dump(scaler, f"model/{scaler_filename}")
print(f"💾 Modelo salvo como model/{modelo_filename}")
print(f"💾 Scaler salvo como model/{scaler_filename}")

# Envia scaler para o S3
print("☁️ Enviando scaler para o S3...")
try:
    s3.upload_file(f"model/{scaler_filename}", BUCKET, f"modelos/{scaler_filename}")
    print(f"✅ Scaler enviado para s3://{BUCKET}/modelos/{scaler_filename}")
except Exception as e:
    raise RuntimeError(f"Erro ao enviar scaler para o S3: {e}")

# Envia modelo para o S3
print("☁️ Enviando modelo para o S3...")
try:
    s3.upload_file(f"model/{modelo_filename}", BUCKET, f"modelos/{modelo_filename}")
    print(f"✅ Modelo enviado para s3://{BUCKET}/modelos/{modelo_filename}")
except Exception as e:
    raise RuntimeError(f"Erro ao enviar modelo para o S3: {e}")
