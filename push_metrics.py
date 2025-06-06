#!/usr/bin/env python3

import boto3
import os
import time
import subprocess

# Configurações
AWS_REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
NAMESPACE = "Custom/System"
DIMENSION_NAME = "InstanceId"  # Ainda tentamos usar, mas caímos no fallback

# Cria cliente CloudWatch
cw_client = boto3.client("cloudwatch", region_name=AWS_REGION)

def get_instance_id():
    """Recupera o ID da instância via metadata. Se falhar, retorna 'unknown'."""
    try:
        instance_id = subprocess.check_output(
            ["curl", "-s", "http://169.254.169.254/latest/meta-data/instance-id"]
        ).decode().strip()
        return instance_id if instance_id else "unknown"
    except Exception:
        return "unknown"

INSTANCE_ID = get_instance_id()

def collect_cpu_usage():
    """
    Coleta uso de CPU (percentual) em 1 segundo, via /proc/stat.
    Retorna (cpu_used_percent, cpu_idle_percent).
    """
    with open("/proc/stat", "r") as f:
        fields_prev = f.readline().split()[1:]
        cpu_prev = list(map(int, fields_prev))
    time.sleep(1)
    with open("/proc/stat", "r") as f:
        fields_cur = f.readline().split()[1:]
        cpu_cur = list(map(int, fields_cur))

    total_prev = sum(cpu_prev[:8])
    total_cur = sum(cpu_cur[:8])
    idle_prev = cpu_prev[3]
    idle_cur = cpu_cur[3]

    delta_total = total_cur - total_prev
    delta_idle = idle_cur - idle_prev

    if delta_total == 0:
        return 0.0, 0.0

    cpu_idle_pct = (delta_idle / delta_total) * 100.0
    cpu_used_pct = 100.0 - cpu_idle_pct
    return round(cpu_used_pct, 2), round(cpu_idle_pct, 2)

def collect_memory_usage():
    """
    Coleta percentual de memória usada via /proc/meminfo.
    Retorna mem_used_percent.
    """
    meminfo = {}
    with open("/proc/meminfo", "r") as f:
        for line in f:
            key, value = line.split(":", 1)
            meminfo[key.strip()] = int(value.split()[0])

    total_kb = meminfo.get("MemTotal", 0)
    avail_kb = meminfo.get("MemAvailable", 0)
    if total_kb == 0:
        return 0.0

    used_kb = total_kb - avail_kb
    used_pct = (used_kb / total_kb) * 100.0
    return round(used_pct, 2)

def collect_disk_usage():
    """
    Coleta percentual de disco usado na partição root (/) via df.
    Retorna disk_used_percent.
    """
    try:
        output = subprocess.check_output(["df", "--output=pcent", "/"]).decode().splitlines()
        usage_str = output[1].strip().strip("%")
        return float(usage_str)
    except Exception:
        return 0.0

def put_metric(metric_name, value):
    """
    Envia um datapoint para o CloudWatch usando boto3.
    Se INSTANCE_ID == "unknown", envia sem dimensão; caso contrário, envia com dimensão.
    """
    metric_data = {
        "MetricName": metric_name,
        "Value": value,
        "Unit": "Percent",
    }

    # Se tiver um ID válido (> 0 chars), envia como dimensão; senão envia sem dimensão
    if INSTANCE_ID and INSTANCE_ID != "unknown":
        metric_data["Dimensions"] = [
            {"Name": DIMENSION_NAME, "Value": INSTANCE_ID}
        ]

    try:
        cw_client.put_metric_data(
            Namespace=NAMESPACE,
            MetricData=[metric_data]
        )
        print(f"✅ {metric_name} = {value}% enviado com sucesso (InstanceId={INSTANCE_ID}).")
    except Exception as e:
        print(f"❌ Erro ao enviar {metric_name}: {e}")

def main():
    cpu_used, cpu_idle = collect_cpu_usage()
    mem_used = collect_memory_usage()
    disk_used = collect_disk_usage()

    put_metric("CPU_Utilization", cpu_used)
    put_metric("CPU_Idle", cpu_idle)
    put_metric("Memory_Used_Percent", mem_used)
    put_metric("Disk_Used_Percent", disk_used)

if __name__ == "__main__":
    main()
