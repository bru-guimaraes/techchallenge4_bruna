import boto3
import os
import requests
from dotenv import load_dotenv

# Carrega o .env atual
load_dotenv()

# Atualiza arquivo .env
def atualizar_env(variaveis):
    with open(".env", "w") as f:
        for k, v in variaveis.items():
            f.write(f"{k}={v}\n")

# Coleta credenciais temporárias
def obter_credenciais():
    session = boto3.Session()
    credentials = session.get_credentials().get_frozen_credentials()

    return {
        "AWS_ACCESS_KEY_ID": credentials.access_key,
        "AWS_SECRET_ACCESS_KEY": credentials.secret_key,
        "AWS_SESSION_TOKEN": credentials.token
    }

# Captura IP público atual
def obter_ip_publico():
    ip = requests.get("https://checkip.amazonaws.com").text.strip()
    return ip

# Atualiza DuckDNS
def atualizar_duckdns(domain, token, ip):
    url = f"https://www.duckdns.org/update?domains={domain}&token={token}&ip={ip}"
    response = requests.get(url)
    if response.status_code == 200 and "OK" in response.text:
        print("✅ DuckDNS atualizado com sucesso.")
    else:
        print(f"❌ Falha ao atualizar DuckDNS: {response.text}")

# -------- EXECUÇÃO PRINCIPAL --------

print("🔐 Buscando novas credenciais AWS temporárias...")
novas_credenciais = obter_credenciais()

print("🌐 Capturando IP público atual...")
ip_publico = obter_ip_publico()

# Carrega variáveis fixas do .env atual
BUCKET_NAME = os.getenv("BUCKET_NAME")
MODEL_KEY = os.getenv("MODEL_KEY")
SCALER_KEY = os.getenv("SCALER_KEY")
ALPHA_VANTAGE_API_KEY = os.getenv("ALPHA_VANTAGE_API_KEY")
PEM_PATH = os.getenv("PEM_PATH")
DUCKDNS_DOMAIN = os.getenv("DUCKDNS_DOMAIN")
DUCKDNS_TOKEN = os.getenv("DUCKDNS_TOKEN")

# Atualiza .env com tudo
variaveis = {
    **novas_credenciais,
    "AWS_DEFAULT_REGION": "us-east-1",
    "BUCKET_NAME": BUCKET_NAME,
    "MODEL_KEY": MODEL_KEY,
    "SCALER_KEY": SCALER_KEY,
    "ALPHA_VANTAGE_API_KEY": ALPHA_VANTAGE_API_KEY,
    "EC2_IP": ip_publico,
    "EC2_USER": "ec2-user",
    "PEM_PATH": PEM_PATH,
    "DUCKDNS_DOMAIN": DUCKDNS_DOMAIN,
    "DUCKDNS_TOKEN": DUCKDNS_TOKEN
}

atualizar_env(variaveis)
print("✅ .env atualizado com novas credenciais e IP!")

# Atualiza o DuckDNS
if DUCKDNS_DOMAIN and DUCKDNS_TOKEN:
    atualizar_duckdns(DUCKDNS_DOMAIN, DUCKDNS_TOKEN, ip_publico)
