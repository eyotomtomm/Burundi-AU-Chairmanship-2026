# Firebase Apple Sign In Setup Guide

## 🔥 Your Firebase Project Info

- **Project ID:** `b4africa-700f7`
- **Project Name:** b4africa
- **Bundle ID (iOS):** `com.burundi.au.burundiAuChairmanship`
- **Status:** ✅ Already configured in your app

---

## 📋 Step-by-Step: Enable Apple Sign In in Firebase

### Step 1: Open Firebase Console

1. Go to: **https://console.firebase.google.com**
2. Sign in with your Google account
3. Click on your project: **"b4africa"** or find project ID `b4africa-700f7`

### Step 2: Navigate to Authentication

1. In the left sidebar, click **"Build"** (or **"Authentication"** if it's visible)
2. Click **"Authentication"**
3. Click the **"Sign-in method"** tab at the top

You should see a list of sign-in providers.

### Step 3: Enable Apple Sign In Provider

1. Find **"Apple"** in the list of providers
2. Click on **"Apple"** to expand it
3. Click the **"Enable"** toggle switch (turn it ON)
4. You'll see a configuration panel

### Step 4: Configure Apple Provider

In the Apple configuration panel, you'll see:

**a) OAuth redirect URI (Firebase provides this):**
- Copy this URI (should be something like):
  ```
  https://b4africa-700f7.firebaseapp.com/__/auth/handler
  ```
- You'll need this for Apple Developer Console (see Step 5)

**b) Team ID (required for iOS):**
- Enter: `5UL786DM5B`

**c) Services ID (optional - for web/Android):**
- Leave empty for now (only needed for web/Android Apple Sign In)
- Or enter: `com.burundi.au.burundi_au_chairmanship.service` if you created one

**d) Key ID (optional - for token verification):**
- Enter: `V78M5AW74C` (your Apple Key ID)

**e) Private Key (optional - for token verification):**
- Click "Upload" and select: `backend/credentials/AuthKey_V78M5AW74C.p8`
- Or paste the contents of the .p8 file

> **Note:** The Key ID and Private Key are optional but recommended for enhanced security.

5. Click **"Save"** at the bottom

### Step 5: Update Apple Developer Console (If Not Done)

If you haven't already configured the redirect URI in Apple Developer:

1. Go to: **https://developer.apple.com/account**
2. Click **"Certificates, Identifiers & Profiles"**
3. Click **"Identifiers"**
4. Select your App ID: `com.burundi.au.burundiAuChairmanship`
5. Find **"Sign in with Apple"** capability
6. Click **"Edit"**
7. Add the Firebase redirect URI:
   ```
   https://b4africa-700f7.firebaseapp.com/__/auth/handler
   ```
8. Click **"Save"**
9. Click **"Continue"** and **"Save"** again

---

## ✅ Verification Checklist

After completing the setup, verify:

- [ ] Apple provider shows "Enabled" in Firebase Console
- [ ] Team ID is set to: `5UL786DM5B`
- [ ] Firebase redirect URI is added to Apple Developer Console
- [ ] Your iOS app has Sign in with Apple capability
- [ ] Your .p8 file is stored securely in `backend/credentials/`

---

## 🧪 Test Your Setup

### On iOS Device:

1. **Build and run your app:**
   ```bash
   cd burundi_au_chairmanship
   flutter run --release
   ```

2. **Test Apple Sign In:**
   - Open the app
   - Tap "Sign In" or "Sign Up"
   - Tap the black **"Apple"** button
   - Authenticate with Face ID/Touch ID/Password
   - Choose to share/hide your email

3. **Expected Result:**
   - Apple Sign In sheet appears
   - After authentication, you're logged into the app
   - User account is created in Firebase Authentication
   - User profile is synced to Django backend

### Verify in Firebase Console:

1. Go to **Authentication** → **Users** tab
2. You should see your user listed
3. Provider column should show "Apple"
4. UID will be the Apple user ID

---

## 🐛 Troubleshooting

### "The operation couldn't be completed"

**Cause:** Firebase can't verify Apple credentials

**Fix:**
- Verify Team ID is correct: `5UL786DM5B`
- Verify Bundle ID matches: `com.burundi.au.burundiAuChairmanship`
- Check Apple Developer Console has Sign in with Apple enabled

### "Invalid redirect URI"

**Cause:** Apple doesn't recognize Firebase redirect URI

**Fix:**
- Copy exact redirect URI from Firebase Console
- Add it to your App ID in Apple Developer Console
- Wait 5-10 minutes for Apple to propagate changes

### "Sign in with Apple is not available"

**Cause:** Device doesn't support Apple Sign In

**Fix:**
- Requires iOS 13+ or macOS 10.15+
- Update device/simulator to newer version

### User's email is null

**Cause:** User chose "Hide My Email"

**Result:**
- Apple provides a relay email like: `abc123@privaterelay.appleid.com`
- This is expected behavior
- Store and use this relay email in your backend

### Name is null after first login

**Cause:** Apple only provides name on FIRST sign in

**Result:**
- Store the name immediately in Django backend
- Subsequent logins won't include name
- This is Apple's design for privacy

---

## 🔐 Security Best Practices

### Firebase Security Rules

Make sure your Firebase security rules are configured:

1. Go to **Firestore Database** or **Realtime Database**
2. Click **"Rules"** tab
3. Set appropriate read/write rules based on authentication

Example Firestore rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Keep Credentials Secure

- ✅ `.p8` file is in `backend/credentials/` (gitignored)
- ✅ Never commit Firebase config files with sensitive data
- ✅ Use environment variables for production secrets

---

## 📊 Monitor Usage

### Firebase Console - Usage Dashboard:

1. Go to **Authentication** → **Usage** tab
2. Monitor sign-in methods
3. Track active users
4. Watch for anomalies

### Firebase Pricing:

- **Free tier:** Unlimited email/social logins
- **Phone auth:** 10,000/month free
- **SMS:** $0.01-0.06 per verification
- Your Apple Sign In usage: **FREE** ✓

---

## 🚀 Production Checklist

Before launching:

- [ ] Test Apple Sign In on multiple devices
- [ ] Test both "Share Email" and "Hide Email" flows
- [ ] Verify user data syncs correctly to Django backend
- [ ] Test sign out and re-sign in
- [ ] Configure Firebase Security Rules
- [ ] Set up Firebase Analytics (optional)
- [ ] Enable Firebase Crashlytics (optional)
- [ ] Review Apple App Store guidelines for Sign in with Apple

---

## 📚 Additional Resources

- [Firebase Apple Auth Docs](https://firebase.google.com/docs/auth/ios/apple)
- [Apple Sign In Best Practices](https://developer.apple.com/sign-in-with-apple/get-started/)
- [Firebase Pricing](https://firebase.google.com/pricing)

---

## 🎯 Next Steps After Setup

1. **Test thoroughly** on real device
2. **Implement error handling** for edge cases
3. **Add analytics** to track sign-in success rates
4. **Test Django backend** creates user profiles correctly
5. **Prepare for App Store submission**

---

**Setup Date:** March 7, 2026
**Firebase Project:** b4africa-700f7
**Status:** Ready to enable Apple Sign In provider ✅
