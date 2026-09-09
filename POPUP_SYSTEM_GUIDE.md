# Popup Notification System - User Guide

This guide explains how to use the popup/announcement system in the Burundi Chairmanship app.

## Overview

The popup system allows admins to create announcements that appear to users when they launch the app. Popups can:
- Display important announcements, event promotions, or project updates
- Include optional images
- Link to internal app screens or external URLs
- Target specific user groups (all users, verified only, or unverified only)
- Show once or repeatedly
- Expire automatically after a set date

## Backend Setup

### Database Model

The `Popup` model is located in `backend/core/models.py` with the following fields:

- **title** / **title_fr**: Popup title in English/French
- **message** / **message_fr**: Main content in English/French
- **image**: Optional image displayed at top (uploaded to `media/popups/`)
- **action_text** / **action_text_fr**: Button text (e.g., "Click here", "Sign up now")
- **action_url**: URL or app route to navigate to when button is clicked
  - Internal routes: `/events`, `/profile`, `/calendar`, etc.
  - External URLs: `https://example.com`
- **popup_type**: Category (general, event, verification, project)
- **is_active**: Only active popups are shown to users
- **priority**: Higher number = shown first (0-100)
- **target_audience**: Who sees this popup
  - `all`: All users
  - `verified_only`: Only users with verified badges
  - `unverified_only`: Only users without badges
- **show_once**: If true, user sees popup only once (tracked in app)
- **expires_at**: Popup won't show after this date/time (optional)

### API Endpoint

**GET** `/api/popups/active/`

Returns active popups for the current authenticated user, filtered by:
- `is_active=True`
- Not expired
- Target audience matches user's verification status
- Ordered by priority (descending), then creation date

## Admin Panel Usage

1. **Login to Admin Panel**
   - Go to `https://api.burundi4africa.com/admin/` (production) or `http://127.0.0.1:8000/admin/` (local)
   - Login with admin credentials

2. **Create a New Popup**
   - Navigate to **Core > Popups/Announcements**
   - Click **Add Popup/Announcement**
   - Fill in the form:

### Example 1: Welcome Message (No Action)
```
Title: Welcome to Burundi Chairmanship 2026!
Title (French): Bienvenue à la Présidence burundaise de l'UA 2026!

Message: Thank you for joining our community. Explore the app to stay updated.
Message (French): Merci de rejoindre notre communauté. Explorez l'application pour rester informé.

Image: [Upload a welcome image or leave blank]
Action Text: [Leave blank]
Action URL: [Leave blank]

Popup Type: General Announcement
Is Active: ✓
Priority: 5
Target Audience: All Users
Show Once: ✓
Expires At: [30 days from now]
```

### Example 2: Event Promotion (Internal Route)
```
Title: New Event: AU Summit Registration Open
Title (French): Nouvel événement: Inscription au Sommet UA ouverte

Message: Register now for the African Union Summit. Limited spots available!
Message (French): Inscrivez-vous maintenant au Sommet de l'Union africaine. Places limitées!

Image: [Upload event banner]
Action Text: Register Now
Action Text (French): S'inscrire maintenant
Action URL: /events

Popup Type: Event Promotion
Is Active: ✓
Priority: 10
Target Audience: All Users
Show Once: ✓
Expires At: [Event date]
```

### Example 3: Verification Reminder (Targeted)
```
Title: Get Your Blue Badge
Title (French): Obtenez votre badge bleu

Message: Verify your account to unlock exclusive features and connect with the community.
Message (French): Vérifiez votre compte pour débloquer des fonctionnalités exclusives.

Image: [Badge illustration]
Action Text: Start Verification
Action Text (French): Commencer la vérification
Action URL: /verification

Popup Type: Verification Reminder
Is Active: ✓
Priority: 8
Target Audience: Unverified Users Only
Show Once: ✓
Expires At: [Leave blank for no expiry]
```

### Example 4: External Link (Website)
```
Title: Read Our Latest Magazine
Title (French): Lisez notre dernier magazine

Message: Check out the latest edition of our monthly magazine featuring exclusive interviews.
Message (French): Consultez la dernière édition de notre magazine mensuel avec des interviews exclusives.

Image: [Magazine cover]
Action Text: Read Online
Action Text (French): Lire en ligne
Action URL: https://burundi4africa.com/magazine

Popup Type: General Announcement
Is Active: ✓
Priority: 7
Target Audience: All Users
Show Once: ✓
Expires At: [Next month]
```

## Frontend Integration

The popup system is automatically integrated in the app. When users launch the app and navigate to the home screen:

1. The app fetches active popups from the API
2. Filters out popups the user has already seen (if `show_once=true`)
3. Displays popups one by one in order of priority
4. Tracks which popups have been shown in local storage

### Technical Implementation

**Files Created:**
- `lib/models/popup_model.dart` - Popup data model
- `lib/services/popup_service.dart` - Service for fetching and tracking popups
- `lib/widgets/popup_dialog.dart` - Material 3 popup dialog UI
- `lib/screens/home/home_screen.dart` - Integration point (updated)

**Storage:**
Seen popup IDs are stored in `SharedPreferences` with key `seen_popups`.

### Internal Routes Supported

The following internal routes can be used in `action_url`:
- `/events` - Calendar/Events screen
- `/profile` - User profile
- `/verification` - Verification request screen
- `/magazine` - Magazine tab
- `/gallery` - Photo gallery
- `/videos` - Video gallery
- `/news` - News/Articles
- `/notifications` - Notifications center
- `/support` - Support tickets
- `/resources` - Resources/Documents
- Any other route defined in `lib/main.dart`

## Testing

### Test Popup Creation (Django Shell)

```bash
cd backend
python3 manage.py shell
```

```python
from core.models import Popup
from django.utils import timezone
from datetime import timedelta

popup = Popup.objects.create(
    title="Test Popup",
    title_fr="Popup de test",
    message="This is a test message",
    message_fr="Ceci est un message de test",
    action_text="Click Me",
    action_text_fr="Cliquez ici",
    action_url="/events",
    popup_type="general",
    is_active=True,
    priority=5,
    target_audience="all",
    show_once=True,
    expires_at=timezone.now() + timedelta(days=7)
)
print(f"Created: {popup}")
```

### Clear Seen Popups (Flutter)

To test popups again in the app, you can clear the seen list:

```dart
import 'package:burundi_au_chairmanship/services/popup_service.dart';

// In a button or debug menu:
final popupService = PopupService();
await popupService.clearSeenPopups();
// Now restart the app to see popups again
```

## Best Practices

1. **Keep messages concise** - Users should understand the popup in 3-5 seconds
2. **Use high-quality images** - 16:9 aspect ratio works best, max 500KB
3. **Set appropriate priorities** - Critical announcements: 10, Regular: 5, Low: 1
4. **Always provide French translations** - App is bilingual EN/FR
5. **Set expiry dates** - Prevent outdated popups from showing
6. **Test before activating** - Create with `is_active=False`, preview, then activate
7. **Don't overuse** - Too many popups annoy users (max 1-2 active at a time)
8. **Use targeting wisely** - Unverified users see different content than verified users

## Troubleshooting

### Popup not showing in app
1. Check `is_active=True` in admin panel
2. Verify `expires_at` is in the future (or null)
3. Check `target_audience` matches your account type
4. Clear app data and re-login
5. Check network connection - popups are fetched from API

### Image not displaying
1. Ensure image is uploaded to `/media/popups/`
2. Check image URL is accessible (not 404)
3. Image should be < 2MB
4. Supported formats: JPG, PNG, WebP

### Action button not working
1. Verify `action_url` is correct
2. For internal routes, must start with `/`
3. For external URLs, must include `https://`
4. Check route exists in `lib/main.dart`

## Database Cleanup

To remove expired popups:

```python
from core.models import Popup
from django.utils import timezone

# Delete expired popups
expired = Popup.objects.filter(expires_at__lt=timezone.now())
print(f"Deleting {expired.count()} expired popups")
expired.delete()
```

Or set up a cron job to run this periodically.

## Security Notes

- Only admins can create popups via admin panel
- API endpoint requires authentication (`IsAuthenticated`)
- XSS protection: All text is sanitized in Flutter widgets
- Images are uploaded to isolated `media/popups/` directory
- External URLs are opened in external browser (not WebView)

## Future Enhancements

Potential features for future versions:
- Analytics: Track popup click-through rates
- A/B testing: Show different versions to different users
- Schedule publishing: Set future activation date
- Rich media: Support for videos in popups
- Interactive popups: Forms, surveys, polls
- Push notification integration: Trigger popup from push notification
