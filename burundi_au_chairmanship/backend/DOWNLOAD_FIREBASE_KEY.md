# Download Firebase Service Account Key

## 🔑 Your Backend Needs This File

The Django backend needs a Firebase Admin SDK service account key to verify authentication tokens from the app.

**File needed:** `backend/config/firebase-adminsdk.json`

---

## 📥 How to Download (2 minutes)

### Step 1: Open Firebase Console

Go to: https://console.firebase.google.com/project/b4africa-700f7/settings/serviceaccounts/adminsdk

Or manually:
1. https://console.firebase.google.com
2. Select "b4africa" project
3. Click the ⚙️ gear icon (top left) → "Project settings"
4. Click "Service accounts" tab

### Step 2: Download the Key

1. You'll see: "Firebase Admin SDK"
2. Language dropdown should show: **Python**
3. Click the button: **"Generate new private key"**
4. A dialog appears: "Generate new private key?"
5. Click **"Generate key"**
6. A JSON file downloads: `b4africa-700f7-firebase-adminsdk-xxxxx.json`

### Step 3: Rename and Place the File

1. **Rename** the downloaded file to: `firebase-adminsdk.json`
2. **Move** it to: `backend/config/firebase-adminsdk.json`

```bash
# Example commands (adjust path to your download):
mv ~/Downloads/b4africa-700f7-firebase-adminsdk-*.json \
   "backend/config/firebase-adminsdk.json"
```

---

## ✅ Verify Installation

Check the file is in place:

```bash
ls -l backend/config/firebase-adminsdk.json
```

You should see the file listed.

---

## 🔒 Security Note

**IMPORTANT:** This file contains sensitive credentials!

- ✅ It's listed in `.gitignore` (won't be committed)
- ✅ Keep it secure - don't share publicly
- ✅ Don't commit to Git
- ✅ For production, use environment variables or secret management

---

## 🔄 Restart Backend After Adding File

After placing the file, restart your Django server:

```bash
# Stop current server (Ctrl+C or):
pkill -f "manage.py runserver"

# Start again:
cd backend
python3 manage.py runserver 0.0.0.0:8000
```

The backend will automatically initialize Firebase Admin SDK.

---

## ✅ Success Message

When backend starts successfully, you should see:

```
Firebase Admin SDK initialized with credentials from: /path/to/firebase-adminsdk.json
```

Then Apple Sign In will work! 🎉

---

## 📍 File Location

```
burundi_au_chairmanship/
└── backend/
    └── config/
        ├── firebase.py (exists ✓)
        └── firebase-adminsdk.json (← download this!)
```

---

## 🆘 Troubleshooting

### "Generate key" button is disabled
- You may not have permission
- Ask project owner to generate and share the key
- Or add yourself as Owner/Editor in Firebase Console

### File already exists but error persists
- Check file is valid JSON (not corrupted)
- Check file permissions (should be readable)
- Restart Django backend

### "Service account doesn't exist"
- Your Firebase project may be new
- Wait a few minutes and try again
- Or contact Firebase support

---

**Ready?** Go download the key and place it in `backend/config/` then restart the backend! 🚀
