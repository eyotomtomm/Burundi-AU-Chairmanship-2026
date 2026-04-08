"""
Celery application configuration.

Usage:
  Start worker:  celery -A config worker --loglevel=info
  Start beat:    celery -A config beat --loglevel=info
  Start both:    celery -A config worker --beat --loglevel=info
"""
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('burundi_au')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
