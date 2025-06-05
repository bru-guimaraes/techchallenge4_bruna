#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY portátil no EC2"

# --- Atualiza ou clona o projeto ---
if [ ! -d "$HOME/techchallenge4_bruna" ]; then
    echo "📂 Clonando projeto no home..."
    git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git "$HOME/techchallenge4_bruna"
else
    echo "🔄 Atualizando projeto no home..."
    cd "$HOME/techchallenge4_bruna"
    git reset --hard origin/main
    git pull || true
fi

cd "$HOME/techchallenge4_bruna"

# --- Verifica e instala Docker ---
if ! command -v docker &> /dev/null; then
    echo "🐳 Instalando Docker..."
    sudo yum update -y
    sudo yum install -y docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"
else
    echo "✅ Docker já instalado"
    sudo systemctl start docker
fi

# --- Verifica e instala Miniconda ---
if [ ! -d "$HOME/miniconda3" ]; then
    echo "📦 Instalando Miniconda em $HOME/miniconda3..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$HOME/miniconda.sh"
    bash "$HOME/miniconda.sh" -b -p "$HOME/miniconda3"
    rm "$HOME/miniconda.sh"
    echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/miniconda3/bin:$PATH"
else
    echo "✅ Miniconda já instalado"
fi

# --- Carrega conda e ativa base ---
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate base

# --- Verifica e instala mamba ---
if ! command -v mamba &> /dev/null; then
    echo "🚀 Instalando mamba..."
    conda install -n base -c conda-forge mamba -y
else
    echo "✅ Mamba já instalado"
fi

# --- Cria ou atualiza o ambiente lstm-pipeline ---
if conda info --envs | grep -q lstm-pipeline; then
    echo "♻️ Atualizando ambiente lstm-pipeline"
    mamba env update -n lstm-pipeline -f environment.yml --prune
else
    echo "🚧 Criando ambiente lstm-pipeline"
    mamba env create -f environment.yml
fi

# --- Ativa ambiente lstm-pipeline ---
conda activate lstm-pipeline

# --- Executa scripts Python ---
echo "📥 Executando coleta e treino de modelo..."
python data/coleta.py
python model/treino_modelo.py

# --- Build e run Docker ---
echo "🐳 (Re)subindo container Docker..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true
docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY portátil concluído com sucesso!"
