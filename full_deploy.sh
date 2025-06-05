#!/bin/bash
set -e

echo "🚀 Iniciando FULL DEPLOY no EC2 - versão auto-atualizável!"

########################################
# 0️⃣ Instala o git caso não tenha
########################################

if ! command -v git &> /dev/null; then
    echo "⚠️ Git não encontrado. Instalando..."
    sudo yum update -y
    sudo yum install git -y
fi

########################################
# 0️⃣ Auto-atualiza o próprio full_deploy.sh do GitHub
########################################

echo "🔄 Verificando atualizações do full_deploy.sh no GitHub..."
git clone https://github.com/bru-guimaraes/techchallenge4_bruna.git temp_clone

if ! cmp -s temp_clone/full_deploy.sh full_deploy.sh; then
    echo "♻️ Atualizando full_deploy.sh local com a versão do GitHub..."
    cp temp_clone/full_deploy.sh full_deploy.sh
    rm -rf temp_clone
    chmod +x full_deploy.sh
    echo "♻️ Reiniciando o full_deploy.sh atualizado..."
    exec ./full_deploy.sh
else
    echo "✅ full_deploy.sh já está atualizado."
    rm -rf temp_clone
fi
