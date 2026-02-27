# Firebase Integration - Quick Start Guide

## Implementation Status: ✅ CODE COMPLETE

All code changes have been implemented. Firebase integration is ready to use after completing the setup steps below.

## What Was Implemented

### Backend (Django)
- ✅ Firebase Admin SDK integration
- ✅ Token verification middleware
- ✅ Firebase auth endpoints (register, login, FCM token)
- ✅ Database models updated (firebase_uid, fcm_token)
- ✅ Migrations created

### Flutter App
- ✅ Firebase Auth service
- ✅ Firebase Messaging service (push notifications)
- ✅ Remote Config service (feature flags)
- ✅ AuthProvider refactored to use Firebase
- ✅ ApiService updated for Firebase tokens
- ✅ iOS and Android platform configuration
- ✅ Main app initialization updated

## Before You Can Run the App

You **MUST** complete these 3 critical steps:

### Step 1: Create Firebase Project (10 minutes)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" → Name it "Burundi AU Chairmanship"
3. Enable Google Analytics (recommended)
4. Click "Continue" to create the project

### Step 2: Add Apps to Firebase Project (10 minutes)

#### Add iOS App:
1. In Firebase Console, click iOS icon
2. Enter bundle ID: `com.burundi.au.burundi_au_chairmanship`
3. Download `GoogleService-Info.plist`
4. Place file at: `burundi_au_chairmanship/ios/Runner/GoogleService-Info.plist`

#### Add Android App:
1. In Firebase Console, click Android icon
2. Enter package name: `com.burundi.au.burundi_au_chairmanship`
3. Download `google-services.json`
4. Place file at: `burundi_au_chairmanship/android/app/google-services.json`

### Step 3: Enable Firebase Services (5 minutes)

#### Authentication:
1. In Firebase Console → Authentication → Get Started
2. Click "Sign-in method" tab
3. Enable "Email/Password" provider
4. Save

#### Download Backend Credentials:
1. In Firebase Console → Project Settings (gear icon)
2. Click "Service Accounts" tab
3. Click "Generate new private key"
4. Save as: `burundi_au_chairmanship/backend/config/firebase-adminsdk.json`

## Installation & Setup

### 1. Generate firebase_options.dart

```bash
cd burundi_au_chairmanship

# Install FlutterFire CLI (one-time)
dart pub global activate flutterfire_cli

# Generate Firebase configuration
flutterfire configure
```

This creates `lib/firebase_options.dart` with your project config.

### 2. Update main.dart

Open `lib/main.dart` and uncomment this line (around line 42):

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform, // UNCOMMENT THIS
);
```

### 3. Install Backend Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 4. Run Migrations

```bash
cd backend
python3 manage.py migrate
```

### 5. Install Flutter Dependencies

```bash
cd burundi_au_chairmanship
flutter pub get
```

### 6. iOS Pod Install (if on macOS)

```bash
cd ios
pod install
cd ..
```

## Run the App

### Start Backend:
```bash
cd backend
python3 manage.py runserver
```

### Start Flutter App:
```bash
cd burundi_au_chairmanship
flutter run
```

## Test the Integration

### Test Registration:
1. Open app
2. Go to registration screen
3. Enter email and password
4. Click "Sign Up"
5. Check your email for verification link
6. Check Firebase Console → Authentication → Users (should show new user)
7. Check Django Admin → User Profiles (should show profile with firebase_uid)

### Test Login:
1. Login with registered credentials
2. Should see home screen
3. Check that API requests work (articles load, etc.)

## Optional: Enable Push Notifications

### For iOS (requires Apple Developer account):
1. Generate APNs key in [Apple Developer Console](https://developer.apple.com/account)
2. Download .p8 key file
3. In Firebase Console → Project Settings → Cloud Messaging
4. Upload APNs key (enter Key ID and Team ID)

### For Android:
Already configured! Push notifications work out of the box.

### Test Push Notification:
1. Run app and copy FCM token from console logs
2. Firebase Console → Cloud Messaging → Send test message
3. Paste FCM token
4. Send notification
5. Should appear on device

## Optional: Setup Remote Config

1. Firebase Console → Remote Config
2. Add parameters:
   - `enable_live_feeds` = true
   - `show_maintenance_banner` = false
   - `maintenance_message` = ""
3. Click "Publish changes"
4. App will fetch config on startup

## Files That Are Gitignored (IMPORTANT)

These files are **NOT committed to Git** for security:

- `backend/config/firebase-adminsdk.json` (backend credentials)
- `ios/Runner/GoogleService-Info.plist` (iOS config)
- `android/app/google-services.json` (Android config)
- `lib/firebase_options.dart` (generated config)

**For production deployment**: You'll need to upload these files to your server securely.

## Production Deployment

### DigitalOcean App Platform:

1. Upload `firebase-adminsdk.json` to server via secure method
2. Set environment variable:
   ```
   FIREBASE_CREDENTIALS_PATH=/app/backend/config/firebase-adminsdk.json
   ```
3. Deploy backend as usual
4. Build Flutter app with production config

### iOS App Store:

1. Open Xcode workspace: `ios/Runner.xcworkspace`
2. Select Runner target
3. Add capabilities:
   - Push Notifications
   - Background Modes → Remote notifications
4. Build and archive
5. Upload to App Store Connect

### Android Google Play:

1. Build release APK: `flutter build apk --release`
2. Or build App Bundle: `flutter build appbundle --release`
3. Upload to Google Play Console

## Troubleshooting

### "Firebase not initialized"
- Did you run `flutterfire configure`?
- Did you place GoogleService-Info.plist and google-services.json in correct locations?
- Did you uncomment `DefaultFirebaseOptions.currentPlatform` in main.dart?

### "No user found with this email"
- User registered in Firebase but not in Django
- Check Django logs for registration errors
- Verify backend is running

### "Invalid Firebase token"
- Backend can't find firebase-adminsdk.json
- Check file is at: `backend/config/firebase-adminsdk.json`
- Check Django console for Firebase initialization errors

### "Pod install failed" (iOS)
- Run: `cd ios && pod repo update && pod install`
- Check Xcode version is 15+

### "google-services plugin error" (Android)
- Verify google-services.json is at: `android/app/google-services.json`
- Run: `flutter clean && flutter pub get`
- Rebuild

## Getting Help

1. Check `FIREBASE_SETUP_GUIDE.md` for detailed setup instructions
2. Check `FIREBASE_IMPLEMENTATION_COMPLETE.md` for architecture details
3. Check Firebase Console → Project Settings → General for config issues
4. Check Django console for backend errors
5. Check Flutter console for Firebase initialization errors

## Next Steps After Setup

1. Test registration and login flows thoroughly
2. Send test push notifications
3. Configure Remote Config parameters
4. Monitor Crashlytics dashboard
5. Review Firebase Analytics data
6. Update privacy policy with Firebase data usage
7. Submit app updates to App Store and Google Play

## Summary

- **Code changes**: ✅ Complete
- **Firebase Console setup**: ⏳ Required before running
- **Configuration files**: ⏳ Required before running
- **Testing**: ⏳ After setup complete

Follow the 3 steps in "Before You Can Run the App" and you'll be ready to go!
