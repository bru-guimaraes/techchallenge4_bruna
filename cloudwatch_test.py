import boto3
import os
import time

# Configurações via variáveis de ambiente (ou configure diretamente aqui)
AWS_REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
NAMESPACE = "TechChallenge/LSTM"
METRIC_NAME = "TestMetricaCustomizada"
DIMENSION_NAME = "App"
DIMENSION_VALUE = "LSTM-Pipeline"

def enviar_metrica(valor):
    client = boto3.client('cloudwatch', region_name=AWS_REGION)
    response = client.put_metric_data(
        Namespace=NAMESPACE,
        MetricData=[
            {
                'MetricName': METRIC_NAME,
                'Dimensions': [
                    {
                        'Name': DIMENSION_NAME,
                        'Value': DIMENSION_VALUE
                    },
                ],
                'Value': valor,
                'Unit': 'None'
            },
        ]
    )
    print("Métrica enviada:", response)

if __name__ == "__main__":
    for i in range(5):
        valor_teste = i * 10  # Valor crescente só para teste
        enviar_metrica(valor_teste)
        time.sleep(5)  # intervalo entre envios
