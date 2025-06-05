#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY no EC2 - versão blindada e definitiva"

# Ativa Conda
source ~/miniconda3/etc/profile.d/conda.sh

# Atualiza o repositório local
echo "🔄 Atualizando projeto com git pull..."
git pull || echo "⚠️ Aviso: git pull falhou, usando versão local existente."
echo "✅ Repositório local atualizado."

# (Re)cria o environment do zero (idempotente)
echo "♻️ (Re)criando o environment lstm-pipeline..."
conda env remove -n lstm-pipeline -y || true
conda env create -f environment.yml

# Ativa o novo environment
conda activate lstm-pipeline

# Limpa build antigo
echo "🧹 Limpando build anterior..."
rm -rf deploy_build projeto_lstm_acoes_full.zip

# Executa a coleta e o treino (usando o novo environment)
echo "📥 Executando coleta de dados e treino..."
python data/coleta.py
python model/treino_modelo.py

# Builda e reinicia o Docker (ciclo completo)
echo "🐳 Reiniciando Docker..."

docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true

docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

docker ps

echo "🎯 FULL DEPLOY concluído com sucesso!"
