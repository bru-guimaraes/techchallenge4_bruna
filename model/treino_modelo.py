import numpy as np
import pandas as pd
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
import joblib
import boto3
import os
from dotenv import load_dotenv
import io

# Carrega variáveis do .env
load_dotenv()

# Parâmetros
BUCKET = "bdadostchallengebruna"
ARQUIVO_S3 = "acoes/AAPL_fechamento.parquet"
SCALER_LOCAL = "model/scaler.gz"
SCALER_S3 = "modelos/scaler.gz"

try:
    # Verifica se credenciais estão definidas
    aws_access_key = os.getenv("AWS_ACCESS_KEY_ID")
    aws_secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
    aws_session_token = os.getenv("AWS_SESSION_TOKEN")
    aws_region = os.getenv("AWS_DEFAULT_REGION")

    if not all([aws_access_key, aws_secret_key, aws_region]):
        raise EnvironmentError("❌ Variáveis de ambiente AWS não estão completamente definidas.")

    # Inicializa cliente S3
    s3 = boto3.client(
        's3',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        aws_session_token=aws_session_token,
        region_name=aws_region
    )

    print("☁️ Lendo dados do S3...")
    obj = s3.get_object(Bucket=BUCKET, Key=ARQUIVO_S3)
    df = pd.read_parquet(io.BytesIO(obj['Body'].read()))

    if df.empty:
        raise ValueError("❌ O DataFrame lido do S3 está vazio.")

except Exception as e:
    raise RuntimeError(f"Erro ao acessar dados do S3: {e}")

try:
    # Pré-processamento
    print("🔄 Normalizando dados...")
    df = df[['Close']].dropna()
    scaler = MinMaxScaler()
    scaled_data = scaler.fit_transform(df)

    # Cria janelas de tempo
    def criar_dataset(dataset, look_back=60):
        X, y = [], []
        for i in range(look_back, len(dataset)):
            X.append(dataset[i-look_back:i, 0])
            y.append(dataset[i, 0])
        return np.array(X), np.array(y)

    X, y = criar_dataset(scaled_data)
    X = np.reshape(X, (X.shape[0], X.shape[1], 1))

except Exception as e:
    raise RuntimeError(f"Erro no pré-processamento dos dados: {e}")

try:
    # Modelo
    print("🧠 Treinando modelo LSTM...")
    model = Sequential()
    model.add(LSTM(units=50, return_sequences=True, input_shape=(X.shape[1], 1)))
    model.add(LSTM(units=50))
    model.add(Dense(1))
    model.compile(optimizer='adam', loss='mean_squared_error')
    model.fit(X, y, epochs=20, batch_size=32)

    # Salva modelo e scaler
    os.makedirs("model", exist_ok=True)
    print("💾 Salvando modelo em model/modelo_lstm.keras")
    model.save('model/modelo_lstm.keras')

    print("💾 Salvando scaler em model/scaler.gz")
    joblib.dump(scaler, SCALER_LOCAL)

    print("☁️ Enviando scaler para o S3...")
    s3.upload_file(SCALER_LOCAL, BUCKET, SCALER_S3)
    print(f"✅ Scaler enviado para s3://{BUCKET}/{SCALER_S3}")

except Exception as e:
    raise RuntimeError(f"Erro durante o treinamento ou salvamento do modelo: {e}")
