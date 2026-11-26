FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 HOST=0.0.0.0 PORT=8080 LOCAL_DEV=false
WORKDIR /app
COPY requirements.lock .
RUN pip install --no-cache-dir -r requirements.lock && useradd --uid 10001 --create-home sowrix
COPY backend/ backend/
COPY operations_v1/ operations_v1/
COPY src/sowrix-public-knowledge.json src/sowrix-public-knowledge.json
# The server validates and serves hashed assets, PWA files, status pages and
# public downloads from the complete generated site tree.
COPY site/ site/
USER sowrix
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/api/defensowrix/health',timeout=4)" || exit 1
CMD ["python","backend/server.py"]
