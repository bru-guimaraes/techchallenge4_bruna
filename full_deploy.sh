#!/bin/bash
set -euo pipefail

echo "🚀 Iniciando FULL DEPLOY UNIVERSAL robusto com validações"

MINICONDA_PATH=/mnt/ebs100/miniconda3
PROJECT_DIR=/mnt/ebs100/techchallenge4_bruna
BUILD_DIR=$PROJECT_DIR/deploy_build

echo "Usando Miniconda em: $MINICONDA_PATH"
echo "Diretório do projeto: $PROJECT_DIR"

retry() {
  local n=0
  local max=3
  local delay=5
  until "$@"; do
    exit=$?
    n=$((n+1))
    if [ $n -lt $max ]; then
      echo "⚠️ Comando falhou. Tentando novamente em $delay segundos... ($n/$max)"
      sleep $delay
    else
      echo "❌ Comando falhou após $n tentativas."
      return $exit
    fi
  done
  return 0
}

# Verifica se Miniconda está instalada
if [ ! -d "$MINICONDA_PATH" ]; then
  echo "❌ Miniconda não encontrada em $MINICONDA_PATH."
  echo "⚠️ Instale Miniconda nesse caminho e tente novamente."
  exit 1
fi
export PATH="$MINICONDA_PATH/bin:$PATH"

# Carrega conda
if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
  source "$MINICONDA_PATH/etc/profile.d/conda.sh"
else
  echo "❌ Arquivo conda.sh não encontrado em $MINICONDA_PATH/etc/profile.d/"
  exit 1
fi

# Verifica Docker instalado
if ! command -v docker &>/dev/null; then
  echo "❌ Docker não instalado. Instale Docker e rode novamente."
  exit 1
fi

# Verifica se Docker está ativo, tenta iniciar se não estiver
if ! systemctl is-active --quiet docker; then
  echo "⚠️ Docker não está ativo, iniciando..."
  sudo systemctl start docker
  sleep 5
  if ! systemctl is-active --quiet docker; then
    echo "❌ Falha ao iniciar Docker."
    exit 1
  fi
fi

echo "✅ Docker está instalado e ativo."

# Verifica se diretório do projeto existe, cria se não existir
if [ ! -d "$PROJECT_DIR" ]; then
  echo "⚠️ Diretório do projeto $PROJECT_DIR não encontrado, criando..."
  mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# Atualiza repositório git com retries para rede instável
echo "🔄 Atualizando repositório local..."
retry git fetch --all
retry git reset --hard origin/main

# Criar ou atualizar ambiente conda com retry
echo "♻️ Criando ou atualizando ambiente conda lstm-pipeline..."
if conda env list | grep -q "lstm-pipeline"; then
  if ! conda env update -n lstm-pipeline -f environment.yml --prune; then
    echo "⚠️ Falha ao atualizar ambiente, tentando recriar..."
    conda env remove -n lstm-pipeline -y
    conda env create -f environment.yml
  fi
else
  conda env create -f environment.yml
fi

echo "🟢 Ativando ambiente lstm-pipeline..."
conda activate lstm-pipeline

# Executa coleta e treino do modelo com mensagens e captura erros
echo "📥 Executando coleta de dados e treino de modelo..."
if ! python data/coleta.py; then
  echo "❌ Falha na coleta de dados."
  exit 1
fi

if ! python model/treino_modelo.py; then
  echo "❌ Falha no treino do modelo."
  exit 1
fi

# Monta diretório build para Docker, cria e limpa se necessário
echo "🧹 Montando diretório para deploy Docker..."
if [ -d "$BUILD_DIR" ]; then
  rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

# Copia arquivos e pastas necessários para build
echo "📁 Copiando arquivos para build..."
cp application.py "$BUILD_DIR/" || echo "⚠️ application.py não encontrado"
cp Dockerfile "$BUILD_DIR/" || echo "⚠️ Dockerfile não encontrado"
cp .env "$BUILD_DIR/" 2>/dev/null || echo "⚠️ Arquivo .env não encontrado, pulando"
cp -r app "$BUILD_DIR/" || echo "⚠️ Diretório app não encontrado"
cp -r model "$BUILD_DIR/" || echo "⚠️ Diretório model não encontrado"
cp -r utils "$BUILD_DIR/" || echo "⚠️ Diretório utils não encontrado"
cp -r data "$BUILD_DIR/" || echo "⚠️ Diretório data não encontrado"

# Para containers e imagens antigas, ignorando erros
echo "🐳 Parando e removendo containers Docker antigos..."
docker stop lstm-app-container 2>/dev/null || true
docker rm lstm-app-container 2>/dev/null || true
docker rmi lstm-app 2>/dev/null || true

# Builda imagem Docker com retry
echo "🐳 Construindo a imagem Docker..."
if ! retry docker build -t lstm-app "$BUILD_DIR"; then
  echo "❌ Falha ao construir imagem Docker."
  exit 1
fi

# Roda container Docker
echo "🐳 Rodando container Docker..."
if ! docker run -d --name lstm-app-container -p 80:80 lstm-app; then
  echo "❌ Falha ao rodar container Docker."
  exit 1
fi

echo "✅ FULL DEPLOY UNIVERSAL concluído com sucesso!"
