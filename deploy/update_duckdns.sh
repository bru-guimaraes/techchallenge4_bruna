#!/bin/bash

# Carrega variáveis do .env
if [ ! -f .env ]; then
  echo "[ERRO] Arquivo .env não encontrado!"
  exit 1
fi

export $(grep -v '^#' .env | xargs)

# Verifica se DUCKDNS_TOKEN e DUCKDNS_DOMAIN existem no .env
if [[ -z "$DUCKDNS_TOKEN" || -z "$DUCKDNS_DOMAIN" ]]; then
  echo "[ERRO] DUCKDNS_TOKEN ou DUCKDNS_DOMAIN não configurados no .env"
  exit 1
fi

# Atualiza o IP no DuckDNS
echo "Atualizando IP no DuckDNS..."
RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=")

if [ "$RESPONSE" == "OK" ]; then
  echo "✅ DuckDNS atualizado com sucesso para domínio: ${DUCKDNS_DOMAIN}.duckdns.org"
else
  echo "❌ Falha ao atualizar DuckDNS: $RESPONSE"
fi
