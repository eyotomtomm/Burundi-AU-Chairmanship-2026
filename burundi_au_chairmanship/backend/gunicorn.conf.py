# Gunicorn production configuration
# Usage: gunicorn config.asgi:application -c gunicorn.conf.py
#
# Uses Uvicorn workers so Gunicorn can serve ASGI (HTTP + WebSocket)
# through a single process group.

import os

# Server socket
bind = "0.0.0.0:8080"

# Worker processes — respect DO App Platform's WEB_CONCURRENCY env var,
# fall back to 2 workers for 1GB containers (cpu_count() returns host
# cores, not container vCPUs, causing OOM).
workers = int(os.environ.get("WEB_CONCURRENCY", 2))
worker_class = "uvicorn.workers.UvicornWorker"

# Timeout (seconds) — increase for slow database queries
timeout = 120
graceful_timeout = 30
keepalive = 5

# Logging
accesslog = "-"
errorlog = "-"
loglevel = "info"

# Security
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

# Restart workers periodically to prevent memory leaks
max_requests = 1000
max_requests_jitter = 50

# Preload app for faster worker startup
preload_app = True
