import os
import pandas as pd
import joblib
import numpy as np
from sklearn.preprocessing import MinMaxScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, mean_absolute_error
from tensorflow import keras

ATIVO = "AAPL"
ARQUIVO_LOCAL = f"data/{ATIVO}_fechamento.parquet"
ARQUIVO_S3 = f"acoes/{ATIVO}_fechamento.parquet"
BUCKET = os.getenv("BUCKET_NAME", "bdadostchallengebruna")

USE_S3 = os.getenv("USE_S3", "false").lower() == "true"

if USE_S3:
    import boto3

    AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
    AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
    AWS_SESSION_TOKEN = os.getenv("AWS_SESSION_TOKEN")

    if not AWS_ACCESS_KEY_ID or not AWS_SECRET_ACCESS_KEY:
        raise EnvironmentError("❌ Credenciais AWS ausentes ou mal definidas no .env.")

    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        aws_session_token=AWS_SESSION_TOKEN
    )
    s3 = session.client("s3")

    print("☁️ Lendo dados do S3...")
    try:
        obj = s3.get_object(Bucket=BUCKET, Key=ARQUIVO_S3)
        df = pd.read_parquet(obj['Body'])
    except Exception as e:
        raise RuntimeError(f"Erro ao acessar dados do S3: {e}")

else:
    print("📄 Lendo dados localmente...")
    if not os.path.exists(ARQUIVO_LOCAL):
        raise FileNotFoundError(f"Arquivo {ARQUIVO_LOCAL} não encontrado para treinamento.")
    df = pd.read_parquet(ARQUIVO_LOCAL)

# Verificação básica do dataframe e correções
if "Date" not in df.columns:
    raise KeyError("Coluna 'Date' não encontrada no dataframe para treino.")

print(f"✅ Dataframe carregado com {len(df)} linhas.")

df.sort_values(by="Date", inplace=True)

# Garantir que 'Close' é numérico
df['Close'] = pd.to_numeric(df['Close'], errors='coerce')

# Remover linhas com NaN
df.dropna(subset=['Close'], inplace=True)

if df.empty:
    raise ValueError("Dataframe está vazio após remoção de NaNs na coluna 'Close'.")

print(f"✅ Dataframe após limpeza tem {len(df)} linhas.")

# Escalar valores de 'Close'
scaler = MinMaxScaler()
df['Close_Scaled'] = scaler.fit_transform(df[['Close']])

# Função para criar sequências para LSTM
def criar_sequencias(series, janela):
    X, y = [], []
    for i in range(len(series) - janela):
        X.append(series[i:i+janela])
        y.append(series[i+janela])
    return np.array(X), np.array(y)

janela = 30
serie = df['Close_Scaled'].values
X, y = criar_sequencias(serie, janela)
X = X.reshape((X.shape[0], X.shape[1], 1))

# Separar dados treino/teste
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, shuffle=False)

# Criar modelo LSTM simples
model = keras.Sequential([
    keras.layers.Input(shape=(X_train.shape[1], 1)),
    keras.layers.LSTM(50, return_sequences=False),
    keras.layers.Dense(1)
])
model.compile(optimizer='adam', loss='mse')

print("🚀 Iniciando treino do modelo...")
model.fit(X_train, y_train, epochs=10, batch_size=16, verbose=1)

# Avaliar modelo
pred = model.predict(X_test)
rmse = np.sqrt(mean_squared_error(y_test, pred))
mae = mean_absolute_error(y_test, pred)
print(f"📊 RMSE: {rmse:.4f} | MAE: {mae:.4f}")

# Salvar modelo e scaler
os.makedirs("model", exist_ok=True)
model.save("model/modelo_lstm.keras")
joblib.dump(scaler, "model/scaler.gz")
print("✅ Modelo e scaler salvos com sucesso.")
