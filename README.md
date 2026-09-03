# 🇧🇮 Burundi Chairmanship App

A Flutter mobile app for the Burundi Chairmanship 2026 with Django REST backend.

---

## 🚀 Quick Start Guide

### Step 1: Start the Backend

Open a terminal and run:

```bash
cd "/Users/designs/Downloads/Burunundi Chairmanship app/burundi_au_chairmanship/backend"
python3 manage.py runserver 0.0.0.0:8000
```

✅ Backend will be available at: **http://127.0.0.1:8000/api/**

**Keep this terminal open!**

---

### Step 2: Start the Flutter App

Open a **new terminal** and run:

```bash
cd "/Users/designs/Downloads/Burunundi Chairmanship app/burundi_au_chairmanship"
flutter run
```

The app will:
1. Ask you to choose a device (iOS Simulator or Android Emulator)
2. Build and launch automatically

✅ **That's it! Your app is running.**

---

## 🎯 Common Commands

### Start iOS Simulator First (Optional)
```bash
open -a Simulator
# or
flutter emulators --launch apple_ios_simulator
```

### Start Android Emulator First (Optional)
```bash
flutter emulators --launch Medium_Phone_API_36.1
```

### See Available Devices
```bash
flutter devices
```

### See Available Emulators
```bash
flutter emulators
```

### Run on Specific Device
```bash
flutter run -d <device-id>
```

---

## 🔥 Hot Reload (While App is Running)

After making code changes, press in the terminal:
- **`r`** → Hot reload (instant, keeps app state)
- **`R`** → Hot restart (resets app state)
- **`q`** → Quit app

---

## 🛑 Stopping Everything

### Stop Backend
Press **`Ctrl + C`** in the backend terminal

### Stop Flutter App
Press **`q`** in the Flutter terminal

---

## 🔐 Admin Access

**Django Admin Panel:** http://127.0.0.1:8000/admin/

- **Username:** admin
- **Password:** admin2026

---

## 🐛 Troubleshooting

### Backend Not Starting
```bash
# Check if port 8000 is already in use
lsof -ti:8000 | xargs kill -9

# Then restart the backend
cd backend
python3 manage.py runserver 0.0.0.0:8000
```

### Flutter Dependencies Issue
```bash
cd burundi_au_chairmanship
flutter clean
flutter pub get
flutter run
```

### iOS Build Issue
```bash
cd burundi_au_chairmanship/ios
pod install
cd ..
flutter run
```

### Reset Database
```bash
cd backend
rm db.sqlite3
python3 manage.py migrate
python3 manage.py seed_data
```

---

## 📱 App Features

✅ JWT Authentication (Login/Register)
✅ Social Login UI (Google, Apple, Facebook)
✅ 5 Main Sections: Home, Magazine, Consular, Locations, More
✅ Bilingual Support (English/French)
✅ Light/Dark Theme
✅ Live Video Feeds
✅ Embassy Locations with Maps
✅ News Articles & Events
✅ Emergency Contacts
✅ Downloadable Resources

---

## 📂 Project Structure

```
burundi_au_chairmanship/
├── lib/                    # Flutter Frontend
│   ├── main.dart          # App entry point
│   ├── screens/           # All app screens
│   ├── providers/         # State management
│   ├── services/          # API services
│   └── widgets/           # Reusable components
│
├── backend/               # Django Backend
│   ├── config/            # Django settings
│   ├── core/              # Main app logic
│   │   ├── models.py     # Database models
│   │   ├── views.py      # API endpoints
│   │   ├── serializers.py # Data serializers
│   │   └── management/
│   │       └── commands/
│   │           └── seed_data.py  # Sample data
│   └── manage.py
│
├── README.md              # This file
└── HOW_TO_RUN.md         # Detailed documentation
```

---

## 🔗 API Endpoints

- `/api/hero-slides/` - Hero carousel
- `/api/feature-cards/` - Feature cards
- `/api/articles/` - News articles
- `/api/magazines/` - Magazines
- `/api/embassies/` - Embassy locations
- `/api/events/` - Calendar events
- `/api/live-feeds/` - Live video feeds
- `/api/resources/` - Downloadable resources
- `/api/emergency-contacts/` - Emergency contacts

---

## 💡 Development Tips

1. **Always start backend first**, then frontend
2. **Keep both terminals open** while developing
3. Use **hot reload (`r`)** instead of restarting - it's instant!
4. Check backend logs for API errors
5. Use Django admin panel to manage data

---

## 📝 Notes

- Python version: 3.9.6 (Use Django 4.2, not 5.0+)
- First build takes 2-5 minutes
- Subsequent builds are faster
- Hot reload is instant (1-2 seconds)

---

## 🆘 Need Help?

Check the detailed guide: **HOW_TO_RUN.md**

---

**Made with ❤️ for Burundi Chairmanship 2026**
