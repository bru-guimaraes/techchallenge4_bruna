#!/bin/bash
set -e

echo "🚀 Iniciando pipeline da aplicação LSTM..."

echo "📥 Coletando dados..."
if ! python data/coleta.py; then
  echo "❌ Erro durante a coleta de dados. Finalizando container."
  exit 1
fi

echo "🧠 Treinando modelo..."
if ! python model/treino_modelo.py; then
  echo "❌ Erro durante o treinamento do modelo. Finalizando container."
  exit 1
fi

echo "📊 Avaliando modelo..."
if ! python model/avaliacao_modelo_lstm.py; then
  echo "❌ Erro durante a avaliação do modelo. Finalizando container."
  exit 1
fi

echo "🚀 Iniciando a API FastAPI..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
