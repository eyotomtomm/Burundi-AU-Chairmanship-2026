# Popup System - Code Examples

## Django Shell Examples

### Creating Popups Programmatically

```python
# Start Django shell
# cd backend && python3 manage.py shell

from core.models import Popup
from django.utils import timezone
from datetime import timedelta

# Example 1: Simple welcome popup (no action)
welcome_popup = Popup.objects.create(
    title="Welcome to Burundi Chairmanship 2026!",
    title_fr="Bienvenue à la Présidence burundaise de l'UA 2026!",
    message="Thank you for being part of our community. We're excited to have you here!",
    message_fr="Merci de faire partie de notre communauté. Nous sommes ravis de vous accueillir!",
    popup_type="general",
    is_active=True,
    priority=5,
    target_audience="all",
    show_once=True,
    expires_at=timezone.now() + timedelta(days=30)
)
print(f"Created: {welcome_popup}")

# Example 2: Event promotion popup with image and action
event_popup = Popup.objects.create(
    title="AU Summit Registration Now Open",
    title_fr="Inscription au Sommet UA ouverte",
    message="Join us for the African Union Summit 2026. Register now to secure your spot. Limited availability!",
    message_fr="Rejoignez-nous pour le Sommet de l'Union africaine 2026. Inscrivez-vous maintenant. Places limitées!",
    action_text="Register Now",
    action_text_fr="S'inscrire maintenant",
    action_url="/events",
    popup_type="event",
    is_active=True,
    priority=10,
    target_audience="all",
    show_once=True,
    expires_at=timezone.now() + timedelta(days=14)
)
print(f"Created: {event_popup}")

# Example 3: Verification reminder (targeted to unverified users)
verification_popup = Popup.objects.create(
    title="Get Your Blue Badge",
    title_fr="Obtenez votre badge bleu",
    message="Verify your account to access exclusive features and connect with verified members of the AU community.",
    message_fr="Vérifiez votre compte pour accéder aux fonctionnalités exclusives et vous connecter avec les membres vérifiés.",
    action_text="Start Verification",
    action_text_fr="Commencer la vérification",
    action_url="/verification",
    popup_type="verification",
    is_active=True,
    priority=8,
    target_audience="unverified_only",
    show_once=True
)
print(f"Created: {verification_popup}")

# Example 4: External link popup
magazine_popup = Popup.objects.create(
    title="Read Our Latest Magazine",
    title_fr="Lisez notre dernier magazine",
    message="Check out this month's edition featuring exclusive interviews with African leaders and changemakers.",
    message_fr="Découvrez l'édition de ce mois avec des interviews exclusives de leaders et acteurs du changement africains.",
    action_text="Read Online",
    action_text_fr="Lire en ligne",
    action_url="https://burundi4africa.com/magazine",
    popup_type="general",
    is_active=True,
    priority=6,
    target_audience="all",
    show_once=True,
    expires_at=timezone.now() + timedelta(days=30)
)
print(f"Created: {magazine_popup}")

# Example 5: Urgent announcement (shown every time)
urgent_popup = Popup.objects.create(
    title="Important System Maintenance",
    title_fr="Maintenance système importante",
    message="The app will undergo maintenance on Saturday, April 5 from 2-4 AM GMT. Some features may be unavailable.",
    message_fr="L'application subira une maintenance le samedi 5 avril de 2h à 4h GMT. Certaines fonctionnalités peuvent être indisponibles.",
    popup_type="general",
    is_active=True,
    priority=10,
    target_audience="all",
    show_once=False,  # Show every time
    expires_at=timezone.now() + timedelta(days=2)
)
print(f"Created: {urgent_popup}")
```

### Querying Popups

```python
from core.models import Popup
from django.utils import timezone

# Get all active popups
active_popups = Popup.objects.filter(is_active=True)
print(f"Active popups: {active_popups.count()}")

# Get non-expired popups
now = timezone.now()
valid_popups = Popup.objects.filter(
    is_active=True
).filter(
    expires_at__isnull=True
) | Popup.objects.filter(
    is_active=True,
    expires_at__gt=now
)
print(f"Valid popups: {valid_popups.count()}")

# Get popups for verified users
verified_popups = Popup.objects.filter(
    is_active=True,
    target_audience__in=['all', 'verified_only']
)
print(f"Popups for verified users: {verified_popups.count()}")

# Get popups by priority
high_priority = Popup.objects.filter(
    is_active=True,
    priority__gte=8
).order_by('-priority')
print(f"High priority popups: {high_priority.count()}")
for popup in high_priority:
    print(f"  - {popup.title} (priority: {popup.priority})")
```

### Updating Popups

```python
from core.models import Popup

# Get a popup by ID
popup = Popup.objects.get(id=1)

# Update title
popup.title = "Updated Welcome Message"
popup.save()

# Deactivate a popup
popup.is_active = False
popup.save()

# Change priority
popup.priority = 10
popup.save()

# Extend expiry
from datetime import timedelta
from django.utils import timezone
popup.expires_at = timezone.now() + timedelta(days=60)
popup.save()

# Update multiple fields at once
popup.title = "New Title"
popup.message = "New message"
popup.priority = 7
popup.save()
```

### Deleting Popups

```python
from core.models import Popup
from django.utils import timezone

# Delete a specific popup
popup = Popup.objects.get(id=1)
popup.delete()

# Delete expired popups
expired_count = Popup.objects.filter(
    expires_at__lt=timezone.now()
).delete()
print(f"Deleted {expired_count[0]} expired popups")

# Delete inactive popups older than 6 months
from datetime import timedelta
six_months_ago = timezone.now() - timedelta(days=180)
old_inactive = Popup.objects.filter(
    is_active=False,
    created_at__lt=six_months_ago
).delete()
print(f"Deleted {old_inactive[0]} old inactive popups")
```

### Bulk Operations

```python
from core.models import Popup

# Deactivate all popups
Popup.objects.update(is_active=False)

# Activate all event popups
Popup.objects.filter(popup_type='event').update(is_active=True)

# Change priority for all general popups
Popup.objects.filter(popup_type='general').update(priority=5)

# Set expiry for all active popups
from django.utils import timezone
from datetime import timedelta
Popup.objects.filter(is_active=True).update(
    expires_at=timezone.now() + timedelta(days=30)
)
```

## Flutter/Dart Examples

### Testing Popup Service

```dart
import 'package:burundi_au_chairmanship/services/popup_service.dart';
import 'package:burundi_au_chairmanship/models/popup_model.dart';

// Get popup service instance
final popupService = PopupService();

// Fetch active popups from API
final popups = await popupService.fetchActivePopups();
print('Fetched ${popups.length} popups');
for (final popup in popups) {
  print('- ${popup.title} (priority: ${popup.priority})');
}

// Get seen popup IDs
final seenIds = await popupService.getSeenPopupIds();
print('Seen popup IDs: $seenIds');

// Mark a popup as seen
await popupService.markPopupAsSeen(1);
print('Marked popup 1 as seen');

// Get popups to show (filters by seen status)
final toShow = await popupService.getPopupsToShow();
print('Popups to show: ${toShow.length}');

// Clear all seen popups (for testing)
await popupService.clearSeenPopups();
print('Cleared all seen popups');
```

### Showing Popups Manually

```dart
import 'package:burundi_au_chairmanship/widgets/popup_dialog.dart';
import 'package:burundi_au_chairmanship/models/popup_model.dart';
import 'package:flutter/material.dart';

// In your widget's method:
void showTestPopup(BuildContext context) async {
  final popup = PopupModel(
    id: 1,
    title: 'Test Popup',
    titleFr: 'Popup de test',
    message: 'This is a test message',
    messageFr: 'Ceci est un message de test',
    image: null,
    actionText: 'Click Me',
    actionTextFr: 'Cliquez ici',
    actionUrl: '/events',
    popupType: 'general',
    priority: 5,
    showOnce: true,
    createdAt: DateTime.now(),
  );

  await PopupDialog.show(
    context: context,
    popup: popup,
    languageCode: 'en',
  );
}
```

### Integration in Custom Screen

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:burundi_au_chairmanship/services/popup_service.dart';
import 'package:burundi_au_chairmanship/widgets/popup_dialog.dart';
import 'package:burundi_au_chairmanship/providers/language_provider.dart';

class MyCustomScreen extends StatefulWidget {
  const MyCustomScreen({super.key});

  @override
  State<MyCustomScreen> createState() => _MyCustomScreenState();
}

class _MyCustomScreenState extends State<MyCustomScreen> {
  @override
  void initState() {
    super.initState();
    // Check popups after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPopups();
    });
  }

  Future<void> _checkPopups() async {
    try {
      final popupService = PopupService();
      final languageProvider = context.read<LanguageProvider>();
      final langCode = languageProvider.currentLocale.languageCode;

      final popups = await popupService.getPopupsToShow();

      if (popups.isEmpty || !mounted) return;

      for (final popup in popups) {
        if (!mounted) break;

        await PopupDialog.show(
          context: context,
          popup: popup,
          languageCode: langCode,
        );

        await popupService.markPopupAsSeen(popup.id);
      }
    } catch (e) {
      print('Error showing popups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Screen')),
      body: const Center(child: Text('Content')),
    );
  }
}
```

## API Examples (curl)

### Get Active Popups

```bash
# Replace TOKEN with your JWT or Firebase ID token
curl -X GET \
  "https://api.burundi4africa.com/api/popups/active/" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json"
```

### Response Example

```json
[
  {
    "id": 1,
    "title": "Welcome to Burundi Chairmanship 2026!",
    "title_fr": "Bienvenue à la Présidence burundaise de l'UA 2026!",
    "message": "Thank you for being part of our community.",
    "message_fr": "Merci de faire partie de notre communauté.",
    "image": "https://api.burundi4africa.com/media/popups/welcome.jpg",
    "action_text": "Explore Now",
    "action_text_fr": "Explorer maintenant",
    "action_url": "/events",
    "popup_type": "general",
    "priority": 10,
    "show_once": true,
    "created_at": "2026-04-02T10:00:00Z"
  },
  {
    "id": 2,
    "title": "Get Your Blue Badge",
    "title_fr": "Obtenez votre badge bleu",
    "message": "Verify your account to access exclusive features.",
    "message_fr": "Vérifiez votre compte pour accéder aux fonctionnalités exclusives.",
    "image": null,
    "action_text": "Start Verification",
    "action_text_fr": "Commencer la vérification",
    "action_url": "/verification",
    "popup_type": "verification",
    "priority": 8,
    "show_once": true,
    "created_at": "2026-04-02T11:00:00Z"
  }
]
```

## Testing Checklist

### Backend Testing

```bash
# 1. Run Django checks
cd backend
python3 manage.py check

# 2. Create test popup
python3 manage.py shell
# (paste code from examples above)

# 3. Verify in admin panel
# Login to http://127.0.0.1:8000/admin/
# Navigate to Core > Popups/Announcements
# Check that popup appears

# 4. Test API endpoint
# Start server: python3 manage.py runserver
# Get token from login
# curl with token (see API examples above)
```

### Frontend Testing

```bash
# 1. Check Flutter syntax
cd burundi_au_chairmanship
flutter analyze lib/models/popup_model.dart
flutter analyze lib/services/popup_service.dart
flutter analyze lib/widgets/popup_dialog.dart

# 2. Run app in debug mode
flutter run

# 3. Navigate to home screen
# Popup should appear automatically

# 4. Test action button
# Click button, verify navigation works

# 5. Test seen tracking
# Close app, reopen
# Popup should NOT appear again (if show_once=true)

# 6. Clear seen popups (for retesting)
# In debug console or add debug button:
# PopupService().clearSeenPopups()
```

## Production Deployment

### Backend

```bash
# 1. Apply migration on production
ssh production-server
cd /path/to/backend
source venv/bin/activate
python3 manage.py migrate

# 2. Restart server
systemctl restart gunicorn

# 3. Create welcome popup via admin panel
# Login to https://api.burundi4africa.com/admin/
# Create first popup
```

### Frontend

```bash
# 1. Build release APK/IPA
./build_release.sh android
# or
./build_release.sh ios

# 2. Upload to Play Store / App Store
# Follow standard release process

# 3. Test on production
# Install app from store
# Login with test account
# Verify popup appears
```

## Common Testing Scenarios

### Scenario 1: Test Priority Ordering

```python
# Create 3 popups with different priorities
Popup.objects.create(title="Low Priority", priority=1, is_active=True, target_audience="all")
Popup.objects.create(title="Medium Priority", priority=5, is_active=True, target_audience="all")
Popup.objects.create(title="High Priority", priority=10, is_active=True, target_audience="all")

# Open app - should see High → Medium → Low order
```

### Scenario 2: Test Target Audience

```python
# Create verified-only popup
Popup.objects.create(
    title="Exclusive for Verified Users",
    is_active=True,
    target_audience="verified_only",
    priority=5
)

# Login with unverified account → Popup should NOT appear
# Login with verified account → Popup should appear
```

### Scenario 3: Test Expiry

```python
from datetime import timedelta
from django.utils import timezone

# Create popup that expires in 1 minute
Popup.objects.create(
    title="Expiring Soon",
    is_active=True,
    expires_at=timezone.now() + timedelta(minutes=1),
    target_audience="all",
    priority=5
)

# Open app immediately → Popup appears
# Wait 2 minutes, reopen app → Popup does NOT appear
```

### Scenario 4: Test Show Once

```python
# Create show-once popup
Popup.objects.create(
    title="Show Once Test",
    is_active=True,
    show_once=True,
    target_audience="all",
    priority=5
)

# First app open → Popup appears
# Close and reopen → Popup does NOT appear

# Create show-always popup
Popup.objects.create(
    title="Show Always Test",
    is_active=True,
    show_once=False,
    target_audience="all",
    priority=5
)

# Every app open → Popup appears
```

## Debugging Tips

### Backend

```python
# Check popup filtering logic
from core.models import Popup
from django.db.models import Q
from django.utils import timezone

popups = Popup.objects.filter(is_active=True)
print(f"Active: {popups.count()}")

now = timezone.now()
popups = popups.filter(Q(expires_at__isnull=True) | Q(expires_at__gt=now))
print(f"Not expired: {popups.count()}")

# Check specific popup
popup = Popup.objects.get(id=1)
print(f"Active: {popup.is_active}")
print(f"Expired: {popup.is_expired()}")
print(f"Target: {popup.target_audience}")
```

### Frontend

```dart
// Add debug prints in popup_service.dart
print('Fetched ${popups.length} popups from API');
print('Seen IDs: $seenIds');
print('Popups to show: ${filtered.length}');

// Check API response
final data = await _apiService.getActivePopups();
print('API response: $data');

// Check SharedPreferences
final prefs = await SharedPreferences.getInstance();
final seen = prefs.getStringList('seen_popups');
print('Seen popups in storage: $seen');
```
