#!/bin/bash

# Burundi AU Chairmanship App - Startup Script
# This script helps you start both backend and frontend

echo "🇧🇮 Burundi AU Chairmanship App - Startup"
echo "=========================================="
echo ""

# Function to check if port is in use
check_port() {
    if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
        echo "⚠️  Port 8000 is already in use!"
        echo "   Backend might already be running, or run: lsof -ti:8000 | xargs kill -9"
        return 1
    fi
    return 0
}

# Function to start backend
start_backend() {
    echo "📡 Starting Django Backend..."
    cd "burundi_au_chairmanship/backend"
    python3 manage.py runserver 0.0.0.0:8000 &
    BACKEND_PID=$!
    echo "✅ Backend started (PID: $BACKEND_PID)"
    echo "   API: http://127.0.0.1:8000/api/"
    echo "   Admin: http://127.0.0.1:8000/admin/ (admin/admin2026)"
    cd ../..
    sleep 2
}

# Function to start Flutter
start_flutter() {
    echo ""
    echo "📱 Starting Flutter App..."
    cd "burundi_au_chairmanship"
    flutter run
}

# Main execution
main() {
    # Check port
    if ! check_port; then
        read -p "Do you want to kill the process and continue? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            lsof -ti:8000 | xargs kill -9
            echo "✅ Port 8000 freed"
        else
            exit 1
        fi
    fi

    # Start backend
    start_backend

    # Start Flutter
    start_flutter
}

# Cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down..."
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null
        echo "✅ Backend stopped"
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

# Run
main
