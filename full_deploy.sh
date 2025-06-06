#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Iniciando FULL DEPLOY SIMPLIFICADO (venv com python3.10 + pip)"

# ----------------------------------------------------
# 0) Defina as pastas do projeto e do venv
# ----------------------------------------------------
BASE_PATH="${BASE_PATH:-/mnt/ebs100}"
PROJECT_DIR="${PROJECT_DIR:-$BASE_PATH/techchallenge4_bruna}"
VENV_DIR="$BASE_PATH/venv310"

# ----------------------------------------------------
# 1) Crie um TMPDIR em volume com espaço livre (por exemplo, /mnt/ebs100/tmp)
# ----------------------------------------------------
TMPDIR="$BASE_PATH/tmp"
mkdir -p "$TMPDIR"
export TMPDIR

# ----------------------------------------------------
# 2) Defina onde ficará o CloudWatch Agent (em /opt para não ter problema de permissão)
# ----------------------------------------------------
CLOUDWATCH_DIR="/opt/aws/amazon-cloudwatch-agent"
CLOUDWATCH_BIN="$CLOUDWATCH_DIR/bin/amazon-cloudwatch-agent-ctl"

echo "🔧 Caminhos configurados:"
echo "  - Projeto:    $PROJECT_DIR"
echo "  - Virtualenv: $VENV_DIR"
echo "  - TMPDIR:     $TMPDIR"
echo "  - CloudWatch: $CLOUDWATCH_DIR"

# ----------------------------------------------------
# 3) Verificar se python3.10 existe
# ----------------------------------------------------
if ! command -v python3.10 &>/dev/null; then
  echo "❌ ERRO: python3.10 não encontrado. Certifique-se de que compilou e instalou o Python 3.10 corretamente."
  exit 1
fi

# ----------------------------------------------------
# 4) (Re)criar ou reutilizar o venv com python3.10
# ----------------------------------------------------
if [ ! -d "$VENV_DIR" ]; then
  echo "♻️ Criando virtualenv em $VENV_DIR com python3.10..."
  python3.10 -m venv "$VENV_DIR"
else
  echo "✅ Virtualenv já existe em $VENV_DIR"
fi

# ----------------------------------------------------
# 5) Ativar o venv
# ----------------------------------------------------
source "$VENV_DIR/bin/activate"

# ----------------------------------------------------
# 6) Atualizar pip / setuptools / wheel usando --no-cache-dir
# ----------------------------------------------------
echo "📦 Atualizando pip, setuptools e wheel (sem usar cache)..."
python3.10 -m pip install --upgrade pip setuptools wheel --no-cache-dir

# ----------------------------------------------------
# 7) Instalar NumPy e SciPy via wheels (sem cache)
# ----------------------------------------------------
echo "📦 Instalando NumPy e SciPy via wheel (sem cache)..."
python3.10 -m pip install numpy scipy --no-cache-dir

# ----------------------------------------------------
# 8) Instalar scikit-learn (forçando wheel binário, sem cache)
# ----------------------------------------------------
echo "📦 Instalando scikit-learn (sem cache, preferindo wheel binário)..."
python3.10 -m pip install --prefer-binary scikit-learn --no-cache-dir

# ----------------------------------------------------
# 9) Instalar TensorFlow separadamente (sem cache) para evitar usar /tmp pequeno
# ----------------------------------------------------
echo "📦 Instalando TensorFlow 2.15.0 (sem cache) usando TMPDIR em $TMPDIR..."
python3.10 -m pip install tensorflow==2.15.0 --no-cache-dir

# ----------------------------------------------------
# 10) Ajustar fastparquet no requirements.txt (se necessário)
# ----------------------------------------------------
REQ_FILE="$PROJECT_DIR/requirements.txt"
if grep -q "fastparquet==2024.3.0" "$REQ_FILE"; then
  echo "🔄 Ajustando fastparquet para uma versão disponível no PyPI..."
  sed -i 's|fastparquet==2024.3.0|fastparquet==2024.2.0|g' "$REQ_FILE"
fi

# ----------------------------------------------------
# 11) Instalar o restante das dependências do projeto (sem cache)
# ----------------------------------------------------
if [ -f "$REQ_FILE" ]; then
  echo "📦 Instalando demais dependências do projeto (sem cache)..."
  python3.10 -m pip install -r "$REQ_FILE" --no-cache-dir
else
  echo "⚠️ Arquivo requirements.txt não encontrado em $PROJECT_DIR. Pulando esta etapa."
fi

# ----------------------------------------------------
# 12) Verificar e iniciar Docker
# ----------------------------------------------------
echo "🐳 Verificando serviço Docker..."
if ! command -v docker &>/dev/null; then
  echo "❌ ERRO: Docker não instalado. Instale o Docker e rode novamente."
  deactivate
  exit 1
fi

# Se o Docker não estiver ativo, inicia-o
if ! systemctl is-active --quiet docker; then
  echo "⚠️ Docker não ativo, iniciando o serviço..."
  sudo systemctl start docker
  sleep 5
  if ! systemctl is-active --quiet docker; then
    echo "❌ ERRO: Falha ao iniciar Docker."
    deactivate
    exit 1
  fi
fi
echo "✅ Docker está ativo."

# ----------------------------------------------------
# 13) Atualizar o repositório local
# ----------------------------------------------------
cd "$PROJECT_DIR"
echo "🔄 Atualizando repositório do GitHub..."
git fetch --all
git reset --hard origin/main
echo "🔄 Repositório atualizado para o commit $(git rev-parse --short HEAD)"

# ----------------------------------------------------
# 14) Rodar coleta e treino (dentro do venv Python3.10)
# ----------------------------------------------------
echo "📥 Executando coleta de dados..."
python3.10 data/coleta.py || { echo "❌ Erro durante a coleta."; deactivate; exit 1; }

echo "📊 Executando treino do modelo..."
python3.10 model/treino_modelo.py || { echo "❌ Erro durante o treino."; deactivate; exit 1; }
# Isso gerará model/modelo_lstm.keras e model/scaler.gz

# ----------------------------------------------------
# 15) Configurar e iniciar o AWS CloudWatch Agent
# ----------------------------------------------------
echo "🚀 Verificando AWS CloudWatch Agent..."

if [ -x "$CLOUDWATCH_BIN" ]; then
  echo "✅ CloudWatch Agent já instalado em $CLOUDWATCH_DIR."
else
  echo "⚠️ Instalando CloudWatch Agent em /opt/aws/amazon-cloudwatch-agent..."

  # 15.1) Criar /opt/aws e ajustar permissões
  sudo mkdir -p /opt/aws
  sudo chown "$USER":"$USER" /opt/aws

  # 15.2) Entrar em /opt/aws, baixar e extrair o RPM
  cd /opt/aws
  wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
  rpm2cpio amazon-cloudwatch-agent.rpm | cpio -idmv

  # 15.3) Mover a pasta correta e ajustar permissões
  sudo mv opt/aws/amazon-cloudwatch-agent /opt/aws/
  sudo chown -R "$USER":"$USER" "$CLOUDWATCH_DIR"

  # 15.4) Limpar arquivos extras
  rm -rf amazon-cloudwatch-agent.rpm opt usr var

  echo "✅ CloudWatch Agent instalado em $CLOUDWATCH_DIR."
fi

# ----------------------------------------------------
# 16) Criar e habilitar o systemd service para o CloudWatch Agent
# ----------------------------------------------------
echo "🛠️  Configurando o service unit do CloudWatch Agent em systemd…"

sudo tee /etc/systemd/system/amazon-cloudwatch-agent.service > /dev/null << 'EOF'
[Unit]
Description=Amazon CloudWatch Agent
After=network.target

[Service]
Type=simple
ExecStart=/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a run
ExecStop=/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "▶️ Recarregando systemd e habilitando o serviço…"
sudo systemctl daemon-reload
sudo systemctl enable amazon-cloudwatch-agent.service
sudo systemctl start amazon-cloudwatch-agent.service

echo "✅ Service unit do CloudWatch Agent habilitado e iniciado."

# ----------------------------------------------------
# 17) Copiar config JSON (na raiz do projeto) para /opt/aws/amazon-cloudwatch-agent/etc
# ----------------------------------------------------
CONFIG_SRC="$PROJECT_DIR/cloudwatch-config.json"
CONFIG_DST="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

if [ -f "$CONFIG_SRC" ]; then
  echo "📄 Copiando cloudwatch-config.json para $CONFIG_DST..."
  sudo cp "$CONFIG_SRC" "$CONFIG_DST"
  sudo chown "$USER":"$USER" "$CONFIG_DST"
else
  echo "❌ ERRO: cloudwatch-config.json não encontrado em $PROJECT_DIR."
  deactivate
  exit 1
fi

# 17.1) Aplicar a configuração ao agente (fetch + restart)
echo "▶️ Aplicando configuração (fetch + restart) no CloudWatch Agent..."
sudo $CLOUDWATCH_BIN -a fetch-config -m ec2 -c file:"$CONFIG_DST" -s

# ----------------------------------------------------
# 18) Executar teste rápido do CloudWatch (opcional)
# ----------------------------------------------------
echo "🚀 Testando métrica customizada (se existir)…"
python3.10 "$PROJECT_DIR/cloudwatch_test.py" || echo "⚠️ Aviso: falha no teste CloudWatch."

# ----------------------------------------------------
# 19) Parar containers/imagens antigos e construir o Docker
# ----------------------------------------------------
echo "🐳 Parando e removendo containers/imagens antigos…"
docker stop lstm-app-container 2>/dev/null || true
docker rm   lstm-app-container 2>/dev/null || true
docker rmi  lstm-app           2>/dev/null || true

echo "🐳 Construindo nova imagem Docker (tag: lstm-app)…"
docker build -t lstm-app .

echo "🐳 Rodando container Docker (lstm-app-container na porta 80)…"
docker run -d --name lstm-app-container -p 80:80 lstm-app

echo "✅ FULL DEPLOY da aplicação concluído com sucesso."

# ----------------------------------------------------
# 20) Configurar envio automático de métricas customizadas
# ----------------------------------------------------
echo "🚀 Configurando envio automático de métricas customizadas para o CloudWatch..."

# 20.1) Instalar AWS CLI (caso ainda não esteja)
if ! command -v aws &>/dev/null; then
  echo "📦 Instalando awscli via yum..."
  sudo yum install -y awscli
else
  echo "✅ awscli já instalado."
fi

# 20.2) Instalar cronie (para suportar crontab)
if ! command -v crontab &>/dev/null; then
  echo "📦 Instalando cronie (para suportar crontab)..."
  sudo yum install -y cronie
else
  echo "✅ cronie (crontab) já instalado."
fi

# 20.3) Garantir que o script push_metrics.py está executável
METRICS_SCRIPT="$PROJECT_DIR/push_metrics.py"
if [ -f "$METRICS_SCRIPT" ]; then
  echo "🔧 Garantindo permissão de execução para $METRICS_SCRIPT..."
  sudo chmod +x "$METRICS_SCRIPT"
else
  echo "❌ ERRO: $METRICS_SCRIPT não encontrado. Verifique o caminho."
  deactivate
  exit 1
fi

# 20.4) Executa uma vez para enviar métricas imediatamente
echo "🚀 Executando push_metrics.py pela primeira vez..."
python3 "$METRICS_SCRIPT" || echo "⚠️ Aviso: falha ao executar $METRICS_SCRIPT agora."

# 20.5) Agendar no cron para rodar a cada 5 minutos (se ainda não estiver agendado)
CRON_ENTRY="*/5 * * * * $METRICS_SCRIPT >> $PROJECT_DIR/push_metrics.log 2>&1"
( crontab -l -u ec2-user 2>/dev/null | grep -F "$METRICS_SCRIPT" ) \
  || ( crontab -l -u ec2-user 2>/dev/null; echo "$CRON_ENTRY" ) | crontab -u ec2-user -

echo "✅ push_metrics.py agendado via cron (a cada 5 minutos)."

# ----------------------------------------------------
# 21) Desativar o venv
# ----------------------------------------------------
deactivate
