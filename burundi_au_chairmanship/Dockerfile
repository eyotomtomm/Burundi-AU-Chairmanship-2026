FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY backend/ .

# Collect static files (fail on error so broken builds are caught)
RUN python manage.py collectstatic --noinput

EXPOSE 8080

# Run migrations then start gunicorn
CMD python manage.py migrate --noinput && gunicorn config.wsgi --bind 0.0.0.0:8080 --log-file -
