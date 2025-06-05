#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY no EC2 - versão definitiva (clean & robusta)"

########################################
# 1️⃣ Instala Git (apenas se ainda não tiver)
########################################

if ! command -v git &> /dev/null; then
    echo "⚠️ Git não encontrado. Instalando..."
    sudo yum update -y
    sudo yum install git -y
fi

########################################
# 2️⃣ Valida Miniconda
########################################

if [ ! -f ~/miniconda3/etc/profile.d/conda.sh ]; then
    echo "⚠️ Miniconda não encontrado. Instalando..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda3
    rm miniconda.sh
fi

source ~/miniconda3/etc/profile.d/conda.sh

########################################
# 3️⃣ Cria (se necessário) e ativa o environment Conda
########################################

if ! conda info --envs | grep -q "lstm-pipeline"; then
    echo "⚠️ Environment lstm-pipeline não encontrado. Criando..."
    conda env create -f environment.yml
else
    echo "✅ Environment lstm-pipeline já existe."
fi

conda activate lstm-pipeline

########################################
# 4️⃣ Atualiza variáveis de ambiente (auto_env)
########################################

echo "📄 Executando auto_env.py para atualizar credenciais..."
python3 auto_env.py

# Garante chaves fixas
if ! grep -q "USE_S3" .env; then
    echo "USE_S3=true" >> .env
fi

if ! grep -q "ALPHAVANTAGE_API_KEY" .env; then
    echo "ALPHAVANTAGE_API_KEY=L2MMCXP58F5Y5F9K" >> .env
fi

export $(grep -v '^#' .env | xargs)

########################################
# 5️⃣ Valida Docker
########################################

if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker não encontrado. Instalando..."
    sudo yum update -y
    sudo yum install docker -y
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ec2-user
    newgrp docker
fi

########################################
# 6️⃣ Executa pipeline de coleta + treino
########################################

echo "📥 Coletando dados e treinando modelo..."
python3 data/coleta.py
python3 model/treino_modelo.py

########################################
# 7️⃣ Builda e reinicia o container Docker
########################################

echo "🐳 Subindo Docker atualizado..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true

docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

docker ps

echo "✅ FULL DEPLOY FINALIZADO COM SUCESSO!"
