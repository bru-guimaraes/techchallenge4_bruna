# Previsão de Preços de Ações com LSTM \U0001F4C8

[![Docker](https://img.shields.io/badge/docker-ready-blue)](https://www.docker.com/)
[![API](https://img.shields.io/badge/fastapi-running-brightgreen)](http://localhost:8000/docs)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Este projeto cria uma solução de Machine Learning com redes neurais **LSTM** para prever o preço de fechamento de ações com base em histórico da bolsa. Inclui desde a coleta com `yfinance` até uma API funcional com FastAPI + Docker.

---

### ✅ Funcionalidades

- Coleta de dados da AAPL com `yfinance`
- Armazenamento em formato Parquet no AWS S3
- Treinamento de modelo LSTM com `TensorFlow`
- Avaliação com MAE, RMSE e MAPE
- API REST com FastAPI para inferência
- Docker + Docker Compose para execução completa

---

### 🔍 Como executar com Docker

1. Crie o arquivo `.env` na raiz:

```env
AWS_ACCESS_KEY_ID=SUACHAVE
AWS_SECRET_ACCESS_KEY=SUA_SECRET
AWS_SESSION_TOKEN=SEU_TOKEN
AWS_DEFAULT_REGION=us-east-1
```

2. Execute:
```bash
docker compose up --build
```

3. Acesse a API em:
[http://localhost:8000/docs](http://localhost:8000/docs)

---

### 📈 Exemplo de previsão:

POST `/prever`
```json
{
  "historico": [199.2, 198.7, 200.1, ..., 205.3]  // 60 valores
}
```

Resposta:
```json
{
  "previsao": 206.72
}
```

---

### 📅 Pipeline automatizada:

Executada dentro do Docker via `entrypoint.sh`:
- `data/coleta.py`
- `model/treino_modelo.py`
- `model/avaliacao_modelo_lstm.py`
- API FastAPI com Uvicorn

---

### 📋 Tecnologias usadas
- Python 3.10
- FastAPI
- TensorFlow 2.15
- yfinance + pandas + boto3
- Docker + Compose

---

### ✅ Status do Projeto
| Etapa                          | Status  |
|-------------------------------|----------|
| Coleta e S3                   | Concluído |
| Treino LSTM                   | Concluído |
| Avaliação com métricas       | Concluído |
| Deploy da API                 | Concluído |
| Docker e automação           | Concluído |
| Documentação (README, .env)  | Concluído |
| Vídeo de apresentação        | Em andamento |

---

### 📅 Autora
Bruna Guimarães  
⚖️ Projeto do Tech Challenge Fase 4