# Tech Challenge 4 - MLET - Previsão de Preço de Ações com LSTM

Projeto completo de coleta, processamento, treinamento e deploy de modelo LSTM para previsão de preço de ações.

## Visão Geral

* Coleta resiliente de dados financeiros (Yahoo Finance + Alpha Vantage + Mock)
* Processamento e normalização dos dados
* Treinamento de modelo LSTM
* Deploy automatizado no EC2 (AWS)
* Atualização automática de IP no DuckDNS
* Gerenciamento automatizado de credenciais temporárias AWS

---

## Arquitetura

* **Backend:** FastAPI
* **ML:** Tensorflow + LSTM
* **AWS:** EC2 + S3
* **DNS:** DuckDNS
* **CI Local:** Powershell para build
* **CI EC2:** Shell Scripts automatizados

---

## Repositório

> [https://github.com/bru-guimaraes/techchallenge4\_bruna](https://github.com/bru-guimaraes/techchallenge4_bruna)

---

## Configuração Inicial

### 1. Criar o .env (NÃO VERSIONADO)

Esse arquivo é sensível e não vai para o Git.

```env
# AWS (deixar vazio pois é gerado via auto_env)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_SESSION_TOKEN=
AWS_DEFAULT_REGION=us-east-1

# S3
BUCKET_NAME=bdadostchallengebruna
MODEL_KEY=modelos/model_lstm.h5
SCALER_KEY=modelos/scaler.gz

# EC2
EC2_IP=
EC2_USER=ec2-user
PEM_PATH=D:/caminho/bruna-techchallenge.pem

# Alpha Vantage
ALPHA_VANTAGE_API_KEY=L2MMCXP58F5Y5F9K

# DuckDNS
DUCKDNS_DOMAIN=techchallenge4brunag
DUCKDNS_TOKEN=c549a1fa-6804-43d5-b4dd-ebaea080834f
```

---

### 2. Pipeline de Execução

#### a) Build local (Windows):

```powershell
./build_deploy.ps1
```

Ele:

* Coleta dados (Yahoo Finance + Alpha Vantage + Mock)
* Treina o modelo
* Gera o .zip
* Envia via SCP para o EC2
* Atualiza IP no DuckDNS automaticamente

#### b) Deploy Full no EC2 (SSH no EC2):

```bash
cd ~/deploy_app
chmod +x full_deploy.sh
./full_deploy.sh
```

Ele:

* Gera novo build no EC2
* Baixa o repositório do GitHub caso não tenha o ZIP local
* Atualiza credenciais AWS com o auto\_env
* Atualiza o IP no DuckDNS
* Executa rebuild do container Docker

---

## API Online

> A API fica exposta via DuckDNS:

**[https://techchallenge4brunag.duckdns.org/](https://techchallenge4brunag.duckdns.org/)**

### Endpoints:

* `/docs` - Swagger auto gerado
* `/prever` - Faz previsão

Exemplo de request:

```json
{
  "historico": [10,11,12,13,14,15,16,17,18,19,20,...]
}
```

---

## Caso o Professor queime minha sessão AWS:

1. Subir novo EC2 (via AWS Academy)
2. Clonar o repositório:

```bash
git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
```

3. Copiar o .env atualizado para o EC2:

```bash
scp -i caminho/chave.pem .env ec2-user@IP_NOVO:/home/ec2-user/deploy_app/
```

4. Rodar o deploy normalmente:

```bash
./full_deploy.sh
```

---

## Extras de Resiliência Implementados

* Multi-source de dados: Yahoo Finance > Alpha Vantage > Mock
* DuckDNS para IP dinâmico
* Auto-atualização de credenciais temporárias AWS
* Totalmente reprodutível sem necessidade de Windows local


#Orientação novo EC2
sudo yum update -y
sudo yum install git -y
git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
cd techchallenge4_bruna
chmod +x full_deploy.sh
./full_deploy.sh

