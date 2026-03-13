import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import '../config/environment.dart';
import '../models/api_models.dart';
import '../models/magazine_model.dart';
import '../models/location_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Use environment-specific API URL
  static final String _baseUrl = Environment.apiBaseUrl;

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      // Try Firebase Auth first (new authentication method)
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final idToken = await firebaseUser.getIdToken(true);
        if (idToken != null) {
          headers['Authorization'] = 'Bearer $idToken';
          return headers;
        }
      }

      // Fallback to JWT token (for backward compatibility)
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

  /// Public GET method
  Future<dynamic> get(String endpoint, {bool auth = false}) =>
      _get(endpoint, auth: auth);

  /// Public POST for simple actions (e.g. record_view, toggle_like)
  Future<dynamic> post(String endpoint, Map<String, dynamic> body, {bool auth = false}) =>
      _post(endpoint, body, auth: auth);

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

  Future<dynamic> _delete(String endpoint, {bool auth = false}) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body);
      }
      throw ApiException('HTTP ${response.statusCode}', response.statusCode);
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

  // Legacy JWT auth endpoints (for backward compatibility)
  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _post('auth/login/', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    return await _post('auth/register/', {'name': name, 'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    return await _post('auth/refresh/', {'refresh': refreshToken});
  }

  // Firebase auth endpoints (new)
  Future<Map<String, dynamic>> firebaseRegister({
    required String idToken,
    required String name,
    required String email,
    String? phoneNumber,
    String? gender,
  }) async {
    return await _post('auth/firebase-register/', {
      'firebase_token': idToken,
      'name': name,
      'email': email,
      'phone_number': phoneNumber ?? '',
      'gender': gender ?? '',
    });
  }

  Future<Map<String, dynamic>> firebaseLogin({required String idToken}) async {
    return await _post('auth/firebase-login/', {
      'firebase_token': idToken,
    });
  }

  Future<void> updateFCMToken(String fcmToken) async {
    await _post('auth/update-fcm-token/', {
      'fcm_token': fcmToken,
    }, auth: true);
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await _get('auth/profile/', auth: true);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/auth/profile/update/'),
            headers: await _headers(auth: true),
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      final body = json.decode(response.body);
      String message = 'Failed to update profile';
      if (body is Map && body.containsKey('detail')) {
        message = body['detail'];
      }
      throw ApiException(message, response.statusCode);
    } on http.ClientException {
      throw ApiException('Connection failed. Check your network.', 0);
    }
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

  // ── Categories ──────────────────────────────────────────
  Future<List<Category>> getCategories() async {
    final data = await _get('categories/');
    return _extractResults(data)
        .map((j) => Category.fromJson(j))
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

  // ── Article Engagement ──────────────────────────────────
  Future<Map<String, dynamic>> recordArticleView(String articleId) async {
    return await _post('articles/$articleId/record-view/', {});
  }

  Future<List<ArticleComment>> getArticleComments(String articleId) async {
    final data = await _get('articles/$articleId/comments/');
    return (data as List).map((j) => ArticleComment.fromJson(j)).toList();
  }

  Future<ArticleComment> postArticleComment(String articleId, String content) async {
    final data = await _post('articles/$articleId/comments/', {'content': content}, auth: true);
    return ArticleComment.fromJson(data);
  }

  Future<void> deleteArticleComment(String articleId, int commentId) async {
    await _delete('articles/$articleId/comments/$commentId/', auth: true);
  }

  Future<Map<String, dynamic>> toggleArticleLike(String articleId) async {
    return await _post('articles/$articleId/toggle-like/', {}, auth: true);
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

  // ── Settings ─────────────────────────────────────────────
  Future<AppSettingsModel?> getSettings() async {
    final data = await _get('settings/');
    if (data is Map<String, dynamic> && data.isNotEmpty) {
      return AppSettingsModel.fromJson(data);
    }
    return null;
  }

  // ── Priority Agendas ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPriorityAgendas() async {
    final data = await _get('priority-agendas/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Gallery ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGalleryAlbums() async {
    final data = await _get('gallery/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Videos ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getVideos({String? category}) async {
    String endpoint = 'videos/';
    if (category != null) endpoint += '?category=$category';
    final data = await _get(endpoint);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> recordVideoView(String videoId) async {
    return await _post('videos/$videoId/record-view/', {});
  }

  // ── Social Media ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSocialMediaLinks() async {
    final data = await _get('social-media/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Home Feed (combined) ─────────────────────────────────
  Future<Map<String, dynamic>> getHomeFeed() async {
    final data = await _get('home-feed/');
    return data as Map<String, dynamic>;
  }

  // ── Hero Text Content ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHeroTextContent() async {
    final data = await _get('hero-text-content/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Quick Access Menu ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getQuickAccessMenu() async {
    final data = await _get('quick-access-menu/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Search ───────────────────────────────────────────────
  Future<List<Article>> searchArticles(String query, String language) async {
    final encodedQuery = Uri.encodeComponent(query);
    final data = await _get('search/articles/?q=$encodedQuery&lang=$language');
    final results = (data['results'] as List<dynamic>?) ?? [];
    return results.map((j) => Article.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<MagazineEdition>> searchMagazines(String query, String language) async {
    final encodedQuery = Uri.encodeComponent(query);
    final data = await _get('search/magazines/?q=$encodedQuery&lang=$language');
    final results = (data['results'] as List<dynamic>?) ?? [];
    return results.map((j) => MagazineEdition.fromJson(j as Map<String, dynamic>)).toList();
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
