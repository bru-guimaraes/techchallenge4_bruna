#!/bin/bash
set -e

echo "🚀 Iniciando"

# Defina o caminho da instalação Miniconda no volume maior
MINICONDA_PATH=/mnt/ebs100/miniconda3

echo "Usando Miniconda em: $MINICONDA_PATH"

# Adiciona Miniconda ao PATH
export PATH="$MINICONDA_PATH/bin:$PATH"

# Carrega conda
if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
  source "$MINICONDA_PATH/etc/profile.d/conda.sh"
else
  echo "❌ Erro: arquivo conda.sh não encontrado em $MINICONDA_PATH/etc/profile.d/"
  exit 1
fi

# Atualiza repositório local
echo "🔄 Atualizando projeto local..."
cd /mnt/ebs100/techchallenge4_bruna
git pull

# Atualiza ou cria o ambiente Conda
echo "♻️ Criando ou atualizando ambiente lstm-pipeline..."
conda env create -f environment.yml || conda env update -n lstm-pipeline -f environment.yml --prune

# Ativa ambiente
echo "🟢 Ativando ambiente lstm-pipeline..."
conda activate lstm-pipeline

# Instala dependências pip automaticamente
if [ -f requirements.txt ]; then
  echo "📦 Instalando dependências pip..."
  pip install -r requirements.txt
else
  echo "⚠️ Arquivo requirements.txt não encontrado, pulando instalação pip."
fi

# Executa build e run do docker container
echo "🐳 Construindo e rodando container Docker..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true

docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY concluído com sucesso!"
