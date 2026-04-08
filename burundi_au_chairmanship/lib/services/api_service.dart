import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import '../config/environment.dart';
import '../models/api_models.dart';
import '../models/magazine_model.dart';
import '../models/location_model.dart';
import '../models/event_registration_model.dart';
import 'pinned_http_client.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// HTTP client with certificate pinning (production) or standard (development)
  final http.Client _client = PinnedHttpClient.create();

  // Use environment-specific API URL
  static final String _baseUrl = Environment.apiBaseUrl;

  // Secure storage for JWT tokens (encrypted via Android Keystore / iOS Keychain)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

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

      // Fallback to JWT token from secure storage (for backward compatibility)
      final token = await _secureStorage.read(key: AppConstants.userTokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> _get(String endpoint, {bool auth = false, int timeoutSeconds = 20}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(Duration(seconds: timeoutSeconds));
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
  Future<dynamic> post(String endpoint, Map<String, dynamic> body, {bool auth = false}) =>
      _post(endpoint, body, auth: auth);

  Future<dynamic> _post(String endpoint, Map<String, dynamic> body, {bool auth = false}) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: await _headers(auth: auth),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 20));
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<dynamic> _delete(String endpoint, {bool auth = false}) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 20));
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
    } on http.ClientException {
      throw ApiException('Connection failed. Check your network.', 0);
    }
  }

  Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
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

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
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
    } on http.ClientException {
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

  Future<Map<String, dynamic>> recordMagazineView(String magazineId) async {
    return await _post('magazines/$magazineId/record-view/', {});
  }

  Future<Map<String, dynamic>> toggleMagazineLike(String magazineId) async {
    return await _post('magazines/$magazineId/toggle-like/', {}, auth: true);
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
    final data = await _get('gallery/', auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> recordGalleryAlbumView(String albumId) async {
    return await _post('gallery/$albumId/record-view/', {});
  }

  Future<Map<String, dynamic>> toggleGalleryAlbumLike(String albumId) async {
    return await _post('gallery/$albumId/toggle-like/', {}, auth: true);
  }

  // ── Videos ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getVideos({String? category}) async {
    String endpoint = 'videos/';
    if (category != null) endpoint += '?category=$category';
    final data = await _get(endpoint, auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> recordVideoView(String videoId) async {
    return await _post('videos/$videoId/record-view/', {});
  }

  Future<Map<String, dynamic>> toggleVideoLike(String videoId) async {
    return await _post('videos/$videoId/toggle-like/', {}, auth: true);
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

  Future<Map<String, dynamic>> submitEventRegistration(int eventId, Map<String, dynamic> formData) async {
    return await _post('event-submissions/', {
      'event_registration': eventId,
      'form_data': formData,
    }, auth: true);
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

  // ── Home Feed (combined) ─────────────────────────────────
  Future<Map<String, dynamic>> getHomeFeed() async {
    // Retry up to 2 times with exponential backoff (handles transient network/Cloudflare issues)
    Exception? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final data = await _get('home-feed/', timeoutSeconds: 25);
        return data as Map<String, dynamic>;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < 2) {
          // Exponential backoff: 1s, then 3s
          await Future.delayed(Duration(seconds: attempt == 0 ? 1 : 3));
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

  // ── Phone OTP Verification (Twilio) ──────────────────────
  Future<Map<String, dynamic>> sendPhoneOtp(String countryCode, String phoneNumber, {String channel = 'sms'}) async {
    return await _post('otp/send-phone/', {
      'country_code': countryCode,
      'phone_number': phoneNumber,
      'channel': channel,
    }, auth: true);
  }

  Future<Map<String, dynamic>> verifyPhoneOtp(String countryCode, String phoneNumber, String otpCode) async {
    return await _post('otp/verify-phone/', {
      'country_code': countryCode,
      'phone_number': phoneNumber,
      'otp_code': otpCode,
    }, auth: true);
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

  // ── Polls ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPolls() async {
    final data = await _get('polls/', auth: true);
    return _extractResults(data).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> votePoll(int pollId, int optionId) async {
    return await _post('polls/$pollId/vote/', {'option_id': optionId}, auth: true);
  }

  // ── Contact Directory ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getContactDirectory() async {
    final data = await _get('contact-directory/');
    return _extractResults(data).cast<Map<String, dynamic>>();
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
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
