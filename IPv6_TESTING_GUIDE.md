# IPv6 Testing Guide
## Burundi AU Chairmanship App

**Apple Requirement:** Guideline 2.5.5
> Apps must support IPv6-only networks. All apps should natively support IPv6.

---

## Why IPv6 Testing is Important

Apple requires all apps to work on IPv6-only networks because:
- Many carriers worldwide use IPv6-only networks
- T-Mobile USA and other major carriers are IPv6-only
- App Review tests apps on IPv6-only networks
- Failure to support IPv6 = automatic rejection

---

## Quick Check: Is Your App IPv6 Compatible?

✅ **Good News!** Your app is likely already IPv6 compatible if:
- ✅ You use high-level networking APIs (http package in Flutter)
- ✅ You use domain names, not hardcoded IP addresses
- ✅ Your backend server supports IPv6
- ✅ You don't use low-level socket programming with IPv4-specific code

Your app uses `http` package with domain names, so it **should be compatible**.

---

## How to Test IPv6 Compatibility

### Method 1: macOS IPv6 Test Network (Recommended)

#### Step 1: Create IPv6-Only Network on Mac

```bash
# 1. Connect your Mac to internet via Ethernet or WiFi
# 2. Open Terminal and run:

sudo networksetup -listallhardwareports

# Note your hardware port name (usually "Wi-Fi" or "Ethernet")

# 3. Create NAT64/DNS64 network
# Replace "Wi-Fi" with your actual interface name
sudo /System/Library/CoreServices/Applications/Network\ Utility.app/Contents/Resources/stroke -6

# OR use Internet Sharing with NAT64
```

#### Step 2: Enable Internet Sharing with IPv6

1. Open **System Preferences** > **Sharing**
2. Select **Internet Sharing** from the list (don't enable yet)
3. Share your connection from: **Wi-Fi** (or your internet source)
4. To computers using: **USB Ethernet** or **Thunderbolt Bridge**
5. Enable **Internet Sharing**

#### Step 3: Connect iPhone to Mac's Shared Network

**Option A: USB Tethering**
1. Connect iPhone to Mac via USB
2. On iPhone: Settings > Personal Hotspot > Allow Others to Join
3. On Mac: System Preferences > Network > iPhone USB
4. Verify connection

**Option B: Create Wi-Fi Hotspot**
1. Mac shares internet via Wi-Fi
2. iPhone connects to Mac's Wi-Fi network
3. Verify connection

#### Step 4: Enable NAT64/DNS64

```bash
# Run this script to enable NAT64/DNS64 on your Mac
# This creates an IPv6-only network

# Save as enable_nat64.sh
#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./enable_nat64.sh"
  exit
fi

# Enable IPv6 forwarding
sysctl -w net.inet6.ip6.forwarding=1

# Configure NAT64
# This requires additional configuration based on your network setup
echo "NAT64/DNS64 configuration requires network-specific setup."
echo "Consider using Apple's IPv6 test instructions instead."
```

### Method 2: Use Apple's Official Test Network

Apple provides an official IPv6 test environment:

#### Step 1: Set Up Mac Internet Sharing

1. **System Preferences** > **Sharing**
2. Select **Internet Sharing**
3. Share from: Your internet connection (Wi-Fi/Ethernet)
4. To computers using: **Wi-Fi** (create a hotspot)
5. Click **Wi-Fi Options** and set:
   - Network Name: `IPv6Test`
   - Channel: `11` (or any available)
   - Security: `WPA2 Personal`
   - Password: `testipv6`

#### Step 2: Configure DNS64/NAT64

Download and run Apple's DNS64/NAT64 setup:

```bash
# This requires running a local DNS64/NAT64 server
# Apple recommends using tayga and bind for this

# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required packages
brew install tayga bind

# Configuration steps are complex - see Apple's full guide at:
# https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/UnderstandingandPreparingfortheIPv6Transition/UnderstandingandPreparingfortheIPv6Transition.html
```

### Method 3: Use a Physical IPv6-Only Network (Most Reliable)

**Option A: T-Mobile USA**
- T-Mobile USA runs an IPv6-only network
- Get a T-Mobile iPhone or SIM card
- Test your app on this network
- Most accurate real-world test

**Option B: Contact Your ISP**
- Ask if they offer IPv6-only testing
- Some ISPs provide IPv6-only access points
- Configure your router for IPv6-only

### Method 4: Use Cloud Testing Services

**AWS or Google Cloud IPv6 Testing:**
```bash
# Deploy your backend to IPv6-enabled cloud
# Test your app against IPv6-only backend
```

---

## Simplified Testing (For Your App)

Since your app uses standard HTTP APIs and domain names, here's a quick test:

### Quick Test Checklist

```bash
# 1. Ensure your backend uses domain names, not IP addresses
# Current: http://127.0.0.1:8000/api/
# Should be: http://api.burundi-au-chairmanship.gov.bi/api/

# 2. Test DNS resolution
nslookup api.burundi-au-chairmanship.gov.bi

# Should return both IPv4 (A) and IPv6 (AAAA) records

# 3. Test backend IPv6 connectivity
curl -6 http://api.burundi-au-chairmanship.gov.bi/api/

# If this works, your backend supports IPv6
```

### Update API Base URL

**File:** `lib/config/app_constants.dart`

```dart
class AppConstants {
  // Change from:
  static const String baseApiUrl = 'http://127.0.0.1:8000/api';

  // To:
  static const String baseApiUrl = 'https://api.burundi-au-chairmanship.gov.bi/api';

  // This ensures domain resolution works for both IPv4 and IPv6
}
```

---

## Common IPv6 Issues and Fixes

### Issue 1: Hardcoded IPv4 Addresses
```dart
// ❌ BAD - Will fail on IPv6-only networks
const url = 'http://192.168.1.100:8000/api';

// ✅ GOOD - Works on both IPv4 and IPv6
const url = 'http://api.example.com/api';
```

### Issue 2: IPv4-Specific Code
```dart
// ❌ BAD - IPv4 only
final ipv4 = InternetAddress('192.168.1.1', type: InternetAddressType.IPv4);

// ✅ GOOD - Supports both
final address = InternetAddress('example.com', type: InternetAddressType.any);
```

### Issue 3: Backend Not Listening on IPv6
```python
# ❌ BAD - Only listens on IPv4
# Django: python manage.py runserver 127.0.0.1:8000

# ✅ GOOD - Listens on both IPv4 and IPv6
# Django: python manage.py runserver [::]:8000
# Or: python manage.py runserver 0.0.0.0:8000 (listens on all interfaces)
```

---

## Automated IPv6 Testing Script

Save this as `test_ipv6.sh`:

```bash
#!/bin/bash

echo "🧪 IPv6 Compatibility Test"
echo "=========================="
echo ""

# Test 1: Check if domain has IPv6 records
echo "Test 1: Checking DNS AAAA records..."
DOMAIN="api.burundi-au-chairmanship.gov.bi"

if host -t AAAA "$DOMAIN" > /dev/null 2>&1; then
    echo "✅ Domain has IPv6 (AAAA) records"
    host -t AAAA "$DOMAIN"
else
    echo "⚠️  Domain missing IPv6 records"
    echo "   Add AAAA records to your DNS"
fi

echo ""

# Test 2: Check backend IPv6 connectivity
echo "Test 2: Testing IPv6 connectivity..."
if curl -6 -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/" 2>/dev/null | grep -q "200\|301\|302"; then
    echo "✅ Backend accessible via IPv6"
else
    echo "⚠️  Backend not accessible via IPv6"
    echo "   Configure server to listen on IPv6"
fi

echo ""

# Test 3: Check app code for hardcoded IPs
echo "Test 3: Scanning for hardcoded IP addresses..."
cd "burundi_au_chairmanship/lib" 2>/dev/null || cd "lib" 2>/dev/null

if grep -r "127\.0\.0\.1\|192\.168\|10\.0\.0\|172\.16" . 2>/dev/null; then
    echo "⚠️  Found hardcoded IP addresses"
    echo "   Replace with domain names"
else
    echo "✅ No hardcoded IP addresses found"
fi

echo ""

# Test 4: Check for IPv4-specific code
echo "Test 4: Checking for IPv4-specific code..."
if grep -r "InternetAddressType\.IPv4\|AF_INET[^6]" . 2>/dev/null; then
    echo "⚠️  Found IPv4-specific code"
    echo "   Update to support both IPv4 and IPv6"
else
    echo "✅ No IPv4-specific code found"
fi

echo ""
echo "=========================="
echo "Test Complete!"
```

Run it:
```bash
chmod +x test_ipv6.sh
./test_ipv6.sh
```

---

## Production Deployment Checklist

Before submitting to App Store:

- [ ] Backend deployed to domain (not IP address)
- [ ] DNS has both A (IPv4) and AAAA (IPv6) records
- [ ] Backend server listens on both IPv4 and IPv6
- [ ] All API calls use domain names, not IPs
- [ ] No hardcoded IP addresses in code
- [ ] Tested on real IPv6-only network (if possible)
- [ ] SSL/TLS certificate supports both protocols

---

## Your App's Current Status

### ✅ Already IPv6 Compatible
- Uses `http` package (built-in IPv6 support)
- Uses Flutter's high-level networking
- No low-level socket code
- No hardcoded IPs in production code

### ⚠️ Needs Attention
- Development uses `127.0.0.1:8000` (localhost)
- Production must use domain name
- Backend should listen on `[::]:8000` or `0.0.0.0:8000`

### Recommendation
**For Development:**
```dart
static const String baseApiUrl = kDebugMode
  ? 'http://localhost:8000/api'  // Works on both IPv4/IPv6
  : 'https://api.burundi-au-chairmanship.gov.bi/api';
```

**For Production:**
- Deploy backend to cloud (AWS, Google Cloud, Azure)
- Use domain name in API calls
- Ensure DNS has AAAA records
- You're done! ✅

---

## Apple's Official Documentation

For complete details, see:
- [Apple IPv6 Support](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/UnderstandingandPreparingfortheIPv6Transition/UnderstandingandPreparingfortheIPv6Transition.html)
- [App Store Review Guidelines 2.5.5](https://developer.apple.com/app-store/review/guidelines/#2.5.5)

---

## FAQ

**Q: Will my app be rejected if I don't test on IPv6?**
A: Possibly, but if you follow best practices (domain names, high-level APIs), you'll likely pass.

**Q: Do I need to support IPv6 for localhost development?**
A: No, use `localhost` instead of `127.0.0.1` for development. It resolves to both.

**Q: What if my backend doesn't support IPv6?**
A: Use a cloud provider (AWS, Google Cloud) with IPv6 support, or use a CDN/proxy that translates.

**Q: Can I use a VPN to test IPv6?**
A: Some VPNs support IPv6, but results may vary. Physical testing is more reliable.

---

**Bottom Line:** Your app should pass IPv6 testing with no changes needed, as long as you use domain names in production! 🎉
