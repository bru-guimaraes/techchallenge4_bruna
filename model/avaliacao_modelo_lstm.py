import numpy as np
import pandas as pd
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import load_model
import boto3
import os
from dotenv import load_dotenv
import io
from sklearn.metrics import mean_absolute_error, mean_squared_error

# Carrega variáveis do .env
load_dotenv()

# Parâmetros
BUCKET = "bdadostchallengebruna"
ARQUIVO_S3 = "acoes/AAPL_fechamento.parquet"
MODELO_LOCAL = "model/modelo_lstm.keras"
MODELO_S3 = "modelos/modelo_lstm.keras"

try:
    aws_access_key = os.getenv("AWS_ACCESS_KEY_ID")
    aws_secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
    aws_session_token = os.getenv("AWS_SESSION_TOKEN")
    aws_region = os.getenv("AWS_DEFAULT_REGION")

    if not all([aws_access_key, aws_secret_key, aws_region]):
        raise EnvironmentError("❌ Variáveis de ambiente AWS não estão completamente definidas.")

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
    print("🔄 Normalizando dados...")
    df = df[['Close']].dropna()
    scaler = MinMaxScaler()
    scaled_data = scaler.fit_transform(df)

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
    # Baixa modelo do S3 se não estiver local
    if not os.path.exists(MODELO_LOCAL):
        try:
            print("☁️ Baixando modelo do S3...")
            s3.download_file(BUCKET, MODELO_S3, MODELO_LOCAL)
            print("✅ Modelo baixado com sucesso.")
        except Exception as e:
            raise FileNotFoundError(f"❌ Erro ao baixar o modelo do S3: {e}")

    print("📊 Avaliando modelo com dados do S3...")
    model = load_model(MODELO_LOCAL)
    previsoes = model.predict(X)
    previsoes = scaler.inverse_transform(previsoes)
    y_true = scaler.inverse_transform(y.reshape(-1, 1))

    mae = mean_absolute_error(y_true, previsoes)
    rmse = np.sqrt(mean_squared_error(y_true, previsoes))
    mape = np.mean(np.abs((y_true - previsoes) / y_true)) * 100

    print("\n📈 Avaliação do Modelo:")
    print(f"MAE : {mae:.4f}")
    print(f"RMSE: {rmse:.4f}")
    print(f"MAPE: {mape:.2f}%")

except FileNotFoundError as e:
    raise RuntimeError(f"Erro durante a avaliação do modelo: {e}")
except Exception as e:
    raise RuntimeError(f"Erro inesperado durante a avaliação: {e}")
