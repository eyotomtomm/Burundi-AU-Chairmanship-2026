# iOS Firebase Setup with Swift Package Manager

## Status: ✅ GoogleService-Info.plist Installed

The `GoogleService-Info.plist` file has been copied to:
```
burundi_au_chairmanship/ios/Runner/GoogleService-Info.plist
```

## Step-by-Step: Add Firebase SDK via Swift Package Manager

### Step 1: Open Xcode Workspace

⚠️ **IMPORTANT**: Always open the `.xcworkspace` file, NOT the `.xcodeproj` file!

```bash
cd burundi_au_chairmanship/ios
open Runner.xcworkspace
```

Wait for Xcode to fully load and index the project.

### Step 2: Add Firebase iOS SDK Package

1. In Xcode menu bar: **File** → **Add Package Dependencies...**

2. In the search bar (top-right), paste the Firebase iOS SDK repository URL:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```

3. Press **Enter** to search

4. **Dependency Rule**: Select "Up to Next Major Version" and enter `11.0.0` (or leave as default for latest)

5. Click **Add Package**

6. Wait for Xcode to resolve the package (this may take 1-2 minutes)

### Step 3: Select Firebase Products to Add

When the "Choose Package Products" dialog appears, select these products:

**Required Products:**
- [x] **FirebaseAuth** (for authentication)
- [x] **FirebaseMessaging** (for push notifications)
- [x] **FirebaseAnalytics** (for analytics tracking)
- [x] **FirebaseCrashlytics** (for crash reporting)

**Optional but Recommended:**
- [x] **FirebaseRemoteConfig** (for feature flags)

**Note**: If you want Analytics without IDFA collection, choose `FirebaseAnalyticsWithoutAdId` instead of `FirebaseAnalytics`.

For each selected product, ensure the target is set to **Runner**.

7. Click **Add Package**

8. Wait for Xcode to download and integrate the packages (this may take a few minutes)

### Step 4: Verify Package Installation

1. In the Xcode project navigator (left sidebar), you should see:
   - **Package Dependencies** folder
   - Inside it: **firebase-ios-sdk**

2. Click on **Runner** (top of project navigator)

3. Select **Runner** target → **General** tab

4. Scroll to **Frameworks, Libraries, and Embedded Content**

5. You should see Firebase frameworks listed (FirebaseAuth, FirebaseMessaging, etc.)

### Step 5: Add Push Notification Capability

1. In Xcode, select **Runner** target

2. Click **Signing & Capabilities** tab

3. Click **+ Capability** button

4. Search for and add:
   - **Push Notifications**
   - **Background Modes** → Check "Remote notifications"

### Step 6: Verify GoogleService-Info.plist in Xcode

1. In Xcode project navigator, expand **Runner** folder

2. You should see `GoogleService-Info.plist` in the file list

3. Click on it to verify it contains your Firebase configuration:
   - `GOOGLE_APP_ID`
   - `GCM_SENDER_ID`
   - `BUNDLE_ID` should be `com.burundi.au.burundi_au_chairmanship`

4. **If you don't see the file**:
   - Right-click **Runner** folder → **Add Files to "Runner"...**
   - Navigate to: `burundi_au_chairmanship/ios/Runner/GoogleService-Info.plist`
   - ✅ Check "Copy items if needed"
   - ✅ Check "Add to targets: Runner"
   - Click **Add**

### Step 7: Update Build Settings (If Needed)

If you encounter build errors, you may need to update these settings:

1. Select **Runner** target → **Build Settings** tab

2. Search for "Other Linker Flags"

3. If not already present, add:
   ```
   -ObjC
   ```

4. Search for "Enable Bitcode"

5. Set to **No** (Firebase doesn't support Bitcode)

## Verify Installation

### Test Build

1. In Xcode, select a simulator (e.g., iPhone 15)

2. Press **Cmd + B** to build

3. You should see: **Build Succeeded**

4. If you get errors, see Troubleshooting section below

### Run on Simulator

```bash
cd burundi_au_chairmanship
flutter run
```

Check the console output for:
```
Firebase initialized successfully
FCM Token: <token>
```

## AppDelegate.swift Configuration

The AppDelegate has already been configured with Firebase initialization:

```swift
import Flutter
import UIKit
import Firebase
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()

    // Set up notifications delegate for iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

This configuration:
- ✅ Initializes Firebase before Flutter
- ✅ Sets up notification delegate
- ✅ Registers Flutter plugins
- ✅ Works with FlutterAppDelegate

## Testing Push Notifications on iOS

### Prerequisites

⚠️ Push notifications require:
1. **Physical iOS device** (simulators don't support push notifications)
2. **Apple Developer account**
3. **APNs Authentication Key** uploaded to Firebase Console

### Get APNs Key

1. Go to [Apple Developer Console](https://developer.apple.com/account/resources/authkeys/list)

2. Click **+** to create a new key

3. Name it "Firebase Push Notifications"

4. Check **Apple Push Notifications service (APNs)**

5. Click **Continue** → **Register**

6. Download the `.p8` key file

7. Note the **Key ID** (e.g., `AB12CD34EF`)

### Upload APNs Key to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)

2. Select your project → **Project Settings** (gear icon)

3. Click **Cloud Messaging** tab

4. Scroll to **Apple app configuration**

5. Click **Upload** under "APNs Authentication Key"

6. Upload your `.p8` file

7. Enter **Key ID** (from step 6 above)

8. Enter **Team ID** (found in Apple Developer Account → Membership)

9. Click **Upload**

### Test Push Notification

1. Run app on physical device:
   ```bash
   flutter run --release
   ```

2. Copy the FCM token from console logs:
   ```
   FCM Token: dT8G...rQx2
   ```

3. In Firebase Console → **Cloud Messaging** → **Send test message**

4. Paste FCM token

5. Enter notification:
   - Title: "Test Notification"
   - Body: "Firebase push notifications working!"

6. Click **Test**

7. Notification should appear on device (even if app is closed)

## Troubleshooting

### Error: "No such module 'Firebase'"

**Solution:**
1. Clean build: **Product** → **Clean Build Folder** (Shift + Cmd + K)
2. Close Xcode completely
3. Delete `ios/Pods` and `ios/Podfile.lock` (if they exist)
4. Reopen `Runner.xcworkspace`
5. Rebuild: Cmd + B

### Error: "GoogleService-Info.plist not found"

**Solution:**
1. Verify file exists at: `ios/Runner/GoogleService-Info.plist`
2. In Xcode, check file is in **Runner** target:
   - Right-click file → **Show File Inspector**
   - Under "Target Membership", ensure **Runner** is checked

### Error: "Multiple commands produce GoogleService-Info.plist"

**Solution:**
1. In Xcode, click **Runner** target
2. Go to **Build Phases** tab
3. Expand **Copy Bundle Resources**
4. Find `GoogleService-Info.plist`
5. If it appears multiple times, delete duplicates (keep only one)

### Firebase.configure() crashes app

**Solution:**
1. Verify `GoogleService-Info.plist` contains valid data (not empty)
2. Clean and rebuild: Shift + Cmd + K, then Cmd + B
3. Check console for specific error message

### Push notifications not working

**Checklist:**
- [ ] Running on physical device (not simulator)
- [ ] APNs key uploaded to Firebase Console
- [ ] Push Notifications capability enabled in Xcode
- [ ] Background Modes → Remote notifications enabled
- [ ] App has notification permission (check iOS Settings → App → Notifications)
- [ ] FCM token successfully sent to backend

### Build fails with "framework not found"

**Solution:**
1. Select **Runner** target → **Build Settings**
2. Search for "Framework Search Paths"
3. Ensure it includes:
   ```
   $(inherited)
   $(PROJECT_DIR)/Flutter
   ```

## SPM vs CocoaPods

### Why Swift Package Manager?

✅ **Advantages:**
- Native Xcode integration
- Faster dependency resolution
- No Podfile/Podspec maintenance
- Better Xcode 15+ support
- Simpler project structure

❌ **CocoaPods (Old Method):**
- Requires Podfile
- Slower pod install
- Extra Pods directory
- Potential version conflicts

### Note on Flutter Firebase Plugins

Flutter's Firebase plugins (firebase_auth, firebase_messaging, etc.) use CocoaPods by default. However:

1. **Our approach**: SPM for Firebase iOS SDK + CocoaPods for Flutter plugins
2. **Why**: Gives us latest Firebase SDK features while maintaining Flutter plugin compatibility
3. **Works because**: Flutter plugins wrap the native Firebase SDK, which we provide via SPM

## iOS Deployment Checklist

Before submitting to App Store:

- [ ] Push Notifications capability added
- [ ] Background Modes enabled
- [ ] APNs key uploaded to Firebase
- [ ] GoogleService-Info.plist in bundle
- [ ] Privacy manifest updated (if required by Apple)
- [ ] Tested on physical device
- [ ] Test push notifications in production
- [ ] Verified Crashlytics reporting

## Next Steps

1. ✅ Complete Xcode setup (Steps 1-7 above)
2. ✅ Build and run app
3. ⏳ Test registration and login
4. ⏳ Upload APNs key for push notifications
5. ⏳ Test push notifications on device
6. ⏳ Monitor Firebase Console for analytics and crashes

## Support

If you encounter issues:
1. Check Xcode console for error messages
2. Verify GoogleService-Info.plist is valid
3. Clean build and restart Xcode
4. Check Firebase Console → Project Settings → iOS app configuration
5. See [Firebase iOS Setup Documentation](https://firebase.google.com/docs/ios/setup)
