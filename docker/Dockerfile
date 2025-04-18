FROM python:3.10-slim-bookworm

WORKDIR /app

COPY ./app ./app
COPY ./model ./model
COPY ./data ./data
COPY ./utils ./utils
COPY docker/entrypoint.sh /app/entrypoint.sh
COPY docker/requirements.txt ./

RUN chmod +x /app/entrypoint.sh
RUN pip install --no-cache-dir -r requirements.txt

CMD ["/app/entrypoint.sh"]
