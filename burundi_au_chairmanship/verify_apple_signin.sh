#!/bin/bash

# Apple Sign In Setup Verification Script
echo "🔍 Verifying Apple Sign In Setup..."
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check counter
checks_passed=0
total_checks=8

# 1. Check .p8 file
echo -n "1. Checking .p8 auth key... "
if [ -f "backend/credentials/AuthKey_V78M5AW74C.p8" ]; then
    echo -e "${GREEN}✓${NC}"
    ((checks_passed++))
else
    echo -e "${RED}✗${NC} (File not found)"
fi

# 2. Check entitlements file
echo -n "2. Checking entitlements file... "
if [ -f "ios/Runner/Runner.entitlements" ]; then
    echo -e "${GREEN}✓${NC}"
    ((checks_passed++))
else
    echo -e "${RED}✗${NC} (File not found)"
fi

# 3. Check sign_in_with_apple in pubspec
echo -n "3. Checking sign_in_with_apple package... "
if grep -q "sign_in_with_apple:" pubspec.yaml; then
    echo -e "${GREEN}✓${NC}"
    ((checks_passed++))
else
    echo -e "${RED}✗${NC} (Package not in pubspec.yaml)"
fi

# 4. Check Firebase Auth Service
echo -n "4. Checking Firebase Auth Service... "
if grep -q "signInWithApple" lib/services/firebase_auth_service.dart; then
    echo -e "${GREEN}✓${NC}"
    ((checks_passed++))
else
    echo -e "${RED}✗${NC} (signInWithApple method not found)"
fi

# 5. Check Auth Provider
echo -n "5. Checking Auth Provider... "
if grep -q "signInWithApple" lib/providers/auth_provider.dart; then
    echo -e "${GREEN}✓${NC}"
    ((checks_passed++))
else
    echo -e "${RED}✗${NC} (signInWithApple method not found)"
fi

# 6. Check Auth Screen UI
echo -n "6. Checking Apple Sign In button UI... "
if grep -q "_signInWithApple" lib/screens/auth/auth_screen.dart; then
    echo -e "${GREEN}✓${NC}"
    ((checks_passed++))
else
    echo -e "${RED}✗${NC} (Apple button not found)"
fi

# 7. Check Xcode project configuration
echo -n "7. Checking Xcode entitlements config... "
if grep -q "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements" ios/Runner.xcodeproj/project.pbxproj; then
    echo -e "${GREEN}✓${NC}"
    ((checks_passed++))
else
    echo -e "${RED}✗${NC} (Not configured in Xcode project)"
fi

# 8. Check Bundle ID
echo -n "8. Checking Bundle ID... "
if grep -q "com.burundi.au.burundiAuChairmanship" ios/Runner.xcodeproj/project.pbxproj; then
    echo -e "${GREEN}✓${NC}"
    ((checks_passed++))
else
    echo -e "${RED}✗${NC} (Bundle ID mismatch)"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $checks_passed -eq $total_checks ]; then
    echo -e "${GREEN}✅ All checks passed! ($checks_passed/$total_checks)${NC}"
    echo -e "${GREEN}🚀 Apple Sign In is ready to test!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Open Xcode: cd ios && open Runner.xcworkspace"
    echo "  2. Sign the app with Team ID: 5UL786DM5B"
    echo "  3. Run on device: flutter run --release"
    echo "  4. Test Apple Sign In button"
else
    echo -e "${YELLOW}⚠️  Some checks failed ($checks_passed/$total_checks)${NC}"
    echo "Please review the failed checks above."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 For detailed setup guide, see: APPLE_SIGNIN_SETUP.md"
