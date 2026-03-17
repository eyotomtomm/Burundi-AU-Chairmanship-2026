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

EXPOSE 8080

# Collect static files, run migrations, then start gunicorn
# collectstatic runs at startup because DJANGO_SECRET_KEY is not available at build time
CMD python manage.py collectstatic --noinput && \
    python manage.py migrate --noinput && \
    gunicorn config.wsgi --bind 0.0.0.0:8080 --workers 3 --log-file -
