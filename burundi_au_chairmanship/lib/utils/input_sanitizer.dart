/// Centralized input validation and sanitization utilities.
///
/// Provides defense-in-depth on the client side. The backend must still
/// perform its own validation — these checks prevent obviously malformed
/// or malicious data from ever leaving the device.
class InputSanitizer {
  InputSanitizer._();

  // ── Length limits ───────────────────────────────────────────────────

  static const int maxNameLength = 100;
  static const int maxEmailLength = 254; // RFC 5321
  static const int maxCommentLength = 2000;
  static const int maxSubjectLength = 200;
  static const int maxMessageLength = 5000;
  static const int minPasswordLength = 8;

  // ── Regex patterns ─────────────────────────────────────────────────

  static final RegExp _emailRegex =
      RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');

  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');

  static final RegExp _scriptRegex =
      RegExp(r'(javascript|on\w+)\s*[:=]', caseSensitive: false);

  static final RegExp _multiWhitespace = RegExp(r'\s{2,}');

  // ── Sanitization methods ───────────────────────────────────────────

  /// Strip HTML tags and script injection patterns from text.
  static String stripHtml(String input) {
    return input
        .replaceAll(_htmlTagRegex, '')
        .replaceAll(_scriptRegex, '');
  }

  /// Normalize whitespace: collapse runs of spaces and trim.
  static String normalizeWhitespace(String input) {
    return input.replaceAll(_multiWhitespace, ' ').trim();
  }

  /// General-purpose sanitization: strip HTML, normalize whitespace, enforce
  /// a maximum length.
  static String sanitize(String input, {int maxLength = 5000}) {
    var result = stripHtml(input);
    result = normalizeWhitespace(result);
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }
    return result;
  }

  /// Sanitize a display name.
  static String sanitizeName(String input) {
    return sanitize(input, maxLength: maxNameLength);
  }

  /// Sanitize a comment or reply body.
  static String sanitizeComment(String input) {
    return sanitize(input, maxLength: maxCommentLength);
  }

  /// Sanitize a support-ticket subject.
  static String sanitizeSubject(String input) {
    return sanitize(input, maxLength: maxSubjectLength);
  }

  /// Sanitize a support-ticket message body.
  static String sanitizeMessage(String input) {
    return sanitize(input, maxLength: maxMessageLength);
  }

  // ── Validation helpers (return error message or null) ──────────────

  /// Validate a full name field.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (trimmed.length > maxNameLength) {
      return 'Name must be under $maxNameLength characters';
    }
    // Only allow letters, spaces, hyphens, apostrophes, and periods
    if (!RegExp(r"^[\p{L}\s\-'.]+$", unicode: true).hasMatch(trimmed)) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  /// Validate an email address.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final trimmed = value.trim();
    if (trimmed.length > maxEmailLength) {
      return 'Email is too long';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validate a password (sign-up or change-password).
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minPasswordLength) {
      return 'At least $minPasswordLength characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Need an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Need a lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Need a number';
    }
    return null;
  }

  /// Validate a comment or reply.
  static String? validateComment(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Comment cannot be empty';
    }
    if (value.trim().length > maxCommentLength) {
      return 'Comment is too long (max $maxCommentLength characters)';
    }
    return null;
  }
}
