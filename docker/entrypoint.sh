#!/bin/sh

echo "📥 Executando coleta de dados..."
python data/coleta.py || exit 1

echo "🧠 Treinando modelo..."
python model/treino_modelo.py || exit 1

echo "📊 Avaliando modelo..."
python model/avaliacao_modelo_lstm.py || exit 1

echo "🚀 Iniciando API..."
uvicorn app.main:app --host 0.0.0.0 --port 8000
