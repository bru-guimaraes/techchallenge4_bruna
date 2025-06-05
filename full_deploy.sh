#!/bin/bash
set -euo pipefail

echo "🚀 Iniciando FULL DEPLOY ROBUSTO com MINICONDA_PATH variável"

MINICONDA_PATH=/mnt/ebs100/miniconda3
PROJECT_DIR=/mnt/ebs100/techchallenge4_bruna

echo "Usando Miniconda em: $MINICONDA_PATH"
echo "Diretório do projeto: $PROJECT_DIR"

# --- Verifica Miniconda instalada ---
if [ ! -d "$MINICONDA_PATH" ]; then
  echo "❌ Miniconda não encontrada em $MINICONDA_PATH."
  echo "⚠️ Por favor, instale Miniconda nesse caminho e tente novamente."
  exit 1
fi

export PATH="$MINICONDA_PATH/bin:$PATH"

# --- Carrega conda ---
if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
  source "$MINICONDA_PATH/etc/profile.d/conda.sh"
else
  echo "❌ Arquivo conda.sh não encontrado em $MINICONDA_PATH/etc/profile.d/"
  exit 1
fi

# --- Verifica Docker instalado e ativo ---
if ! command -v docker &>/dev/null; then
  echo "❌ Docker não instalado. Instale Docker e rode novamente."
  exit 1
fi

if ! systemctl is-active --quiet docker; then
  echo "⚠️ Docker não está ativo, iniciando..."
  sudo systemctl start docker
  sleep 5
  if ! systemctl is-active --quiet docker; then
    echo "❌ Falha ao iniciar Docker."
    exit 1
  fi
fi

echo "✅ Docker está instalado e ativo."

# --- Atualiza repo ---
if [ ! -d "$PROJECT_DIR" ]; then
  echo "❌ Diretório do projeto $PROJECT_DIR não encontrado."
  exit 1
fi

cd "$PROJECT_DIR"
echo "🔄 Atualizando repositório local..."
git fetch --all
git reset --hard origin/main

# --- Criar ou atualizar ambiente conda ---
echo "♻️ Criando ou atualizando ambiente conda lstm-pipeline..."
if conda env list | grep -q "lstm-pipeline"; then
  conda env update -n lstm-pipeline -f environment.yml --prune || {
    echo "⚠️ Falha ao atualizar ambiente, tentando recriar..."
    conda env remove -n lstm-pipeline -y
    conda env create -f environment.yml
  }
else
  conda env create -f environment.yml
fi

# --- Ativa ambiente ---
echo "🟢 Ativando ambiente lstm-pipeline..."
conda activate lstm-pipeline

# --- Instala dependências pip ---
if [ -f requirements.txt ]; then
  echo "📦 Instalando dependências pip..."
  pip install -r requirements.txt
else
  echo "⚠️ Arquivo requirements.txt não encontrado, pulando instalação pip."
fi

# --- Para e remove containers e imagens antigas ---
echo "🐳 Parando e removendo containers Docker antigos..."
docker stop lstm-app-container 2>/dev/null || true
docker rm lstm-app-container 2>/dev/null || true
docker rmi lstm-app 2>/dev/null || true

# --- Build e run docker ---
echo "🐳 Construindo a imagem Docker..."
docker build -t lstm-app .

echo "🐳 Rodando container Docker..."
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY ROBUSTO concluído com sucesso!"
