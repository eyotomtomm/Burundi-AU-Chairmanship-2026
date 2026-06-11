import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_messaging_service.dart';
import '../services/like_service.dart';

/// Authentication provider using Firebase Auth + Django backend
///
/// This provider uses a hybrid approach:
/// - Firebase Auth handles authentication (login, signup, password reset)
/// - Django backend stores rich user profile data
/// - Firebase ID tokens are used for API authentication
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();
  final ApiService _api = ApiService();
  // Secure storage for sensitive data (JWT tokens) — encrypted via Android Keystore / iOS Keychain
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// Completer that resolves once initial auth state has been fully determined.
  /// The splash screen awaits this before deciding where to navigate.
  final Completer<void> _initCompleter = Completer<void>();

  /// A future that completes when auth initialization is done.
  /// Await this in the splash screen to avoid race conditions.
  Future<void> get initialized => _initCompleter.future;

  bool _isAuthenticated = false;
  int? _userId;
  String? _userName;
  String? _userEmail;
  String? _phoneNumber;
  String? _gender;
  String? _nationality;
  String? _dateOfBirth;
  bool _isEmailVerified = false;
  bool _isGovernmentOfficial = false;
  bool _isVerified = false;
  String? _badgeType; // 'GOLD' or 'BLUE'
  String? _profilePictureUrl;
  String? _verificationTitle; // e.g. "H.E. (His/Her Excellency)"
  String? _verificationRole; // e.g. "Ambassador to the AU"
  String? _verificationName; // Real name from verification request
  bool _isLoading = false;
  String? _errorMessage;
  bool _requiresEmailVerification = false;
  bool _hasInitialized = false; // Guard against premature sign-out during startup
  bool _isSigningIn = false; // Guard against auth listener racing with active sign-in
  bool _receivesNewsletter = false;

  bool get isAuthenticated => _isAuthenticated;
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get phoneNumber => _phoneNumber;
  String? get gender => _gender;
  String? get nationality => _nationality;
  String? get dateOfBirth => _dateOfBirth;
  bool get isEmailVerified => _isEmailVerified;
  bool get isGovernmentOfficial => _isGovernmentOfficial;
  bool get isVerified => _isVerified;
  String? get badgeType => _badgeType;
  String? get profilePictureUrl => _profilePictureUrl;
  String? get verificationTitle => _verificationTitle;
  String? get verificationRole => _verificationRole;
  String? get verificationName => _verificationName;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get requiresEmailVerification => _requiresEmailVerification;
  bool get receivesNewsletter => _receivesNewsletter;

  /// Whether the current user has an email/password credential (not SSO-only).
  /// Returns true for email/password users who can change their password.
  /// Returns false for Google/Apple SSO-only users.
  bool get hasPasswordProvider {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  AuthProvider() {
    _checkAuthStatus();
    _listenToAuthChanges();
  }

  /// Listen to Firebase auth state changes
  ///
  /// Guards against premature sign-out: during app startup, Firebase may briefly
  /// report null before restoring the auth state. We skip ALL auth-change events
  /// until [_checkAuthStatus] has completed and [_hasInitialized] is true,
  /// because _checkAuthStatus already handles the initial state.
  void _listenToAuthChanges() {
    _firebaseAuth.authStateChanges.listen((User? firebaseUser) async {
      // Skip all events during initial boot — _checkAuthStatus handles startup
      if (!_hasInitialized) return;

      if (firebaseUser != null) {
        // Skip if a sign-in method is already handling the backend call.
        // Without this guard, both the listener and signInWithGoogle/Apple
        // hit firebase_login simultaneously for new users, causing a
        // database race condition (duplicate User.objects.create).
        if (_isSigningIn) return;

        // User signed in (or token refreshed) — sync with Django backend
        await _syncWithBackend();
      } else {
        // Double-check: if we have cached credentials, don't sign out yet
        if (_isAuthenticated) {
          // Wait briefly and recheck — Firebase might be recovering
          await Future.delayed(const Duration(seconds: 2));
          if (_firebaseAuth.currentUser != null) return;

          // Also check for legacy JWT tokens
          final token = await _secureStorage.read(key: AppConstants.userTokenKey);
          if (token != null && token.isNotEmpty) return;
        }

        // User genuinely signed out
        _isAuthenticated = false;
        await _clearUserData();
        notifyListeners();
      }
    });
  }

  /// Load cached user profile data locally so app does not block on startup
  Future<void> _loadLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    _userName = prefs.getString('user_name');
    _userEmail = prefs.getString('user_email');
    _phoneNumber = prefs.getString('user_phone');
    _gender = prefs.getString('user_gender');
    _nationality = prefs.getString('user_nationality');
    _dateOfBirth = prefs.getString('user_date_of_birth');
    _isEmailVerified = prefs.getBool('user_email_verified') ?? false;
    _isGovernmentOfficial = prefs.getBool('user_is_official') ?? false;
    _isVerified = prefs.getBool('user_is_verified') ?? false;
    _badgeType = prefs.getString('user_badge_type');
    _profilePictureUrl = prefs.getString('user_profile_picture');
    _verificationTitle = prefs.getString('user_verification_title');
    _verificationRole = prefs.getString('user_verification_role');
    _verificationName = prefs.getString('user_verification_name');
    _receivesNewsletter = prefs.getBool('user_receives_newsletter') ?? false;
  }

  /// Check if user is already authenticated.
  ///
  /// This method determines auth state from Firebase Auth and/or stored JWT
  /// tokens, loads cached profile data, and then syncs with the backend.
  /// It completes [_initCompleter] when finished so the splash screen
  /// can reliably await initialization.
  Future<void> _checkAuthStatus() async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        // User is signed in with Firebase — load cached profile immediately
        _isAuthenticated = true;
        await _loadLocalUserData();

        // Don't set _requiresEmailVerification from cache here — the
        // backend sync below will set the authoritative value.  Using
        // stale cache caused users who verified their email to be
        // re-prompted after signing back in.

        notifyListeners();

        // Sync with backend and wait for it so user data (userId, email) is populated.
        // Use a timeout so slow networks don't block startup forever.
        try {
          await _syncWithBackend().timeout(const Duration(seconds: 8));
        } catch (e) {
          // Sync failed or timed out — user stays authenticated with cached data.
          // If we have cached userId, that's enough for the app to function.
          if (kDebugMode) print('Auth init: backend sync failed/timed out: $e');
        }
      } else {
        // No Firebase user — check for legacy JWT auth (backward compatibility)
        // Tokens stored in encrypted secure storage (Android Keystore / iOS Keychain)
        final token = await _secureStorage.read(key: AppConstants.userTokenKey);
        if (token != null && token.isNotEmpty) {
          _isAuthenticated = true;
          await _loadLocalUserData();
        } else {
          // Migration: check if token exists in old SharedPreferences and migrate
          final prefs = await SharedPreferences.getInstance();
          final legacyToken = prefs.getString(AppConstants.userTokenKey);
          if (legacyToken != null && legacyToken.isNotEmpty) {
            // Migrate token to secure storage
            await _secureStorage.write(key: AppConstants.userTokenKey, value: legacyToken);
            final legacyRefresh = prefs.getString('refresh_token');
            if (legacyRefresh != null) {
              await _secureStorage.write(key: 'refresh_token', value: legacyRefresh);
            }
            // Remove from insecure storage
            await prefs.remove(AppConstants.userTokenKey);
            await prefs.remove('refresh_token');
            _isAuthenticated = true;
            await _loadLocalUserData();
          }
        }
      }
    } catch (e) {
      // If anything fails during init, don't crash — just treat as unauthenticated
      if (kDebugMode) print('Auth init error: $e');
    }

    _hasInitialized = true;
    notifyListeners();

    // Signal that initialization is complete so splash screen can proceed
    if (!_initCompleter.isCompleted) {
      _initCompleter.complete();
    }
  }

  /// Get device name for session tracking
  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.name;
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }

  /// Sync Firebase user with Django backend
  Future<void> _syncWithBackend() async {
    try {
      final idToken = await _firebaseAuth.getIdToken();
      if (idToken == null) return;

      final deviceName = await _getDeviceName();
      final data = await _api.firebaseLogin(
        idToken: idToken,
        deviceName: deviceName,
        deviceType: Platform.operatingSystem,
        appVersion: AppConstants.appVersion,
      );
      await _storeUserData(data['user']);

      // Capture email verification requirement
      _requiresEmailVerification = data['requires_email_verification'] == true;

      _isAuthenticated = true;
      notifyListeners();
    } on ApiException catch (e) {
      if (kDebugMode) print('Backend sync rejected: ${e.statusCode} ${e.message}');
      // If backend explicitly rejects (401/403 = account deactivated/deleted),
      // sign out completely so the user isn't stuck as "authenticated"
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _firebaseAuth.signOut();
        await _clearUserData();
        _isAuthenticated = false;
        notifyListeners();
      } else {
        // Other errors (500, timeout) — keep cached data, stay authenticated
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Failed to sync with backend: $e');
      // Network error — keep cached data, stay authenticated
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  /// Sign up a new user with Firebase Auth + Django backend
  ///
  /// [honeypot] is an anti-bot field. If filled (by a bot), the backend
  /// silently rejects the registration. Real users never see this field.
  Future<bool> signUp(String name, String email, String password,
      {String? phoneNumber, String? gender, String? honeypot}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Create Firebase user
      final credential = await _firebaseAuth.signUpWithEmail(email, password);

      // 2. Send email verification
      await _firebaseAuth.sendEmailVerification();

      // 3. Get Firebase ID token
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get Firebase ID token');
      }

      // 4. Register with Django backend (idempotent — safe to retry)
      final data = await _api.firebaseRegister(
        idToken: idToken,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        gender: gender,
        honeypot: honeypot ?? '',
      );

      // 5. Store user data locally
      await _storeUserData(data['user']);

      // Capture email verification requirement
      _requiresEmailVerification = data['requires_email_verification'] == true;

      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _firebaseAuth.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      // Firebase succeeded but backend rejected — sign out Firebase
      try { await _firebaseAuth.signOut(); } catch (_) {}
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      try { await _firebaseAuth.signOut(); } catch (_) {}
      _errorMessage = 'Registration failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in an existing user with Firebase Auth
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Sign in with Firebase
      final credential = await _firebaseAuth.signInWithEmail(email, password);

      // 2. Get Firebase ID token
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get Firebase ID token');
      }

      // 3. Login with Django backend (include device info for session tracking)
      final deviceName = await _getDeviceName();
      final data = await _api.firebaseLogin(
        idToken: idToken,
        deviceName: deviceName,
        deviceType: Platform.operatingSystem,
        appVersion: AppConstants.appVersion,
      );

      // 4. Store user data locally
      await _storeUserData(data['user']);

      // Sign-in never requires email verification — that's only for sign-up.
      // A user who can sign in already has an account.
      _requiresEmailVerification = false;

      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _firebaseAuth.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      // Firebase succeeded but backend rejected — sign out Firebase
      try { await _firebaseAuth.signOut(); } catch (_) {}
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      try { await _firebaseAuth.signOut(); } catch (_) {}
      _errorMessage = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _isSigningIn = true; // Prevent auth listener from racing with this method
    notifyListeners();

    try {
      // 1. Sign in with Firebase via Google
      final credential = await _firebaseAuth.signInWithGoogle();

      // 2. Get Firebase ID token
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get Firebase ID token');
      }

      // 3. Login or register with backend (backend auto-creates if new)
      //    If login returns 404, auto-register the user
      final data = await _firebaseLoginOrRegister(
        idToken: idToken,
        name: credential.user?.displayName ?? '',
        email: credential.user?.email ?? '',
      );
      await _storeUserData(data['user']);

      // Google sign-in: backend trusts Firebase email_verified flag
      _requiresEmailVerification = data['requires_email_verification'] == true;

      _isAuthenticated = true;
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _firebaseAuth.getErrorMessage(e);
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      // Firebase succeeded but backend rejected — sign out Firebase
      // so the user doesn't get stuck in a half-authenticated state
      try { await _firebaseAuth.signOut(); } catch (_) {}
      _errorMessage = e.message;
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Sign out Firebase if it succeeded but something else failed
      try { await _firebaseAuth.signOut(); } catch (_) {}
      _errorMessage = 'Google Sign-In failed: $e';
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    _isSigningIn = true; // Prevent auth listener from racing with this method
    notifyListeners();

    try {
      // 1. Sign in with Firebase via Apple
      final credential = await _firebaseAuth.signInWithApple();

      // 2. Get Firebase ID token
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get Firebase ID token');
      }

      // 3. Login or register with backend (backend auto-creates if new)
      //    If login returns 404, auto-register the user
      final data = await _firebaseLoginOrRegister(
        idToken: idToken,
        name: credential.user?.displayName ?? '',
        email: credential.user?.email ?? '',
      );
      await _storeUserData(data['user']);

      // Apple sign-in: backend trusts Firebase email_verified flag
      _requiresEmailVerification = data['requires_email_verification'] == true;

      _isAuthenticated = true;
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _firebaseAuth.getErrorMessage(e);
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      try { await _firebaseAuth.signOut(); } catch (_) {}
      _errorMessage = e.message;
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();
      return false;
    } catch (e) {
      try { await _firebaseAuth.signOut(); } catch (_) {}
      _errorMessage = 'Apple Sign-In failed: $e';
      _isLoading = false;
      _isSigningIn = false;
      notifyListeners();
      return false;
    }
  }

  /// Try firebase login first; if user doesn't exist (404), auto-register
  Future<Map<String, dynamic>> _firebaseLoginOrRegister({
    required String idToken,
    required String name,
    required String email,
  }) async {
    try {
      final deviceName = await _getDeviceName();
      return await _api.firebaseLogin(
        idToken: idToken,
        deviceName: deviceName,
        deviceType: Platform.operatingSystem,
        appVersion: AppConstants.appVersion,
      );
    } on ApiException catch (e) {
      // If user not found on backend, auto-create their account
      if (e.statusCode == 404 || e.statusCode == 401) {
        return await _api.firebaseRegister(
          idToken: idToken,
          name: name.isNotEmpty ? name : email.split('@').first,
          email: email,
        );
      }
      rethrow;
    }
  }

  /// Send sign-up email verification OTP
  Future<bool> sendSignupEmailOtp() async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('auth/send-signup-otp/', {}, auth: true);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send verification code. Try again.';
      notifyListeners();
      return false;
    }
  }

  /// Verify sign-up email OTP
  Future<bool> verifySignupEmailOtp(String code) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.post('auth/verify-signup-otp/', {'otp_code': code}, auth: true);
      if (data['email_verified'] == true) {
        _isEmailVerified = true;
        _requiresEmailVerification = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('user_email_verified', true);
        notifyListeners();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Verification failed. Try again.';
      notifyListeners();
      return false;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    // Deactivate FCM token on backend before signing out
    // (don't delete - allows reactivation on next login)
    try {
      final messaging = FirebaseMessagingService();
      await messaging.deactivateToken();
    } catch (e) {
      if (kDebugMode) print('Failed to deactivate FCM token on logout: $e');
    }

    await _firebaseAuth.signOut();
    LikeService().clearAll();
    await _clearUserData();
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseAuth.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _firebaseAuth.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send reset email. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send email verification to current user
  Future<bool> sendEmailVerification() async {
    try {
      await _firebaseAuth.sendEmailVerification();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send verification email. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Reload user to get updated email verification status
  Future<void> reloadUser() async {
    try {
      await _firebaseAuth.reloadUser();
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        _isEmailVerified = firebaseUser.emailVerified;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Failed to reload user: $e');
    }
  }

  /// Update user profile
  Future<bool> updateProfile(String name, {String? gender, String? nationality, String? dateOfBirth, String? phoneNumber}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{'name': name};
      if (gender != null) payload['gender'] = gender;
      if (nationality != null) payload['nationality'] = nationality;
      if (dateOfBirth != null) payload['date_of_birth'] = dateOfBirth;
      if (phoneNumber != null) payload['phone_number'] = phoneNumber;

      final data = await _api.updateProfile(payload);
      await _storeUserData(data);

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update profile. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh user profile from backend (e.g., after verification status changes)
  Future<bool> refreshProfile() async {
    try {
      // Fetch latest profile data from backend
      final data = await _api.getProfile();
      await _storeUserData(data);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('Failed to refresh profile: $e');
      return false;
    }
  }

  /// Upload profile picture
  Future<bool> uploadProfilePicture(File imageFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.uploadProfilePicture(imageFile);
      await _storeUserData(data);

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to upload profile picture. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Deactivate account ("Take a Break")
  Future<bool> deactivateAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.deactivateAccount();

      // Deactivate FCM token so push notifications stop
      try {
        final messaging = FirebaseMessagingService();
        await messaging.deactivateToken();
      } catch (_) {}

      // Sign out from Firebase so the session doesn't persist on restart
      await _firebaseAuth.signOut();

      await _clearUserData();

      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to deactivate account. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete user account (soft-delete via Django, 30-day window)
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Schedule deletion on Django backend (30-day soft delete)
      await _api.deleteAccount();

      // Deactivate FCM token so push notifications stop
      try {
        final messaging = FirebaseMessagingService();
        await messaging.deactivateToken();
      } catch (_) {}

      // Sign out from Firebase (don't delete Firebase account yet —
      // it gets cleaned up after 30 days when Django purges)
      await _firebaseAuth.signOut();

      // Clear local data
      await _clearUserData();

      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete account. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Store user data in SharedPreferences
  Future<void> _storeUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();

    final uid = user['id'] as int?;
    final name = user['name'] ?? '';
    final email = user['email'] ?? '';
    final phone = user['phone_number'] ?? '';
    final gender = user['gender'] ?? '';
    final nationality = user['nationality'] ?? '';
    final dateOfBirth = user['date_of_birth'] as String? ?? '';
    final emailVerified = user['is_email_verified'] ?? false;
    final isOfficial = user['is_government_official'] ?? false;
    final isVerified = user['is_verified'] ?? false;
    final badgeType = user['badge_type'] as String?;
    final verificationTitle = user['verification_title'] as String?;
    final verificationRole = user['verification_role'] as String?;
    final verificationName = user['verification_name'] as String?;
    // receives_newsletter may be top-level or nested in profile
    var receivesNewsletter = user['receives_newsletter'];
    if (receivesNewsletter == null && user['profile'] is Map) {
      receivesNewsletter = user['profile']['receives_newsletter'];
    }
    receivesNewsletter = receivesNewsletter ?? false;

    // Profile picture: can be in top-level or nested in profile
    String? profilePic = user['profile_picture'] as String?;
    if (profilePic == null && user['profile'] is Map) {
      profilePic = user['profile']['profile_picture'] as String?;
    }

    if (uid != null) await prefs.setInt('user_id', uid);
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_gender', gender);
    await prefs.setString('user_nationality', nationality);
    await prefs.setString('user_date_of_birth', dateOfBirth);
    await prefs.setBool('user_email_verified', emailVerified);
    await prefs.setBool('user_is_official', isOfficial);
    await prefs.setBool('user_is_verified', isVerified);
    if (badgeType != null) {
      await prefs.setString('user_badge_type', badgeType);
    } else {
      await prefs.remove('user_badge_type');
    }
    if (profilePic != null && profilePic.isNotEmpty) {
      await prefs.setString('user_profile_picture', profilePic);
    } else {
      await prefs.remove('user_profile_picture');
    }
    if (verificationTitle != null) {
      await prefs.setString('user_verification_title', verificationTitle);
    } else {
      await prefs.remove('user_verification_title');
    }
    if (verificationRole != null) {
      await prefs.setString('user_verification_role', verificationRole);
    } else {
      await prefs.remove('user_verification_role');
    }
    if (verificationName != null) {
      await prefs.setString('user_verification_name', verificationName);
    } else {
      await prefs.remove('user_verification_name');
    }

    _userId = uid;
    _userName = name;
    _userEmail = email;
    _phoneNumber = phone;
    _gender = gender;
    _nationality = nationality;
    _dateOfBirth = dateOfBirth;
    _isEmailVerified = emailVerified;
    _isGovernmentOfficial = isOfficial;
    _isVerified = isVerified;
    _badgeType = badgeType;
    _profilePictureUrl = profilePic;
    _verificationTitle = verificationTitle;
    _verificationRole = verificationRole;
    _verificationName = verificationName;
    _receivesNewsletter = receivesNewsletter;
    await prefs.setBool('user_receives_newsletter', receivesNewsletter);

    // Link the FCM token to the authenticated user
    try {
      final messaging = FirebaseMessagingService();
      await messaging.linkTokenToUser();
    } catch (e) {
      if (kDebugMode) print('Failed to link FCM token to user: $e');
    }
  }

  /// Toggle newsletter subscription
  Future<bool> toggleNewsletter(bool receives) async {
    try {
      await _api.toggleNewsletter(receives);
      _receivesNewsletter = receives;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_receives_newsletter', receives);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('Failed to toggle newsletter: $e');
      return false;
    }
  }

  /// Clear user data from SharedPreferences and secure storage
  Future<void> _clearUserData() async {
    // Clear tokens from secure storage
    await _secureStorage.delete(key: AppConstants.userTokenKey);
    await _secureStorage.delete(key: 'refresh_token');
    // Clear profile data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userTokenKey); // Remove legacy if exists
    await prefs.remove('refresh_token'); // Remove legacy if exists
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    await prefs.remove('user_gender');
    await prefs.remove('user_nationality');
    await prefs.remove('user_date_of_birth');
    await prefs.remove('user_email_verified');
    await prefs.remove('user_is_official');
    await prefs.remove('user_is_verified');
    await prefs.remove('user_badge_type');
    await prefs.remove('user_profile_picture');
    await prefs.remove('user_verification_title');
    await prefs.remove('user_verification_role');
    await prefs.remove('user_verification_name');
    await prefs.remove('user_receives_newsletter');
    // Clear verification cache to prevent data leaking between accounts
    await prefs.remove('cached_is_verified');
    await prefs.remove('cached_verification_status');
    await prefs.remove('cached_badge_type');
    await prefs.remove('cached_verification_request_id');

    _userId = null;
    _userName = null;
    _userEmail = null;
    _phoneNumber = null;
    _gender = null;
    _nationality = null;
    _dateOfBirth = null;
    _isEmailVerified = false;
    _isGovernmentOfficial = false;
    _isVerified = false;
    _badgeType = null;
    _profilePictureUrl = null;
    _verificationTitle = null;
    _verificationRole = null;
    _verificationName = null;
    _receivesNewsletter = false;
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Skip authentication (continue as guest)
  Future<void> skipAuth() async {
    _isAuthenticated = false;
    notifyListeners();
  }
}
