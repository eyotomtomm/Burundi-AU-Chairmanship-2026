# Apple Sign In Setup Guide

## ✅ Status: READY TO USE

All Apple Sign In credentials are configured and the app is ready for testing!

---

## 📋 Your Apple Credentials

- **Team ID:** `5UL786DM5B`
- **Bundle ID:** `com.burundi.au.burundiAuChairmanship`
- **Key ID:** `V78M5AW74C`
- **Auth Key (.p8):** Stored in `backend/credentials/AuthKey_V78M5AW74C.p8`

---

## ✅ What's Already Done

### 1. Flutter/Dart Code
- ✅ `sign_in_with_apple` package added to `pubspec.yaml`
- ✅ Apple Sign In implemented in `lib/services/firebase_auth_service.dart`
- ✅ Auth provider has `signInWithApple()` method in `lib/providers/auth_provider.dart`
- ✅ UI has Apple Sign In button (iOS only) in `lib/screens/auth/auth_screen.dart`
- ✅ Google logo asset exists for Google Sign In button

### 2. iOS Configuration
- ✅ Bundle ID configured: `com.burundi.au.burundiAuChairmanship`
- ✅ Entitlements file created: `ios/Runner/Runner.entitlements`
- ✅ Sign in with Apple capability enabled in Xcode project
- ✅ Xcode project configured to use entitlements file

### 3. Backend Security
- ✅ `.p8` auth key stored in `backend/credentials/AuthKey_V78M5AW74C.p8`
- ✅ Credentials directory has `.gitignore` to prevent committing secrets

---

## 🎯 Next Steps to Test Apple Sign In

### Option 1: Test on Physical iOS Device (Recommended)

1. **Open Xcode:**
   ```bash
   cd burundi_au_chairmanship/ios
   open Runner.xcworkspace
   ```

2. **Sign the App:**
   - In Xcode, select the "Runner" target
   - Go to "Signing & Capabilities"
   - Select your Team ID: `5UL786DM5B`
   - Xcode will automatically provision the app

3. **Verify Sign in with Apple Capability:**
   - In "Signing & Capabilities" tab
   - You should see "Sign in with Apple" capability
   - If not, click "+" and add "Sign in with Apple"

4. **Connect Your iPhone:**
   - Connect your iPhone via USB
   - Trust the computer if prompted
   - Select your device in Xcode

5. **Build and Run:**
   ```bash
   # From the Flutter project root
   flutter run --release
   ```
   Or click the "Run" button in Xcode

6. **Test Sign In:**
   - Open the app on your device
   - Tap "Sign Up" or "Sign In" tab
   - Tap the Apple Sign In button (black button with Apple icon)
   - Complete the Apple Sign In flow
   - App will create/login your account

### Option 2: Test on iOS Simulator (Limited)

**Note:** Apple Sign In works on simulator but requires special setup.

1. **Requirements:**
   - macOS 13.3+ with Xcode 13.3+
   - iOS Simulator 15.4+

2. **Run on Simulator:**
   ```bash
   flutter run
   ```

3. **Sign In Flow:**
   - Simulator will show Apple ID sign-in sheet
   - Use your real Apple ID or test account
   - Some features may be limited in simulator

---

## 🔧 Troubleshooting

### "Sign in with Apple is not available on this device"
- Apple Sign In requires iOS 13+ or macOS 10.15+
- Update your device/simulator to a newer version

### "Invalid Bundle Identifier"
- Verify Bundle ID in Xcode matches: `com.burundi.au.burundiAuChairmanship`
- Check Apple Developer Portal that Sign in with Apple is enabled for this Bundle ID

### "Credential is Invalid"
- Ensure Firebase has Apple Sign In enabled:
  1. Go to Firebase Console → Authentication → Sign-in method
  2. Enable "Apple" provider
  3. Add Service ID: `com.burundi.au.burundi_au_chairmanship.service`

### Firebase Configuration

If you need to verify Apple Sign In on Firebase:

1. **Go to Firebase Console:**
   - https://console.firebase.google.com
   - Select your project: "b4africa"

2. **Enable Apple Sign In:**
   - Authentication → Sign-in method
   - Click "Apple"
   - Toggle "Enable"
   - No additional configuration needed for iOS apps

---

## 📱 How Apple Sign In Works in Your App

1. **User Flow:**
   - User opens app → Auth screen
   - User taps "Apple" button (iOS only, button auto-hides on Android)
   - iOS shows native Apple Sign In sheet
   - User authenticates with Face ID/Touch ID/Password
   - User chooses to share/hide email
   - App receives Firebase ID token
   - Backend creates/updates user profile
   - User is logged in

2. **Architecture:**
   ```
   User → Apple Sign In Button
        → sign_in_with_apple package
        → Firebase Auth (with Apple provider)
        → Firebase ID token
        → Django Backend API
        → User profile created/updated
        → App home screen
   ```

3. **Security:**
   - Apple Sign In uses OAuth 2.0
   - Firebase verifies Apple ID tokens
   - Django backend verifies Firebase ID tokens
   - No passwords stored in your database
   - Users can choose to hide their real email

---

## 🎨 UI Details

The Apple Sign In button appears:
- On the auth screen (Sign In & Sign Up tabs)
- Only on iOS devices (auto-hidden on Android)
- Black background in light mode
- White background in dark mode
- Next to Google Sign In button

---

## 📝 Additional Notes

### Privacy
- Users can choose to "Hide My Email" during sign up
- Apple will create a relay email like `abc123@privaterelay.appleid.com`
- Your app receives this relay email instead of real email

### Name Information
- Name is only provided on FIRST sign in
- Store the name immediately in Django backend
- Subsequent sign-ins will NOT include name

### Testing Accounts
- You can use your real Apple ID for testing
- Or create a test account in App Store Connect
- Sandbox environment works with development builds

---

## 🚀 Production Checklist

Before submitting to App Store:

- [ ] Test Apple Sign In on physical device
- [ ] Verify Bundle ID matches Apple Developer Portal
- [ ] Ensure Sign in with Apple capability is enabled
- [ ] Test both sign up and sign in flows
- [ ] Test "Hide My Email" flow
- [ ] Verify user data is stored correctly in backend
- [ ] Test sign out and re-sign in
- [ ] Enable Apple Sign In provider in Firebase Production project
- [ ] Update `.p8` key if using different Apple Developer account

---

## 📚 Resources

- [Apple Sign In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Firebase Apple Auth](https://firebase.google.com/docs/auth/ios/apple)
- [sign_in_with_apple package](https://pub.dev/packages/sign_in_with_apple)

---

**Setup completed on:** March 7, 2026
**Ready to test:** ✅ YES
