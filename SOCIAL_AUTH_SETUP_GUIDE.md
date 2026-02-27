# Social Authentication Setup Guide

## ✅ Implementation Complete

All code implementation for Google Sign-In and Apple Sign-In is complete! The following has been done:

### Flutter Code Changes
- ✅ Added `google_sign_in` and `sign_in_with_apple` packages to `pubspec.yaml`
- ✅ Implemented `signInWithGoogle()` and `signInWithApple()` in `FirebaseAuthService`
- ✅ Added social auth methods to `AuthProvider`
- ✅ Updated `AuthScreen` UI with Google and Apple sign-in buttons
- ✅ Added "OR" dividers and proper button styling
- ✅ Apple Sign-In button only shows on iOS devices

### Platform Configuration
- ✅ iOS: Added Google Sign-In URL scheme placeholder in `Info.plist`
- ✅ Android: Added Apple Sign-In callback activity in `AndroidManifest.xml`

---

## 🔧 Required Firebase Console Configuration

To complete the setup, you need to configure Firebase Console and Apple Developer Console:

### Step 1: Enable Google Sign-In in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **b4africa-700f7**
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Google** provider
5. Click **Enable**
6. Set a support email address
7. Click **Save**

8. **Download Updated Configuration Files:**
   - Go to **Project Settings** → **General**
   - Under "Your apps" section:
     - For iOS app: Click **Download GoogleService-Info.plist**
     - Replace the file at: `burundi_au_chairmanship/ios/Runner/GoogleService-Info.plist`
     - For Android app: Click **Download google-services.json**
     - Replace the file at: `burundi_au_chairmanship/android/app/google-services.json`

9. **Update iOS Info.plist:**
   - Open the NEW `GoogleService-Info.plist` you just downloaded
   - Find the `REVERSED_CLIENT_ID` value (looks like: `com.googleusercontent.apps.XXXXXX`)
   - Open `burundi_au_chairmanship/ios/Runner/Info.plist`
   - Replace `REPLACE_WITH_REVERSED_CLIENT_ID` with the actual value

### Step 2: Enable Apple Sign-In (Required for App Store)

#### A. Apple Developer Console Configuration

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers** → Find your App ID: `com.burundi.au.burundi_au_chairmanship`
4. Click **Edit**
5. Enable **Sign in with Apple** capability
6. Save changes

#### B. Create Service ID (for Android web fallback)

1. In **Identifiers**, click the **+** button
2. Select **Services IDs** → Continue
3. Description: `Burundi AU Chairmanship Service`
4. Identifier: `com.burundi.au.burundi_au_chairmanship.service`
5. Check **Sign in with Apple**
6. Click **Configure** next to Sign in with Apple:
   - Primary App ID: Select `com.burundi.au.burundi_au_chairmanship`
   - Domains and Subdomains: `b4africa-700f7.firebaseapp.com`
   - Return URLs: `https://b4africa-700f7.firebaseapp.com/__/auth/handler`
7. Save and Continue

#### C. Create Private Key

1. In **Keys** section, click the **+** button
2. Key Name: `Burundi AU Apple Sign In Key`
3. Check **Sign in with Apple**
4. Click **Configure** and select your Primary App ID
5. Click **Save** → **Continue** → **Register**
6. **Download the .p8 key file** (YOU CAN ONLY DOWNLOAD THIS ONCE!)
7. Note the **Key ID** (10-character string)

#### D. Configure Firebase Console with Apple Credentials

1. Go back to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Authentication** → **Sign-in method**
3. Click on **Apple** provider
4. Click **Enable**
5. Enter the following information:
   - **Service ID**: `com.burundi.au.burundi_au_chairmanship.service`
   - **Apple Team ID**: Find this in Apple Developer → Membership
   - **Key ID**: The 10-character Key ID from step C.6
   - **Private Key**: Open the .p8 file and paste the contents
6. Click **Save**

### Step 3: iOS Xcode Configuration

1. Open Xcode:
   ```bash
   open burundi_au_chairmanship/ios/Runner.xcworkspace
   ```

2. In Xcode, select the **Runner** target

3. Go to **Signing & Capabilities** tab

4. Click **+ Capability** button

5. Add **Sign in with Apple** capability

6. Verify your **Bundle Identifier** is: `com.burundi.au.burundiAuChairmanship`

7. Verify your **Team** is selected

### Step 4: Add Google Logo Asset

1. Download the official Google logo from:
   - [Google Brand Guidelines](https://developers.google.com/identity/branding-guidelines)

2. Save as: `burundi_au_chairmanship/assets/icons/google_logo.png`
   - Recommended size: 96x96px (48x48 dp @ 2x)
   - Use the colored "G" logo

3. Alternatively, use any 48x48 Google logo image you have

---

## 🧪 Testing Instructions

### Test on iOS

1. **Run the app:**
   ```bash
   cd burundi_au_chairmanship
   flutter run -d iPhone
   ```

2. **Test Google Sign-In:**
   - Tap "Continue with Google"
   - Select a Google account
   - Verify redirected to home screen
   - Check Firebase Console → Authentication (user should appear)

3. **Test Apple Sign-In:**
   - Tap "Continue with Apple"
   - Authenticate with Face ID / Touch ID / Password
   - Verify redirected to home screen
   - Check Firebase Console → Authentication (user should appear)

### Test on Android

1. **Run the app:**
   ```bash
   flutter run -d emulator-5554
   ```

2. **Test Google Sign-In:**
   - Tap "Continue with Google"
   - Select a Google account
   - Verify redirected to home screen

3. **Apple Sign-In on Android:**
   - Apple button is hidden on Android by default
   - If you want to test the web fallback, modify the code to show it on Android

### Test Account Linking

1. Sign up with email/password
2. Sign out
3. Try to sign in with Google using the **same email**
4. Verify: Firebase should link the accounts OR show friendly error

---

## 🐛 Troubleshooting

### Google Sign-In Issues

**Problem:** "Developer Error" or "10:"
- **Solution:** Make sure you've downloaded the updated `google-services.json` and `GoogleService-Info.plist` after enabling Google Sign-In in Firebase Console
- Verify SHA-1 fingerprint is configured in Firebase Console (for Android)

**Problem:** "Sign in cancelled" immediately
- **Solution:** Check that `REVERSED_CLIENT_ID` in `Info.plist` matches the value in `GoogleService-Info.plist`

### Apple Sign-In Issues

**Problem:** "Apple Sign-In not available"
- **Solution:** Make sure you're testing on iOS 13+ or macOS 10.15+
- Verify "Sign in with Apple" capability is added in Xcode

**Problem:** "Invalid client" or "Invalid redirect URI"
- **Solution:** Double-check the Service ID configuration in Apple Developer Console
- Verify the redirect URL is: `https://b4africa-700f7.firebaseapp.com/__/auth/handler`

### Firebase Admin SDK (Backend)

If your backend shows errors about "No project ID found":
1. Make sure `firebase-adminsdk.json` is uploaded to your production server
2. Set environment variable: `FIREBASE_CREDENTIALS_PATH=/path/to/firebase-adminsdk.json`

---

## 📱 App Store Submission Notes

### Apple App Store Requirements

**IMPORTANT:** Since you're offering Google Sign-In, you MUST also offer Apple Sign-In. This is an Apple App Store requirement.

- ✅ Apple Sign-In is implemented and shows on iOS
- ✅ Button follows Apple Human Interface Guidelines
- ✅ Positioned at same prominence as Google button

### Screenshots

When submitting to App Store, show screenshots that include:
- The auth screen with all three options (Email, Google, Apple)
- Emphasize the social login convenience

---

## 🎯 Success Checklist

Before going to production, verify:

- [ ] Google Sign-In enabled in Firebase Console
- [ ] Apple Sign-In enabled in Firebase Console
- [ ] Apple Developer Console: App ID has Sign in with Apple enabled
- [ ] Apple Developer Console: Service ID created and configured
- [ ] Apple Developer Console: Private key created and added to Firebase
- [ ] iOS Info.plist: REVERSED_CLIENT_ID updated with correct value
- [ ] Xcode: Sign in with Apple capability added
- [ ] Google logo asset added to `assets/icons/google_logo.png`
- [ ] Tested Google Sign-In on iOS
- [ ] Tested Google Sign-In on Android
- [ ] Tested Apple Sign-In on iOS
- [ ] Tested email/password still works
- [ ] Tested sign out clears all sessions
- [ ] Firebase Console shows users from all auth providers
- [ ] Backend verifies Firebase tokens from all providers

---

## 📚 Additional Resources

- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [Google Sign-In Branding Guidelines](https://developers.google.com/identity/branding-guidelines)
- [Apple Sign-In Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
- [Sign in with Apple - Flutter Package](https://pub.dev/packages/sign_in_with_apple)
- [Google Sign-In - Flutter Package](https://pub.dev/packages/google_sign_in)

---

## 🎉 What's Next?

Once testing is complete:

1. **Track Analytics:**
   - Monitor which auth method users prefer
   - Track signup conversion rates
   - Use Firebase Analytics to measure adoption

2. **Optional Enhancements:**
   - Add profile picture sync from Google/Apple
   - Implement account linking UI in Settings
   - Add phone number authentication
   - Enable Facebook login if needed

3. **Production Deployment:**
   - Update Firebase security rules
   - Configure production OAuth redirect URLs
   - Set up monitoring and error tracking
   - Update privacy policy to mention social auth

---

## Need Help?

If you encounter issues:

1. Check Firebase Console → Authentication → Users (to see if auth is working)
2. Check Flutter logs: `flutter run --verbose`
3. Check Firebase Crashlytics for errors
4. Review the error messages in the app (shown via SnackBar)
5. Verify all configuration files are up to date

Good luck! 🚀
