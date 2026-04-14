import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';
import '../services/firebase_messaging_service.dart';
import 'auth_provider.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  bool get isEnglish => _locale.languageCode == 'en';
  bool get isFrench => _locale.languageCode == 'fr';

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(AppConstants.languageKey) ?? 'en';
    _locale = Locale(langCode);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != _locale.languageCode) {
      _locale = Locale(languageCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.languageKey, languageCode);
      notifyListeners();

      // Sync language preference with backend for push notification targeting
      await _syncLanguageWithBackend(languageCode);
      // Sync FCM topics so the topic broadcast path is also language-aware
      await FirebaseMessagingService().syncLanguageTopics(languageCode);
    }
  }

  Future<void> toggleLanguage() async {
    final newLang = _locale.languageCode == 'en' ? 'fr' : 'en';
    await setLanguage(newLang);
  }

  /// Idempotent startup re-sync: ensures the backend + FCM topics always
  /// match whatever language is persisted locally, even after cold starts,
  /// app updates, or OS upgrades. Safe to call multiple times.
  Future<void> ensureSynced(AuthProvider auth) async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(AppConstants.languageKey) ?? 'en';
    if (auth.isAuthenticated) {
      await _syncLanguageWithBackend(code);
    }
    await FirebaseMessagingService().syncLanguageTopics(code);
  }

  /// Sync language preference to backend so push notifications are language-targeted
  Future<void> _syncLanguageWithBackend(String languageCode) async {
    try {
      await ApiService().post('auth/update-language/', {
        'preferred_language': languageCode,
      }, auth: true);
    } catch (e) {
      if (kDebugMode) print('Failed to sync language preference: $e');
    }
  }
}
