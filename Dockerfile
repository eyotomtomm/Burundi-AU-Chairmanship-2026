FROM python:3.9-slim

WORKDIR /app

COPY burundi_au_chairmanship/backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY burundi_au_chairmanship/backend/ .

RUN python manage.py collectstatic --noinput || true

EXPOSE 8080

CMD ["gunicorn", "config.wsgi", "--bind", "0.0.0.0:8080", "--workers", "2"]
