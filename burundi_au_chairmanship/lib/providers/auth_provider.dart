import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';
import '../services/firebase_auth_service.dart';

/// Authentication provider using Firebase Auth + Django backend
///
/// This provider uses a hybrid approach:
/// - Firebase Auth handles authentication (login, signup, password reset)
/// - Django backend stores rich user profile data
/// - Firebase ID tokens are used for API authentication
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();
  final ApiService _api = ApiService();

  bool _isAuthenticated = false;
  int? _userId;
  String? _userName;
  String? _userEmail;
  String? _phoneNumber;
  String? _gender;
  bool _isEmailVerified = false;
  bool _isGovernmentOfficial = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get phoneNumber => _phoneNumber;
  String? get gender => _gender;
  bool get isEmailVerified => _isEmailVerified;
  bool get isGovernmentOfficial => _isGovernmentOfficial;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkAuthStatus();
    _listenToAuthChanges();
  }

  /// Listen to Firebase auth state changes
  void _listenToAuthChanges() {
    _firebaseAuth.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        // User signed in - sync with Django backend
        await _syncWithBackend();
      } else {
        // User signed out
        _isAuthenticated = false;
        await _clearUserData();
        notifyListeners();
      }
    });
  }

  /// Check if user is already authenticated
  Future<void> _checkAuthStatus() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      // User is signed in with Firebase - sync with backend
      await _syncWithBackend();
    } else {
      // Check for legacy JWT auth (for backward compatibility)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.userTokenKey);
      if (token != null && token.isNotEmpty) {
        _isAuthenticated = true;
        _userId = prefs.getInt('user_id');
        _userName = prefs.getString('user_name');
        _userEmail = prefs.getString('user_email');
        _phoneNumber = prefs.getString('user_phone');
        _gender = prefs.getString('user_gender');
        _isEmailVerified = prefs.getBool('user_email_verified') ?? false;
        _isGovernmentOfficial = prefs.getBool('user_is_official') ?? false;
      }
    }
    notifyListeners();
  }

  /// Sync Firebase user with Django backend
  Future<void> _syncWithBackend() async {
    try {
      final idToken = await _firebaseAuth.getIdToken();
      if (idToken == null) return;

      final data = await _api.firebaseLogin(idToken: idToken);
      await _storeUserData(data['user']);

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      print('Failed to sync with backend: $e');
      // If sync fails, user is still authenticated with Firebase
      // but profile data may be incomplete
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  /// Sign up a new user with Firebase Auth + Django backend
  Future<bool> signUp(String name, String email, String password,
      {String? phoneNumber, String? gender}) async {
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

      // 4. Register with Django backend
      final data = await _api.firebaseRegister(
        idToken: idToken,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        gender: gender,
      );

      // 5. Store user data locally
      await _storeUserData(data['user']);

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
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
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

      // 3. Login with Django backend
      final data = await _api.firebaseLogin(idToken: idToken);

      // 4. Store user data locally
      await _storeUserData(data['user']);

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
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
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
    notifyListeners();

    try {
      // 1. Sign in with Firebase via Google
      final credential = await _firebaseAuth.signInWithGoogle();

      // 2. Get Firebase ID token
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get Firebase ID token');
      }

      // 3. Check if user exists in backend
      bool isNewUser = credential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // Register new user with backend
        final name = credential.user?.displayName ?? '';
        final email = credential.user?.email ?? '';

        final data = await _api.firebaseRegister(
          idToken: idToken,
          name: name,
          email: email,
        );

        await _storeUserData(data['user']);
      } else {
        // Login existing user
        final data = await _api.firebaseLogin(idToken: idToken);
        await _storeUserData(data['user']);
      }

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
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Sign in with Firebase via Apple
      final credential = await _firebaseAuth.signInWithApple();

      // 2. Get Firebase ID token
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get Firebase ID token');
      }

      // 3. Check if user exists in backend
      bool isNewUser = credential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // Register new user with backend
        final name = credential.user?.displayName ?? 'Apple User';
        final email = credential.user?.email ?? '';

        final data = await _api.firebaseRegister(
          idToken: idToken,
          name: name,
          email: email,
        );

        await _storeUserData(data['user']);
      } else {
        // Login existing user
        final data = await _api.firebaseLogin(idToken: idToken);
        await _storeUserData(data['user']);
      }

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
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Apple Sign-In failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
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
      _errorMessage = 'Failed to send reset email: $e';
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
      _errorMessage = 'Failed to send verification email: $e';
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
      print('Failed to reload user: $e');
    }
  }

  /// Update user profile
  Future<bool> updateProfile(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _api.updateProfile({'name': name});

      final updatedName = data['name'] ?? name;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', updatedName);

      _userName = updatedName;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete user account (Firebase + Django)
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Delete from Django backend
      await _api.deleteAccount();

      // 2. Delete Firebase account
      await _firebaseAuth.deleteAccount();

      // 3. Clear local data
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
    } on FirebaseAuthException catch (e) {
      _errorMessage = _firebaseAuth.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete account: $e';
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
    final emailVerified = user['is_email_verified'] ?? false;
    final isOfficial = user['is_government_official'] ?? false;

    if (uid != null) await prefs.setInt('user_id', uid);
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_gender', gender);
    await prefs.setBool('user_email_verified', emailVerified);
    await prefs.setBool('user_is_official', isOfficial);

    _userId = uid;
    _userName = name;
    _userEmail = email;
    _phoneNumber = phone;
    _gender = gender;
    _isEmailVerified = emailVerified;
    _isGovernmentOfficial = isOfficial;
  }

  /// Clear user data from SharedPreferences
  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userTokenKey);
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_phone');
    await prefs.remove('user_gender');
    await prefs.remove('user_email_verified');
    await prefs.remove('user_is_official');

    _userId = null;
    _userName = null;
    _userEmail = null;
    _phoneNumber = null;
    _gender = null;
    _isEmailVerified = false;
    _isGovernmentOfficial = false;
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
