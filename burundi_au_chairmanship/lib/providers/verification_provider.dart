import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class VerificationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _verificationStatus;
  bool _isChecking = false;
  String? _lastCheckedRequestId;

  Map<String, dynamic>? get verificationStatus => _verificationStatus;
  bool get isChecking => _isChecking;
  bool get hasActiveRequest => _verificationStatus != null;

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
      if (response['has_request'] == true) {
        _verificationStatus = response;

        // Track if we need to show popup
        final requestId = response['id']?.toString();
        if (requestId != null && requestId != _lastCheckedRequestId) {
          // New status - we should show popup
          await _markStatusAsNew(requestId);
        }
      } else {
        _verificationStatus = null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking verification status: $e');
      // Don't clear existing status on error
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
    final shownKey = 'verification_popup_shown_$requestId';
    final status = requestStatus;

    // Show popup for approved or rejected status (one time only)
    if (status == 'approved' || status == 'rejected') {
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

    final prefs = await SharedPreferences.getInstance();
    final shownKey = 'verification_popup_shown_$requestId';
    await prefs.setBool(shownKey, true);
    _lastCheckedRequestId = requestId;
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

  /// Mark a new status as requiring popup
  Future<void> _markStatusAsNew(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final shownKey = 'verification_popup_shown_$requestId';
    // Reset the shown flag for this new request
    await prefs.remove(shownKey);
  }

  /// Clear verification data (e.g., on logout)
  void clear() {
    _verificationStatus = null;
    _isChecking = false;
    _lastCheckedRequestId = null;
    notifyListeners();
  }
}
