# How to Run Burundi AU Chairmanship App

## Prerequisites
- Flutter SDK installed (`flutter doctor` should show no critical issues)
- Python 3.9+ installed
- iOS Simulator or Android Emulator
- Django backend dependencies installed

## Quick Start (Both Frontend & Backend)

### 1. Start the Backend Server

```bash
cd "burundi_au_chairmanship/backend"
python3 manage.py runserver 0.0.0.0:8000
```

The backend will be available at: `http://127.0.0.1:8000/api/`

**Admin credentials:**
- Username: `admin`
- Password: `admin2026`

### 2. Start an Emulator

**Option A: iOS Simulator (Mac only)**
```bash
flutter emulators --launch apple_ios_simulator
```

**Option B: Android Emulator**
```bash
flutter emulators --launch Medium_Phone_API_36.1
```

**Check available emulators:**
```bash
flutter emulators
```

**Check running devices:**
```bash
flutter devices
```

### 3. Run the Flutter App

```bash
cd "burundi_au_chairmanship"
flutter run
```

Or specify a specific device:
```bash
flutter run -d <device-id>
```

## Troubleshooting

### Backend Issues

**Port already in use:**
```bash
# Find and kill the process using port 8000
lsof -ti:8000 | xargs kill -9
```

**Database issues:**
```bash
cd backend
python3 manage.py migrate
python3 manage.py seed_data  # Re-seed the database
```

### Flutter Issues

**Dependencies out of sync:**
```bash
cd burundi_au_chairmanship
flutter pub get
flutter clean
flutter pub get
```

**iOS build issues:**
```bash
cd ios
pod install
cd ..
flutter run
```

**Android build issues:**
```bash
flutter clean
flutter pub get
flutter run
```

## Development Tips

### Hot Reload
While the Flutter app is running, press:
- `r` - Hot reload (preserves state)
- `R` - Hot restart (resets state)
- `q` - Quit

### Backend Development
The Django server auto-reloads when you change Python files. No need to restart manually.

### API Testing
Test the backend API directly:
```bash
# Check API root
curl http://127.0.0.1:8000/api/

# Get hero slides
curl http://127.0.0.1:8000/api/hero-slides/

# Get articles
curl http://127.0.0.1:8000/api/articles/
```

### Admin Panel
Access Django admin at: `http://127.0.0.1:8000/admin/`
- Username: `admin`
- Password: `admin2026`

## Project Structure

```
burundi_au_chairmanship/
├── lib/                    # Flutter frontend
│   ├── main.dart          # App entry point
│   ├── providers/         # State management (Provider)
│   ├── screens/           # UI screens
│   ├── services/          # API services
│   └── widgets/           # Reusable widgets
├── backend/               # Django REST backend
│   ├── config/            # Django settings
│   ├── core/              # Main app (models, views, serializers)
│   └── manage.py          # Django management script
└── HOW_TO_RUN.md         # This file
```

## Features

### Completed Features
- JWT Authentication (register/login/profile)
- Mock auth fallback for development
- 5 main tabs: Home, Magazine, Consular, Locations, More
- Video player for Live Feeds
- Bilingual support (English/French)
- Light/Dark theme toggle
- Maps integration for embassy locations
- Contact support (mailto)
- About dialog

### API Endpoints
- `/api/hero-slides/` - Hero carousel slides
- `/api/feature-cards/` - Feature cards for home
- `/api/articles/` - News articles
- `/api/magazines/` - Magazine publications
- `/api/embassies/` - Embassy locations
- `/api/events/` - Calendar events
- `/api/live-feeds/` - Live video feeds
- `/api/resources/` - Downloadable resources
- `/api/emergency-contacts/` - Emergency contact information

## Notes

- System Python is 3.9.6 - use Django 4.2 (not 5.0+)
- Backend API runs on `http://127.0.0.1:8000/api`
- Frontend is configured to connect to this local backend
- First iOS/Android build can take 5-10 minutes
- Subsequent builds are much faster (hot reload is instant)
