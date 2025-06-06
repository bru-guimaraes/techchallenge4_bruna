#!/bin/bash
set -euo pipefail

echo "🚀 Iniciando FULL DEPLOY ROBUSTO com MAMBA e VARIÁVEIS PARAMETRIZADAS"

# --- Variáveis base parametrizáveis ---
BASE_PATH="${BASE_PATH:-/mnt/ebs100}"
MINICONDA_PATH="${MINICONDA_PATH:-$BASE_PATH/miniconda3}"
PROJECT_DIR="${PROJECT_DIR:-$BASE_PATH/techchallenge4_bruna}"
CLOUDWATCH_DIR="${CLOUDWATCH_DIR:-$BASE_PATH/amazon-cloudwatch-agent}"
CLOUDWATCH_BIN="$CLOUDWATCH_DIR/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

echo "🔧 Diretórios configurados:"
echo "  - Miniconda: $MINICONDA_PATH"
echo "  - Projeto:   $PROJECT_DIR"
echo "  - CloudWatch: $CLOUDWATCH_DIR"

# --- Verifica Miniconda instalada ---
if [ ! -d "$MINICONDA_PATH" ]; then
  echo "❌ Miniconda não encontrada em $MINICONDA_PATH."
  exit 1
fi

export PATH="$MINICONDA_PATH/bin:$PATH"

# --- Carrega conda para habilitar conda e mamba ---
if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
  source "$MINICONDA_PATH/etc/profile.d/conda.sh"
  export PATH="$MINICONDA_PATH/bin:$PATH"
else
  echo "❌ Arquivo conda.sh não encontrado."
  exit 1
fi

# --- Verifica e instala mamba se faltar ---
echo "🔎 Verificando mamba..."
if ! command -v mamba &>/dev/null; then
  echo "⚠️ Mamba não encontrado. Instalando via conda-forge..."
  conda install -n base -c conda-forge mamba -y
  export PATH="$MINICONDA_PATH/bin:$PATH"
else
  echo "✅ Mamba já instalado."
fi

# --- Verifica Docker ativo ---
if ! command -v docker &>/dev/null; then
  echo "❌ Docker não instalado."
  exit 1
fi

if ! systemctl is-active --quiet docker; then
  echo "⚠️ Docker não está ativo, iniciando…"
  sudo systemctl start docker
  sleep 5
fi
echo "✅ Docker está instalado e ativo."

# --- Atualiza repositório local ---
cd "$PROJECT_DIR"
echo "🔄 Atualizando repositório local..."
git fetch --all
git reset --hard origin/main
echo "🔄 Código atualizado para commit: $(git rev-parse --short HEAD)"

# --- Criar ou verificar ambiente conda 'lstm-pipeline' ---
echo "♻️ Verificando ambiente conda lstm-pipeline..."
if mamba env list | awk '{ print $1 }' | grep -qx "lstm-pipeline"; then
  echo "✅ Ambiente 'lstm-pipeline' já existe. Pulando criação."
else
  echo "♻️ Ambiente 'lstm-pipeline' não encontrado. Criando com mamba..."
  mamba env create -f environment.yml
fi

# --- Executa pipeline do projeto: coleta e treino ---
echo "📥 Executando coleta de dados…"
conda run -n lstm-pipeline python data/coleta.py || { echo "❌ Erro na coleta de dados"; exit 1; }

echo "📊 Executando treino de modelo…"
conda run -n lstm-pipeline python model/treino_modelo.py || { echo "❌ Erro no treino de modelo"; exit 1; }

# --- CloudWatch Agent ---
echo "🚀 Verificando CloudWatch Agent…"
if [ -x "$CLOUDWATCH_BIN" ]; then
  echo "✅ CloudWatch Agent já instalado"
else
  mkdir -p "$CLOUDWATCH_DIR"
  cd "$CLOUDWATCH_DIR"
  wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
  rpm2cpio amazon-cloudwatch-agent.rpm | cpio -idmv
  mv opt/amazon-cloudwatch-agent "$CLOUDWATCH_DIR"
fi

CONFIG_SRC="$PROJECT_DIR/cloudwatch-config.json"
CONFIG_DST="$CLOUDWATCH_DIR/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

if [ -f "$CONFIG_SRC" ]; then
  cp "$CONFIG_SRC" "$CONFIG_DST"
else
  echo "❌ Arquivo cloudwatch-config.json não encontrado"
  exit 1
fi

"$CLOUDWATCH_BIN" -a fetch-config -m ec2 -c file:"$CONFIG_DST" -s

echo "🚀 Teste CloudWatch…"
conda run -n lstm-pipeline python "$PROJECT_DIR/cloudwatch_test.py" || echo "⚠️ Falha ao executar teste CloudWatch."

# --- Docker Build & Run ---
echo "🐳 Parando e limpando containers antigos…"
docker stop lstm-app-container 2>/dev/null || true
docker rm lstm-app-container 2>/dev/null || true
docker rmi lstm-app 2>/dev/null || true

echo "🐳 Build Docker…"
docker build -t lstm-app .

echo "🐳 Start container…"
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY concluído com sucesso!"
