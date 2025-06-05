import boto3
import subprocess

print("🔧 Atualizando variáveis AWS no .env...")

# Carrega credenciais atuais da AWS CLI
aws_access_key = subprocess.getoutput("aws configure get aws_access_key_id").strip()
aws_secret_key = subprocess.getoutput("aws configure get aws_secret_access_key").strip()
aws_session_token = subprocess.getoutput("aws configure get aws_session_token").strip()

# Valida
if not aws_access_key or not aws_secret_key:
    print("❌ AWS CLI não configurado corretamente. Rode aws configure.")
    exit(1)

# Carrega arquivo .env existente
env_path = ".env"
try:
    with open(env_path, "r") as f:
        linhas = f.readlines()
except FileNotFoundError:
    linhas = []

# Atualiza variáveis no .env
novas_linhas = []
chaves_processadas = set()

for linha in linhas:
    if linha.startswith("AWS_ACCESS_KEY_ID="):
        novas_linhas.append(f"AWS_ACCESS_KEY_ID={aws_access_key}\n")
        chaves_processadas.add("AWS_ACCESS_KEY_ID")
    elif linha.startswith("AWS_SECRET_ACCESS_KEY="):
        novas_linhas.append(f"AWS_SECRET_ACCESS_KEY={aws_secret_key}\n")
        chaves_processadas.add("AWS_SECRET_ACCESS_KEY")
    elif linha.startswith("AWS_SESSION_TOKEN="):
        novas_linhas.append(f"AWS_SESSION_TOKEN={aws_session_token}\n")
        chaves_processadas.add("AWS_SESSION_TOKEN")
    elif linha.startswith("USE_S3="):
        novas_linhas.append("USE_S3=true\n")
        chaves_processadas.add("USE_S3")
    elif linha.startswith("ALPHAVANTAGE_API_KEY="):
        novas_linhas.append("ALPHAVANTAGE_API_KEY=L2MMCXP58F5Y5F9K\n")
        chaves_processadas.add("ALPHAVANTAGE_API_KEY")
    else:
        novas_linhas.append(linha)

# Adiciona variáveis que não existiam ainda
if "AWS_ACCESS_KEY_ID" not in chaves_processadas:
    novas_linhas.append(f"AWS_ACCESS_KEY_ID={aws_access_key}\n")

if "AWS_SECRET_ACCESS_KEY" not in chaves_processadas:
    novas_linhas.append(f"AWS_SECRET_ACCESS_KEY={aws_secret_key}\n")

if "AWS_SESSION_TOKEN" not in chaves_processadas:
    novas_linhas.append(f"AWS_SESSION_TOKEN={aws_session_token}\n")

if "USE_S3" not in chaves_processadas:
    novas_linhas.append("USE_S3=true\n")

if "ALPHAVANTAGE_API_KEY" not in chaves_processadas:
    novas_linhas.append("ALPHAVANTAGE_API_KEY=L2MMCXP58F5Y5F9K\n")

# EC2_IP permanece manual, como você já controla.

# Escreve .env atualizado
with open(env_path, "w") as f:
    f.writelines(novas_linhas)

print("✅ Variáveis .env atualizadas com sucesso!")
