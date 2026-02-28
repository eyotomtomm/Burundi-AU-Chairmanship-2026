# Environment Configuration Guide

## Overview
The app supports three environments: **Development**, **Staging**, and **Production**. Each environment has different API endpoints and security settings.

## Environment Types

### 1. Development
- **API URL**: `http://localhost:8000/api`
- **Use Case**: Local development with Django backend running on localhost
- **Security**: HTTP allowed, verbose logging enabled
- **Analytics**: Disabled

### 2. Staging
- **API URL**: `https://staging-api.burundi4africa.com/api`
- **Use Case**: Testing before production deployment
- **Security**: HTTPS enforced
- **Analytics**: Enabled

### 3. Production
- **API URL**: `https://api.burundi4africa.com/api`
- **Use Case**: Live app for end users
- **Security**: HTTPS enforced, debug features disabled
- **Analytics**: Enabled

## Building for Different Environments

### Development (Default)
```bash
# Build for development (uses localhost)
flutter build ios
flutter build apk
```

### Staging
```bash
# Build for staging environment
flutter build ios --dart-define=ENVIRONMENT=staging
flutter build apk --dart-define=ENVIRONMENT=staging
```

### Production
```bash
# Build for production environment
flutter build ios --dart-define=ENVIRONMENT=production
flutter build apk --dart-define=ENVIRONMENT=production

# Or use short form
flutter build ios --dart-define=ENVIRONMENT=prod
flutter build apk --dart-define=ENVIRONMENT=prod
```

### Custom API URL
You can override the API URL for any environment:
```bash
flutter build ios --dart-define=API_URL=https://my-custom-api.com/api
flutter build apk --dart-define=API_URL=https://my-custom-api.com/api
```

## iOS App Transport Security (ATS)

### Development Mode
For development with HTTP localhost, add this to `ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

### Production Mode
Remove or disable ATS exceptions for production builds. iOS will enforce HTTPS.

## Android Network Security Configuration

### Development Mode
For development with HTTP localhost, `android/app/src/main/AndroidManifest.xml` includes:
```xml
android:usesCleartextTraffic="true"
```

### Production Mode
Set `usesCleartextTraffic="false"` for production builds:
```xml
android:usesCleartextTraffic="false"
```

## Backend CORS Configuration

### Development
Backend allows all origins when `DEBUG=True`:
```python
CORS_ALLOW_ALL_ORIGINS = DEBUG
```

### Production
Backend restricts CORS to specific domains when `DEBUG=False`:
```python
CORS_ALLOWED_ORIGINS = [
    'https://burundi4africa.com',
    'https://www.burundi4africa.com',
]
```

**Note**: Mobile apps don't trigger CORS checks, so this primarily affects web deployments.

## Environment Detection in Code

You can check the current environment in Dart code:

```dart
import 'package:burundi_au_chairmanship/config/environment.dart';

// Check environment type
if (Environment.isProduction) {
  print('Running in production');
}

if (Environment.isDevelopment) {
  print('Running in development');
}

// Get API URL
final apiUrl = Environment.apiBaseUrl;

// Fix media URLs from backend
final imageUrl = Environment.fixMediaUrl(backendImageUrl);
```

## URL Fixing for Media Files

The `Environment.fixMediaUrl()` function handles different scenarios:

### Development
- Converts `127.0.0.1` to `localhost` (iOS compatibility)
- Keeps HTTP protocol for local development

### Production/Staging
- Replaces any localhost URLs with production domain
- Enforces HTTPS protocol
- Example: `http://localhost:8000/media/image.jpg` → `https://api.burundi4africa.com/media/image.jpg`

## Build Scripts

### iOS Production Build
```bash
#!/bin/bash
flutter clean
flutter pub get
flutter build ios \
  --dart-define=ENVIRONMENT=production \
  --release
```

### Android Production Build
```bash
#!/bin/bash
flutter clean
flutter pub get
flutter build appbundle \
  --dart-define=ENVIRONMENT=production \
  --release
```

### iOS Staging Build
```bash
#!/bin/bash
flutter clean
flutter pub get
flutter build ios \
  --dart-define=ENVIRONMENT=staging \
  --release
```

## Security Checklist

### Before Production Release
- [ ] Verify `ENVIRONMENT=production` is set
- [ ] Confirm HTTPS is being used for all API calls
- [ ] Check that sensitive data is not logged
- [ ] Verify analytics is enabled
- [ ] Test with production backend
- [ ] Remove any hardcoded credentials
- [ ] Disable debug features
- [ ] Test on real devices (not just simulators)

### Before Staging Release
- [ ] Verify `ENVIRONMENT=staging` is set
- [ ] Confirm staging backend URL is correct
- [ ] Test all API endpoints
- [ ] Verify error handling
- [ ] Check logging and monitoring

### Development Setup
- [ ] Backend running on `http://localhost:8000`
- [ ] `ENVIRONMENT=development` (default)
- [ ] Firebase emulators configured (if using)
- [ ] iOS simulator or Android emulator running

## Troubleshooting

### "Failed to connect to API"
- **Development**: Ensure Django backend is running on port 8000
- **iOS Simulator**: Use `localhost`, not `127.0.0.1`
- **Android Emulator**: Use `10.0.2.2` instead of `localhost` if needed
- **Production**: Verify HTTPS URL is correct and backend is accessible

### "ATS blocked a cleartext HTTP connection"
- Add NSAllowsLocalNetworking exception for development
- Ensure production uses HTTPS

### "Images not loading"
- Check media URLs in backend responses
- Verify `Environment.fixMediaUrl()` is being used
- Confirm backend serves media files correctly

### "CORS error" (Web only)
- Update backend CORS_ALLOWED_ORIGINS
- Verify request origin matches allowed origins

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `ENVIRONMENT` | `development` | Environment name (development/staging/production) |
| `API_URL` | *(varies)* | Custom API base URL override |

## File Structure

```
lib/
├── config/
│   ├── environment.dart          # Environment configuration
│   ├── app_constants.dart         # App constants (deprecated API URL)
│   └── app_colors.dart            # Color constants
└── services/
    └── api_service.dart            # API service (uses Environment.apiBaseUrl)
```

## Migration from Hardcoded URLs

Old code (❌ Don't use):
```dart
static const String baseApiUrl = 'http://localhost:8000/api';
final url = imageUrl.replaceAll('127.0.0.1', 'localhost');
```

New code (✅ Use this):
```dart
import 'package:burundi_au_chairmanship/config/environment.dart';

final apiUrl = Environment.apiBaseUrl;
final fixedUrl = Environment.fixMediaUrl(imageUrl);
```

## Production Deployment

### 1. Update Backend
Ensure backend is deployed and accessible at production URL:
```bash
https://api.burundi4africa.com
```

### 2. Build App
```bash
flutter build ios --dart-define=ENVIRONMENT=production
flutter build appbundle --dart-define=ENVIRONMENT=production
```

### 3. Test
- Verify API connectivity
- Test all features end-to-end
- Check error handling
- Verify images and PDFs load correctly

### 4. Submit to Stores
- Upload to App Store Connect (iOS)
- Upload to Google Play Console (Android)

---

**Last Updated**: February 28, 2026
**Maintained By**: Development Team
