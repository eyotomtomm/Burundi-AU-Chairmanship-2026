# Admin Panel Workflow - Creating Popups

## Step-by-Step Guide

### Step 1: Login to Admin Panel

1. Navigate to admin URL:
   - Production: `https://api.burundi4africa.com/admin/`
   - Development: `http://127.0.0.1:8000/admin/`

2. Enter credentials:
   - Username: `admin`
   - Password: `admin2026` (or your credentials)

### Step 2: Navigate to Popups Section

1. In the left sidebar or main menu, find **Core** section
2. Click on **Popups/Announcements**
3. You'll see a list of existing popups

### Step 3: Create New Popup

1. Click **Add Popup/Announcement** button (top right)
2. You'll see the creation form with organized sections

### Step 4: Fill Content (English)

**Section: Content (English)**

- **Title**: Enter the main headline
  - Example: `Welcome to Burundi Chairmanship 2026!`
  - Keep it under 60 characters for best display

- **Message**: Enter the main content
  - Example: `Thank you for joining our community. Explore the app to stay updated on events, news, and initiatives.`
  - Keep it 2-3 sentences maximum
  - Be clear and concise

- **Action Text**: Enter button label (optional)
  - Example: `Explore Now`
  - Leave blank if you don't want an action button
  - Keep it 1-3 words

### Step 5: Fill Content (French)

**Section: Content (French)** - Expand this section

- **Title (French)**: French translation of title
  - Example: `Bienvenue à la Présidence burundaise de l'UA 2026!`

- **Message (French)**: French translation of message
  - Example: `Merci de rejoindre notre communauté. Explorez l'application pour rester informé des événements, nouvelles et initiatives.`

- **Action Text (French)**: French translation of button
  - Example: `Explorer maintenant`

> **Important**: Always provide French translations for bilingual support!

### Step 6: Add Media & Action

**Section: Media & Action**

- **Image**: Upload an image (optional)
  - Click **Choose File**
  - Select image from your computer
  - Recommended: 800x450px (16:9 ratio)
  - Max size: 2MB
  - Formats: JPG, PNG, WebP
  - Leave blank for text-only popup

- **Action URL**: Where the button goes (optional)
  - For app screens, use routes like:
    - `/events` - Opens Events/Calendar
    - `/profile` - Opens user profile
    - `/verification` - Opens verification screen
    - `/magazine` - Opens Magazine tab
    - `/gallery` - Opens photo gallery
    - `/videos` - Opens video gallery
    - `/news` - Opens news articles
    - `/support` - Opens support tickets
  - For external websites, use full URL:
    - `https://burundi4africa.com`
    - `https://example.com/page`
  - Leave blank if no action needed (close button only)

### Step 7: Configure Settings

**Section: Settings**

- **Popup Type**: Select category
  - `General Announcement` - Default, general info
  - `Event Promotion` - Event-related announcements
  - `Verification Reminder` - Badge verification prompts
  - `Project Update` - Project/initiative updates

- **Is Active**: Check this to show popup to users
  - ✓ = Active (users will see it)
  - ✗ = Inactive (hidden, saved as draft)
  - **Tip**: Create with ✗, preview, then activate

- **Priority**: Enter number 0-100
  - `10` = Critical (shown first)
  - `8` = Important
  - `5` = Regular
  - `3` = Minor
  - `1` = Low priority
  - Higher numbers appear first

- **Target Audience**: Who sees this
  - `All Users` - Everyone sees it (default)
  - `Verified Users Only` - Only Gold/Blue badge holders
  - `Unverified Users Only` - Only non-verified users

- **Show Once**: Control repeat display
  - ✓ = Show only once per user (recommended)
  - ✗ = Show every time app launches
  - **Tip**: Usually keep checked

- **Expires At**: Auto-hide date (optional)
  - Click calendar icon
  - Select date and time
  - Popup won't show after this date
  - Leave blank for no expiry
  - **Tip**: Set for time-sensitive announcements

### Step 8: Save

1. Review all fields
2. Click **Save** button (bottom right)
3. You'll return to the popup list

### Step 9: Verify

1. Find your popup in the list
2. Check the columns:
   - **Title**: Your popup title
   - **Popup Type**: Category you selected
   - **Is Active**: Should show ✓ (green checkmark)
   - **Priority**: Your priority number
   - **Target Audience**: Who can see it
   - **Show Once**: ✓ or ✗
   - **Expires At**: Date or blank
   - **Created At**: Just now

### Step 10: Test in App

1. Open the Burundi Chairmanship app
2. Login if needed
3. Navigate to Home screen
4. Popup should appear automatically
5. Test the action button (if provided)
6. Verify it looks correct

## Quick Edit Workflow

To quickly activate/deactivate popups:

1. In the popup list, find your popup
2. **Either**:
   - Click the **Is Active** checkbox in the row
   - Click **Save** at the bottom
3. **Or**:
   - Check the checkbox on the left of the row
   - In the action dropdown (top), select action
   - Click **Go**

## Common Scenarios

### Scenario 1: Welcome Message

```
Title: Welcome!
Message: Thanks for joining. Explore the app.
Image: [Leave blank]
Action Text: [Leave blank]
Action URL: [Leave blank]
Popup Type: General Announcement
Is Active: ✓
Priority: 5
Target Audience: All Users
Show Once: ✓
Expires At: [30 days from now]
```

### Scenario 2: Event Registration

```
Title: New Event: AU Summit Registration Open
Message: Register now for the African Union Summit. Limited spots!
Image: [Upload event banner]
Action Text: Register Now
Action URL: /events
Popup Type: Event Promotion
Is Active: ✓
Priority: 10
Target Audience: All Users
Show Once: ✓
Expires At: [Event date]
```

### Scenario 3: External Promotion

```
Title: Read Our Latest Magazine
Message: Check out this month's edition with exclusive interviews.
Image: [Upload magazine cover]
Action Text: Read Online
Action URL: https://burundi4africa.com/magazine
Popup Type: General Announcement
Is Active: ✓
Priority: 7
Target Audience: All Users
Show Once: ✓
Expires At: [Next month]
```

### Scenario 4: Verification Reminder

```
Title: Get Your Blue Badge
Message: Verify your account to unlock exclusive features.
Image: [Upload badge icon]
Action Text: Start Verification
Action URL: /verification
Popup Type: Verification Reminder
Is Active: ✓
Priority: 8
Target Audience: Unverified Users Only
Show Once: ✓
Expires At: [Leave blank]
```

## Editing Existing Popups

1. Click on the popup title in the list
2. Make your changes
3. Click **Save**
4. Changes are immediate

## Deactivating a Popup

**Method 1: Edit Form**
1. Click popup title
2. Uncheck **Is Active**
3. Click **Save**

**Method 2: Quick Edit**
1. Check popup checkbox
2. Action dropdown → Select action
3. Click **Go**

**Method 3: Inline Edit**
1. Uncheck **Is Active** in the row
2. Page auto-saves

## Deleting a Popup

1. Click popup title
2. Scroll to bottom
3. Click **Delete** button (red)
4. Confirm deletion
5. Or check multiple popups and use bulk delete action

## Tips & Best Practices

### Content Tips
1. Keep titles under 60 characters
2. Keep messages under 200 characters
3. Use clear, action-oriented language
4. Always provide French translations
5. Proofread before saving

### Image Tips
1. Use 16:9 aspect ratio (e.g., 800x450px)
2. Optimize images before upload (< 500KB)
3. Use high-quality, relevant images
4. Test image on light and dark backgrounds
5. Images are optional - text-only works too

### Targeting Tips
1. Use "Verified Only" for exclusive content
2. Use "Unverified Only" for verification reminders
3. Use "All Users" for general announcements
4. Don't create too many verified-only popups

### Priority Tips
1. Use 10 only for critical/emergency
2. Most popups should be 3-7
3. Don't set everything to 10 (defeats the purpose)
4. Lower priority for optional info

### Timing Tips
1. Set expiry for time-sensitive content
2. No expiry for evergreen content
3. Review and update monthly
4. Deactivate outdated popups

## Troubleshooting

### Popup not showing in app
- Check **Is Active** = ✓
- Check **Expires At** is future or blank
- Check **Target Audience** matches test user
- Clear app data and re-login
- Wait 5-10 seconds after login

### Image not displaying
- Check image uploaded successfully
- Verify file size < 2MB
- Check file format (JPG/PNG)
- Test image URL accessibility

### Action button not working
- Verify **Action URL** is correct
- For app screens, must start with `/`
- For websites, must have `https://`
- Check route exists in app

### Changes not appearing
- Wait a few seconds (cache)
- Force close and reopen app
- Clear app data
- Check **Is Active** is checked

## Getting Help

1. Check `POPUP_SYSTEM_GUIDE.md` for detailed docs
2. Review `POPUP_QUICK_REFERENCE.md` for examples
3. Test in development first
4. Contact technical support if issues persist

## Checklist Before Activating

- [ ] Title is clear and concise
- [ ] Message is easy to understand
- [ ] French translations provided
- [ ] Image uploaded (if using)
- [ ] Action URL tested (if using)
- [ ] Priority set appropriately
- [ ] Target audience selected
- [ ] Expiry date set (if needed)
- [ ] Previewed with Is Active = ✗
- [ ] Ready to activate with Is Active = ✓
