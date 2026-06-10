#!/bin/bash
# =============================================================================
# Production Release Build — Be 4 Africa Flutter App
# =============================================================================
# Builds release APK (Android) and IPA (iOS) with production configuration.
#
# Prerequisites:
#   1. Set your Sentry DSN below (or pass via environment)
#   2. Android: upload-keystore.jks + key.properties configured
#   3. iOS: Xcode signing configured (Apple Developer account)
#
# Usage:
#   bash build_release.sh android   # Build APK only
#   bash build_release.sh ios       # Build IPA only
#   bash build_release.sh all       # Build both
# =============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
# Override via environment variable or edit here
SENTRY_DSN="${SENTRY_DSN_FLUTTER:-}"
ENVIRONMENT="production"
# =============================================================================

cd "$(dirname "$0")"

echo "========================================="
echo "  Building Be 4 Africa"
echo "  Environment: $ENVIRONMENT"
echo "========================================="

# Common dart-define flags
DART_DEFINES="--dart-define=ENVIRONMENT=$ENVIRONMENT"
if [ -n "$SENTRY_DSN" ]; then
  DART_DEFINES="$DART_DEFINES --dart-define=SENTRY_DSN=$SENTRY_DSN"
  echo "  Sentry: Enabled"
else
  echo "  Sentry: Disabled (set SENTRY_DSN_FLUTTER env var to enable)"
fi
echo "========================================="

build_android() {
  echo ""
  echo "[Android] Building release APK..."
  flutter build apk --release $DART_DEFINES
  echo ""
  echo "[Android] APK ready at:"
  echo "  build/app/outputs/flutter-apk/app-release.apk"
  echo ""
  echo "[Android] Building App Bundle (for Play Store)..."
  flutter build appbundle --release $DART_DEFINES
  echo ""
  echo "[Android] AAB ready at:"
  echo "  build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
  echo ""
  echo "[iOS] Building release IPA..."
  flutter build ipa --release $DART_DEFINES
  echo ""
  echo "[iOS] Archive ready at:"
  echo "  build/ios/archive/Runner.xcarchive"
  echo ""
  echo "[iOS] To upload to App Store Connect:"
  echo "  1. Open build/ios/archive/Runner.xcarchive in Xcode"
  echo "  2. Organizer → Distribute App → App Store Connect"
}

TARGET="${1:-all}"

case "$TARGET" in
  android)
    build_android
    ;;
  ios)
    build_ios
    ;;
  all)
    build_android
    build_ios
    ;;
  *)
    echo "Usage: bash build_release.sh [android|ios|all]"
    exit 1
    ;;
esac

echo ""
echo "========================================="
echo "  Build complete!"
echo "========================================="
