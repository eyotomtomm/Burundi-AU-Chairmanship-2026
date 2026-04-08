import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../services/api_service.dart';

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
      _syncLanguageWithBackend(languageCode);
    }
  }

  Future<void> toggleLanguage() async {
    final newLang = _locale.languageCode == 'en' ? 'fr' : 'en';
    await setLanguage(newLang);
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
