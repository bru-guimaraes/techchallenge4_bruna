# build_deploy.ps1 FINAL AJUSTADO - FULL AUTOENV embutido

Write-Output "Atualizando variaveis AWS automaticamente..."

# Busca variáveis AWS locais (aws configure)
$awsAccessKey = (aws configure get aws_access_key_id).Trim()
$awsSecretKey = (aws configure get aws_secret_access_key).Trim()
$awsSessionToken = (aws configure get aws_session_token)

if ($awsSessionToken) {
    $awsSessionToken = $awsSessionToken.Trim()
} else {
    $awsSessionToken = ""
}

if (-not $awsAccessKey -or -not $awsSecretKey) {
    Write-Output "[ERRO] AWS CLI nao configurado corretamente no seu Windows. Rode: aws configure"
    exit 1
}

# Atualiza o .env local
$envFile = ".env"
if (!(Test-Path $envFile)) {
    Write-Output "[ERRO] Arquivo .env nao encontrado!"
    exit 1
}

# Apenas atualiza as variáveis sensíveis, mantendo o EC2_IP atual do .env
(Get-Content $envFile) | ForEach-Object {
    $_ -replace '^AWS_ACCESS_KEY_ID=.*', "AWS_ACCESS_KEY_ID=$awsAccessKey" `
       -replace '^AWS_SECRET_ACCESS_KEY=.*', "AWS_SECRET_ACCESS_KEY=$awsSecretKey" `
       -replace '^AWS_SESSION_TOKEN=.*', "AWS_SESSION_TOKEN=$awsSessionToken"
} | Set-Content $envFile -Encoding UTF8

Write-Output "Variaveis .env atualizadas com sucesso!"

# Carrega variáveis do .env atualizado
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        Set-Item -Path "env:$name" -Value $value
    }
}

# Valida PEM
if (!(Test-Path $env:PEM_PATH)) {
    Write-Output "[ERRO] Arquivo PEM nao encontrado em $env:PEM_PATH"
    exit 1
}

# Ativa Conda
Write-Output "Ativando ambiente Conda..."
conda activate lstm-pipeline

# Valida model_loader
if (!(Test-Path .\app\model_loader.py)) {
    Write-Output "[ERRO] model_loader.py nao encontrado em ./app/"
    exit 1
}

# Limpa build anterior
Write-Output "Limpando build anterior..."
Remove-Item -Recurse -Force .\deploy_build\* 2>$null

# Executa coleta de dados
Write-Output "Executando coleta de dados..."
python .\data\coleta.py

# Executa treino do modelo
Write-Output "Executando treino do modelo..."
python .\model\treino_modelo.py

# Monta build
Write-Output "Montando diretorio de build..."
New-Item -ItemType Directory -Force -Path .\deploy_build
Copy-Item .\application.py .\deploy_build\
Copy-Item .\Dockerfile .\deploy_build\
Copy-Item .\.env .\deploy_build\.env -Force
Copy-Item -Recurse .\app .\deploy_build\app
Copy-Item -Recurse .\model .\deploy_build\model
Copy-Item -Recurse .\utils .\deploy_build\utils
Copy-Item -Recurse .\data .\deploy_build\data
Copy-Item .\full_deploy.sh .\deploy_build\

# Gera o ZIP cross-platform via Python
Write-Output "Gerando pacote full cross-platform via Python..."
$pythonScript = @"
import shutil
shutil.make_archive('projeto_lstm_acoes_full', 'zip', 'deploy_build')
"@
$pythonScript | Out-File build_zip.py -Encoding ASCII
python build_zip.py
Remove-Item build_zip.py

Write-Output "Pacote full gerado com sucesso!"

# Envio via SCP
Write-Output "Enviando pacote via SCP para EC2..."
$maxAttempts = 5
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        $zipPath = (Resolve-Path .\projeto_lstm_acoes_full.zip).Path -replace '\\','/'
        scp -i $env:PEM_PATH $zipPath ${env:EC2_USER}@${env:EC2_IP}:/home/ec2-user/deploy_app/
        Write-Output "Deploy enviado com sucesso via SCP!"
        break
    } catch {
        Write-Output "Tentativa $attempt falhou: $_"
        if ($attempt -eq $maxAttempts) {
            Write-Output "[ERRO] Falha ao enviar apos $maxAttempts tentativas."
            exit 1
        }
        Start-Sleep -Seconds 5
    }
}
