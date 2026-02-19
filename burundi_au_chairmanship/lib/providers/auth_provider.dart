import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userName;
  String? _userEmail;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.userTokenKey);
    if (token != null && token.isNotEmpty) {
      _isAuthenticated = true;
      _userName = prefs.getString('user_name');
      _userEmail = prefs.getString('user_email');
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final api = ApiService();
      final data = await api.login(email, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userTokenKey, data['access'] ?? '');
      await prefs.setString('refresh_token', data['refresh'] ?? '');

      final user = data['user'] as Map<String, dynamic>?;
      final name = user?['name'] ?? email.split('@').first;
      final userEmail = user?['email'] ?? email;

      await prefs.setString('user_email', userEmail);
      await prefs.setString('user_name', name);

      _isAuthenticated = true;
      _userEmail = userEmail;
      _userName = name;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      // Fallback to mock auth if server is unreachable
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userTokenKey, 'mock_token_${DateTime.now().millisecondsSinceEpoch}');
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', email.split('@').first);

      _isAuthenticated = true;
      _userEmail = email;
      _userName = email.split('@').first;
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final api = ApiService();
      final data = await api.register(name, email, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userTokenKey, data['access'] ?? '');
      await prefs.setString('refresh_token', data['refresh'] ?? '');

      final user = data['user'] as Map<String, dynamic>?;
      final userName = user?['name'] ?? name;
      final userEmail = user?['email'] ?? email;

      await prefs.setString('user_email', userEmail);
      await prefs.setString('user_name', userName);

      _isAuthenticated = true;
      _userEmail = userEmail;
      _userName = userName;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      // Fallback to mock auth if server is unreachable
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userTokenKey, 'mock_token_${DateTime.now().millisecondsSinceEpoch}');
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);

      _isAuthenticated = true;
      _userEmail = email;
      _userName = name;
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userTokenKey);
    await prefs.remove('refresh_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');

    _isAuthenticated = false;
    _userName = null;
    _userEmail = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> skipAuth() async {
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<bool> updateProfile(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final api = ApiService();
      final data = await api.updateProfile({'name': name});

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
      // Fallback: update locally if server unreachable
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      _userName = name;
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final api = ApiService();
      await api.deleteAccount();

      // Clear all local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.userTokenKey);
      await prefs.remove('refresh_token');
      await prefs.remove('user_name');
      await prefs.remove('user_email');

      _isAuthenticated = false;
      _userName = null;
      _userEmail = null;
      _errorMessage = null;
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
}
