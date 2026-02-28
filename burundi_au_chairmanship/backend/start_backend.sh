#!/bin/bash

# Burundi AU Chairmanship Backend Startup Script
# This script sets up environment variables, creates a superuser (if needed), and starts the Django server

echo "=================================================="
echo "Burundi AU Chairmanship Backend"
echo "=================================================="
echo ""

# Set environment variables for development
export DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY:-temp-dev-key-$(date +%s)}"
export DJANGO_DEBUG="${DJANGO_DEBUG:-True}"
export DJANGO_ALLOWED_HOSTS="${DJANGO_ALLOWED_HOSTS:-localhost,127.0.0.1}"

echo "✓ Environment variables set"
echo "  - DEBUG: $DJANGO_DEBUG"
echo "  - ALLOWED_HOSTS: $DJANGO_ALLOWED_HOSTS"
echo ""

# Check if superuser exists
echo "Checking for superuser..."
SUPERUSER_EXISTS=$(python3 manage.py shell -c "from django.contrib.auth.models import User; print(User.objects.filter(is_superuser=True).exists())" 2>/dev/null | tail -n 1)

if [ "$SUPERUSER_EXISTS" = "False" ]; then
    echo ""
    echo "No superuser found. Creating one now..."
    echo "--------------------------------------------"
    echo "Please enter superuser credentials:"
    echo ""

    # Create superuser interactively
    python3 manage.py createsuperuser

    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ Superuser created successfully!"
    else
        echo ""
        echo "⚠ Failed to create superuser. You can create one later with:"
        echo "  python3 manage.py createsuperuser"
    fi
else
    echo "✓ Superuser already exists"
fi

echo ""
echo "=================================================="
echo "Starting Django development server..."
echo "=================================================="
echo ""
echo "Admin panel: http://localhost:8000/admin/"
echo "API root: http://localhost:8000/api/"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start the server
python3 manage.py runserver
