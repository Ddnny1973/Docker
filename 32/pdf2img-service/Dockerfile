FROM python:3.10-slim-bookworm

WORKDIR /app

# Instalar solo lo necesario para convertir PDF a imagen (pdftoppm de poppler)
RUN apt-get update && apt-get install -y --no-install-recommends \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias de Python
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py /app/

EXPOSE 5000

CMD ["python", "app.py"]

