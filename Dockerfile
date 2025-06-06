# ----------------------------------------------------
# 1) Etapa de Build (Multi‐stage) para 
#    preparar tudo sem poluir a imagem final
# ----------------------------------------------------
FROM python:3.10-slim AS builder

WORKDIR /build

# 1.1) Instala dependências de sistema que podem ser requeridas por algumas wheels
RUN apt-get update && apt-get install -y \
      build-essential \
      gcc \
      libglu1 \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 1.2) Copia requirements e instala em um diretório próprio
COPY requirements.txt .
# Definimos variáveis para forçar pip a não manter cache
ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

RUN pip install --upgrade pip && \
    pip install \
      --no-cache-dir \
      --target=/build/deps \
      numpy==1.26.4 \
      pandas==2.2.2 \
      joblib==1.3.2 \
      boto3==1.34.103 \
      pyarrow==15.0.2 \
      tensorflow==2.15.0 \
      fastapi==0.115.1 \
      "uvicorn[standard]==0.34.1" \
      pydantic==2.11.5 \
      yfinance==0.2.37 \
      python-dotenv==1.0.1

# ----------------------------------------------------
# 2) Etapa "Runtime" – imagem menor, só com o necessário
# ----------------------------------------------------
FROM python:3.10-slim

WORKDIR /app

# 2.1) Copia a pasta 'deps' do builder (todas as libs instaladas)
COPY --from=builder /build/deps /usr/local/lib/python3.10/site-packages

# 2.2) Cria diretórios para a API e para o model
RUN mkdir -p /app/model

# 2.3) Copia apenas o código-fonte e os artefatos necessários
COPY app/ ./app/
COPY model/modelo_lstm.keras ./model/
COPY model/scaler.gz      ./model/

# 2.4) Garante que não existam caches do apt nem do pip na imagem final
RUN apt-get purge -y build-essential gcc \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /root/.cache

# 2.5) Expõe a porta e define o comando de inicialização
EXPOSE 80

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]
