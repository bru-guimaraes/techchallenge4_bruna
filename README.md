Tech Challenge 4 - MLET - Previsão de Preço de Ações com LSTM

Este projeto foi desenvolvido dentro das restrições da AWSLab Tech Challenge 4.

Projeto completo de coleta, processamento, treinamento e deploy de modelo LSTM para previsão de preço de ações.

# Visão Geral

- Coleta resiliente de dados financeiros (Yahoo Finance + Alpha Vantage + Mock)
- Processamento e normalização dos dados
- Treinamento de modelo LSTM
- Deploy automatizado no EC2 (AWS) utilizando Docker para isolamento e escalabilidade
- Gerenciamento automatizado de credenciais temporárias AWS

# Arquitetura

- Backend: FastAPI
- ML: Tensorflow + LSTM
- AWS: EC2 + S3
- Contêinerização: Docker para deployment consistente
- CI Local: Powershell para build e envio
- CI EC2: Shell Scripts para deploy automático e gestão do container Docker

# Repositório

https://github.com/bru-guimaraes/techchallenge4_bruna

# Cumprimento dos Requisitos do Projeto

1. Extração dos dados: A coleta é realizada a partir de múltiplas fontes financeiras (Yahoo Finance, Alpha Vantage e dados mock), garantindo resiliência e disponibilidade.

2. Processamento dos dados: Os dados são normalizados e preparados para o modelo LSTM através de um pipeline robusto.

3. Treinamento do modelo: O modelo LSTM é treinado automaticamente após a coleta dos dados.

4. Deploy e automação no EC2: O projeto é implantado em instância EC2 usando Docker para facilitar o deploy, garantir isolamento do ambiente e permitir escalabilidade.

5. Monitoramento e escalabilidade: O uso do Docker e AWS possibilita monitoramento via CloudWatch e escalabilidade futura do ambiente.

# Configuração Inicial

1. Criar o arquivo .env (NÃO VERSIONADO)

Este arquivo contém informações sensíveis e não é versionado no repositório.

Exemplo de .env:

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_SESSION_TOKEN=
AWS_DEFAULT_REGION=us-east-1

BUCKET_NAME=bdadostchallengebruna
MODEL_KEY=modelos/model_lstm.h5
SCALER_KEY=modelos/scaler.gz

EC2_IP=
EC2_USER=ec2-user
PEM_PATH=

ALPHA_VANTAGE_API_KEY=L2MMCXP58F5Y5F9K

# Pipeline de Execução

a) Build local (Windows):

./build_deploy.ps1

Este script realiza:

- Coleta dos dados (Yahoo Finance + Alpha Vantage + Mock)
- Treinamento do modelo
- Geração do pacote para deploy
- Envio do pacote via SCP para a instância EC2
- Atualização automática das credenciais AWS

b) Deploy Full no EC2 (via SSH):

1. Procedimentos para replicação em novo ambiente EC2

sudo yum update -y
sudo yum install git -y
git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
cd techchallenge4_bruna
chmod +x full_deploy.sh
./full_deploy.sh

2. Após a primeira execução, para atualizações subsequentes:

cd ~/deploy_app
chmod +x full_deploy.sh
./full_deploy.sh

Este script realiza:

- Clonagem ou atualização do repositório do GitHub
- Criação ou atualização do ambiente Conda
- Ativação do ambiente com as dependências necessárias
- Parada, remoção e reconstrução do container Docker com a aplicação
- Inicialização do container expondo a API na porta 80

# API Online

A API fica disponível no IP público da instância EC2:

http://<IP_PUBLICO_DO_EC2>/

Endpoints:

- /docs — documentação Swagger auto gerada
- /prever — endpoint para realizar previsões

Exemplo de requisição JSON:

{
  "historico": [10,11,12,13,14,15,16,17,18,19,20,...]
}

# Validação do Monitoramento com AWS CloudWatch

Após o deploy automático que configura e inicia o AWS CloudWatch Agent na instância EC2, você pode validar se o monitoramento está ativo seguindo estes passos:

1. Acesse o Console AWS:
   https://console.aws.amazon.com/cloudwatch/

2. No menu lateral, selecione "Metrics" (Métricas).

3. Procure pelo namespace do agente do CloudWatch, geralmente chamado de:
   - "CWAgent"
   - Ou o nome personalizado configurado no arquivo `cloudwatch-config.json`

4. Visualize métricas importantes como:
   - CPU Utilization (Uso de CPU)
   - Memory Utilization (Uso de memória)
   - Disk I/O (Operações de disco)
   - Network Traffic (Tráfego de rede)
   - Logs do container Docker, se configurado

5. Para conferir os logs, no menu lateral selecione "Logs" e procure o grupo de logs configurado, geralmente com nome similar ao serviço ou container.

6. Verifique se os logs e métricas estão sendo atualizados em tempo real conforme a aplicação estiver rodando.

---

Caso não encontre métricas ou logs, verifique:

- Se o serviço `amazon-cloudwatch-agent` está ativo na instância EC2:

- Se o arquivo de configuração `cloudwatch-config.json` está presente e correto no caminho `/opt/aws/amazon-cloudwatch-agent/etc/`.

- Se a política IAM da instância EC2 permite envio de métricas e logs para o CloudWatch.

---

Este monitoramento ajuda a:

- Detectar possíveis gargalos de CPU ou memória.
- Identificar problemas de disco e rede.
- Monitorar o comportamento do container Docker da API.
- Facilitar a escalabilidade e manutenção em produção.

---


# Extras de Resiliência Implementados

- Multi-source de dados garantindo alta disponibilidade e redundância
- Automação para atualização de credenciais AWS temporárias
- Uso do Docker para garantir isolamento, replicabilidade e facilidade na escalabilidade do ambiente
- Deploy e build totalmente automatizados para facilitar uso em diferentes ambientes sem necessidade de intervenção manual
- Logs e mensagens claras para acompanhamento e diagnóstico durante o deploy e execução

# Orientação para novo EC2

sudo yum update -y
sudo yum install git -y
git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
cd techchallenge4_bruna
chmod +x full_deploy.sh
./full_deploy.sh

---
