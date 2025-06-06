#!/bin/bash
set -euo pipefail

echo "🚀 Iniciando FULL DEPLOY SIMPLIFICADO usando venv + pip"

# --- Definições de caminhos ---
BASE_PATH="${BASE_PATH:-/mnt/ebs100}"
PROJECT_DIR="${PROJECT_DIR:-$BASE_PATH/techchallenge4_bruna}"
VENV_DIR="$BASE_PATH/venv"
CLOUDWATCH_DIR="$BASE_PATH/amazon-cloudwatch-agent"
CLOUDWATCH_BIN="$CLOUDWATCH_DIR/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

echo "🔧 Diretórios configurados:"
echo "  - Projeto:    $PROJECT_DIR"
echo "  - Virtualenv: $VENV_DIR"
echo "  - CloudWatch: $CLOUDWATCH_DIR"

# --- 1) Verifica se Python3 e venv estão disponíveis ---
if ! command -v python3 &>/dev/null; then
  echo "❌ Python3 não encontrado. Instale python3 e python3-venv e tente novamente."
  exit 1
fi

# --- 2) Criar (ou reusar) a virtualenv em $VENV_DIR ---
if [ ! -d "$VENV_DIR" ]; then
  echo "♻️ Criando virtualenv em $VENV_DIR..."
  python3 -m venv "$VENV_DIR"
else
  echo "✅ Virtualenv já existe em $VENV_DIR, pulando criação."
fi

# Ativar a venv nesta sessão
source "$VENV_DIR/bin/activate"

# --- 3) Instalar/atualizar pacotes via pip ---
echo "📦 Instalando dependências Python..."
pip install --upgrade pip
pip install -r "$PROJECT_DIR/requirements.txt"

# --- 4) Verifica Docker (instale se faltar) ---
if ! command -v docker &>/dev/null; then
  echo "❌ Docker não instalado. Instale Docker e rode novamente."
  exit 1
fi

if ! systemctl is-active --quiet docker; then
  echo "⚠️ Docker não está ativo, iniciando..."
  sudo systemctl start docker
  sleep 5
  if ! systemctl is-active --quiet docker; then
    echo "❌ Falha ao iniciar Docker."
    exit 1
  fi
fi
echo "✅ Docker está ativo."

# --- 5) Atualiza repositório local ---
cd "$PROJECT_DIR"
echo "🔄 Atualizando repositório local..."
git fetch --all
git reset --hard origin/main
echo "🔄 Código atualizado para commit: $(git rev-parse --short HEAD)"

# --- 6) Executa coleta de dados e treino usando a venv ---
echo "📥 Executando coleta de dados (data/coleta.py)..."
python data/coleta.py || { echo "❌ Erro na coleta de dados"; exit 1; }

echo "📊 Executando treino de modelo (model/treino_modelo.py)..."
python model/treino_modelo.py || { echo "❌ Erro no treino de modelo"; exit 1; }

# --- 7) Instalar/configurar AWS CloudWatch Agent (opcional) ---
echo "🚀 Verificando AWS CloudWatch Agent..."
if [ -x "$CLOUDWATCH_BIN" ]; then
  echo "✅ CloudWatch Agent já instalado em $CLOUDWATCH_BIN"
else
  echo "⚠️ CloudWatch Agent não encontrado. Instalando no volume..."
  mkdir -p "$CLOUDWATCH_DIR"
  cd "$CLOUDWATCH_DIR"
  wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
  rpm2cpio amazon-cloudwatch-agent.rpm | cpio -idmv
  mv opt/amazon-cloudwatch-agent "$CLOUDWATCH_DIR"
  echo "✅ CloudWatch Agent instalado em $CLOUDWATCH_DIR"
fi

# Copia a configuração (presume-se que exista cloudwatch-config.json no projeto)
CONFIG_SRC="$PROJECT_DIR/cloudwatch-config.json"
CONFIG_DST="$CLOUDWATCH_DIR/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

if [ -f "$CONFIG_SRC" ]; then
  echo "📋 Copiando configuração para $CONFIG_DST"
  cp "$CONFIG_SRC" "$CONFIG_DST"
else
  echo "❌ Arquivo cloudwatch-config.json não encontrado em $CONFIG_SRC"
  exit 1
fi

echo "▶️ Iniciando CloudWatch Agent..."
"$CLOUDWATCH_BIN" -a fetch-config -m ec2 -c file:"$CONFIG_DST" -s
echo "✅ CloudWatch Agent iniciado."

echo "🚀 Testando métrica customizada no CloudWatch..."
python "$PROJECT_DIR/cloudwatch_test.py" || echo "⚠️ Falha no teste CloudWatch."
echo "✅ Teste CloudWatch finalizado."

# --- 8) Parar e limpar containers/imagens antigas ---
echo "🐳 Parando e removendo containers Docker antigos..."
docker stop lstm-app-container 2>/dev/null || true
docker rm lstm-app-container 2>/dev/null || true
docker rmi lstm-app 2>/dev/null || true

# --- 9) Build e run Docker ---
echo "🐳 Construindo a imagem Docker..."
docker build -t lstm-app .

echo "🐳 Rodando container Docker..."
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY concluído com sucesso!"

# --- 10) Desativa a venv nesta sessão ---
deactivate
