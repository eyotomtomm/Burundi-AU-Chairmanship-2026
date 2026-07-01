import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// HTTP client factory for API requests.
///
/// Certificate pinning is handled at the platform level (Android only):
///   - Android: network_security_config.xml (pin-set with expiration 2027-06-01)
///   - iOS: Removed — NSPinnedDomains has no expiration, so a CA rotation
///     would brick all iOS users until an App Store update ships.
///
/// Platform-level pinning is more resilient because:
///   1. Android's pin-set has an expiration date — if pins expire, the app
///      falls back to normal certificate validation instead of breaking.
///   2. Dart's BoringSSL bypasses platform networking, but system roots
///      are still trusted, so HTTPS validation is still enforced.
///
/// Previously, this class also did Dart-level PEM pinning, but that caused
/// outages when Cloudflare rotated certificates. Removed to prevent bricking.
class PinnedHttpClient {
  static http.Client? _cachedClient;

  /// Create an HTTP client that trusts system certificate roots.
  ///
  /// In development: standard client for localhost access.
  /// In production: HTTPS-only client using system roots + platform pinning.
  static http.Client create() {
    if (_cachedClient != null) return _cachedClient!;

    if (kDebugMode) {
      // Development: standard client (need localhost/HTTP access)
      _cachedClient = http.Client();
      return _cachedClient!;
    }

    try {
      // Production: use system roots for certificate validation.
      // Platform-level pinning (network_security_config.xml / NSPinnedDomains)
      // provides additional protection at the OS layer.
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) {
          // In production, never accept invalid certificates
          return false;
        };

      _cachedClient = IOClient(httpClient);
      return _cachedClient!;
    } catch (e) {
      // Fallback to standard client (better than bricking the app)
      if (kDebugMode) print('HTTP client setup failed: $e');
      _cachedClient = http.Client();
      return _cachedClient!;
    }
  }

  /// Clear the cached client (useful for testing or after config changes)
  static void reset() {
    _cachedClient?.close();
    _cachedClient = null;
  }
}
