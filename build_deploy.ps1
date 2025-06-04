# Carrega variáveis do .env
$envFile = ".env"
if (!(Test-Path $envFile)) {
    Write-Output "[ERRO] Arquivo .env não encontrado!"
    exit 1
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]*)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        Set-Item -Path "env:$name" -Value $value
    }
}

# Valida o PEM
if (!(Test-Path $env:PEM_PATH)) {
    Write-Output "[ERRO] Arquivo PEM não encontrado em $env:PEM_PATH"
    exit 1
}

# Ativa Conda
Write-Output "Ativando ambiente Conda..."
conda activate lstm-pipeline

# Limpa build anterior
Write-Output "Limpando build anterior..."
Remove-Item -Recurse -Force .\deploy_build\* 2>$null

# Executa coleta e treino
Write-Output "Executando coleta de dados..."
python .\data\coleta.py
Write-Output "Executando treino do modelo..."
python .\model\treino_modelo.py

# Monta build
Write-Output "Montando diretório de build..."
New-Item -ItemType Directory -Force -Path .\deploy_build
Copy-Item .\application.py .\deploy_build\
Copy-Item .\Dockerfile .\deploy_build\
Copy-Item .\.env .\deploy_build\.env -Force
Copy-Item .\auto_env.py .\deploy_build\
Copy-Item -Recurse .\app .\deploy_build\app
Copy-Item -Recurse .\model .\deploy_build\model
Copy-Item -Recurse .\utils .\deploy_build\utils
Copy-Item -Recurse .\data .\deploy_build\data

# Gera ZIP via Python (robusto cross-platform)
Write-Output "Gerando pacote full..."
$pythonScript = @"
import shutil
shutil.make_archive('projeto_lstm_acoes_full', 'zip', 'deploy_build')
"@
$pythonScript | Out-File build_zip.py -Encoding ASCII
python build_zip.py
Remove-Item build_zip.py
Write-Output "Pacote full gerado com sucesso."

# Envia via SCP com retry
Write-Output "Enviando via SCP para o EC2..."
$maxAttempts = 5
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        $zipPath = (Resolve-Path .\projeto_lstm_acoes_full.zip).Path -replace '\\','/'
        scp -i $env:PEM_PATH $zipPath ${env:EC2_USER}@${env:EC2_IP}:/home/ec2-user/deploy_app/
        Write-Output "✅ Deploy enviado com sucesso!"
        break
    } catch {
        Write-Output "Tentativa $attempt falhou: $_"
        if ($attempt -eq $maxAttempts) {
            Write-Output "[ERRO] Falha ao enviar após $maxAttempts tentativas."
            exit 1
        }
        Start-Sleep -Seconds 5
    }
}
