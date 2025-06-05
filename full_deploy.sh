#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY no EC2 - versão universal e definitiva"

# --- CRIA DIRETÓRIO NO VOLUME GRANDE SE NÃO EXISTIR ---
if [ ! -d "/mnt/data/techchallenge4_bruna" ]; then
    echo "📂 Criando diretório de trabalho no volume com espaço..."
    mkdir -p /mnt/data/techchallenge4_bruna
    cd /mnt/data
    git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
else
    echo "✅ Diretório de trabalho já existe"
    cd /mnt/data/techchallenge4_bruna
    git reset --hard origin/main
    git pull || true
fi

# --- VALIDANDO DOCKER ---
if ! command -v docker &> /dev/null; then
    echo "🐳 Instalando Docker..."
    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start || sudo systemctl start docker
    sudo usermod -aG docker ec2-user
else
    echo "✅ Docker já instalado"
    sudo service docker start || sudo systemctl start docker
fi

# --- VALIDANDO MINICONDA ---
if [ ! -d "$HOME/miniconda3" ]; then
    echo "📦 Instalando Miniconda..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
    bash ~/miniconda.sh -b -p $HOME/miniconda3
    echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
else
    echo "✅ Miniconda já instalado"
fi

# --- GARANTE QUE O CONDA ESTÁ ATIVADO NO CONTEXTO DO SCRIPT ---
source ~/miniconda3/etc/profile.d/conda.sh
conda activate base
export PATH="$HOME/miniconda3/bin:$PATH"

# --- INSTALA MAMBA (caso não tenha) ---
if ! conda list | grep -q mamba; then
    echo "🚀 Instalando mamba (mais rápido que conda puro)..."
    conda install -n base -c conda-forge mamba -y
else
    echo "✅ Mamba já instalado"
fi

# --- GARANTIR QUE NÃO ESTÁ EM NENHUM ENV ---
conda deactivate || true

# --- (RE)CRIA ENVIRONMENT ---
if conda info --envs | grep -q lstm-pipeline; then
    echo "♻️ Ambiente lstm-pipeline já existe, removendo para recriar..."
    mamba env remove -n lstm-pipeline -y || true
fi

echo "🚧 Criando o environment lstm-pipeline..."
mamba env create -f environment.yml

# --- ATIVA ENVIRONMENT ---
echo "✅ Ativando o environment lstm-pipeline"
conda activate lstm-pipeline

# --- EXECUTA PIPELINE DE COLETA E TREINO ---
echo "📥 Executando coleta de dados e treino de modelo..."
python data/coleta.py
python model/treino_modelo.py

# --- DOCKER BUILD ---
echo "🐳 (Re)subindo aplicação Docker..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true
docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY concluído com sucesso!"
