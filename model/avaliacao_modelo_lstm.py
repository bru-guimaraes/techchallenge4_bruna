import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import load_model
import boto3
import os
from dotenv import load_dotenv
import io

# Carrega variáveis do .env
load_dotenv()

# Parâmetros
BUCKET = "bdadostchallengebruna"
ARQUIVO_S3 = "acoes/AAPL_fechamento.parquet"
MODELO_PATH = "model/modelo_lstm.keras"

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
    print("📊 Avaliando modelo com dados do S3...")
    df = df[['Close']].dropna()
    if df.empty:
        raise ValueError("❌ Série temporal está vazia após remoção de valores nulos.")

    scaler = MinMaxScaler()
    scaled_data = scaler.fit_transform(df)

    # Divide em treino e validação
    look_back = 60
    if len(scaled_data) <= look_back:
        raise ValueError("❌ Dados insuficientes para formar janelas temporais com look_back.")

    train_size = int(len(scaled_data) * 0.8)
    test_data = scaled_data[train_size - look_back:]

    def criar_dataset(dataset, look_back):
        X, y = [], []
        for i in range(look_back, len(dataset)):
            X.append(dataset[i - look_back:i, 0])
            y.append(dataset[i, 0])
        return np.array(X), np.array(y)

    X_test, y_test = criar_dataset(test_data, look_back)
    if len(X_test) == 0:
        raise ValueError("❌ Nenhum dado foi gerado para teste.")

    X_test = np.reshape(X_test, (X_test.shape[0], X_test.shape[1], 1))

except Exception as e:
    raise RuntimeError(f"Erro no pré-processamento dos dados: {e}")

try:
    # Verifica se modelo existe
    if not os.path.exists(MODELO_PATH):
        raise FileNotFoundError(f"❌ Modelo não encontrado em {MODELO_PATH}.")

    # Carrega modelo
    model = load_model(MODELO_PATH)

    # Predição e avaliação
    y_pred = model.predict(X_test)
    y_test_inv = scaler.inverse_transform(y_test.reshape(-1, 1))
    y_pred_inv = scaler.inverse_transform(y_pred)

    mae = mean_absolute_error(y_test_inv, y_pred_inv)
    rmse = mean_squared_error(y_test_inv, y_pred_inv, squared=False)
    mape = np.mean(np.abs((y_test_inv - y_pred_inv) / y_test_inv)) * 100

    print(f"\n📈 Avaliação do Modelo:")
    print(f"MAE : {mae:.4f}")
    print(f"RMSE: {rmse:.4f}")
    print(f"MAPE: {mape:.2f}%")

except Exception as e:
    raise RuntimeError(f"Erro durante a avaliação do modelo: {e}")
