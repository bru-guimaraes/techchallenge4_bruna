#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY UNIVERSAL"

# --- Define variáveis básicas ---
MINICONDA_DIR="$HOME/miniconda3"
ENV_NAME="lstm-pipeline"
PROJECT_DIR="$HOME/techchallenge4_bruna"
ENV_YML="$PROJECT_DIR/environment.yml"

# --- Função para adicionar export no bashrc se não existir ---
add_to_bashrc_if_missing() {
  local line="$1"
  grep -qxF "$line" ~/.bashrc || echo "$line" >> ~/.bashrc
}

# --- Atualiza projeto git ---
if [ ! -d "$PROJECT_DIR" ]; then
  echo "📂 Clonando projeto em $PROJECT_DIR"
  git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git "$PROJECT_DIR"
else
  echo "🔄 Atualizando projeto em $PROJECT_DIR"
  cd "$PROJECT_DIR"
  git reset --hard origin/main
  git pull || true
fi

cd "$PROJECT_DIR"

# --- Instala Miniconda se não existir ---
if [ ! -d "$MINICONDA_DIR" ]; then
  echo "📦 Instalando Miniconda em $MINICONDA_DIR..."
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
  bash /tmp/miniconda.sh -b -p "$MINICONDA_DIR"
  rm /tmp/miniconda.sh

  add_to_bashrc_if_missing "export PATH=\"$MINICONDA_DIR/bin:\$PATH\""
  export PATH="$MINICONDA_DIR/bin:$PATH"
else
  echo "✅ Miniconda já instalado"
fi

# --- Configura ambiente Conda para shell atual ---
source "$MINICONDA_DIR/etc/profile.d/conda.sh"

# --- Instala mamba se não existir ---
if ! command -v mamba &> /dev/null; then
  echo "🚀 Instalando mamba..."
  conda install -n base -c conda-forge mamba -y
else
  echo "✅ Mamba já instalado"
fi

# --- Corrige LD_LIBRARY_PATH para evitar erros libmamba ---
LIB_PATH="$MINICONDA_DIR/lib"
export LD_LIBRARY_PATH="$LIB_PATH:$LD_LIBRARY_PATH"
add_to_bashrc_if_missing "export LD_LIBRARY_PATH=\"$LIB_PATH:\$LD_LIBRARY_PATH\""

# --- Cria ou atualiza ambiente Conda ---
if conda env list | grep -q "$ENV_NAME"; then
  echo "♻️ Atualizando ambiente $ENV_NAME"
  mamba env update -n "$ENV_NAME" -f "$ENV_YML" --prune
else
  echo "🚧 Criando ambiente $ENV_NAME"
  mamba env create -f "$ENV_YML"
fi

# --- Ativa ambiente ---
conda activate "$ENV_NAME"

# --- Executa scripts Python ---
echo "📥 Executando coleta e treino de modelo..."
python data/coleta.py
python model/treino_modelo.py

# --- Instala e inicia Docker se necessário ---
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

# --- Build e run container Docker ---
echo "🐳 (Re)subindo container Docker..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true
docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY concluído com sucesso!"
