FROM python:3.10-slim-bookworm

WORKDIR /app

# Copiando os diretórios do contexto raiz do projeto
COPY app/ app/
COPY model/ model/
COPY data/ data/
COPY utils/ utils/
COPY docker/requirements.txt requirements.txt
COPY entrypoint.sh entrypoint.sh

# Permissões e dependências
RUN chmod +x entrypoint.sh
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install tensorflow==2.15.0

# Comando de inicialização
CMD ["./entrypoint.sh"]