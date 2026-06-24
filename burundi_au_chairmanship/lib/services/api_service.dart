import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import '../config/environment.dart';
import '../main.dart' show getOrCreateDeviceId;
import '../models/api_models.dart';
import '../models/magazine_model.dart';
import '../models/event_registration_model.dart';
import '../models/location_model.dart';
import 'pinned_http_client.dart';

/// Wraps a single page of results from a paginated DRF response.
class PaginatedResponse<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  PaginatedResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromItem,
  ) {
    return PaginatedResponse<T>(
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => fromItem(e))
              .toList() ??
          [],
    );
  }

  bool get hasNext => next != null;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Set by main.dart so ApiService can redirect to maintenance screen on 503.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Tracks whether we're already redirecting to avoid duplicate navigations.
  static bool _redirectingToMaintenance = false;

  /// HTTP client with certificate pinning (production) or standard (development)
  final http.Client _client = PinnedHttpClient.create();

  // Use environment-specific API URL
  static final String _baseUrl = Environment.apiBaseUrl;

  // Secure storage for JWT tokens (encrypted via Android Keystore / iOS Keychain)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// Whether Firebase token fetch has failed and we're using the JWT fallback.
  /// UI can listen to this to show a "Reconnecting..." banner.
  final ValueNotifier<bool> authDegraded = ValueNotifier<bool>(false);

  Future<Map<String, String>> _headers({bool auth = false, bool noAutoAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    // Persistent device ID for ban enforcement
    try {
      final deviceId = await getOrCreateDeviceId();
      if (deviceId.isNotEmpty) {
        headers['X-Device-Id'] = deviceId;
      }
    } catch (_) {}
    // Skip auto-auth for endpoints that handle their own token (e.g. firebase-login, firebase-register)
    if (noAutoAuth) return headers;
    // Always include Firebase token when user is logged in so the
    // backend can return personalised fields (is_liked, etc.)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      // First attempt: cached token (5s ceiling so a stalled SDK
      // doesn't block the entire API call indefinitely)
      try {
        final idToken = await firebaseUser
            .getIdToken()
            .timeout(const Duration(seconds: 5));
        if (idToken != null) {
          headers['Authorization'] = 'Bearer $idToken';
          _notifyAuthHealthy();
          return headers;
        }
      } catch (_) {}

      // Second attempt: force-refresh the token
      try {
        final idToken = await firebaseUser
            .getIdToken(true)
            .timeout(const Duration(seconds: 5));
        if (idToken != null) {
          headers['Authorization'] = 'Bearer $idToken';
          _notifyAuthHealthy();
          return headers;
        }
      } catch (_) {}

      // Both Firebase attempts failed — we're degraded
      _notifyAuthDegraded();
    }
    if (auth) {
      // Fallback to JWT token from secure storage (for backward compatibility)
      final token = await _secureStorage.read(key: AppConstants.userTokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  void _notifyAuthDegraded() {
    if (!authDegraded.value) authDegraded.value = true;
  }

  void _notifyAuthHealthy() {
    if (authDegraded.value) authDegraded.value = false;
  }

  void _redirectToMaintenance() {
    if (_redirectingToMaintenance) return;
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    _redirectingToMaintenance = true;

    // Fetch fresh maintenance data, then navigate
    getMaintenanceStatus().then((status) {
      nav.pushNamedAndRemoveUntil('/maintenance', (route) => false,
          arguments: status);
    }).catchError((_) {
      nav.pushNamedAndRemoveUntil('/maintenance', (route) => false);
    }).whenComplete(() {
      _redirectingToMaintenance = false;
    });
  }

  /// In-flight GET deduplication: callers for the same endpoint share one Future.
  final Map<String, Completer<dynamic>> _inflightGets = {};

  /// Wraps an HTTP call with automatic retry on transient server errors.
  /// - 429: respects Retry-After header (capped at 30s)
  /// - 500, 502, 504: retried with exponential backoff
  /// - 503: retried only if NOT a maintenance_mode response
  /// - 4xx client errors (400, 401, 403, 404, etc.): never retried
  /// Max 2 retries with exponential backoff (1s, 2s).
  /// [fetchHeaders] is called on each attempt so auth tokens are fresh.
  Future<http.Response> _retryOnTransient(
    Future<http.Response> Function(Map<String, String> headers) execute,
    Future<Map<String, String>> Function() fetchHeaders,
  ) async {
    const maxRetries = 2;
    const retryableStatuses = {429, 500, 502, 504};

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final headers = await fetchHeaders();
      final response = await execute(headers);
      final status = response.statusCode;

      // Maintenance 503 — redirect and stop, never retry
      if (status == 503) {
        try {
          final data = json.decode(response.body);
          if (data is Map && data['code'] == 'maintenance_mode') {
            _redirectToMaintenance();
            throw ApiException('App is under maintenance', 503);
          }
        } catch (e) {
          if (e is ApiException) rethrow;
        }
        // Non-maintenance 503: fall through to retry logic
      }

      // Success or non-retryable status — return immediately
      if (status < 500 && status != 429) return response;
      if (!retryableStatuses.contains(status) && status != 503) return response;

      // Last attempt — return whatever we got
      if (attempt == maxRetries) return response;

      // Calculate backoff
      Duration backoff;
      if (status == 429) {
        final retryAfter = response.headers['retry-after'];
        final seconds = retryAfter != null ? int.tryParse(retryAfter) : null;
        backoff = Duration(seconds: (seconds ?? 1).clamp(1, 30));
      } else {
        backoff = Duration(seconds: 1 << attempt); // 1s, 2s
      }

      await Future.delayed(backoff);
    }

    // Unreachable, but satisfies the type system
    throw ApiException('Retry logic error', 0);
  }

  Future<dynamic> _get(String endpoint, {bool auth = false, int timeoutSeconds = 20, Map<String, String>? queryParams}) async {
    // Deduplicate concurrent GET requests for the same endpoint
    final key = '$endpoint|auth=$auth|${queryParams ?? {}}';
    if (_inflightGets.containsKey(key)) {
      return _inflightGets[key]!.future;
    }
    final completer = Completer<dynamic>();
    _inflightGets[key] = completer;
    try {
      final result = await _doGet(endpoint, auth: auth, timeoutSeconds: timeoutSeconds, queryParams: queryParams);
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inflightGets.remove(key);
    }
  }

  Future<dynamic> _doGet(String endpoint, {bool auth = false, int timeoutSeconds = 20, Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse('$_baseUrl/$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          ...queryParams,
        });
      }
      final response = await _retryOnTransient(
        (headers) => _client
            .get(uri, headers: headers)
            .timeout(Duration(seconds: timeoutSeconds)),
        () => _headers(auth: auth),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw ApiException('HTTP ${response.statusCode}', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed: $e', 0);
    }
  }

  /// Public GET method
  Future<dynamic> get(String endpoint, {bool auth = false}) =>
      _get(endpoint, auth: auth);

  /// Public POST for simple actions (e.g. record_view, toggle_like)
  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = false,
    Map<String, String>? extraHeaders,
  }) =>
      _post(endpoint, body, auth: auth, extraHeaders: extraHeaders);

  Future<dynamic> _post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = false,
    bool noAutoAuth = false,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final encodedBody = json.encode(body);
      final response = await _retryOnTransient(
        (headers) {
          if (extraHeaders != null) headers.addAll(extraHeaders);
          return _client
              .post(
                Uri.parse('$_baseUrl/$endpoint'),
                headers: headers,
                body: encodedBody,
              )
              .timeout(const Duration(seconds: 20));
        },
        () => _headers(auth: auth, noAutoAuth: noAutoAuth),
      );
      final data = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      // Extract error message
      String message = 'Request failed';
      String? referenceId;
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
        if (data.containsKey('reference_id')) {
          referenceId = data['reference_id']?.toString();
        }
      }
      throw ApiException(message, response.statusCode, referenceId: referenceId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed: $e', 0);
    }
  }

  Future<dynamic> _delete(String endpoint, {bool auth = false}) async {
    try {
      final response = await _retryOnTransient(
        (headers) => _client
            .delete(Uri.parse('$_baseUrl/$endpoint'), headers: headers)
            .timeout(const Duration(seconds: 20)),
        () => _headers(auth: auth),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body);
      }
      throw ApiException('HTTP ${response.statusCode}', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<dynamic> _patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final encodedBody = json.encode(body);
      final response = await _retryOnTransient(
        (headers) => _client
            .patch(
              Uri.parse('$_baseUrl/$endpoint'),
              headers: headers,
              body: encodedBody,
            )
            .timeout(const Duration(seconds: 20)),
        () => _headers(auth: auth),
      );
      final data = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      String message = 'Request failed';
      String? referenceId;
      if (data is Map) {
        if (data.containsKey('detail')) {
          message = data['detail'];
        }
        if (data.containsKey('reference_id')) {
          referenceId = data['reference_id']?.toString();
        }
      }
      throw ApiException(message, response.statusCode, referenceId: referenceId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed: $e', 0);
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

  /// Fetch a single page with pagination metadata.
  Future<PaginatedResponse<T>> _getPaginated<T>(
    String endpoint,
    T Function(dynamic) fromItem, {
    bool auth = false,
    Map<String, String>? queryParams,
  }) async {
    final data = await _get(endpoint, auth: auth, queryParams: queryParams);
    if (data is Map<String, dynamic> && data.containsKey('results')) {
      return PaginatedResponse.fromJson(data, fromItem);
    }
    // Non-paginated fallback (endpoint returns bare list)
    final items = _extractResults(data);
    return PaginatedResponse<T>(
      count: items.length,
      results: items.map((e) => fromItem(e)).toList(),
    );
  }

  /// Fetch all pages of a paginated endpoint and combine results.
  /// Safety cap at [maxPages] to prevent runaway requests.
  Future<List<T>> _fetchAllPages<T>(
    String endpoint,
    T Function(dynamic) fromItem, {
    bool auth = false,
    Map<String, String>? queryParams,
    int maxPages = 50,
  }) async {
    final allResults = <T>[];
    var page = 1;
    final params = Map<String, String>.from(queryParams ?? {});

    while (page <= maxPages) {
      params['page'] = page.toString();
      final response = await _getPaginated<T>(
        endpoint,
        fromItem,
        auth: auth,
        queryParams: params,
      );
      allResults.addAll(response.results);
      if (!response.hasNext) break;
      page++;
    }
    return allResults;
  }

  // ── Auth ────────────────────────────────────────────────

  // Legacy JWT auth endpoints (for backward compatibility)
  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _post('auth/login/', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, {String honeypot = ''}) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    // Honeypot anti-bot field — only sent if a bot filled it in
    if (honeypot.isNotEmpty) {
      body['_hp'] = honeypot;
    }
    return await _post('auth/register/', body);
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
    String honeypot = '',
  }) async {
    final body = <String, dynamic>{
      'firebase_token': idToken,
      'name': name,
      'email': email,
      'phone_number': phoneNumber ?? '',
      'gender': gender ?? '',
    };
    // Honeypot anti-bot field — only sent if a bot filled it in
    if (honeypot.isNotEmpty) {
      body['_hp'] = honeypot;
    }
    return await _post('auth/firebase-register/', body, noAutoAuth: true);
  }

  Future<Map<String, dynamic>> firebaseLogin({
    required String idToken,
    String? deviceName,
    String? deviceType,
    String? appVersion,
  }) async {
    return await _post('auth/firebase-login/', {
      'firebase_token': idToken,
      if (deviceName != null) 'device_name': deviceName,
      if (deviceType != null) 'device_type': deviceType,
      if (appVersion != null) 'app_version': appVersion,
    }, noAutoAuth: true);
  }

  /// Presence ping used for the admin "users online now" counter.
  /// Cheap fire-and-forget — safe to call every 60s while foregrounded.
  /// Accepts both authenticated and anonymous calls; passing [fcmToken]
  /// lets the backend track anonymous devices via the X-FCM-Token header.
  Future<void> heartbeat({String? fcmToken}) async {
    try {
      await _post(
        'heartbeat/',
        const {},
        auth: true,
        extraHeaders: fcmToken != null ? {'X-FCM-Token': fcmToken} : null,
      );
    } catch (_) {
      // Presence pings must never surface errors to the user.
    }
  }

  Future<void> updateFCMToken(String fcmToken, {String? preferredLanguage}) async {
    await _post('auth/update-fcm-token/', {
      'fcm_token': fcmToken,
      if (preferredLanguage != null) 'preferred_language': preferredLanguage,
    }, auth: true);
  }

  /// Register FCM token without requiring authentication.
  /// This allows anonymous users to receive global push notifications.
  /// [preferredLanguage] should be the current in-app language ('en' or 'fr')
  /// so anonymous devices are correctly bucketed for language-targeted sends.
  Future<void> registerFCMToken(
    String fcmToken, {
    String? deviceType,
    String? deviceOs,
    String? preferredLanguage,
  }) async {
    await _post('register-fcm-token/', {
      'fcm_token': fcmToken,
      if (deviceType != null) 'device_type': deviceType,
      if (deviceOs != null) 'device_os': deviceOs,
      if (preferredLanguage != null) 'preferred_language': preferredLanguage,
    }, auth: false);
  }

  /// Deactivate FCM token on logout (don't delete, just mark inactive)
  Future<void> deactivateFCMToken(String fcmToken) async {
    await _post('auth/deactivate-fcm-token/', {
      'fcm_token': fcmToken,
    }, auth: true);
  }

  Future<void> updateDeviceInfo({
    required String deviceType,
    required String deviceOs,
    required String appVersion,
  }) async {
    await _post('auth/update-device-info/', {
      'device_type': deviceType,
      'device_os': deviceOs,
      'app_version': appVersion,
    }, auth: true);
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await _get('auth/profile/', auth: true);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _client
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    _validateUploadFile(imageFile,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      maxSizeBytes: 5 * 1024 * 1024,
    );
    try {
      final uri = Uri.parse('$_baseUrl/auth/profile/update/');
      final request = http.MultipartRequest('PUT', uri);

      // Add auth headers
      final headers = await _headers(auth: true);
      headers.remove('Content-Type'); // Let multipart set its own content type
      request.headers.addAll(headers);

      // Attach the image file
      request.files.add(
        await http.MultipartFile.fromPath('profile_picture', imageFile.path),
      );

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw ApiException('Failed to upload profile picture', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<Map<String, dynamic>> deactivateAccount() async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/deactivate-account/'),
            headers: await _headers(auth: true),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw ApiException('Failed to deactivate account', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await _client
          .delete(
            Uri.parse('$_baseUrl/auth/delete-account/'),
            headers: await _headers(auth: true),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw ApiException('Failed to delete account', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
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
    String endpoint = 'articles/?content_type=article';
    if (featured != null) endpoint += '&is_featured=$featured';
    final data = await _get(endpoint);
    return _extractResults(data)
        .map((j) => Article.fromJson(j))
        .toList();
  }

  Future<List<Article>> getNews({bool? featured}) async {
    String endpoint = 'articles/?content_type=news';
    if (featured != null) endpoint += '&is_featured=$featured';
    final data = await _get(endpoint);
    return _extractResults(data)
        .map((j) => Article.fromJson(j))
        .toList();
  }

  Future<Article> getArticle(String articleId) async {
    final data = await _get('articles/$articleId/');
    return Article.fromJson(data as Map<String, dynamic>);
  }

  // ── Article Engagement ──────────────────────────────────
  Future<Map<String, dynamic>> recordArticleView(String articleId) async {
    return await _post('articles/$articleId/record-view/', {});
  }

  Future<List<ArticleComment>> getArticleComments(String articleId) async {
    final data = await _get('articles/$articleId/comments/');
    return _extractResults(data).map((j) => ArticleComment.fromJson(j)).toList();
  }

  Future<ArticleComment> postArticleComment(
    String articleId,
    String content, {
    int? parentId,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      if (parentId != null) 'parent': parentId,
    };
    final data = await _post('articles/$articleId/comments/', body, auth: true);
    return ArticleComment.fromJson(data);
  }

  Future<void> deleteArticleComment(String articleId, int commentId) async {
    await _delete('articles/$articleId/comments/$commentId/', auth: true);
  }

  Future<Map<String, dynamic>> editArticleComment(String articleId, int commentId, String content) async {
    return await _patch('articles/$articleId/comments/$commentId/edit/', {'content': content}, auth: true);
  }

  Future<Map<String, dynamic>> toggleArticleCommentLike(String articleId, int commentId) async {
    return await _post('articles/$articleId/comments/$commentId/toggle-like/', {}, auth: true);
  }

  Future<Map<String, dynamic>> toggleArticleLike(String articleId) async {
    return await _post('articles/$articleId/toggle-like/', {}, auth: true);
  }

  // ── Related Articles ──────────────────────────────────────
  Future<List<Article>> getRelatedArticles(String articleId) async {
    final data = await _get('articles/$articleId/related/');
    if (data is List) return data.map((j) => Article.fromJson(j as Map<String, dynamic>)).toList();
    return _extractResults(data).map((j) => Article.fromJson(j)).toList();
  }

  // ── Article Reading Progress ──────────────────────────────
  Future<Map<String, dynamic>> getArticleReadingProgress(String articleId) async {
    return await _get('articles/$articleId/reading-progress/', auth: true) as Map<String, dynamic>;
  }

  Future<void> saveArticleReadingProgress(String articleId, int scrollPosition, int progressPercent) async {
    await _post('articles/$articleId/reading-progress/', {
      'scroll_position': scrollPosition,
      'progress_percent': progressPercent,
    }, auth: true);
  }

  // ── Magazines ────────────────────────────────────────────
  Future<List<MagazineEdition>> getMagazines() async {
    final data = await _get('magazines/');
    return _extractResults(data)
        .map((j) => MagazineEdition.fromJson(j))
        .toList();
  }

  Future<Map<String, dynamic>> recordMagazineView(String magazineId) async {
    return await _post('magazines/$magazineId/record-view/', {});
  }

  Future<Map<String, dynamic>> toggleMagazineLike(String magazineId) async {
    return await _post('magazines/$magazineId/toggle-like/', {}, auth: true);
  }

  Future<List<ArticleComment>> getMagazineComments(String magazineId) async {
    final data = await _get('magazines/$magazineId/comments/');
    return _extractResults(data).map((j) => ArticleComment.fromJson(j)).toList();
  }

  Future<ArticleComment> postMagazineComment(
    String magazineId,
    String content, {
    int? parentId,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      if (parentId != null) 'parent': parentId,
    };
    final data = await _post('magazines/$magazineId/comments/', body, auth: true);
    return ArticleComment.fromJson(data);
  }

  Future<void> deleteMagazineComment(String magazineId, int commentId) async {
    await _delete('magazines/$magazineId/comments/$commentId/', auth: true);
  }

  Future<Map<String, dynamic>> editMagazineComment(String magazineId, int commentId, String content) async {
    return await _patch('magazines/$magazineId/comments/$commentId/edit/', {'content': content}, auth: true);
  }

  Future<Map<String, dynamic>> toggleMagazineCommentLike(String magazineId, int commentId) async {
    return await _post('magazines/$magazineId/comments/$commentId/toggle-like/', {}, auth: true);
  }

  // ── Events ───────────────────────────────────────────────
  Future<List<EventLocation>> getEvents() async {
    final data = await _get('events/');
    return _extractResults(data)
        .map((j) => EventLocation.fromJson(j))
        .toList();
  }

  // ── Live Feeds ───────────────────────────────────────────
  Future<Map<String, dynamic>> recordLiveFeedView(int feedId) async {
    return await _post('live-feeds/$feedId/record-view/', {});
  }

  Future<List<ApiLiveFeed>> getLiveFeeds({String? status}) async {
    String endpoint = 'live-feeds/';
    if (status != null) endpoint += '?status=$status';
    final data = await _get(endpoint);
    return _extractResults(data)
        .map((j) => ApiLiveFeed.fromJson(j))
        .toList();
  }

  Future<Map<String, dynamic>> toggleLiveFeedLike(int feedId) async {
    return await _post('live-feeds/$feedId/toggle-like/', {}, auth: true);
  }

  Future<List<Map<String, dynamic>>> getLiveFeedComments(int feedId) async {
    final data = await _get('live-feeds/$feedId/comments/');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> postLiveFeedComment(int feedId, String content, {int? parentId}) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parent'] = parentId;
    return await _post('live-feeds/$feedId/comments/', body, auth: true);
  }

  Future<void> deleteLiveFeedComment(int feedId, int commentId) async {
    await _delete('live-feeds/$feedId/comments/$commentId/', auth: true);
  }

  Future<Map<String, dynamic>> editLiveFeedComment(int feedId, int commentId, String content) async {
    return await _patch('live-feeds/$feedId/comments/$commentId/edit/', {'content': content}, auth: true);
  }

  Future<Map<String, dynamic>> toggleLiveFeedCommentLike(int feedId, int commentId) async {
    return await _post('live-feeds/$feedId/comments/$commentId/toggle-like/', {}, auth: true);
  }

  // ── Resources ────────────────────────────────────────────
  Future<Map<String, dynamic>> recordResourceView(int resourceId) async {
    return await _post('resources/$resourceId/record-view/', {});
  }

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

  // ── Feature Cards ──────────────────────────────────────
  Future<Map<String, dynamic>> recordFeatureCardView(int cardId) async {
    return await _post('feature-cards/$cardId/record-view/', {});
  }

  // ── Priority Agendas ─────────────────────────────────────
  Future<Map<String, dynamic>> recordAgendaView(int agendaId) async {
    return await _post('priority-agendas/$agendaId/record-view/', {});
  }

  Future<List<Map<String, dynamic>>> getPriorityAgendas() async {
    final data = await _get('priority-agendas/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Gallery ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGalleryAlbums() async {
    try {
      final data = await _get('gallery/', auth: true);
      return _extractResults(data).cast<Map<String, dynamic>>();
    } on ApiException catch (e) {
      // If auth fails (401/403), retry without auth so guests can still browse
      if (e.statusCode == 401 || e.statusCode == 403) {
        final data = await _get('gallery/');
        return _extractResults(data).cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> recordGalleryAlbumView(String albumId) async {
    return await _post('gallery/$albumId/record-view/', {});
  }

  Future<Map<String, dynamic>> toggleGalleryAlbumLike(String albumId) async {
    return await _post('gallery/$albumId/toggle-like/', {}, auth: true);
  }

  Future<List<Map<String, dynamic>>> getGalleryComments(String albumId) async {
    final data = await _get('gallery/$albumId/comments/');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> postGalleryComment(String albumId, String content, {int? parentId}) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parent'] = parentId;
    return await _post('gallery/$albumId/comments/', body, auth: true);
  }

  Future<void> deleteGalleryComment(String albumId, int commentId) async {
    await _delete('gallery/$albumId/comments/$commentId/', auth: true);
  }

  Future<Map<String, dynamic>> editGalleryComment(String albumId, int commentId, String content) async {
    return await _patch('gallery/$albumId/comments/$commentId/edit/', {'content': content}, auth: true);
  }

  Future<Map<String, dynamic>> toggleGalleryCommentLike(String albumId, int commentId) async {
    return await _post('gallery/$albumId/comments/$commentId/toggle-like/', {}, auth: true);
  }

  // ── Videos ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getVideos({String? category}) async {
    String endpoint = 'videos/';
    if (category != null) endpoint += '?category=$category';
    try {
      final data = await _get(endpoint, auth: true);
      return _extractResults(data).cast<Map<String, dynamic>>();
    } on ApiException catch (e) {
      // If auth fails (401/403), retry without auth so guests can still browse
      if (e.statusCode == 401 || e.statusCode == 403) {
        final data = await _get(endpoint);
        return _extractResults(data).cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> recordVideoView(String videoId) async {
    return await _post('videos/$videoId/record-view/', {});
  }

  Future<Map<String, dynamic>> toggleVideoLike(String videoId) async {
    return await _post('videos/$videoId/toggle-like/', {}, auth: true);
  }

  Future<List<Map<String, dynamic>>> getVideoComments(String videoId) async {
    final data = await _get('videos/$videoId/comments/');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> postVideoComment(String videoId, String content, {int? parentId}) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parent'] = parentId;
    return await _post('videos/$videoId/comments/', body, auth: true);
  }

  Future<void> deleteVideoComment(String videoId, int commentId) async {
    await _delete('videos/$videoId/comments/$commentId/', auth: true);
  }

  Future<Map<String, dynamic>> editVideoComment(String videoId, int commentId, String content) async {
    return await _patch('videos/$videoId/comments/$commentId/edit/', {'content': content}, auth: true);
  }

  Future<Map<String, dynamic>> toggleVideoCommentLike(String videoId, int commentId) async {
    return await _post('videos/$videoId/comments/$commentId/toggle-like/', {}, auth: true);
  }

  // ── Social Media ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSocialMediaLinks() async {
    final data = await _get('social-media/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Event Registrations ────────────────────────────────────
  Future<List<EventRegistrationModel>> getEventRegistrations() async {
    final data = await _get('event-registrations/', auth: true);
    return _extractResults(data)
        .map((j) => EventRegistrationModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<EventRegistrationModel> getEventRegistration(int id) async {
    final data = await _get('event-registrations/$id/', auth: true);
    return EventRegistrationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> submitEventRegistration(int eventId, Map<String, dynamic> formData, {List<String>? uploadedFiles}) async {
    final body = <String, dynamic>{
      'event_registration': eventId,
      'form_data': formData,
    };
    if (uploadedFiles != null && uploadedFiles.isNotEmpty) {
      body['uploaded_files'] = uploadedFiles;
    }
    return await _post('event-submissions/', body, auth: true);
  }

  Future<Map<String, dynamic>> uploadRegistrationFile(File file) async {
    _validateUploadFile(file,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      maxSizeBytes: 10 * 1024 * 1024,
    );
    try {
      final uri = Uri.parse('${_baseUrl}event-submissions/upload-file/');
      final request = http.MultipartRequest('POST', uri);

      final headers = await _headers(auth: true);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }
      final errorBody = json.decode(response.body);
      throw ApiException(errorBody['detail'] ?? 'Failed to upload file', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<Map<String, dynamic>> submitProxyRegistration({
    required int eventId,
    required String proxyName,
    required String proxyEmail,
    required String proxyPhone,
    Map<String, dynamic>? formData,
  }) async {
    return await _post('event-submissions/register-proxy/', {
      'event_registration': eventId,
      'proxy_name': proxyName,
      'proxy_email': proxyEmail,
      'proxy_phone': proxyPhone,
      'form_data': formData ?? {},
    }, auth: true);
  }

  // ── QR Code Verification ─────────────────────────────────
  Future<Map<String, dynamic>> verifyQrCode(String qrData) async {
    final data = await _post('verify-qr/', {'qr_data': qrData}, auth: true);
    return data as Map<String, dynamic>;
  }

  // ── Event Ticket & Calendar ────────────────────────────────
  Future<Map<String, dynamic>> getEventQrTicket(int submissionId) async {
    final data = await _get('event-submissions/$submissionId/qr-ticket/', auth: true);
    return data as Map<String, dynamic>;
  }

  /// Returns the URL for downloading the ICS calendar file for an event registration.
  String getEventRegistrationIcsUrl(int eventRegId) {
    return '$_baseUrl/event-registrations/$eventRegId/ics/';
  }

  // ── Home Feed (combined) ─────────────────────────────────
  Future<Map<String, dynamic>> getHomeFeed() async {
    // Retry once with short backoff (handles transient network/Cloudflare 502s).
    // Worst case: 2 × 10s + 1s backoff = 21s. Callers should have cached
    // data to show while this runs in the background.
    Exception? lastError;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final data = await _get('home-feed/', timeoutSeconds: 10);
        return data as Map<String, dynamic>;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    throw lastError ?? ApiException('Failed to load content', 0);
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

  // ── Verification ─────────────────────────────────────────
  Future<Map<String, dynamic>> submitVerificationRequest({
    required String title,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String positionRole,
    String? firstName,
    String? lastName,
    String? countryCode,
    String? gender,
    String? badgeType,
    String? reasoningMessage,
    String? twitterUrl,
    String? linkedinUrl,
    String? facebookUrl,
    String? instagramUrl,
    String? tiktokUrl,
    String? youtubeUrl,
    String? otherSocialUrl,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'position_role': positionRole,
    };
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (countryCode != null) body['country_code'] = countryCode;
    if (gender != null && gender.isNotEmpty) body['gender'] = gender;
    if (badgeType != null && badgeType.isNotEmpty) body['badge_type'] = badgeType;
    if (reasoningMessage != null) body['reasoning_message'] = reasoningMessage;
    if (twitterUrl != null && twitterUrl.isNotEmpty) body['twitter_url'] = twitterUrl;
    if (linkedinUrl != null && linkedinUrl.isNotEmpty) body['linkedin_url'] = linkedinUrl;
    if (facebookUrl != null && facebookUrl.isNotEmpty) body['facebook_url'] = facebookUrl;
    if (instagramUrl != null && instagramUrl.isNotEmpty) body['instagram_url'] = instagramUrl;
    if (tiktokUrl != null && tiktokUrl.isNotEmpty) body['tiktok_url'] = tiktokUrl;
    if (youtubeUrl != null && youtubeUrl.isNotEmpty) body['youtube_url'] = youtubeUrl;
    if (otherSocialUrl != null && otherSocialUrl.isNotEmpty) body['other_social_url'] = otherSocialUrl;
    return await _post('verification/request/', body, auth: true);
  }

  // ── Sign-Up Email Verification ──────────────────────────
  Future<Map<String, dynamic>> sendSignupOtp() async {
    return await _post('auth/send-signup-otp/', {}, auth: true);
  }

  Future<Map<String, dynamic>> verifySignupOtp(String otpCode) async {
    return await _post('auth/verify-signup-otp/', {'otp_code': otpCode}, auth: true);
  }



  // ── Support Tickets ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTickets() async {
    final data = await _get('support/tickets/', auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createTicket(String subject, String message) async {
    return await _post('support/tickets/', {
      'subject': subject,
      'message': message,
    }, auth: true);
  }

  Future<Map<String, dynamic>> getTicketDetail(int ticketId) async {
    return await _get('support/tickets/$ticketId/', auth: true);
  }

  Future<Map<String, dynamic>> replyToTicket(int ticketId, String message) async {
    return await _post('support/tickets/$ticketId/reply/', {
      'message': message,
    }, auth: true);
  }

  Future<Map<String, dynamic>> markTicketRead(int ticketId) async {
    return await _post('support/tickets/$ticketId/mark-read/', {}, auth: true);
  }

  Future<Map<String, dynamic>> rateTicket(int ticketId, int rating, {String comment = ''}) async {
    return await _post('support/tickets/$ticketId/rate/', {
      'rating': rating,
      'comment': comment,
    }, auth: true);
  }

  Future<int> getUnreadNotificationCount() async {
    final data = await _get('notifications/unread-count/', auth: true);
    return data['unread_count'] ?? 0;
  }

  Future<void> markAllNotificationsAsRead() async {
    await post('notifications/mark-all-as-read/', {}, auth: true);
  }

  Future<int> getUnreadSupportCount() async {
    final data = await _get('support/unread-count/', auth: true);
    return data['unread_count'] ?? 0;
  }

  Future<Map<String, dynamic>> getVerificationStatus() async {
    return await _get('verification/status/', auth: true);
  }

  Future<Map<String, dynamic>> submitVerificationAppeal(String appealMessage) async {
    return await _post('verification/appeal/', {
      'appeal_message': appealMessage,
    }, auth: true);
  }

  // ── Popups/Announcements ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getActivePopups() async {
    final data = await _get('popups/active/', auth: true);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ── Bookmarks ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final data = await _get('bookmarks/', auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addBookmark(String contentType, int contentId) async {
    return await _post('bookmarks/', {
      'content_type': contentType,
      'content_id': contentId,
    }, auth: true);
  }

  Future<void> removeBookmark(int bookmarkId) async {
    await _delete('bookmarks/$bookmarkId/', auth: true);
  }

  Future<Map<String, dynamic>> checkBookmark(String contentType, int contentId) async {
    return await _get('bookmarks/check_bookmark/?content_type=$contentType&content_id=$contentId', auth: true);
  }

  // ── Reactions ─────────────────────────────────────────────
  Future<Map<String, dynamic>> toggleReaction(String contentType, int contentId, String reactionType) async {
    return await _post('reactions/toggle/', {
      'content_type': contentType,
      'content_id': contentId,
      'reaction_type': reactionType,
    }, auth: true);
  }

  Future<Map<String, dynamic>> getReactions(String contentType, int contentId) async {
    return await _get('reactions/?content_type=$contentType&content_id=$contentId', auth: true);
  }

  // ── Discussions / Forums ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getDiscussions({String? category}) async {
    String endpoint = 'discussions/';
    if (category != null) endpoint += '?category=$category';
    final data = await _get(endpoint, auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getDiscussionDetail(int id) async {
    return await _get('discussions/$id/', auth: true);
  }

  Future<Map<String, dynamic>> createDiscussion(String title, String content, String category) async {
    return await _post('discussions/', {
      'title': title,
      'content': content,
      'category': category,
    }, auth: true);
  }

  Future<List<Map<String, dynamic>>> getDiscussionReplies(int discussionId) async {
    final data = await _get('discussions/$discussionId/replies/', auth: true);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> postDiscussionReply(int discussionId, String content, {int? parentId}) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parent'] = parentId;
    return await _post('discussions/$discussionId/replies/', body, auth: true);
  }

  Future<void> deleteDiscussionReply(int discussionId, int replyId) async {
    await _delete('discussions/$discussionId/replies/$replyId/', auth: true);
  }

  Future<Map<String, dynamic>> editDiscussionReply(int discussionId, int replyId, String content) async {
    return await _patch('discussions/$discussionId/replies/$replyId/edit/', {'content': content}, auth: true);
  }

  Future<Map<String, dynamic>> toggleDiscussionReplyLike(int discussionId, int replyId) async {
    return await _post('discussions/$discussionId/replies/$replyId/toggle-like/', {}, auth: true);
  }

  Future<Map<String, dynamic>> recordDiscussionView(int discussionId) async {
    return await _post('discussions/$discussionId/record-view/', {});
  }

  Future<Map<String, dynamic>> toggleDiscussionLike(int discussionId) async {
    return await _post('discussions/$discussionId/toggle-like/', {}, auth: true);
  }

  // ── Polls ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPolls() async {
    final data = await _get('polls/', auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> votePoll(int pollId, int optionId) async {
    return await _post('polls/$pollId/vote/', {'option_id': optionId}, auth: true);
  }

  // ── Announcement Banners ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getAnnouncementBanners() async {
    final data = await _get('announcement-banners/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Event Speakers ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getEventSpeakers({int? eventId}) async {
    String endpoint = 'event-speakers/';
    if (eventId != null) endpoint += '?event=$eventId';
    final data = await _get(endpoint);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Conversations / Messages ──────────────────────────────
  Future<List<Map<String, dynamic>>> getConversations() async {
    final data = await _get('conversations/', auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getConversationMessages(int conversationId) async {
    final data = await _get('conversations/$conversationId/messages/', auth: true);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendMessage(int conversationId, String content) async {
    return await _post('conversations/$conversationId/messages/', {
      'content': content,
    }, auth: true);
  }

  Future<Map<String, dynamic>> startConversation(int userId, String message) async {
    return await _post('conversations/', {
      'participant_id': userId,
      'message': message,
    }, auth: true);
  }

  // ── Notification Preferences ──────────────────────────────
  Future<Map<String, dynamic>> getNotificationPreferences() async {
    return await _get('notification-preferences/', auth: true);
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(Map<String, dynamic> prefs) async {
    return await _post('notification-preferences/', prefs, auth: true);
  }

  // ── User Preferences ─────────────────────────────────────
  Future<Map<String, dynamic>> getUserPreferences() async {
    return await _get('preferences/', auth: true);
  }

  Future<Map<String, dynamic>> updateUserPreferences(Map<String, dynamic> prefs) async {
    return await _post('preferences/', prefs, auth: true);
  }

  // ── Onboarding ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getOnboardingSteps() async {
    final data = await _get('onboarding-steps/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<void> completeOnboarding() async {
    await _post('onboarding/complete/', {}, auth: true);
  }

  // ── Security ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLoginHistory() async {
    final data = await _get('auth/login-history/', auth: true);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final data = await _get('auth/active-sessions/', auth: true);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<void> revokeSession(int sessionId) async {
    await _post('auth/sessions/$sessionId/revoke/', {}, auth: true);
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    return await _post('auth/change-password/', {
      'current_password': currentPassword,
      'new_password': newPassword,
    }, auth: true);
  }

  // ── Trending Content ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTrendingContent() async {
    final data = await _get('trending/');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Event Features ────────────────────────────────────────
  Future<Map<String, dynamic>> submitEventFeedback(int eventId, int rating, {String comment = ''}) async {
    return await _post('events/feedback/', {
      'event': eventId,
      'rating': rating,
      'comment': comment,
    }, auth: true);
  }

  Future<Map<String, dynamic>> eventCheckIn(int eventId, {String? qrCode}) async {
    final body = <String, dynamic>{'event': eventId};
    if (qrCode != null) body['qr_code'] = qrCode;
    return await _post('events/checkin/', body, auth: true);
  }

  Future<Map<String, dynamic>> joinEventWaitlist(int eventId) async {
    return await _post('events/waitlist/', {'event': eventId}, auth: true);
  }

  // ── App Updates ───────────────────────────────────────────
  Future<Map<String, dynamic>> checkAppUpdate(String currentVersion) async {
    return await _get('app-update/?current_version=$currentVersion');
  }

  // ── Maintenance Status ────────────────────────────────────
  Future<Map<String, dynamic>> getMaintenanceStatus() async {
    return await _get('maintenance/');
  }

  // ── Live Q&A ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLiveQASessions() async {
    final data = await _get('live-qa/', auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> submitQAQuestion(int sessionId, String question) async {
    return await _post('live-qa/$sessionId/questions/', {
      'question': question,
    }, auth: true);
  }

  Future<Map<String, dynamic>> upvoteQAQuestion(int sessionId, int questionId) async {
    return await _post('live-qa/$sessionId/upvote_question/', {
      'question_id': questionId,
    }, auth: true);
  }

  // ── Reading Progress ──────────────────────────────────────
  Future<void> updateReadingProgress(String contentType, int contentId, double progress) async {
    await _post('reading-progress/', {
      'content_type': contentType,
      'content_id': contentId,
      'progress_percentage': progress,
    }, auth: true);
  }

  // ── Weather ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWeatherCities() async {
    final data = await _get('weather-cities/');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Event Reminders ───────────────────────────────────────
  Future<Map<String, dynamic>> setEventReminder(int eventId, int minutesBefore) async {
    return await _post('event-reminders/', {
      'event': eventId,
      'minutes_before': minutesBefore,
    }, auth: true);
  }

  Future<void> removeEventReminder(int reminderId) async {
    await _delete('event-reminders/$reminderId/', auth: true);
  }

  // ── Export User Data (GDPR) ───────────────────────────────
  Future<Map<String, dynamic>> exportUserData() async {
    return await _get('auth/export-data/', auth: true);
  }

  // ── Profile Completion ───────────────────────────────────
  Future<Map<String, dynamic>> getProfileCompletion() async {
    return await _get('profile-completion/', auth: true);
  }

  // ── Password Strength ────────────────────────────────────
  Future<Map<String, dynamic>> validatePasswordStrength(String password) async {
    return await _post('password-strength/', {'password': password});
  }

  // ── What's New ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWhatsNew() async {
    final data = await _get('whats-new/');
    return (data is List) ? List<Map<String, dynamic>>.from(data) : _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Auto Translate ───────────────────────────────────────
  Future<Map<String, dynamic>> autoTranslate(String text, String source, String target) async {
    return await _post('admin/auto-translate/', {'text': text, 'source': source, 'target': target}, auth: true);
  }

  // ── Event Agenda Items ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getEventAgendaItems(int eventId) async {
    final data = await _get('event-agenda-items/?event=$eventId');
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Event Comments ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getEventComments(int eventId) async {
    final data = await _get('events/$eventId/comments/');
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> postEventComment(int eventId, String content, {int? parentId}) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parent'] = parentId;
    return await _post('events/$eventId/comments/', body, auth: true);
  }

  Future<void> deleteEventComment(int eventId, int commentId) async {
    await _delete('events/$eventId/comments/$commentId/', auth: true);
  }

  Future<Map<String, dynamic>> editEventComment(int eventId, int commentId, String content) async {
    return await _patch('events/$eventId/comments/$commentId/edit/', {'content': content}, auth: true);
  }

  Future<Map<String, dynamic>> toggleEventCommentLike(int eventId, int commentId) async {
    return await _post('events/$eventId/comments/$commentId/toggle-like/', {}, auth: true);
  }

  Future<Map<String, dynamic>> recordEventView(int eventId) async {
    return await _post('events/$eventId/record-view/', {});
  }

  Future<Map<String, dynamic>> toggleEventLike(int eventId) async {
    return await _post('events/$eventId/toggle-like/', {}, auth: true);
  }

  // ── Event Attendees ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getEventAttendees(int eventId) async {
    final data = await _get('events/$eventId/attendees/', auth: true);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  // ── Event Photos ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getEventPhotos(int eventId) async {
    final data = await _get('event-photos/?event=$eventId', auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> uploadEventPhoto(int eventId, File imageFile, {String caption = ''}) async {
    _validateUploadFile(imageFile,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      maxSizeBytes: 10 * 1024 * 1024,
    );
    try {
      final uri = Uri.parse('$_baseUrl/event-photos/');
      final request = http.MultipartRequest('POST', uri);

      final headers = await _headers(auth: true);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.fields['event'] = eventId.toString();
      request.fields['caption'] = caption;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }
      throw ApiException('Failed to upload photo', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  // ── Newsletter ──────────────────────────────────────────
  Future<Map<String, dynamic>> toggleNewsletter(bool receives) async {
    return await _post('newsletter/toggle/', {'receives_newsletter': receives}, auth: true);
  }

  Future<Map<String, dynamic>> subscribeNewsletter({
    required String name,
    required String email,
    String? phoneNumber,
  }) async {
    return await _post('newsletter/subscribe/', {
      'name': name,
      'email': email,
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
    }, auth: false);
  }

  Future<Map<String, dynamic>> checkNewsletterSubscription() async {
    return await _get('newsletter/check/', auth: true);
  }

  // ── Linked Accounts ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLinkedAccounts() async {
    final data = await _get('auth/linked-accounts/', auth: true);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> linkAccount({
    required String provider,
    required String providerUid,
    String email = '',
    String displayName = '',
  }) async {
    return await _post('auth/link-account/', {
      'provider': provider,
      'provider_uid': providerUid,
      'email': email,
      'display_name': displayName,
    }, auth: true);
  }

  Future<Map<String, dynamic>> unlinkAccount(String provider, {String? providerUid}) async {
    final body = <String, dynamic>{'provider': provider};
    if (providerUid != null) body['provider_uid'] = providerUid;
    return await _post('auth/unlink-account/', body, auth: true);
  }

  Future<Map<String, dynamic>> mergeAccounts(int sourceUserId) async {
    return await _post('auth/merge-accounts/', {
      'source_user_id': sourceUserId,
    }, auth: true);
  }

  // ── App Open Tracking ──────────────────────────────────
  Future<void> recordAppOpen({
    String? deviceId,
    String? deviceType,
    String? deviceOs,
    String? appVersion,
    String? countryCode,
  }) async {
    try {
      await _post('app-open/', {
        'device_id': deviceId ?? '',
        'device_type': deviceType ?? '',
        'device_os': deviceOs ?? '',
        'app_version': appVersion ?? '',
        'country_code': countryCode ?? '',
      });
    } catch (_) {
      // Silent fail — don't let analytics block app launch
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  PROMOTIONAL SPLASH
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getActivePromotionalSplash() async {
    final data = await _get('promotional-splash/active/');
    return data['splash'];
  }

  Future<void> trackPromotionalSplashClick(int id) async {
    await _post('promotional-splash/$id/click/', {});
  }

  // ═══════════════════════════════════════════════════════════
  //  YOUTH DIALOGUE
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> youthDialogueSettings() async {
    return await _get('youth-dialogue/settings/');
  }

  Future<Map<String, dynamic>> youthDialogueApply(Map<String, dynamic> formData) async {
    return await _post('youth-dialogue/apply/', formData, auth: true);
  }

  Future<Map<String, dynamic>> youthDialogueStatus() async {
    return await _get('youth-dialogue/status/', auth: true);
  }

  Future<Map<String, dynamic>> youthDialogueUploadDocument(
    File file,
    String docType, {
    int? replacesId,
  }) async {
    _validateUploadFile(file,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      maxSizeBytes: 10 * 1024 * 1024,
    );
    try {
      final uri = Uri.parse('$_baseUrl/youth-dialogue/upload-document/');
      final request = http.MultipartRequest('POST', uri);

      final headers = await _headers(auth: true);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.fields['document_type'] = docType;
      if (replacesId != null) {
        request.fields['replaces'] = replacesId.toString();
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }
      final errorBody = json.decode(response.body);
      throw ApiException(errorBody['detail'] ?? 'Failed to upload document', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<Map<String, dynamic>> youthDialogueSubmitDocuments() async {
    return await _post('youth-dialogue/submit-documents/', {}, auth: true);
  }

  Future<Map<String, dynamic>> youthDialogueCredential() async {
    return await _get('youth-dialogue/credential/', auth: true);
  }

  /// Downloads the credential PDF with auth headers and returns the file bytes.
  Future<List<int>> downloadCredentialPdf() async {
    final headers = await _headers(auth: true);
    headers.remove('Content-Type'); // Not needed for download
    final response = await _client
        .get(Uri.parse('$_baseUrl/youth-dialogue/credential-pdf/'), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw ApiException('Failed to download PDF: HTTP ${response.statusCode}', response.statusCode);
  }

  Future<Map<String, dynamic>> youthDialogueEligibility() async {
    return await _get('youth-dialogue/eligibility/', auth: true);
  }

  Future<void> youthDialogueLogActivity(
    String action,
    String screenName, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _post('youth-dialogue/log-activity/', {
        'action': action,
        'screen_name': screenName,
        if (metadata != null) 'metadata': metadata,
      }, auth: true);
    } catch (_) {
      // Silent fail — activity logging is non-critical
    }
  }

  Future<List<dynamic>> youthDialogueScanHistory() async {
    final data = await _get('youth-dialogue/scan-history/', auth: true);
    return data['results'] as List<dynamic>? ?? [];
  }

  // ── Upload Validation ────────────────────────────────────
  void _validateUploadFile(File file, {
    required List<String> allowedExtensions,
    required int maxSizeBytes,
  }) {
    final ext = file.path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw ApiException(
        'Invalid file type. Allowed: ${allowedExtensions.join(", ")}',
        0,
      );
    }
    final size = file.lengthSync();
    if (size > maxSizeBytes) {
      final maxMB = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      throw ApiException('File too large. Maximum size: ${maxMB}MB', 0);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? referenceId;
  ApiException(this.message, this.statusCode, {this.referenceId});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
