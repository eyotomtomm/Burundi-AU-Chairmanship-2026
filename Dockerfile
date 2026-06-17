FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY burundi_au_chairmanship/backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY burundi_au_chairmanship/backend/ .

# Run as non-root — limits blast radius of any RCE/path-traversal exploit.
# Static files dir must be writable for collectstatic (runs in pre-deploy job).
RUN useradd --create-home --no-log-init appuser \
    && mkdir -p /app/staticfiles \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

# Web process only — migrate and collectstatic run in the pre-deploy job
# (see .do/app.yaml jobs section and Procfile).
CMD ["gunicorn", "config.wsgi", "--bind", "0.0.0.0:8080", "--workers", "3", "--log-file", "-"]
