FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN pip install --upgrade pip

RUN pip install \
    numpy==1.26.4 \
    scikit-learn==1.3.2 \
    pandas==2.2.2 \
    joblib==1.3.2 \
    boto3==1.34.103 \
    pyarrow==15.0.2 \
    tensorflow==2.15.0 \
    fastapi==0.115.1 \
    uvicorn[standard]==0.34.1 \
    pydantic==2.11.5 \
    yfinance==0.2.37 \
    python-dotenv==1.0.1

CMD ["uvicorn", "application:application", "--host", "0.0.0.0", "--port", "80"]
