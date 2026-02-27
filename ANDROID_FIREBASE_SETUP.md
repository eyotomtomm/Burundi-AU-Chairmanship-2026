# Android Firebase Setup Guide

## Current Status

- ✅ Build configuration updated (google-services plugin added)
- ✅ AndroidManifest.xml updated (POST_NOTIFICATIONS permission)
- ⏳ **REQUIRED**: google-services.json file needed

## Step 1: Download google-services.json

### From Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/)

2. Select your project: **Burundi AU Chairmanship**

3. Click the **gear icon** (⚙️) → **Project settings**

4. Scroll down to **Your apps** section

5. Find your Android app or add it:
   - If not added yet, click **Add app** → **Android** icon
   - Package name: `com.burundi.au.burundi_au_chairmanship`
   - App nickname: "Burundi AU Android"
   - Click **Register app**

6. Download `google-services.json` file

7. **Place the file at**:
   ```
   burundi_au_chairmanship/android/app/google-services.json
   ```

### Using Command Line:

```bash
# Copy the downloaded file to the correct location
cp ~/Downloads/google-services.json "/Users/designs/Downloads/Burunundi Chairmanship app/burundi_au_chairmanship/android/app/google-services.json"
```

## Step 2: Verify File Placement

Run this command to verify:

```bash
ls -la "/Users/designs/Downloads/Burunundi Chairmanship app/burundi_au_chairmanship/android/app/" | grep google-services.json
```

You should see:
```
-rw-r--r--  1 user  staff  XXXX  google-services.json
```

## Step 3: Verify google-services.json Content

The file should contain:

```json
{
  "project_info": {
    "project_number": "...",
    "project_id": "burundi-au-chairmanship",
    "storage_bucket": "..."
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:...",
        "android_client_info": {
          "package_name": "com.burundi.au.burundi_au_chairmanship"
        }
      },
      "oauth_client": [...],
      "api_key": [...],
      "services": {
        "appinvite_service": {...}
      }
    }
  ],
  "configuration_version": "1"
}
```

**Important**: Verify `package_name` matches: `com.burundi.au.burundi_au_chairmanship`

## Step 4: Build Configuration (Already Done)

The following have already been configured:

### android/build.gradle.kts
```kotlin
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

### android/app/build.gradle.kts
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // ✅ Already added
}
```

### android/app/src/main/AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>  <!-- ✅ Already added -->
```

## Step 5: Test Android Build

After placing google-services.json:

```bash
cd burundi_au_chairmanship

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build Android APK
flutter build apk --debug
```

Expected output:
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

## Step 6: Run on Android Device/Emulator

```bash
flutter run
```

Check console for Firebase initialization:
```
[Firebase] Initialized successfully
[FCM] Token: <fcm-token>
```

## Testing Push Notifications on Android

### Prerequisites

- Android device or emulator (API level 21+)
- google-services.json installed
- App running

### Get FCM Token

1. Run app: `flutter run`

2. Check console logs for FCM token:
   ```
   FCM Token: dT8G9w...rQx2
   ```

3. Copy this token

### Send Test Notification

1. Go to [Firebase Console](https://console.firebase.google.com/)

2. Navigate to **Cloud Messaging** → **Send your first message**

3. Fill in:
   - Notification title: "Test Notification"
   - Notification text: "Firebase push notifications working!"

4. Click **Send test message**

5. Paste your FCM token

6. Click **Test**

7. Notification should appear on device

### Test Notification States

Test in these states:
- **Foreground**: App is open and active → Shows local notification
- **Background**: App is in background → Shows system notification
- **Terminated**: App is completely closed → Shows system notification

All three states should work!

## Troubleshooting

### Error: "File google-services.json is missing"

**Solution:**
1. Verify file exists: `ls android/app/google-services.json`
2. If missing, download from Firebase Console
3. Place at: `android/app/google-services.json` (NOT in `android/` root)

### Error: "No matching client found for package name"

**Solution:**
1. Open `google-services.json`
2. Check `package_name` is: `com.burundi.au.burundi_au_chairmanship`
3. If wrong, download correct config from Firebase Console:
   - Ensure Android app package name matches exactly
   - Re-download google-services.json

### Error: "Execution failed for task ':app:processDebugGoogleServices'"

**Solution:**
1. Verify `google-services.json` is valid JSON (not corrupted)
2. Clean build:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --debug
   ```

### Build fails with "plugin com.google.gms.google-services not found"

**Solution:**
1. Check `android/build.gradle.kts` has:
   ```kotlin
   classpath("com.google.gms:google-services:4.4.0")
   ```
2. Sync Gradle files in Android Studio:
   - Open `android/` folder in Android Studio
   - Click "Sync Project with Gradle Files"

### Push notifications not received

**Checklist:**
- [ ] google-services.json installed correctly
- [ ] POST_NOTIFICATIONS permission in AndroidManifest.xml
- [ ] App has notification permission (check Android Settings → Apps → App → Notifications)
- [ ] FCM token successfully retrieved (check logs)
- [ ] FCM token sent to backend via `updateFCMToken()`
- [ ] Test notification sent from Firebase Console

### Gradle build slow

**Solution:**
1. Enable Gradle daemon in `~/.gradle/gradle.properties`:
   ```properties
   org.gradle.daemon=true
   org.gradle.parallel=true
   org.gradle.caching=true
   ```

## Android Notification Channels

For Android 8.0+ (API 26+), notifications require a channel. This is already configured in `FirebaseMessagingService`:

```dart
AndroidNotificationDetails(
  'default_channel',  // Channel ID
  'Default Notifications',  // Channel name
  channelDescription: 'Default notification channel for general updates',
  importance: Importance.high,
  priority: Priority.high,
)
```

### Custom Notification Channels

To add more channels (e.g., for different notification types):

```dart
// In FirebaseMessagingService._initializeLocalNotifications()

// Create channels
const channels = [
  AndroidNotificationChannel(
    'breaking_news',
    'Breaking News',
    description: 'Important breaking news alerts',
    importance: Importance.max,
  ),
  AndroidNotificationChannel(
    'events',
    'Events',
    description: 'Event reminders and updates',
    importance: Importance.high,
  ),
];

for (var channel in channels) {
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}
```

## Android Deployment Checklist

Before publishing to Google Play:

- [ ] google-services.json in production build
- [ ] POST_NOTIFICATIONS permission in manifest
- [ ] Tested on Android 8.0+ (API 26+)
- [ ] Tested on Android 13+ (API 33+) for notification runtime permission
- [ ] Notification channels configured
- [ ] FCM token syncs with backend
- [ ] Push notifications work in all states (foreground/background/terminated)
- [ ] Verified Crashlytics reporting

## Comparison: iOS vs Android Setup

| Feature | iOS | Android |
|---------|-----|---------|
| Config File | GoogleService-Info.plist | google-services.json |
| Location | ios/Runner/ | android/app/ |
| SDK Installation | Swift Package Manager | Gradle plugin |
| Push Cert | APNs key required | Built-in |
| Notification Permission | Automatic prompt | Runtime permission (API 33+) |
| Background Modes | Capability required | Built-in |

## Next Steps

1. ⏳ Download google-services.json from Firebase Console
2. ⏳ Place file at: `android/app/google-services.json`
3. ⏳ Run `flutter clean && flutter pub get`
4. ⏳ Build and test: `flutter run`
5. ⏳ Test push notifications
6. ⏳ Verify Crashlytics reporting

## Support

If you encounter issues:
1. Check Android Studio logcat for error messages
2. Verify google-services.json is valid and in correct location
3. Clean build and sync Gradle
4. Check Firebase Console → Project Settings → Android app configuration
5. See [Firebase Android Setup Documentation](https://firebase.google.com/docs/android/setup)
