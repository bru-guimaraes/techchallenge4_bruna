#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY no EC2..."

# Ativa Conda
source ~/miniconda3/etc/profile.d/conda.sh
conda activate lstm-pipeline

echo "📄 Executando auto_env.py para atualizar credenciais e IP..."
python3 auto_env.py

# Recarrega variáveis de ambiente
export $(grep -v '^#' .env | xargs)

# Limpa build anterior
echo "🧹 Limpando build antigo..."
rm -rf app data model utils application.py Dockerfile deploy_build .env projeto_lstm_acoes_full.zip

# Busca ZIP (prioridade local)
if [ -f projeto_lstm_acoes_full.zip ]; then
    echo "🎯 Encontrado pacote local no EC2."
else
    echo "☁️ Tentando buscar pacote do S3..."
    aws s3 cp s3://$BUCKET_NAME/deploys/projeto_lstm_acoes_full.zip . || echo "⚠️ Pacote não encontrado no S3."
fi

# Se ainda não encontrou, clona do GitHub
if [ ! -f projeto_lstm_acoes_full.zip ]; then
    echo "🌐 Clonando projeto diretamente do GitHub..."
    git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git repo_clone
    cp -r repo_clone/* .
    rm -rf repo_clone
    echo "🎯 Projeto clonado diretamente do repositório."
fi

# Extrai o ZIP caso tenha encontrado
if [ -f projeto_lstm_acoes_full.zip ]; then
    unzip -o projeto_lstm_acoes_full.zip
fi

# Executa pipeline completo
echo "📥 Coletando dados e treinando modelo..."
python3 data/coleta.py
python3 model/treino_modelo.py

# Limpa docker antigo
echo "🐳 Reiniciando Docker..."
docker stop lstm-app-container || true
docker rm lstm-app-container || true
docker rmi lstm-app || true

# Builda docker
docker build -t lstm-app .
docker run -d --name lstm-app-container -p 80:80 lstm-app

docker ps
echo "🎯 FULL DEPLOY concluído com sucesso!"
