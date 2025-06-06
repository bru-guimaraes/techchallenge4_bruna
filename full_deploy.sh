#!/bin/bash
set -euo pipefail

echo "🚀 Iniciando FULL DEPLOY ROBUSTO com MINICONDA_PATH variável"

MINICONDA_PATH=/mnt/ebs100/miniconda3
PROJECT_DIR=/mnt/ebs100/techchallenge4_bruna
CLOUDWATCH_DIR="/mnt/ebs100/amazon-cloudwatch-agent"
CLOUDWATCH_BIN="$CLOUDWATCH_DIR/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

echo "Usando Miniconda em: $MINICONDA_PATH"
echo "Diretório do projeto: $PROJECT_DIR"

# --- Verifica Miniconda instalada ---
if [ ! -d "$MINICONDA_PATH" ]; then
  echo "❌ Miniconda não encontrada em $MINICONDA_PATH."
  exit 1
fi

export PATH="$MINICONDA_PATH/bin:$PATH"

# --- Carrega conda ---
if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
  source "$MINICONDA_PATH/etc/profile.d/conda.sh"
else
  echo "❌ Arquivo conda.sh não encontrado."
  exit 1
fi

# --- Verifica Docker ---
if ! command -v docker &>/dev/null; then
  echo "❌ Docker não instalado."
  exit 1
fi

if ! systemctl is-active --quiet docker; then
  echo "⚠️ Docker não está ativo, iniciando..."
  sudo systemctl start docker
  sleep 5
fi

echo "✅ Docker está instalado e ativo."

# --- Atualiza repo ---
cd "$PROJECT_DIR"
echo "🔄 Atualizando repositório local..."
git fetch --all
git reset --hard origin/main
echo "🔄 Código atualizado para commit: $(git rev-parse --short HEAD)"

# --- Criar ou verificar ambiente conda ---
echo "♻️ Verificando ambiente conda lstm-pipeline..."
if conda env list | grep -q "lstm-pipeline"; then
  echo "✅ Ambiente lstm-pipeline já existe, ativando..."
else
  echo "♻️ Criando ambiente lstm-pipeline..."
  conda env create -f environment.yml
fi

# --- Ativa ambiente (AJUSTE FINAL) ---
echo "🟢 Ativando ambiente lstm-pipeline..."
source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate lstm-pipeline

# --- Executa pipeline do projeto ---
echo "📥 Executando coleta de dados..."
python data/coleta.py || { echo "❌ Erro na coleta"; exit 1; }

echo "📊 Executando treino do modelo..."
python model/treino_modelo.py || { echo "❌ Erro no treino"; exit 1; }

# --- CloudWatch ---
echo "🚀 Verificando CloudWatch Agent..."
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

echo "🚀 Teste CloudWatch..."
python "$PROJECT_DIR/cloudwatch_test.py" || echo "⚠️ Falha ao executar teste CloudWatch."

# --- Docker ---
echo "🐳 Parando e limpando containers antigos..."
docker stop lstm-app-container 2>/dev/null || true
docker rm lstm-app-container 2>/dev/null || true
docker rmi lstm-app 2>/dev/null || true

echo "🐳 Build Docker..."
docker build -t lstm-app .

echo "🐳 Start container..."
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY concluído com sucesso!"
