# ───────────────────────────────────────────────────────
# ETAPA 1: BUILDER (instala tudo em /deps sem poluir o runtime)
# ───────────────────────────────────────────────────────
FROM python:3.10-slim AS builder

WORKDIR /build

# 1. Instala apenas o que for necessário para compilar algumas wheels (ex.: TensorFlow)
RUN apt-get update && apt-get install -y \
      build-essential \
      gcc \
      libgl1 \
      libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 2. Copia apenas o requirements.txt para reduzir contexto de build
COPY requirements.txt .

# 3. Define variáveis para pip não criar cache em /root/.cache
ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# 4. Instala em /build/deps (não em site-packages do sistema), para mover só o que precisa
RUN pip install --upgrade pip && \
    pip install \
      --no-cache-dir \
      --target=/build/deps \
        tensorflow==2.15.0 \
        fastapi==0.115.1 \
        "uvicorn[standard]==0.34.1" \
        pydantic==2.11.5 \
        boto3==1.34.103 \
        joblib==1.3.2

# ───────────────────────────────────────────────────────
# ETAPA 2: RUNTIME (imagem enxuta, só com o necessário)
# ───────────────────────────────────────────────────────
FROM python:3.10-slim

WORKDIR /app

# 1. Copia apenas os pacotes Python instalados no builder
COPY --from=builder /build/deps /usr/local/lib/python3.10/site-packages

# 2. Cria pasta para salvar o modelo
RUN mkdir -p /app/model

# 3. Copia somente o código da API e os artefatos do modelo (já gerados em 'model/')
COPY app/       ./app/
COPY model/     ./model/
COPY requirements.txt .

# 4. Remove caches de apt e pip para liberar espaço (não removemos build-essential/gcc,
#    pois eles não existem na runtime)
RUN rm -rf /var/lib/apt/lists/* /root/.cache

# 5. Expõe porta 80
EXPOSE 80

# 6. Define o entrypoint para iniciar o FastAPI
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]
