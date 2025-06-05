#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY no EC2 - versão blindada e definitiva"

# --- PRE-REQUISITOS BÁSICOS ---
echo "🔧 Validando pré-requisitos..."
sudo yum update -y
sudo yum install -y git docker gcc g++ make

# --- DOCKER ---
echo "🐳 Validando Docker..."
sudo service docker start || sudo systemctl start docker
sudo usermod -aG docker ec2-user

# --- MINICONDA ---
if [ ! -d "$HOME/miniconda3" ]; then
    echo "📦 Instalando Miniconda..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
    bash ~/miniconda.sh -b -p $HOME/miniconda3
    echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
else
    echo "✅ Miniconda já instalado"
fi

# --- ATIVA CONDA ---
source ~/miniconda3/etc/profile.d/conda.sh

# --- INSTALA MAMBA (melhor que conda puro) ---
echo "🚀 Instalando mamba (gerenciador rápido de envs)..."
conda install -n base -c conda-forge mamba -y

# --- CLONA OU ATUALIZA REPO ---
cd ~
if [ ! -d "$HOME/techchallenge4_bruna" ]; then
    echo "🌐 Clonando projeto do GitHub..."
    git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
else
    echo "🔄 Atualizando projeto do GitHub..."
    cd techchallenge4_bruna
    git reset --hard origin/main   # força ficar igual ao remoto
    git pull || true
fi
cd ~/techchallenge4_bruna

# --- GARANTIR QUE NÃO ESTÁ EM NENHUM ENV ---
echo "🚧 Garantindo ambiente limpo antes de remover environment..."
conda deactivate || true

# --- (RE)CRIA ENVIRONMENT ---
echo "♻️ (Re)criando o environment lstm-pipeline..."
if conda info --envs | grep -q lstm-pipeline; then
    echo "⚠️ Ambiente lstm-pipeline já existe, removendo..."
    mamba env remove -n lstm-pipeline -y || true
fi

mamba env create -f environment.yml

# --- ATIVA ENVIRONMENT ---
echo "✅ Ativando o environment lstm-pipeline"
source ~/miniconda3/etc/profile.d/conda.sh
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
