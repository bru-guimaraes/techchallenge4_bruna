Tech Challenge 4 – MLET – Previsão de Preço de Ações com LSTM

Este projeto foi desenvolvido dentro das restrições da AWSLab Tech Challenge 4 e implementa todo o pipeline de coleta, processamento, treinamento e deploy de um modelo LSTM para previsão de preços de ações.

---

# Visão Geral

- Coleta resiliente de dados financeiros (Yahoo Finance + Alpha Vantage + Mock)
- Processamento e normalização dos dados para modelagem
- Treinamento de modelo LSTM com TensorFlow
- Deploy automatizado no EC2 (AWS) usando Docker para isolamento e escalabilidade
- Automação de credenciais temporárias AWS para acesso seguro a S3 e outros serviços

---

# Arquitetura

- Backend: FastAPI
- Machine Learning: TensorFlow + LSTM
- Infraestrutura: EC2 + S3
- Contêinerização: Docker
- CI/CD Local: PowerShell (Windows) para build e envio ao EC2
- CI/CD EC2: Shell scripts para deploy automático e gestão do container Docker
- Monitoramento: AWS CloudWatch Agent

---

# Link do Repositório

https://github.com/bru-guimaraes/techchallenge4_bruna

---

# Funcionalidades Cumpridas

1. Extração de dados
   - Múltiplas fontes (Yahoo Finance, Alpha Vantage e dados mock)
   - Fallback para dados mock em caso de falha de rede ou cotação indisponível
2. Processamento de dados
   - Normalização e organização em formato adequado para LSTM
   - Manipulação de dataframes e conversão para Parquet
3. Treinamento do modelo
   - Pipeline automatizado que dispara o treino após coleta dos dados
   - Saída: modelo salvo em S3 (.h5) e scaler (.gz)
4. Deploy e automação no EC2
   - Dockerfile para empacotar a aplicação FastAPI + modelo
   - Shell scripts (full_deploy.sh) que instalam dependências e criam/atualizam o container
5. Monitoramento e escalabilidade
   - CloudWatch Agent rodando na instância EC2
   - Métricas de CPU, memória, disco e logs do container
6. Redundância e resiliência
   - Multi-source para garantir disponibilidade de dados
   - Automação de credenciais AWS para leitura/gravação em S3
   - Strings de conexão e chaves sensíveis mantidas em .env

---

# Pré-requisitos

Em uma máquina Linux (Amazon Linux 2023 ou similar) ou EC2 nova, é necessário:

1. Acesso à Internet / Permissões sudo
2. Git
3. Docker
4. Python 3.10

Instalação passo a passo:

1. Instalar Git
   sudo yum update -y
   sudo yum install git -y

2. Instalar Python 3.10 (compilando, pois não existe pacote pronto em AL2023)
   sudo dnf update -y
   sudo dnf install -y gcc gcc-c++ make wget openssl-devel libffi-devel bzip2-devel zlib-devel xz-devel
   cd /usr/src
   sudo mkdir -p python3.10-build
   sudo chown "$USER":"$USER" python3.10-build
   cd python3.10-build
   wget https://www.python.org/ftp/python/3.10.12/Python-3.10.12.tgz
   tar -xf Python-3.10.12.tgz
   cd Python-3.10.12
   ./configure --enable-optimizations --enable-shared
   make -j "$(nproc)"
   sudo make altinstall
   echo -e "/usr/local/lib64\n/usr/local/lib" | sudo tee /etc/ld.so.conf.d/python3.10.conf
   sudo ldconfig
   sudo ln -sfn /usr/local/bin/python3.10 /usr/bin/python3.10
   sudo ln -sfn /usr/local/bin/pip3.10 /usr/bin/pip3.10
   python3.10 --version
   pip3.10 --version

3. Instalar Docker
   sudo dnf install docker -y
   sudo systemctl enable --now docker
   sudo usermod -aG docker ec2-user
   exit (relogue via SSH)

4. (Opcional) Instalar Miniconda / Mamba para testes locais
   wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda3.sh
   bash Miniconda3.sh -b -p /mnt/ebs100/miniconda3
   rm Miniconda3.sh
   export PATH="/mnt/ebs100/miniconda3/bin:$PATH"
   source /mnt/ebs100/miniconda3/etc/profile.d/conda.sh
   conda init
   source ~/.bashrc
   conda install -n base -c conda-forge mamba -y

---

Arquivo .env

Crie um arquivo chamado .env na raiz do projeto (não versionar). Exemplo:

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

ALPHAVANTAGE_API_KEY=L2MMCXP58F5Y5F9K

---

# Pipeline de Execução

A) Build Local (Windows / PowerShell)

- Execute em PowerShell:
  .\\build_deploy.ps1
  (Coleta dados, treina modelo e envia pacote ao EC2 via SCP)

B) Deploy Full no EC2 (via SSH)

1. ssh -i /caminho/para/key.pem ec2-user@<IP_DA_INSTÂNCIA>
2. sudo yum update -y
3. sudo yum install git -y
4. cd /mnt/ebs100 || sudo mkdir -p /mnt/ebs100
5. sudo chown -R ec2-user:ec2-user /mnt/ebs100
6. cd /mnt/ebs100
7. git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git
8. cd techchallenge4_bruna
9. chmod +x full_deploy.sh
10. ./full_deploy.sh

Após a primeira execução, para updates:
cd /mnt/ebs100/techchallenge4_bruna
git fetch --all
git reset --hard origin/main
chmod +x full_deploy.sh
./full_deploy.sh

---

# Script Docker

O Dockerfile está na raiz do repositório (caminho: techchallenge4_bruna/Dockerfile). Ele define a imagem base em Python 3.10, copia o código da aplicação, instala dependências e expõe a porta 80.

Para construir manualmente:
cd techchallenge4_bruna
docker build -t lstm-app .

Para rodar:
docker run -d --name lstm-app-container -p 80:80 lstm-app

---

# API Online

URL base: http://<IP_PUBLICO_DA_INSTÂNCIA>/

Endpoints:
- /docs     (Swagger UI)
- /prever   (POST, recebe JSON com campo "historico": lista de valores)

Exemplo:
{
  "historico": [10.0,11.2,12.1,11.8,...]
}

---

# Link do Vídeo Explicativo

<INSERIR_AQUI_LINK_DO_VÍDEO>
"""