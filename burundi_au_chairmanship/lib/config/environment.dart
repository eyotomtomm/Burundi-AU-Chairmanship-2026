import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kReleaseMode;

/// Environment configuration for the app
///
/// Supports multiple environments: development, staging, production
/// Can be configured via --dart-define at build time.
/// Safety net: release builds default to production even without the flag.
class Environment {
  /// Current environment name
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: '',
  );

  /// API base URL configured via --dart-define
  static const String _configuredApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  /// Get current environment type
  /// If no ENVIRONMENT flag is set, release builds default to production
  /// and debug builds default to development.
  static EnvironmentType get current {
    final env = _environment.toLowerCase();
    if (env.isEmpty) {
      return kReleaseMode ? EnvironmentType.production : EnvironmentType.development;
    }
    switch (env) {
      case 'production':
      case 'prod':
        return EnvironmentType.production;
      case 'staging':
      case 'stage':
        return EnvironmentType.staging;
      case 'development':
      case 'dev':
      default:
        return EnvironmentType.development;
    }
  }

  /// Get API base URL based on environment
  static String get apiBaseUrl {
    // If URL is explicitly configured via --dart-define, use it
    if (_configuredApiUrl.isNotEmpty) {
      // Security: enforce HTTPS in production even for custom URLs
      if (isProduction && _configuredApiUrl.startsWith('http://')) {
        assert(false, 'SECURITY: Production API URL must use HTTPS');
        return _configuredApiUrl.replaceFirst('http://', 'https://');
      }
      return _configuredApiUrl;
    }

    // Otherwise use environment-specific defaults
    switch (current) {
      case EnvironmentType.production:
        return 'https://burundi4africa.com/api';
      case EnvironmentType.staging:
        return 'https://staging-api.burundi4africa.com/api';
      case EnvironmentType.development:
        // Android emulator uses 10.0.2.2 to reach the host machine;
        // iOS simulator shares the host network so localhost works.
        final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
        return 'http://$host:8000/api';
    }
  }

  /// Get base URL for media files (images, PDFs, etc.)
  static String get mediaBaseUrl {
    // Media URLs need to use the same base as API but without /api suffix
    final apiUrl = apiBaseUrl;
    if (apiUrl.endsWith('/api')) {
      return apiUrl.substring(0, apiUrl.length - 4);
    }
    return apiUrl;
  }

  /// Get WebSocket base URL derived from the API base URL.
  /// Result: `wss://burundi4africa.com` (prod) or `ws://localhost:8000` (dev).
  static String get wsBaseUrl {
    final api = apiBaseUrl;
    final base = api.endsWith('/api') ? api.substring(0, api.length - 4) : api;
    return base
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  /// Base URL for legal/public web pages (privacy policy, terms of service)
  static String get siteBaseUrl {
    switch (current) {
      case EnvironmentType.production:
        return 'https://burundi4africa.com';
      case EnvironmentType.staging:
        return 'https://staging-api.burundi4africa.com';
      case EnvironmentType.development:
        return mediaBaseUrl;
    }
  }

  /// Check if we're in production
  static bool get isProduction => current == EnvironmentType.production;

  /// Check if we're in staging
  static bool get isStaging => current == EnvironmentType.staging;

  /// Check if we're in development
  static bool get isDevelopment => current == EnvironmentType.development;

  /// Check if debug features should be enabled
  static bool get enableDebugFeatures => !isProduction;

  /// Check if analytics should be enabled
  static bool get enableAnalytics => isProduction || isStaging;

  /// Check if verbose logging should be enabled
  static bool get enableVerboseLogging => isDevelopment;

  /// Sentry DSN configured via --dart-define
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Sentry traces sample rate (0.0 to 1.0)
  static double get sentryTracesSampleRate {
    switch (current) {
      case EnvironmentType.production:
        return 0.2;
      case EnvironmentType.staging:
        return 0.5;
      case EnvironmentType.development:
        return 1.0;
    }
  }

  /// Sentry profiles sample rate (0.0 to 1.0)
  static double get sentryProfilesSampleRate {
    switch (current) {
      case EnvironmentType.production:
        return 0.1;
      case EnvironmentType.staging:
        return 0.3;
      case EnvironmentType.development:
        return 1.0;
    }
  }

  /// Get environment display name
  static String get displayName {
    switch (current) {
      case EnvironmentType.production:
        return 'Production';
      case EnvironmentType.staging:
        return 'Staging';
      case EnvironmentType.development:
        return 'Development';
    }
  }

  /// Fix media URL to use correct host for current environment
  ///
  /// This handles the case where backend returns localhost URLs
  /// but we need to access them from the app
  static String fixMediaUrl(String url) {
    if (url.isEmpty) return url;

    // Handle relative URLs (e.g. /media/videos/foo.mp4)
    if (url.startsWith('/') && !url.startsWith('//')) {
      return '$mediaBaseUrl$url';
    }

    // In development, rewrite host to match the platform
    if (isDevelopment) {
      final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      return url
          .replaceAll('127.0.0.1:8000', '$host:8000')
          .replaceAll('localhost:8000', '$host:8000');
    }

    // In production/staging, ensure HTTPS is used
    if (isProduction || isStaging) {
      // Replace any localhost/127.0.0.1 URLs with production domain
      if (url.contains('localhost') || url.contains('127.0.0.1')) {
        // Extract the path from the URL
        final uri = Uri.parse(url);
        final path = uri.path;
        return '$mediaBaseUrl$path';
      }

      // Ensure HTTPS
      if (url.startsWith('http://') && !url.contains('localhost')) {
        return url.replaceFirst('http://', 'https://');
      }
    }

    return url;
  }
}

/// Environment types
enum EnvironmentType {
  development,
  staging,
  production,
}
