#!/bin/bash
set -e

# Garantir que miniconda esteja sempre no PATH em qualquer shell
export PATH="$HOME/miniconda3/bin:$PATH"

echo "🚀 Iniciando FULL DEPLOY no EC2 - versão blindada e definitiva"

# Garantir git instalado
if ! command -v git &> /dev/null; then
    echo "⚠️ Git não encontrado. Instalando..."
    sudo yum update -y
    sudo yum install git -y
fi

# Auto-atualização via git pull
echo "🔄 Atualizando projeto com git pull..."
git pull
echo "✅ Repositório local atualizado."

# Instalar Miniconda caso ainda não exista
if [ ! -f ~/miniconda3/etc/profile.d/conda.sh ]; then
    echo "⚠️ Miniconda não encontrado. Instalando..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda3
    rm miniconda.sh
fi

source ~/miniconda3/etc/profile.d/conda.sh

# Instalar Mamba turbo resolver
if ! conda list -n base | grep mamba &> /dev/null; then
    echo "⚙️ Instalando mamba..."
    conda install -n base -c conda-forge mamba -y
fi

# Recriar environment sempre blindado
echo "♻️ (Re)criando o environment lstm-pipeline..."
mamba env remove -n lstm-pipeline -y || true
mamba env create -f environment.yml

conda activate lstm-pipeline

# Atualizar variáveis do .env
echo "📄 Executando auto_env.py..."
python3 auto_env.py

# Ajuste de variáveis adicionais (caso ainda não existam)
if ! grep -q "USE_S3" .env; then
    echo "USE_S3=true" >> .env
fi

if ! grep -q "ALPHAVANTAGE_API_KEY" .env; then
    echo "ALPHAVANTAGE_API_KEY=L2MMCXP58F5Y5F9K" >> .env
fi

export $(grep -v '^#' .env | xargs)

# Garantir Docker instalado
if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker não encontrado. Instalando..."
    sudo yum update -y
    sudo yum install docker -y
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ec2-user
    newgrp docker
fi

# Executar pipeline completo
echo "📥 Coletando dados e treinando modelo..."
python3 data/coleta.py
python3 model/treino_modelo.py

# Build e restart do Docker
echo "🐳 Subindo Docker atualizado..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true

docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

docker ps

echo "✅ FULL DEPLOY FINALIZADO COM SUCESSO!"
