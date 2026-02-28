# 🎴 Feature Cards Configuration Guide

**Date**: February 28, 2026
**Status**: ✅ **FULLY FUNCTIONAL**

---

## 🎯 What Are Feature Cards?

Feature cards are the **beautiful horizontal sliding cards** on the home screen, located just below the hero slideshow. They showcase important features, campaigns, or calls-to-action.

**Previous Issue**: These cards were NOT clickable - users could see them but tapping did nothing.

**Now Fixed**: ✅ All feature cards are now fully interactive and configurable from Django Admin without any code changes.

---

## 🔧 How to Configure Feature Cards

### Step 1: Access Django Admin

1. Go to your backend URL: `https://api.burundi4africa.com/admin/`
2. Login with superuser credentials
3. Navigate to **Core → Feature Cards**

---

### Step 2: Create/Edit a Feature Card

Click "Add Feature Card" or edit an existing one.

#### **Required Fields**:

**1. Title (English)**
- Main heading shown on the card
- Example: "AU Vision 2063"
- Max 200 characters

**2. Title (French)** *(optional)*
- French translation
- Example: "Vision de l'UA 2063"

**3. Description (English)**
- Subtitle/body text on the card
- Example: "An integrated, prosperous and peaceful Africa"
- Can be longer, but keep it concise for mobile

**4. Description (French)** *(optional)*
- French translation

**5. Gradient Start Color**
- Hex color for gradient start
- Example: `#1EB53A` (Burundi Green)
- Format: `#RRGGBB`

**6. Gradient End Color**
- Hex color for gradient end
- Example: `#4CAF50` (Lighter Green)
- Creates beautiful gradient background

**7. Icon Name** *(NEW!)*
- Flutter icon name to display
- Examples:
  - `stars` - Star icon (Vision)
  - `security` - Shield icon (Security)
  - `public` - Globe icon (Global)
  - `groups` - People icon (Community)
  - `handshake` - Partnership
  - `flag` - Leadership
  - `campaign` - Announcements
  - `workspace_premium` - Excellence
- See full list below

**8. Action Type** *(NEW!)* ⭐
- **none** - Card is not clickable (display only)
- **url** - Opens external website in browser
- **route** - Navigates to app screen

**9. Action Value** *(NEW!)* ⭐
- **If Action Type = url**: Enter full URL
  - Example: `https://au.int/en/vision2063`
  - Example: `https://burundi4africa.com/summit`
- **If Action Type = route**: Enter app route name
  - Example: `/news`
  - Example: `/magazine`
  - Example: `/calendar`
  - See full route list below

**10. Image** *(optional)*
- Upload a background image for the card
- Recommended size: 1200x400px
- If provided, shows instead of gradient
- Leave blank to use gradient colors

**11. Order**
- Number to control card sequence
- Lower numbers appear first
- Example: 0, 1, 2, 3...

**12. Is Active**
- ✅ Checked = Card is visible in app
- ❌ Unchecked = Card is hidden

---

## 📱 Supported App Routes

Use these route names in **Action Value** when **Action Type = route**:

| Route | Screen | Description |
|-------|--------|-------------|
| `/news` | News Screen | Latest articles and news |
| `/magazine` | Magazine Screen | Digital magazine editions |
| `/calendar` | Calendar Screen | Events and schedule |
| `/live-feeds` | Live Feeds | Live video streams |
| `/resources` | Resources Screen | Documents and downloads |
| `/weather` | Weather Screen | Weather forecasts |
| `/translate` | Translate Screen | Language translation |
| `/gallery` | Gallery Screen | Photo albums |
| `/videos` | Videos Screen | Video library |
| `/social-media` | Social Media | Social media links |
| `/profile` | Profile Screen | User profile (requires login) |
| `/water-sanitation` | Water & Sanitation Agenda | Priority agenda detail |
| `/arise-initiative` | ARISE Initiative | Priority agenda detail |
| `/peace-security` | Peace & Security | Priority agenda detail |

---

## 🎨 Available Icon Names

Use these in the **Icon Name** field:

| Icon Name | Icon | Best For |
|-----------|------|----------|
| `stars` | ⭐ | Vision, Excellence, Featured |
| `security` | 🛡️ | Security, Safety, Protection |
| `public` | 🌍 | Global, International, AU |
| `groups` | 👥 | Community, People, Teams |
| `handshake` | 🤝 | Partnership, Cooperation |
| `flag` | 🚩 | Leadership, Nation, Government |
| `campaign` | 📢 | Announcements, Campaigns |
| `workspace_premium` | 🏆 | Premium, Quality, Awards |
| `travel_explore` | ✈️ | Diplomacy, Travel, Relations |
| `gavel` | ⚖️ | Justice, Law, Policy |
| `policy` | 📋 | Policies, Governance |
| `auto_stories` | 📖 | Magazine, Stories, Content |

---

## 💡 Example Configurations

### Example 1: AU Vision 2063 (Internal Screen)

```
Title: AU Vision 2063
Title (FR): Vision de l'UA 2063
Description: An integrated, prosperous and peaceful Africa
Description (FR): Une Afrique intégrée, prospère et pacifique
Gradient Start: #1EB53A
Gradient End: #4CAF50
Icon Name: stars
Action Type: route
Action Value: /news
Order: 0
Is Active: ✅
```

**Result**: Tapping this card navigates to the News screen.

---

### Example 2: AU Summit Website (External URL)

```
Title: AU Summit 2026
Title (FR): Sommet de l'UA 2026
Description: Official African Union Summit website
Description (FR): Site officiel du Sommet de l'Union Africaine
Gradient Start: #D4AF37
Gradient End: #DAA520
Icon Name: public
Action Type: url
Action Value: https://au.int/en/summit2026
Order: 1
Is Active: ✅
```

**Result**: Tapping this card opens the AU website in the browser.

---

### Example 3: Discover Burundi (Magazine)

```
Title: Discover Burundi
Title (FR): Découvrir le Burundi
Description: Explore the heart of Africa through our digital magazine
Gradient Start: #0A5C1E
Gradient End: #1EB53A
Icon Name: auto_stories
Action Type: route
Action Value: /magazine
Order: 2
Is Active: ✅
```

**Result**: Tapping this card navigates to the Magazine screen.

---

### Example 4: Consular Services (External URL)

```
Title: Consular Services
Title (FR): Services Consulaires
Description: Embassy services, visa applications, and support
Gradient Start: #1565C0
Gradient End: #42A5F5
Icon Name: handshake
Action Type: url
Action Value: https://burundi.gov.bi/consular
Order: 3
Is Active: ✅
```

**Result**: Tapping this card opens the consular services website.

---

## 🔄 How to Remove/Replace Cards

### To Remove a Card:
1. Edit the card in Django Admin
2. Uncheck **Is Active**
3. Save

The card will disappear from the app immediately.

### To Replace a Card:
1. **Option A**: Edit the existing card and change all fields
2. **Option B**:
   - Uncheck **Is Active** on the old card
   - Create a new card with new content
   - Set the **Order** to control position

---

## 🎯 Best Practices

### Visual Design:
- Use **high-contrast** gradient colors for readability
- Keep titles **short** (1-5 words)
- Keep descriptions **concise** (1-2 lines)
- Use **relevant icons** that match the content

### Color Combinations:
- **Green/Gold**: `#1EB53A` → `#DAA520` (AU official colors)
- **Blue**: `#0077B6` → `#00B4D8` (Trust, authority)
- **Purple**: `#6A1B9A` → `#9C27B0` (Royalty, premium)
- **Red**: `#C62828` → `#E53935` (Urgent, important)
- **Orange**: `#E65100` → `#F57C00` (Energy, enthusiasm)

### Content Strategy:
- **Limit to 3-5 cards** for best user experience
- **Mix actions**: Some internal routes, some external URLs
- **Update regularly**: Change cards for campaigns, events, announcements
- **Test on mobile**: Preview in app after creating

### Performance:
- **Use images sparingly**: Gradients are faster and look great
- **If using images**: Compress to <200KB, size 1200x400px
- **Keep active cards under 10**: Users won't swipe through more

---

## 🚀 Deployment Workflow

### Local Testing:
1. Start Django server: `python manage.py runserver`
2. Create/edit feature cards in admin
3. Open Flutter app (connected to localhost)
4. Cards update automatically on app refresh

### Production:
1. Login to production Django admin
2. Create/edit feature cards
3. Changes are **INSTANT** - no deployment needed
4. App fetches new cards on next home screen load

---

## 🐛 Troubleshooting

### Card Not Showing:
- ✅ Check **Is Active** is checked
- ✅ Check **Order** number (lower = first)
- ✅ Refresh app (pull down on home screen)

### Card Not Clickable:
- ✅ Check **Action Type** is not 'none'
- ✅ Check **Action Value** is filled in
- ✅ For routes: Verify route exists in app
- ✅ For URLs: Verify URL is correct

### Icon Not Showing:
- ✅ Check **Icon Name** spelling (lowercase, underscores)
- ✅ Use names from supported list above
- ✅ If invalid, app uses default star icon

### Gradient Not Showing:
- ✅ Check hex format: `#RRGGBB` (6 characters + #)
- ✅ Examples: `#1EB53A`, `#4CAF50`, `#D4AF37`
- ✅ If invalid, app uses green default

### URL Not Opening:
- ✅ Check URL includes `https://` or `http://`
- ✅ Test URL in browser first
- ✅ Verify **Action Type** is set to 'url'

---

## 📊 Current Feature Cards

To see all current feature cards:

```bash
cd backend
python manage.py shell

>>> from core.models import FeatureCard
>>> for card in FeatureCard.objects.all():
...     print(f"{card.order}: {card.title} ({card.action_type}:{card.action_value})")
```

---

## ✅ Success Checklist

When configuring a new feature card:

- [ ] Title is clear and concise
- [ ] Description explains the value/action
- [ ] Gradient colors are visually appealing
- [ ] Icon name is from supported list
- [ ] Action type is selected (url or route)
- [ ] Action value is correct (URL or route name)
- [ ] Order number is set
- [ ] Is Active is checked
- [ ] Tested on mobile device
- [ ] Card appears on home screen
- [ ] Tapping card performs expected action

---

## 🎉 You're All Set!

Feature cards are now a powerful tool for:
- ✅ Promoting campaigns and initiatives
- ✅ Driving traffic to specific app screens
- ✅ Linking to external resources
- ✅ Showcasing AU priorities
- ✅ Engaging users with dynamic content

**No code changes needed** - just use Django Admin!

---

**Last Updated**: February 28, 2026
**Status**: ✅ PRODUCTION READY

**For Questions**: Check DEPLOYMENT_GUIDE.md or COMPLETE_UI_BACKEND_VERIFICATION.md
