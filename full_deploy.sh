#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Iniciando FULL DEPLOY SIMPLIFICADO (venv com python3.10 + pip)"

BASE_PATH="${BASE_PATH:-/mnt/ebs100}"
PROJECT_DIR="${PROJECT_DIR:-$BASE_PATH/techchallenge4_bruna}"
VENV_DIR="$BASE_PATH/venv310"
TMPDIR="$BASE_PATH/tmp"

# CloudWatch Agent ficará em /opt/aws/amazon-cloudwatch-agent
CLOUDWATCH_DIR="/opt/aws/amazon-cloudwatch-agent"
CLOUDWATCH_BIN="$CLOUDWATCH_DIR/bin/amazon-cloudwatch-agent-ctl"

echo "🔧 Caminhos:"
echo "  - Projeto:         $PROJECT_DIR"
echo "  - Virtualenv:      $VENV_DIR"
echo "  - TMPDIR:          $TMPDIR"
echo "  - CloudWatch dir:  $CLOUDWATCH_DIR"

# 1) Criar TMPDIR para pip e builds (evita “No space left” em /tmp)
mkdir -p "$TMPDIR"
export TMPDIR

# 2) Verifica se python3.10 está instalado
if ! command -v python3.10 &>/dev/null; then
  echo "❌ python3.10 não encontrado. Certifique-se de ter seguido o build do Python 3.10 (make altinstall)."
  exit 1
fi

# 3) Criar (ou reutilizar) o venv com python3.10
if [ ! -d "$VENV_DIR" ]; then
  echo "♻️ Criando venv em $VENV_DIR com python3.10..."
  python3.10 -m venv "$VENV_DIR"
else
  echo "✅ Virtualenv já existe em $VENV_DIR"
fi

# 4) Ativar o venv
source "$VENV_DIR/bin/activate"

# 5) Atualizar pip / setuptools / wheel
echo "📦 Atualizando pip, setuptools e wheel..."
python3.10 -m pip install --upgrade pip setuptools wheel --no-cache-dir

# 6) Instalar NumPy e SciPy via wheels
echo "📦 Instalando NumPy e SciPy via wheel..."
python3.10 -m pip install numpy scipy --no-cache-dir

# 7) Instalar scikit-learn via wheels binários
echo "📦 Instalando scikit-learn via wheel (--prefer-binary)..."
python3.10 -m pip install --prefer-binary scikit-learn --no-cache-dir

# 8) Ajustar fastparquet no requirements.txt (versão 2024.3.0 não existe)
REQ_FILE="$PROJECT_DIR/requirements.txt"
if grep -q "fastparquet==2024.3.0" "$REQ_FILE"; then
  echo "🔄 Substituindo fastparquet==2024.3.0 por fastparquet==2024.2.0 no requirements.txt"
  sed -i 's|fastparquet==2024.3.0|fastparquet==2024.2.0|g' "$REQ_FILE"
fi

# 9) Instalar demais dependências do projeto (usando TMPDIR e sem cache)
if [ -f "$REQ_FILE" ]; then
  echo "📦 Instalando demais dependências do projeto (requirements.txt)..."
  python3.10 -m pip install -r "$REQ_FILE" --no-cache-dir
else
  echo "⚠️ requirements.txt não encontrado em $PROJECT_DIR; pulando esta etapa."
fi

# 10) Verificar Docker
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

# 11) Atualizar repositório local
cd "$PROJECT_DIR"
echo "🔄 Atualizando repositório..."
git fetch --all
git reset --hard origin/main
echo "🔄 Código em $(git rev-parse --short HEAD)"

# 12) Executar coleta e treino (já no venv Python 3.10)
echo "📥 Executando coleta de dados…"
python3.10 data/coleta.py || { echo "❌ Erro na coleta"; deactivate; exit 1; }

echo "📊 Executando treino…"
python3.10 model/treino_modelo.py || { echo "❌ Erro no treino"; deactivate; exit 1; }

# 13) Configurar CloudWatch Agent (opcional)
echo "🚀 Verificando AWS CloudWatch Agent…"
if [ -x "$CLOUDWATCH_BIN" ]; then
  echo "✅ CloudWatch Agent já instalado em $CLOUDWATCH_DIR."
else
  echo "⚠️ Instalando CloudWatch Agent em /opt/aws/amazon-cloudwatch-agent..."
  # Criar /opt/aws, caso não exista, e ajustar permissões
  sudo mkdir -p /opt/aws
  sudo chown "$USER":"$USER" /opt/aws

  cd /opt/aws
  wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
  rpm2cpio amazon-cloudwatch-agent.rpm | cpio -idmv

  # Mover a pasta correta
  sudo mv opt/aws/amazon-cloudwatch-agent /opt/aws/
  sudo chown -R "$USER":"$USER" "$CLOUDWATCH_DIR"

  # Limpar arquivos extras
  rm -rf amazon-cloudwatch-agent.rpm opt usr var

  echo "✅ CloudWatch Agent instalado em $CLOUDWATCH_DIR."
fi

# 14) Copiar config do CloudWatch para o local correto
CONFIG_SRC="$PROJECT_DIR/cloudwatch-config.json"
CONFIG_DST="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
if [ -f "$CONFIG_SRC" ]; then
  sudo cp "$CONFIG_SRC" "$CONFIG_DST"
  sudo chown "$USER":"$USER" "$CONFIG_DST"
else
  echo "❌ cloudwatch-config.json não encontrado."
  deactivate
  exit 1
fi

# 15) Iniciar o CloudWatch Agent via ctl (não usa systemd)
echo "▶️ Iniciando CloudWatch Agent…"
sudo "$CLOUDWATCH_BIN" -a fetch-config -m ec2 -c file:"$CONFIG_DST" -s
echo "✅ CloudWatch Agent iniciado."

echo "🚀 Testando métrica customizada…"
python3.10 "$PROJECT_DIR/cloudwatch_test.py" || echo "⚠️ Falha no teste CloudWatch."

# 16) Build e run no Docker
echo "🐳 Parando e limpando containers/imagens antigos…"
docker stop lstm-app-container 2>/dev/null || true
docker rm lstm-app-container 2>/dev/null || true
docker rmi lstm-app 2>/dev/null || true

echo "🐳 Construindo imagem Docker…"
docker build -t lstm-app .

echo "🐳 Rodando container Docker…"
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY concluído com sucesso!"

# 17) Desativa o venv
deactivate
