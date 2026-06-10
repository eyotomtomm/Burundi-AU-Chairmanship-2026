import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class VerificationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _verificationStatus;
  bool _isChecking = false;
  String? _lastCheckedStatusKey;

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

        // Track if we need to show popup using both request ID and status
        // so that when status changes (e.g., pending -> approved), we detect it
        final requestId = response['id']?.toString();
        final status = response['status']?.toString();
        final statusKey = '${requestId}_$status';

        if (statusKey != _lastCheckedStatusKey) {
          // Status changed - mark as needing popup
          if (requestId != null) {
            await _markStatusAsNew(requestId, status ?? '');
          }
        }
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

  /// Check if we should show popup for current status
  Future<bool> shouldShowStatusPopup() async {
    if (_verificationStatus == null) return false;

    final requestId = _verificationStatus!['id']?.toString();
    if (requestId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final status = requestStatus;

    // Show popup for approved or rejected status (one time only per status change)
    if (status == 'approved' || status == 'rejected') {
      final shownKey = 'verification_popup_shown_${requestId}_$status';
      final alreadyShown = prefs.getBool(shownKey) ?? false;
      return !alreadyShown;
    }

    return false;
  }

  /// Mark status popup as shown
  Future<void> markStatusPopupShown() async {
    if (_verificationStatus == null) return;

    final requestId = _verificationStatus!['id']?.toString();
    if (requestId == null) return;

    final status = requestStatus;
    final prefs = await SharedPreferences.getInstance();
    final shownKey = 'verification_popup_shown_${requestId}_$status';
    await prefs.setBool(shownKey, true);
    _lastCheckedStatusKey = '${requestId}_$status';
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

  /// Mark a new status change as requiring popup
  Future<void> _markStatusAsNew(String requestId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final shownKey = 'verification_popup_shown_${requestId}_$status';
    // Reset the shown flag for this new status
    await prefs.remove(shownKey);
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

  /// Clear verification data (e.g., on logout)
  void clear() {
    _verificationStatus = null;
    _isChecking = false;
    _lastCheckedStatusKey = null;
    notifyListeners();
  }
}
