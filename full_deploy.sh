#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY no EC2 - versão definitiva Git-centric!"

########################################
# 1️⃣ Valida Miniconda
########################################

if [ ! -f ~/miniconda3/etc/profile.d/conda.sh ]; then
    echo "⚠️ Miniconda não encontrado. Instalando..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda3
    rm miniconda.sh
fi

# Só agora podemos dar o source
source ~/miniconda3/etc/profile.d/conda.sh

########################################
# 2️⃣ Valida environment Conda via environment.yml
########################################

if ! conda info --envs | grep -q "lstm-pipeline"; then
    echo "⚠️ Environment lstm-pipeline não encontrado. Criando..."
    conda env create -f environment.yml
else
    echo "✅ Environment lstm-pipeline já existe."
fi

conda activate lstm-pipeline

########################################
# 3️⃣ Executa auto_env.py
########################################

echo "📄 Executando auto_env.py para atualizar credenciais e IP..."
python3 auto_env.py

# Garante as variáveis fixas (por segurança extra)
if ! grep -q "USE_S3" .env; then
    echo "USE_S3=true" >> .env
fi

if ! grep -q "ALPHAVANTAGE_API_KEY" .env; then
    echo "ALPHAVANTAGE_API_KEY=L2MMCXP58F5Y5F9K" >> .env
fi

export $(grep -v '^#' .env | xargs)

########################################
# 4️⃣ Limpa diretório de projeto antigo
########################################

echo "🧹 Limpando código antigo (preservando .env)..."
find . -mindepth 1 -maxdepth 1 ! -name '.env' -exec rm -rf {} +

########################################
# 5️⃣ Sempre clona do GitHub (main branch)
########################################

echo "🌐 Clonando projeto atualizado do GitHub..."
git clone -b main https://github.com/bru-guimaraes/techchallenge4_bruna.git repo_clone

# Move o conteúdo da pasta clone para o diretório raiz
mv repo_clone/* .
mv repo_clone/.* . 2>/dev/null || true
rm -rf repo_clone

echo "✅ Código atualizado a partir do GitHub"

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
    newgrp docker
fi

########################################
# 7️⃣ Executa pipeline
########################################

echo "📥 Coletando dados e treinando modelo..."
python3 data/coleta.py
python3 model/treino_modelo.py

########################################
# 8️⃣ Builda e reinicia o container Docker
########################################

echo "🐳 Subindo Docker atualizado..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true

docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

docker ps

echo "✅ FULL DEPLOY FINALIZADO COM SUCESSO!"
