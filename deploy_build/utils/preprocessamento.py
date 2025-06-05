from sklearn.preprocessing import MinMaxScaler
import numpy as np

def normalizar_dados(dados):
    scaler = MinMaxScaler()
    return scaler.fit_transform(dados), scaler

def criar_janelas(dados, look_back=60):
    X, y = [], []
    for i in range(look_back, len(dados)):
        X.append(dados[i-look_back:i, 0])
        y.append(dados[i, 0])
    return np.array(X), np.array(y)
