FROM python:3.11-slim AS builder

WORKDIR /app
COPY ../requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim

WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY ../app.py .
COPY ../templates/ templates/

RUN apt-get update && apt-get install -y --no-install-recommends gosu && \
    rm -rf /var/lib/apt/lists/* && \
    adduser --disabled-password --gecos '' appuser && \
    mkdir -p /app/data /app/uploads && \
    chown -R appuser:appuser /app/data /app/uploads

COPY docker/entrypoint.sh /entrypoint.sh
# USER is intentionally not set here — entrypoint drops to appuser after chown
RUN chmod +x /entrypoint.sh

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "app.py"]
