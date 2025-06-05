#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY UNIVERSAL com variável MINICONDA_PATH"

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

# Executa o deploy
echo "🐳 Executando deploy..."
chmod +x full_deploy.sh
./full_deploy.sh

echo "✅ FULL DEPLOY concluído com sucesso!"
