# Tech Challenge 4 - Pipeline LSTM Previsao de Acoes (AWS + EC2 + FastAPI + DuckDNS)

---

## Visao Geral

Este projeto implementa um pipeline completo de coleta, treino e deploy de um modelo LSTM de previsao de precos de acoes, utilizando:

* **AWS EC2** (com armazenamento em disco adicional)
* **S3 (quando disponivel)**
* **GitHub (backup de seguranca)**
* **Alpha Vantage e Yahoo Finance (para coleta de dados)**
* **FastAPI com deploy Dockerizado**
* **DuckDNS (para exposicao publica automatica)**
* **Auto atualizacao de credenciais AWS temporarias e IP dinamico**

---

## Funcionalidades Implementadas

* ✅ Coleta de dados de acoes (tenta YFinance, fallback Alpha Vantage, fallback Mock)
* ✅ Treinamento e normalizacao dos dados (com janela de 60 dias)
* ✅ Salvamento do modelo e scaler no S3
* ✅ Build automatico no Windows com Powershell
* ✅ Deploy completo no EC2 com um unico `full_deploy.sh`
* ✅ Atualizacao automatica de credenciais AWS e IP dinamico com `auto_env.py`
* ✅ Integracao com DuckDNS (substitui IP dinamico por dominio fixo)
* ✅ Busca de ultima versao de codigo (prioridade: ZIP local > S3 > GitHub)

---

## Estrutura do Projeto

```
├── app/
│   └── main.py, model_loader.py, schemas.py...
├── data/
│   └── coleta.py (pipeline resiliente de coleta de dados)
├── model/
│   └── treino_modelo.py
├── utils/
│   └── preprocessamento.py
├── deploy_build/ (gerado no build)
├── projeto_lstm_acoes_full.zip (pacote gerado para o EC2)
├── auto_env.py  (auto atualizacao de credenciais)
├── build_deploy.ps1  (build Windows)
├── full_deploy.sh  (deploy final EC2)
├── Dockerfile
├── .env
└── README.md
```

---

## Fluxo de Execucao

### 1. Build local (Windows / VSCode)

* Edite o arquivo `.env` com suas credenciais AWS temporarias, pem, IP, etc.
* Execute `build_deploy.ps1` no Windows:

  ```
  ./build_deploy.ps1
  ```
* Ele:

  * Coleta dados
  * Treina o modelo
  * Salva no S3
  * Gera ZIP
  * Faz o SCP automatico para o EC2

### 2. Deploy no EC2

* Conecte-se na instancia EC2 via SSH
* Acesse a pasta `/home/ec2-user/deploy_app`
* Execute:

  ```
  chmod +x full_deploy.sh
  ./full_deploy.sh
  ```

O `full_deploy.sh`:

* Atualiza automaticamente o .env com as novas credenciais AWS
* Atualiza o DuckDNS
* Faz coleta e treino no proprio EC2
* Faz rebuild do Docker
* Sobe a API em 80/tcp

---

## Configuracoes do DuckDNS

* Ja automatizado via `auto_env.py`
* Sempre atualizado a cada deploy.
* Exemplo de acesso a API final:

  ```
  http://techchallenge4brunag.duckdns.org/docs
  ```

---

## Consideracoes importantes:

* As credenciais AWS temporarias mudam a cada sessao da AWS Academy.
* Use `auto_env.py` para sempre atualizar o .env automaticamente no EC2.
* O arquivo `.env` NUNCA deve ir para o GitHub. No EC2 ele eh atualizado automaticamente.
* O EC2 sempre busca primeiro o zip local, depois o S3, depois o GitHub oficial:

  ```
  https://github.com/bru-guimaraes/techchallenge4_bruna
  ```

---

## Caso o professor queira executar:

1. Ter um usuario IAM na AWS com permissão de leitura S3 (opcional, se desejar utilizar o bucket existente).

2. Criar nova instancia EC2 com permissao de Internet publica.

3. Clonar o projeto via GitHub:

   ```bash
   git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
   ```

4. Preencher o arquivo `.env` no EC2:

   ```bash
   vi /home/ec2-user/deploy_app/.env
   ```

5. Rodar o `full_deploy.sh` normalmente.

**A partir desse ponto, o deploy passa a ser totalmente autonomo.**

---

## Pipeline 100% resiliente ✅

* Build Windows --> Envia ZIP --> EC2 --> Atualiza credenciais --> Faz coleta --> Treina --> Docker --> API --> Exposicao via DuckDNS

---