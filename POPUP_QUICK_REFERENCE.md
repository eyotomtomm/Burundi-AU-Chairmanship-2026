# Popup System - Quick Reference Card

## Admin Panel Access
- Production: `https://api.burundi4africa.com/admin/`
- Local: `http://127.0.0.1:8000/admin/`
- Navigate to: **Core > Popups/Announcements**

## Quick Create Checklist

### Required Fields
- [ ] Title (English)
- [ ] Message (English)
- [ ] Is Active (✓ to show to users)
- [ ] Priority (1-100, higher = shown first)
- [ ] Target Audience (all / verified_only / unverified_only)

### Optional Fields
- [ ] Title (French) - Recommended for bilingual support
- [ ] Message (French) - Recommended for bilingual support
- [ ] Image - Visual appeal (max 2MB)
- [ ] Action Text - Button label
- [ ] Action URL - Where button goes
- [ ] Expires At - Auto-hide after date

## Action URL Examples

| Type | Example | What It Does |
|------|---------|--------------|
| No action | *(leave blank)* | Popup with close button only |
| Events | `/events` | Opens Events/Calendar screen |
| Profile | `/profile` | Opens user profile |
| Verification | `/verification` | Opens verification request screen |
| Magazine | `/magazine` | Opens Magazine tab |
| Gallery | `/gallery` | Opens photo gallery |
| Videos | `/videos` | Opens video gallery |
| News | `/news` | Opens news/articles |
| Support | `/support` | Opens support tickets |
| External | `https://example.com` | Opens in external browser |

## Target Audience

| Option | Who Sees It |
|--------|-------------|
| All Users | Everyone (default) |
| Verified Only | Users with Gold/Blue badges |
| Unverified Only | Users without badges |

## Priority Guide

| Priority | Use Case |
|----------|----------|
| 10 | Critical announcements (emergency, breaking news) |
| 8 | Important events (summit registration, deadlines) |
| 5 | Regular announcements (new features, updates) |
| 3 | Minor updates (app tips, suggestions) |
| 1 | Low-priority info (general reminders) |

## Common Scenarios

### Welcome Message
```
Priority: 5
Target: All Users
Show Once: ✓
Expires: 30 days
Action: /profile (optional)
```

### Event Promotion
```
Priority: 8
Target: All Users
Show Once: ✓
Expires: Event date
Action: /events
```

### Verification Reminder
```
Priority: 7
Target: Unverified Only
Show Once: ✓
Expires: None
Action: /verification
```

### Urgent Announcement
```
Priority: 10
Target: All Users
Show Once: ✗ (show every time)
Expires: 2-3 days
Action: External URL (optional)
```

## Tips

1. Always fill French translations for bilingual support
2. Test with `is_active=False` before enabling
3. Use clear, concise messages (2-3 sentences max)
4. Upload images in 16:9 ratio (e.g., 800x450px)
5. Set expiry dates to keep popups fresh
6. Don't create too many active popups (max 1-2)

## Deactivating a Popup

1. Find the popup in the list
2. Uncheck **Is Active**
3. Click **Save**

Or use the quick edit:
1. Check the popup checkbox
2. Select "Is Active" dropdown = ✗
3. Click **Go**
