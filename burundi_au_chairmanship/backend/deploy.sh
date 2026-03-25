#!/bin/bash
# =============================================================================
# Production Deployment Script — Burundi AU Chairmanship Backend
# =============================================================================
# Run this script on the production server or as part of CI/CD.
# Usage: bash deploy.sh
# =============================================================================

set -euo pipefail

echo "========================================="
echo "  Burundi AU Chairmanship — Deploying..."
echo "========================================="

# Ensure we're in the backend directory
cd "$(dirname "$0")"

# 1. Install/update Python dependencies
echo "[1/5] Installing dependencies..."
pip install -r requirements.txt --no-cache-dir

# 2. Run database migrations
echo "[2/5] Running database migrations..."
python manage.py migrate --noinput

# 3. Collect static files
echo "[3/5] Collecting static files..."
python manage.py collectstatic --noinput

# 4. Create cache table (if using database cache)
echo "[4/5] Setting up cache..."
python manage.py createcachetable 2>/dev/null || true

# 5. Run Django system check
echo "[5/5] Running system checks..."
python manage.py check --deploy

echo ""
echo "========================================="
echo "  Deployment complete!"
echo "========================================="
echo ""
echo "Start the server with:"
echo "  gunicorn config.wsgi -c gunicorn.conf.py"
echo ""
