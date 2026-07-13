# Gunicorn production configuration
# Usage: gunicorn config.asgi:application -c gunicorn.conf.py
#
# Uses Uvicorn workers so Gunicorn can serve ASGI (HTTP + WebSocket)
# through a single process group.

import os

# Server socket
bind = "0.0.0.0:8080"

# Worker processes — professional-xs (1 vCPU, 1GB RAM) can only safely
# run 1 uvicorn worker.  Each worker loads Django + Firebase + Sentry
# (~400-500MB).  2 workers caused OOM kills and crash loops.
workers = int(os.environ.get("WEB_CONCURRENCY", 1))
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

# Restart workers periodically to prevent memory leaks.
# Lower threshold = more frequent recycles = less memory growth.
max_requests = 500
max_requests_jitter = 50

# Preload app for faster worker startup
preload_app = True
