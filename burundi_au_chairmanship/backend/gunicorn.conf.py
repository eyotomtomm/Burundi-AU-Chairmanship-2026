# Gunicorn production configuration
# Usage: gunicorn config.wsgi -c gunicorn.conf.py

import multiprocessing

# Server socket
bind = "0.0.0.0:8080"

# Worker processes — (2 x CPU cores) + 1
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "gthread"
threads = 2

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
