import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/api_models.dart';
import '../models/magazine_model.dart';
import '../models/location_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _baseUrl = AppConstants.baseApiUrl;

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.userTokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> _get(String endpoint, {bool auth = false}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw ApiException('HTTP ${response.statusCode}', response.statusCode);
    } on http.ClientException {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<dynamic> _post(String endpoint, Map<String, dynamic> body, {bool auth = false}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: await _headers(auth: auth),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      // Extract error message
      String message = 'Request failed';
      if (data is Map) {
        if (data.containsKey('detail')) {
          message = data['detail'];
        } else {
          // Collect field errors
          final errors = <String>[];
          data.forEach((key, value) {
            if (value is List) {
              errors.addAll(value.map((e) => e.toString()));
            } else {
              errors.add(value.toString());
            }
          });
          if (errors.isNotEmpty) message = errors.join('\n');
        }
      }
      throw ApiException(message, response.statusCode);
    } on http.ClientException {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  /// Extract results from paginated or flat list responses
  List<dynamic> _extractResults(dynamic data) {
    if (data is List) return data;
    if (data is Map && data.containsKey('results')) {
      return data['results'] as List<dynamic>;
    }
    return [];
  }

  // ── Auth ────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _post('auth/login/', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    return await _post('auth/register/', {'name': name, 'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    return await _post('auth/refresh/', {'refresh': refreshToken});
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await _get('auth/profile/', auth: true);
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/auth/delete-account/'),
            headers: await _headers(auth: true),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw ApiException('Failed to delete account', response.statusCode);
    } on http.ClientException {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<Map<String, dynamic>> exportUserData() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/auth/export-data/'),
            headers: await _headers(auth: true),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw ApiException('Failed to export data', response.statusCode);
    } on http.ClientException {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  // ── Hero Slides ──────────────────────────────────────────
  Future<List<HeroSlide>> getHeroSlides() async {
    final data = await _get('hero-slides/');
    return _extractResults(data)
        .map((j) => HeroSlide.fromJson(j))
        .toList();
  }

  // ── Articles ─────────────────────────────────────────────
  Future<List<Article>> getArticles({bool? featured}) async {
    String endpoint = 'articles/';
    if (featured != null) endpoint += '?is_featured=$featured';
    final data = await _get(endpoint);
    return _extractResults(data)
        .map((j) => Article.fromJson(j))
        .toList();
  }

  // ── Magazines ────────────────────────────────────────────
  Future<List<MagazineEdition>> getMagazines() async {
    final data = await _get('magazines/');
    return _extractResults(data)
        .map((j) => MagazineEdition.fromJson(j))
        .toList();
  }

  // ── Embassies ────────────────────────────────────────────
  Future<List<EmbassyLocation>> getEmbassies() async {
    final data = await _get('embassies/');
    return _extractResults(data)
        .map((j) => EmbassyLocation.fromJson(j))
        .toList();
  }

  // ── Events ───────────────────────────────────────────────
  Future<List<EventLocation>> getEvents() async {
    final data = await _get('events/');
    return _extractResults(data)
        .map((j) => EventLocation.fromJson(j))
        .toList();
  }

  // ── Live Feeds ───────────────────────────────────────────
  Future<List<ApiLiveFeed>> getLiveFeeds({String? status}) async {
    String endpoint = 'live-feeds/';
    if (status != null) endpoint += '?status=$status';
    final data = await _get(endpoint);
    return _extractResults(data)
        .map((j) => ApiLiveFeed.fromJson(j))
        .toList();
  }

  // ── Resources ────────────────────────────────────────────
  Future<List<ApiResource>> getResources() async {
    final data = await _get('resources/');
    return _extractResults(data)
        .map((j) => ApiResource.fromJson(j))
        .toList();
  }

  // ── Emergency Contacts ───────────────────────────────────
  Future<List<ApiEmergencyContact>> getEmergencyContacts() async {
    final data = await _get('emergency-contacts/');
    return _extractResults(data)
        .map((j) => ApiEmergencyContact.fromJson(j))
        .toList();
  }

  // ── Settings ─────────────────────────────────────────────
  Future<AppSettingsModel?> getSettings() async {
    final data = await _get('settings/');
    if (data is Map<String, dynamic> && data.isNotEmpty) {
      return AppSettingsModel.fromJson(data);
    }
    return null;
  }

  // ── Home Feed (combined) ─────────────────────────────────
  Future<Map<String, dynamic>> getHomeFeed() async {
    final data = await _get('home-feed/');
    return data as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
