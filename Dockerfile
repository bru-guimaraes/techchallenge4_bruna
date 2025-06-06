# ───────────────────────────────────────────────────────
# ETAPA 1: BUILDER (instala tudo em /build/deps sem poluir o runtime)
# ───────────────────────────────────────────────────────
FROM python:3.10-slim AS builder

WORKDIR /build

# 1) Instala ferramentas necessárias para compilar partes nativas (ex.: TensorFlow)
RUN apt-get update && apt-get install -y \
      build-essential \
      gcc \
      libgl1 \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 2) Copia apenas requirements.txt (assim o contexto de build fica menor)
COPY requirements.txt .

# 3) Define variáveis para pip não criar cache em /root/.cache
ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# 4) Instala só as libs que precisamos para rodar a inferência
#    Incluímos scikit-learn para poder carregar o scaler
RUN pip install --upgrade pip && \
    pip install \
      --no-cache-dir \
      --target=/build/deps \
        tensorflow==2.15.0 \
        fastapi==0.115.1 \
        "uvicorn[standard]==0.34.1" \
        pydantic==2.11.5 \
        boto3==1.34.103 \
        joblib==1.3.2 \
        scikit-learn==1.3.2

# ───────────────────────────────────────────────────────
# ETAPA 2: RUNTIME (imagem enxuta, só rodar a API + modelo)
# ───────────────────────────────────────────────────────
FROM python:3.10-slim

WORKDIR /app

# 1) Copia as libs instaladas no builder para o site-packages do Python
COPY --from=builder /build/deps /usr/local/lib/python3.10/site-packages

# 2) Cria pasta para o modelo
RUN mkdir -p /app/model

# 3) Copia apenas o código da API (app/) e os artefatos do modelo (model/)
COPY app/   ./app/
COPY model/ ./model/
COPY requirements.txt .

# 4) Limpa caches do apt e do pip para liberar espaço
RUN rm -rf /var/lib/apt/lists/* /root/.cache

# 5) Expõe a porta 80
EXPOSE 80

# 6) Usa “python -m uvicorn” para não depender do script uvicorn no PATH
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]
