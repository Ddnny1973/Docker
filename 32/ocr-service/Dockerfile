FROM python:3.10-slim

WORKDIR /app

# Instalar solo lo necesario para convertir PDF a imagen
RUN apt-get update && apt-get install -y \
    poppler-utils \
    libglib2.0-0 libsm6 libxext6 libxrender-dev libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias de Python
RUN pip install flask pdf2image pillow sentence-transformers torch --no-cache-dir

# Descargar modelo en build time (evita descarga en cada inicio)
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('distiluse-base-multilingual-cased-v2')"

COPY app.py /app/

EXPOSE 5000

CMD ["python", "app.py"]
