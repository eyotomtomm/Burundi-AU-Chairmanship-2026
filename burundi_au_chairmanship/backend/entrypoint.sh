#!/bin/sh
set -e

# Migrations and collectstatic run in the PRE_DEPLOY job (app.yaml).
# Only run them here if PRE_DEPLOY was skipped (local dev / docker-compose).
if [ "${SKIP_ENTRYPOINT_MIGRATE:-}" != "1" ]; then
    echo "Running migrations..."
    python manage.py migrate --noinput

    echo "Collecting static files..."
    python manage.py collectstatic --noinput
fi

echo "Starting gunicorn (ASGI via uvicorn workers)..."
exec gunicorn config.asgi:application -c gunicorn.conf.py
