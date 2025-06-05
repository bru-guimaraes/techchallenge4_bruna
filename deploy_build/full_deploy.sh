#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY no EC2 - versão blindada!"

########################################
# 1️⃣ Valida Miniconda
########################################

if [ ! -f ~/miniconda3/etc/profile.d/conda.sh ]; then
    echo "⚠️ Miniconda não encontrado. Instalando..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda3
    rm miniconda.sh
fi

# Ativa Conda
source ~/miniconda3/etc/profile.d/conda.sh

########################################
# 2️⃣ Valida environment Conda
########################################

if ! conda info --envs | grep -q "lstm-pipeline"; then
    echo "⚠️ Environment lstm-pipeline não encontrado. Criando..."
    conda create -y -n lstm-pipeline python=3.10
    conda activate lstm-pipeline
    pip install --upgrade pip
    pip install -r requirements.txt
else
    conda activate lstm-pipeline
fi

########################################
# 3️⃣ Executa auto_env
########################################

echo "📄 Executando auto_env.py para atualizar credenciais e IP..."
python3 auto_env.py

# Garante as variáveis fixas
if ! grep -q "USE_S3" .env; then
    echo "USE_S3=true" >> .env
fi

if ! grep -q "ALPHAVANTAGE_API_KEY" .env; then
    echo "ALPHAVANTAGE_API_KEY=L2MMCXP58F5Y5F9K" >> .env
fi

export $(grep -v '^#' .env | xargs)

########################################
# 4️⃣ Garante diretórios do projeto
########################################

echo "📁 Garantindo diretórios locais..."
mkdir -p data model utils deploy_build

########################################
# 5️⃣ Busca o projeto
########################################

if [ -f projeto_lstm_acoes_full.zip ]; then
    echo "🎯 Pacote local encontrado."
else
    echo "☁️ Buscando do S3 (se existir)..."
    aws s3 cp s3://$BUCKET_NAME/deploys/projeto_lstm_acoes_full.zip . || echo "⚠️ Pacote não encontrado no S3."
fi

if [ ! -f projeto_lstm_acoes_full.zip ]; then
    echo "🌐 Clonando projeto do GitHub..."
    git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git repo_clone
    cp -r repo_clone/* .
    rm -rf repo_clone
fi

echo "📦 Descompactando..."
unzip -o projeto_lstm_acoes_full.zip

########################################
# 6️⃣ Valida Docker
########################################

if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker não encontrado. Instalando..."
    sudo yum update -y
    sudo yum install docker -y
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ec2-user
fi

# Garante diretório docker externo se quiser usar:
# sudo mkdir -p /data/docker && sudo chown ec2-user:ec2-user /data/docker

########################################
# 7️⃣ Executa pipeline
########################################

echo "📥 Coletando dados e treinando modelo..."
python3 data/coleta.py
python3 model/treino_modelo.py

########################################
# 8️⃣ Reinicia Docker container
########################################

echo "🐳 Subindo Docker..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true

docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

docker ps

echo "✅ FULL DEPLOY finalizado com sucesso!"
