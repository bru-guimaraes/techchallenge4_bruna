# Dockerfile

FROM python:3.10-slim

# ----------------------------------------------------
# 1) Instale ferramentas de compilação e bibliotecas do sistema
# ----------------------------------------------------
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    libgl1 \
    libglib2.0-0 \
  && rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------
# 2) Defina o diretório de trabalho
# ----------------------------------------------------
WORKDIR /app

# ----------------------------------------------------
# 3) Crie a pasta onde o modelo e o scaler ficarão
# ----------------------------------------------------
RUN mkdir -p /app/model

# ----------------------------------------------------
# 4) Copiar todo o código-fonte (incluindo
#    app/, model/, requirements.txt etc.)
# ----------------------------------------------------
COPY . .

# ----------------------------------------------------
# 5) Atualizar pip antes de instalar dependências
# ----------------------------------------------------
RUN pip install --upgrade pip

# ----------------------------------------------------
# 6) Instalar todas as dependências Python necessárias
#    (use --no-cache-dir para evitar cache desnecessário)
# ----------------------------------------------------
RUN pip install --no-cache-dir \
    numpy==1.26.4 \
    scikit-learn==1.3.2 \
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
# 7) Expor a porta 80
# ----------------------------------------------------
EXPOSE 80

# ----------------------------------------------------
# 8) Comando de inicialização: Uvicorn usando
#    app.main:app (conforme seu app/main.py)
# ----------------------------------------------------
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]
