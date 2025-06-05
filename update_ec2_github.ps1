# Caminho: você pode colocar esse script dentro da sua raiz do projeto

# ⚠ ATENÇÃO: este script presume que você já configurou o Git localmente no seu Windows.
# Ex: git config --global user.name e user.email já definidos

# Exibe status antes
git status

# Pergunta mensagem de commit
$msg = Read-Host "Digite a mensagem de commit"

# Adiciona todas as alterações
git add .

# Faz o commit
git commit -m "$msg"

# Faz o pull para garantir que está atualizado com remoto
git pull origin main

# Dá o push final
git push origin main

Write-Output "`n✅ Repositório atualizado com sucesso!"
Write-Output "O EC2 já pode rodar o full_deploy.sh com o novo código."
