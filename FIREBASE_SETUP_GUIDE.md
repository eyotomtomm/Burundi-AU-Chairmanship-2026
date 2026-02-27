# Firebase Setup Guide - Burundi AU Chairmanship App

## Phase 1: Firebase Console Setup (REQUIRED BEFORE RUNNING APP)

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or "Create a project"
3. Enter project name: **Burundi AU Chairmanship**
4. Enable Google Analytics (recommended)
5. Select or create Analytics account
6. Click "Create project"

### Step 2: Add iOS App

1. In Firebase Console, click the iOS icon to add iOS app
2. Enter iOS bundle ID: `com.burundi.au.burundi_au_chairmanship`
3. Enter app nickname: "Burundi AU iOS"
4. Download **GoogleService-Info.plist**
5. **Place file at:** `burundi_au_chairmanship/ios/Runner/GoogleService-Info.plist`

### Step 3: Add Android App

1. In Firebase Console, click the Android icon to add Android app
2. Enter Android package name: `com.burundi.au.burundi_au_chairmanship`
3. Enter app nickname: "Burundi AU Android"
4. Download **google-services.json**
5. **Place file at:** `burundi_au_chairmanship/android/app/google-services.json`

### Step 4: Enable Firebase Authentication

1. In Firebase Console, go to **Authentication** section
2. Click "Get started"
3. Go to **Sign-in method** tab
4. Enable **Email/Password** provider
5. Save changes

### Step 5: Enable Cloud Messaging (FCM)

1. In Firebase Console, go to **Cloud Messaging** section
2. For iOS push notifications:
   - Go to Apple Developer Console
   - Create APNs Authentication Key
   - Download .p8 key file
   - In Firebase Console → Project Settings → Cloud Messaging
   - Upload APNs key under "Apple app configuration"
   - Enter Key ID and Team ID

### Step 6: Enable Analytics

1. Analytics is auto-enabled when you create project with it
2. Go to **Analytics** → **Dashboard** to verify setup

### Step 7: Enable Crashlytics

1. In Firebase Console, go to **Crashlytics** section
2. Click "Enable Crashlytics"

### Step 8: Set Up Remote Config

1. In Firebase Console, go to **Remote Config** section
2. Add these default parameters:

| Parameter Key | Default Value | Type |
|--------------|---------------|------|
| enable_live_feeds | true | Boolean |
| enable_magazines | true | Boolean |
| show_maintenance_banner | false | Boolean |
| maintenance_message | "" | String |
| min_app_version | 1.0.0 | String |
| api_base_url | http://127.0.0.1:8000/api | String |

3. Click "Publish changes"

### Step 9: Generate Firebase Admin SDK Credentials (Backend)

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Click **Service Accounts** tab
3. Click **Generate new private key**
4. Download JSON file
5. **Rename to:** `firebase-adminsdk.json`
6. **Place at:** `burundi_au_chairmanship/backend/config/firebase-adminsdk.json`
7. **IMPORTANT:** This file is already in .gitignore - NEVER commit it to Git

### Step 10: Run FlutterFire CLI (Optional but Recommended)

This generates platform-specific configuration:

```bash
cd burundi_au_chairmanship

# Install FlutterFire CLI if not already installed
dart pub global activate flutterfire_cli

# Configure Firebase for Flutter
flutterfire configure
```

This will:
- Detect your Firebase project
- Generate `lib/firebase_options.dart` with platform-specific configs
- Update platform files if needed

---

## Phase 2: Environment Variables (Production)

For production deployment (DigitalOcean):

1. Add environment variable in DigitalOcean App Platform:
   ```
   FIREBASE_CREDENTIALS_PATH=/app/backend/config/firebase-adminsdk.json
   ```

2. Upload firebase-adminsdk.json to DigitalOcean via secure method (not Git)

---

## Verification Checklist

After setup, verify:

- [ ] GoogleService-Info.plist exists at `ios/Runner/GoogleService-Info.plist`
- [ ] google-services.json exists at `android/app/google-services.json`
- [ ] firebase-adminsdk.json exists at `backend/config/firebase-adminsdk.json`
- [ ] firebase_options.dart generated (if using flutterfire configure)
- [ ] Email/Password authentication enabled in Firebase Console
- [ ] APNs key uploaded for iOS push notifications
- [ ] Remote Config parameters created

---

## Testing Firebase Integration

### Test 1: Backend Token Verification

```bash
# Start Django server
cd backend
python manage.py runserver

# Test with Firebase token (get from Flutter app after login)
curl -X POST http://localhost:8000/api/auth/firebase-login/ \
  -H "Content-Type: application/json" \
  -d '{"firebase_token": "YOUR_FIREBASE_ID_TOKEN"}'
```

### Test 2: Flutter Registration Flow

1. Run Flutter app: `flutter run`
2. Go to registration screen
3. Enter email and password
4. Submit form
5. Check:
   - Firebase Authentication console shows new user
   - Django admin shows UserProfile with firebase_uid
   - Email verification sent

### Test 3: Push Notifications

1. In Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Enter notification title and body
4. Add FCM token from Flutter app (check console logs)
5. Send notification
6. Verify app receives notification (foreground/background/terminated)

### Test 4: Remote Config

1. In Flutter app, toggle a feature flag in Firebase Console
2. Wait 1 hour (or force fetch in code)
3. Verify app behavior changes based on flag

### Test 5: Crashlytics

1. In Flutter app, trigger a test crash:
   ```dart
   FirebaseCrashlytics.instance.crash();
   ```
2. Check Crashlytics dashboard for crash report

---

## Troubleshooting

### Issue: "No Firebase App '[DEFAULT]' has been created"
**Solution:** Ensure Firebase.initializeApp() is called before using Firebase services

### Issue: iOS push notifications not working
**Solution:**
- Verify APNs key uploaded to Firebase Console
- Check Push Notifications capability enabled in Xcode
- Test on physical device (not simulator)

### Issue: Android build fails with google-services plugin error
**Solution:**
- Verify google-services.json is in android/app/ directory
- Check plugin is added to android/app/build.gradle.kts
- Run `flutter clean && flutter pub get`

### Issue: Backend can't verify Firebase tokens
**Solution:**
- Verify firebase-adminsdk.json path is correct
- Check file has proper JSON structure
- Ensure firebase-admin package installed

---

## Security Notes

1. **NEVER commit firebase-adminsdk.json to Git**
2. **NEVER expose Firebase API keys in public repositories** (they're already in config files but restricted by Firebase security rules)
3. **Always use HTTPS in production** for API requests
4. **Rotate APNs keys periodically**
5. **Monitor Firebase Console for suspicious activity**

---

## Next Steps After Setup

Once Firebase setup is complete:
1. Run backend migrations: `python manage.py migrate`
2. Test registration and login flows
3. Configure push notification topics
4. Set up Firebase security rules
5. Deploy to production with environment variables
