# Model Loader

Este projeto implementa uma API RESTful com FastAPI para previsão de preços de ações utilizando um modelo LSTM treinado com dados do Yahoo Finance. A aplicação inclui:

## ✅ Funcionalidades
- Coleta de dados históricos com `yfinance`
- Armazenamento em Parquet e envio para Amazon S3
- Treinamento de modelo LSTM com Keras
- Avaliação com métricas: MAE, RMSE, MAPE
- Exportação do modelo e scaler (`.keras` e `.gz`)
- API RESTful com FastAPI
- Swagger disponível em `/docs`
- Middleware de monitoramento de tempo de resposta

## 🚀 Como usar

### 1. Variáveis de ambiente
Crie um arquivo `.env` com:
```env
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_SESSION_TOKEN=...
AWS_DEFAULT_REGION=us-east-1
```

### 2. Coleta de dados
```bash
python data/coleta.py
```

### 3. Treinamento do modelo
```bash
python model/treinar_modelo.py
```

### 4. Avaliação do modelo
```bash
python model/avaliacao_modelo_lstm.py
```

### 5. Subir API com Docker
```bash
docker compose up --build
```

### 6. Testar API
Acesse: [http://localhost:8000/docs](http://localhost:8000/docs)

Exemplo de payload para `/prever`:
```json
{
  "historico": [191.34, 191.50, ..., 203.44]
}
```

## 📈 Monitoramento
A API possui middleware que registra o tempo de resposta de cada requisição no console:
```
⏱️ POST /prever demorou 0.123s
```

## 📂 Estrutura
- `app/` → API FastAPI
- `data/` → Coleta de dados
- `model/` → Treinamento e avaliação
- `utils/` → Utilitários
- `docker/` → Dockerfile, entrypoint

---

🔒 Projeto organizado para deploy local ou em nuvem (AWS, Render, Railway).

---