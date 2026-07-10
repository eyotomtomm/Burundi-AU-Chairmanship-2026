import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class VerificationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _verificationStatus;
  bool _isChecking = false;

  Map<String, dynamic>? get verificationStatus => _verificationStatus;
  bool get isChecking => _isChecking;
  bool get hasActiveRequest => _verificationStatus != null;

  /// Whether the user's profile is verified (independent of request status)
  bool get isProfileVerified => _verificationStatus?['is_verified'] == true;

  String? get requestStatus => _verificationStatus?['status'];
  String? get badgeType => _verificationStatus?['badge_type'];
  String? get rejectionReason => _verificationStatus?['rejection_reason'];
  bool get canAppeal => requestStatus == 'rejected' &&
                        (_verificationStatus?['appealed_at'] == null);

  /// Check verification status from backend
  Future<void> checkVerificationStatus({bool silent = false}) async {
    if (_isChecking) return;

    _isChecking = true;
    if (!silent) notifyListeners();

    try {
      final response = await _api.getVerificationStatus();

      // Only update if we got a valid response
      if (response['has_verification_request'] == true) {
        _verificationStatus = response;
      } else if (response['is_verified'] == true) {
        // Admin verified user directly from backend without a verification request.
        // Store the response so isProfileVerified returns true.
        _verificationStatus = response;
      } else {
        _verificationStatus = null;
      }

      // Persist verification state locally for quick access
      await _cacheVerificationState();
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking verification status: $e');
      // On error, load cached state if we don't have anything
      if (_verificationStatus == null) {
        await _loadCachedVerificationState();
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Build the SharedPreferences key for tracking popup shown state.
  /// Uses requestId + status when available, falls back to 'admin_verified'
  /// for users verified directly by admin without a verification request.
  String? _popupShownKey() {
    if (_verificationStatus == null) return null;

    final requestId = _verificationStatus!['id']?.toString();
    final status = requestStatus;

    if (requestId != null && status != null) {
      return 'verification_popup_shown_${requestId}_$status';
    }

    // Admin-verified without a request — use a stable key per user
    if (_verificationStatus!['is_verified'] == true) {
      return 'verification_popup_shown_admin_verified';
    }

    return null;
  }

  /// Check if we should show popup for current status
  Future<bool> shouldShowStatusPopup() async {
    if (_verificationStatus == null) return false;

    final status = requestStatus;
    final isAdminVerified = _verificationStatus!['is_verified'] == true && status == null;

    // Show popup for approved, rejected, or admin-verified (once per status)
    if (status == 'approved' || status == 'rejected' || isAdminVerified) {
      final key = _popupShownKey();
      if (key == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(key) ?? false;
      return !alreadyShown;
    }

    return false;
  }

  /// Mark status popup as shown — persisted permanently so it never shows again
  Future<void> markStatusPopupShown() async {
    final key = _popupShownKey();
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  /// Submit appeal for rejected request
  Future<bool> submitAppeal(String appealMessage) async {
    if (!canAppeal) return false;

    try {
      await _api.submitVerificationAppeal(appealMessage);

      // Refresh status after appeal
      await checkVerificationStatus(silent: true);

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error submitting appeal: $e');
      return false;
    }
  }

  /// Cache verification state locally so we don't re-prompt on every launch
  Future<void> _cacheVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_verificationStatus != null) {
      await prefs.setBool('cached_is_verified', _verificationStatus!['is_verified'] == true);
      await prefs.setString('cached_verification_status', _verificationStatus!['status']?.toString() ?? '');
      await prefs.setString('cached_badge_type', _verificationStatus!['badge_type']?.toString() ?? '');
      final requestId = _verificationStatus!['id']?.toString();
      if (requestId != null) {
        await prefs.setString('cached_verification_request_id', requestId);
      }
    } else {
      await prefs.remove('cached_is_verified');
      await prefs.remove('cached_verification_status');
      await prefs.remove('cached_badge_type');
      await prefs.remove('cached_verification_request_id');
    }
  }

  /// Load cached verification state (used on startup or when API fails)
  Future<void> _loadCachedVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStatus = prefs.getString('cached_verification_status');
    if (cachedStatus != null && cachedStatus.isNotEmpty) {
      _verificationStatus = {
        'is_verified': prefs.getBool('cached_is_verified') ?? false,
        'status': cachedStatus,
        'badge_type': prefs.getString('cached_badge_type'),
        'id': prefs.getString('cached_verification_request_id'),
        'has_verification_request': true,
      };
    }
  }

  /// Clear verification data (e.g., on logout).
  /// Note: we do NOT clear the popup-shown SharedPreferences keys here
  /// so that the congratulations popup never re-appears after logout/login.
  void clear() {
    _verificationStatus = null;
    _isChecking = false;
    notifyListeners();
  }
}
