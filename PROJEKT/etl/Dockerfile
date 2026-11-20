FROM python:3.12-slim

WORKDIR /app

# Instalacja zależności
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopiowanie kodu modułu ETL
COPY . .

# Tworzenie katalogów na dane
RUN mkdir -p /app/data/inbox /app/data/processed /app/data/failed

ENV PYTHONUNBUFFERED=1

# Domyślne uruchomienie
CMD ["python", "etl_loader.py", "--once"]
