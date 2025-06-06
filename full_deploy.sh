#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Iniciando FULL DEPLOY SIMPLIFICADO (venv com python3.10 + pip)"

BASE_PATH="${BASE_PATH:-/mnt/ebs100}"
PROJECT_DIR="${PROJECT_DIR:-$BASE_PATH/techchallenge4_bruna}"
VENV_DIR="$BASE_PATH/venv310"
CLOUDWATCH_DIR="$BASE_PATH/amazon-cloudwatch-agent"
CLOUDWATCH_BIN="$CLOUDWATCH_DIR/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

echo "🔧 Caminhos:"
echo "  - Projeto:    $PROJECT_DIR"
echo "  - Virtualenv: $VENV_DIR"
echo "  - CloudWatch: $CLOUDWATCH_DIR"

# 1) Verifica se python3.10 está instalado
if ! command -v python3.10 &>/dev/null; then
  echo "❌ python3.10 não encontrado. Certifique-se de ter seguido o build do Python 3.10 (make altinstall)."
  exit 1
fi

# 2) Criar (ou reutilizar) o venv com python3.10
if [ ! -d "$VENV_DIR" ]; then
  echo "♻️ Criando venv em $VENV_DIR com python3.10..."
  python3.10 -m venv "$VENV_DIR"
else
  echo "✅ Virtualenv já existe em $VENV_DIR"
fi

# 3) Ativar o venv
source "$VENV_DIR/bin/activate"

# 4) Atualizar pip / setuptools / wheel e instalar numpy, scipy, scikit-learn via wheels
echo "📦 Atualizando pip, setuptools e wheel..."
python3.10 -m pip install --upgrade pip setuptools wheel

echo "📦 Instalando NumPy e SciPy via wheel..."
python3.10 -m pip install numpy scipy

echo "📦 Instalando scikit-learn via wheel (--prefer-binary)..."
python3.10 -m pip install --prefer-binary scikit-learn

# 5) Instalar demais dependências do projeto
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
  echo "📦 Instalando demais dependências do projeto (requirements.txt)..."
  python3.10 -m pip install -r "$PROJECT_DIR/requirements.txt"
else
  echo "⚠️ requirements.txt não encontrado em $PROJECT_DIR; pulando esta etapa."
fi

# 6) Verificar Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker não instalado. Instale o Docker e tente novamente."
  deactivate
  exit 1
fi
if ! systemctl is-active --quiet docker; then
  echo "⚠️ Docker não ativo, iniciando..."
  sudo systemctl start docker
  sleep 5
  if ! systemctl is-active --quiet docker; then
    echo "❌ Falha ao iniciar Docker."
    deactivate
    exit 1
  fi
fi
echo "✅ Docker ativo."

# 7) Atualizar repositório local
cd "$PROJECT_DIR"
echo "🔄 Atualizando repositório..."
git fetch --all
git reset --hard origin/main
echo "🔄 Código em $(git rev-parse --short HEAD)"

# 8) Executar coleta e treino (já no venv Python 3.10)
echo "📥 Executando coleta de dados…"
python3.10 data/coleta.py || { echo "❌ Erro na coleta"; deactivate; exit 1; }

echo "📊 Executando treino…"
python3.10 model/treino_modelo.py || { echo "❌ Erro no treino"; deactivate; exit 1; }

# 9) Configurar CloudWatch Agent (opcional)
echo "🚀 Verificando AWS CloudWatch Agent…"
if [ -x "$CLOUDWATCH_BIN" ]; then
  echo "✅ CloudWatch Agent já instalado."
else
  echo "⚠️ Instalando CloudWatch Agent no volume maior…"
  mkdir -p "$CLOUDWATCH_DIR"
  cd "$CLOUDWATCH_DIR"
  wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
  rpm2cpio amazon-cloudwatch-agent.rpm | cpio -idmv
  mv opt/amazon-cloudwatch-agent "$CLOUDWATCH_DIR"
  echo "✅ CloudWatch Agent instalado."
fi

# Copiar config do CloudWatch
CONFIG_SRC="$PROJECT_DIR/cloudwatch-config.json"
CONFIG_DST="$CLOUDWATCH_DIR/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
if [ -f "$CONFIG_SRC" ]; then
  cp "$CONFIG_SRC" "$CONFIG_DST"
else
  echo "❌ cloudwatch-config.json não encontrado."
  deactivate
  exit 1
fi

echo "▶️ Iniciando CloudWatch Agent…"
"$CLOUDWATCH_BIN" -a fetch-config -m ec2 -c file:"$CONFIG_DST" -s
echo "✅ CloudWatch Agent iniciado."

echo "🚀 Testando métrica customizada…"
python3.10 "$PROJECT_DIR/cloudwatch_test.py" || echo "⚠️ Falha no teste CloudWatch."

# 10) Build e run no Docker
echo "🐳 Parando e limpando containers/imagens antigos…"
do
