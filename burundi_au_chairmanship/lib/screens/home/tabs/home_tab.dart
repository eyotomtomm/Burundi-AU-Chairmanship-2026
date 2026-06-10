import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../widgets/verified_badge.dart';
import '../../../models/api_models.dart';
import '../../../models/magazine_model.dart';
import '../../magazine/pdf_viewer_screen.dart';
import '../../../models/event_registration_model.dart';
import '../../../services/api_service.dart';
import '../../../services/deep_link_router.dart';
import '../../../services/firebase_messaging_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../articles/articles_screen.dart';
import '../../news/article_detail_screen.dart';
import '../../feature_card/feature_card_detail_screen.dart';
import '../../events/event_detail_screen.dart';
import '../painters/zigzag_line_painter.dart';
import '../painters/card_pattern_painter.dart';
import '../widgets/quick_access_grid.dart';
import '../widgets/news_card.dart';
import '../widgets/event_card.dart';
import '../../../widgets/login_gate.dart';
import '../../../widgets/shimmer_loading.dart';

class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const HomeTab({super.key, this.onSwitchTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Large offset so users can swipe left from the first slide too
  static const int _kLoopOffset = 10000;

  final PageController _heroPageController = PageController(initialPage: _kLoopOffset);
  final PageController _featureCardPageController = PageController(
    viewportFraction: 0.85,
    initialPage: _kLoopOffset,
  );
  Timer? _heroTimer;
  Timer? _featureTimer;
  int _heroRawPage = _kLoopOffset;
  int _featureRawPage = _kLoopOffset;

  // API data
  List<HeroSlide>? _apiHeroSlides;
  List<Article>? _apiArticles;
  List<Article>? _apiNewsItems;
  List<Map<String, dynamic>>? _apiFeatureCards;
  List<Map<String, dynamic>>? _apiPriorityAgendas;
  List<EventRegistrationModel>? _apiEventCards;
  List<MagazineEdition>? _apiMagazines;
  Map<String, String>? _heroTextContent;
  List<Map<String, dynamic>>? _quickAccessItems;
  int _unreadBadgeCount = 0;
  Timer? _badgeTimer;
  bool _isLoading = true;
  bool _hasError = false;

  // Trending content
  List<Map<String, dynamic>>? _trendingItems;

  // Announcement banner
  Map<String, dynamic>? _announcementBanner;
  bool _announcementDismissed = false;

  // Youth Dialogue eligibility (for conditional Quick Access visibility)
  bool _ydEligible = false;

  // Youth Dialogue settings (for Quick Access visibility + icon)
  Map<String, dynamic>? _ydSettings;

  // Profile completion prompt
  bool _showProfilePrompt = false;
  bool _profilePromptDismissed = false;

  // Computed getters
  List<Map<String, dynamic>> get _heroSlides {
    if (_apiHeroSlides != null && _apiHeroSlides!.isNotEmpty) {
      return _apiHeroSlides!.map((s) => {
        'image': s.image,
        'label': s.getLabel(Localizations.localeOf(context).languageCode),
        'isNetwork': true,
      }).toList();
    }
    // No fallback - show empty state
    return [];
  }

  List<Map<String, dynamic>> get _featureCards {
    if (_apiFeatureCards != null && _apiFeatureCards!.isNotEmpty) {
      return _apiFeatureCards!;
    }
    // No fallback - show empty state
    return [];
  }

  List<Article> get _articles {
    if (_apiArticles != null && _apiArticles!.isNotEmpty) return _apiArticles!;
    return [];
  }

  List<Article> get _newsItems {
    if (_apiNewsItems != null && _apiNewsItems!.isNotEmpty) return _apiNewsItems!;
    return [];
  }

  String _getHeroText(String key) {
    if (_heroTextContent != null && _heroTextContent!.containsKey(key)) {
      return _heroTextContent![key]!;
    }
    // No fallback - return empty string
    return '';
  }

  /// Parse hex color string like "#409843" into a Color
  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.isEmpty) return const Color(0xFF409843);
    if (hex.length == 6) hex = 'FF$hex';
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return const Color(0xFF409843);
    return Color(parsed);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _loadAnnouncementBanner();
    _loadTrendingContent();
    _startHeroAutoSlide();
    _startFeatureAutoSlide();
    // Poll unread count every 60 seconds
    _badgeTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadUnreadCount());
    // Check notification permission after a brief delay (non-blocking)
    _checkNotificationPermission();
    // Check if profile is incomplete for contextual prompt + FIAM trigger
    _checkProfileCompletion();
  }

  /// Show a permission dialog if push notifications are not enabled.
  /// Prompts at most once per week to avoid being annoying.
  Future<void> _checkNotificationPermission() async {
    // Wait for the home screen to finish building before showing dialog
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final langCode = context.read<LanguageProvider>().languageCode;
    final messagingService = FirebaseMessagingService();
    await messagingService.showPermissionDialog(context, langCode);
  }

  /// Check if the user's profile is incomplete and show a prompt + log an
  /// analytics event that FIAM campaigns can trigger on.
  Future<void> _checkProfileCompletion() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;

    // Check if user previously dismissed the prompt this session
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('profile_prompt_dismissed') == true) return;

    // Consider profile incomplete if key fields are missing
    final isIncomplete = (auth.userName == null || auth.userName!.isEmpty) ||
        (auth.nationality == null || auth.nationality!.isEmpty) ||
        (auth.gender == null || auth.gender!.isEmpty);

    if (isIncomplete && mounted) {
      setState(() => _showProfilePrompt = true);
      // Log analytics event — FIAM campaigns can trigger on this
      try {
        FirebaseAnalytics.instance.logEvent(name: 'profile_incomplete');
      } catch (_) {}
    }
  }

  Future<void> _loadUnreadCount() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;
    try {
      final api = ApiService();
      final count = await api.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadBadgeCount = count);
    } catch (_) {
      // Silently fail - badge is non-critical
    }
  }

  Future<void> _loadAnnouncementBanner() async {
    try {
      final api = ApiService();
      final banners = await api.getAnnouncementBanners();
      if (banners.isNotEmpty && mounted) {
        setState(() => _announcementBanner = banners.first);
      }
    } catch (_) {
      // Silently fail - announcements are non-critical
    }
  }

  Future<void> _loadTrendingContent() async {
    try {
      final items = await ApiService().getTrendingContent();
      if (mounted) {
        setState(() => _trendingItems = items);
      }
    } catch (_) {
      // Silently fail - trending is non-critical
    }
  }

  /// Cache feature toggle flags from API settings into SharedPreferences.
  /// These flags control visibility of Newsletter in the app.
  Future<void> _cacheFeatureFlags(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('feature_newsletter_enabled', settings['newsletter_enabled'] ?? true);
    } catch (_) {}
  }

  /// Cache the home feed response for offline/fallback use
  Future<void> _cacheHomeFeed(Map<String, dynamic> homeFeed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_home_feed', json.encode(homeFeed));
    } catch (_) {}
  }

  /// Load cached home feed data as fallback when network fails
  Future<Map<String, dynamic>?> _loadCachedHomeFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_home_feed');
      if (cached != null) {
        return json.decode(cached) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService();

      // Fetch main home feed + secondary data in parallel
      final results = await Future.wait([
        api.getHomeFeed(),
        api.getPriorityAgendas().catchError((_) => <Map<String, dynamic>>[]),
        api.getHeroTextContent().catchError((_) => <Map<String, dynamic>>[]),
        api.getQuickAccessMenu().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final homeFeed = results[0] as Map<String, dynamic>;
      final priorityAgendas = results[1] as List<Map<String, dynamic>>;
      final heroTextData = results[2] as List<Map<String, dynamic>>;
      final quickAccessMenu = results[3] as List<Map<String, dynamic>>;

      // Cache successful response for future fallback
      _cacheHomeFeed(homeFeed);

      _applyHomeFeedData(homeFeed, priorityAgendas, heroTextData, quickAccessMenu);

      // Fetch Youth Dialogue settings + eligibility in the background
      final isAuth = context.read<AuthProvider>().isAuthenticated;
      api.youthDialogueSettings().then((ydSettingsData) {
        if (mounted) setState(() => _ydSettings = ydSettingsData);
      }).catchError((_) {});
      if (isAuth) {
        api.youthDialogueEligibility().then((ydData) {
          if (mounted) setState(() => _ydEligible = ydData['eligible'] == true);
        }).catchError((_) {});
      }
    } catch (e, stack) {
      debugPrint('Failed to load home feed data: $e');
      Sentry.captureException(e, stackTrace: stack);

      if (!mounted) return;

      // Try loading cached data as fallback
      final cachedFeed = await _loadCachedHomeFeed();
      if (cachedFeed != null && mounted) {
        // Use cached data so user sees something
        _applyHomeFeedData(cachedFeed, [], [], []);
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          // Store error type for specific messaging
          _lastErrorMessage = e is ApiException && e.statusCode == 0
              ? 'no_internet'
              : 'server_error';
        });
      }
    }
  }

  String _lastErrorMessage = '';

  /// Apply parsed home feed data to state (shared between live and cached loads)
  void _applyHomeFeedData(
    Map<String, dynamic> homeFeed,
    List<Map<String, dynamic>> priorityAgendas,
    List<Map<String, dynamic>> heroTextData,
    List<Map<String, dynamic>> quickAccessMenu,
  ) {
    // Parse hero slides
    final heroSlides = (homeFeed['hero_slides'] as List<dynamic>?)
        ?.map((j) => HeroSlide.fromJson(j as Map<String, dynamic>))
        .toList();

    // Parse articles and news items
    final articles = (homeFeed['articles'] as List<dynamic>?)
        ?.map((j) => Article.fromJson(j as Map<String, dynamic>))
        .toList();
    final newsItems = (homeFeed['news_items'] as List<dynamic>?)
        ?.map((j) => Article.fromJson(j as Map<String, dynamic>))
        .toList();

    // Parse feature cards from API
    final langCode = mounted ? Localizations.localeOf(context).languageCode : 'en';
    final featureCardIcons = [Icons.stars, Icons.travel_explore, Icons.gavel, Icons.auto_stories];
    final rawCards = homeFeed['feature_cards'] as List<dynamic>? ?? [];
    final featureCards = rawCards.asMap().entries.map((entry) {
      final j = entry.value as Map<String, dynamic>;
      final gradStart = _hexToColor(j['gradient_start'] ?? '#409843');
      final gradEnd = _hexToColor(j['gradient_end'] ?? '#4CAF50');

      IconData icon = featureCardIcons[entry.key % featureCardIcons.length];
      final iconName = j['icon_name'] as String?;
      if (iconName != null && iconName.isNotEmpty) {
        icon = _getIconFromName(iconName);
      }

      return <String, dynamic>{
        'title': langCode == 'fr' ? (j['title_fr'] ?? j['title'] ?? '') : (j['title'] ?? ''),
        'description': langCode == 'fr' ? (j['description_fr'] ?? j['description'] ?? '') : (j['description'] ?? ''),
        'icon': icon,
        'iconImageUrl': j['icon_image'] ?? '',
        'gradient': [gradStart, gradEnd],
        'imageUrl': j['image'] ?? '',
        'actionType': j['action_type'] ?? 'none',
        'actionValue': j['action_value'] ?? '',
        'gradient_start': j['gradient_start'] ?? '#409843',
        'gradient_end': j['gradient_end'] ?? '#4CAF50',
        'overview': j['overview'] ?? '',
        'overview_fr': j['overview_fr'] ?? '',
        'key_points': j['key_points'] ?? [],
        'key_points_fr': j['key_points_fr'] ?? [],
        'impact_areas': j['impact_areas'] ?? [],
        'impact_areas_fr': j['impact_areas_fr'] ?? [],
        'extra_content': j['extra_content'] ?? '',
        'extra_content_fr': j['extra_content_fr'] ?? '',
        'media': j['media'] ?? [],
        'title_raw': j['title'] ?? '',
        'title_fr': j['title_fr'] ?? '',
      };
    }).toList();

    // Parse hero text content
    final heroTextMap = <String, String>{};
    for (final item in heroTextData) {
      final key = item['key'] as String?;
      if (key == null) continue;
      final text = langCode == 'fr' && item['text_fr'] != null && (item['text_fr'] as String).isNotEmpty
          ? item['text_fr'] as String
          : item['text_en'] as String;
      heroTextMap[key] = text;
    }

    // Parse event cards
    final rawEventCards = homeFeed['event_cards'] as List<dynamic>? ?? [];
    final eventCards = rawEventCards
        .map((j) => EventRegistrationModel.fromJson(j as Map<String, dynamic>))
        .toList();

    // Parse magazines
    final rawMagazines = homeFeed['magazines'] as List<dynamic>? ?? [];
    final magazines = rawMagazines
        .map((j) => MagazineEdition.fromJson(j as Map<String, dynamic>))
        .toList();

    // Cache feature toggle flags from settings for use by other tabs (e.g. MoreTab)
    final settingsData = homeFeed['settings'] as Map<String, dynamic>? ?? {};
    _cacheFeatureFlags(settingsData);

    setState(() {
      _apiHeroSlides = heroSlides;
      _apiArticles = articles;
      _apiNewsItems = newsItems;
      _apiFeatureCards = featureCards;
      _apiPriorityAgendas = priorityAgendas;
      _apiEventCards = eventCards;
      _apiMagazines = magazines;
      _heroTextContent = heroTextMap;
      _quickAccessItems = quickAccessMenu;
      _isLoading = false;
      _hasError = false;
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _featureTimer?.cancel();
    _badgeTimer?.cancel();
    _heroPageController.dispose();
    _featureCardPageController.dispose();
    super.dispose();
  }

  void _startHeroAutoSlide() {
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _heroSlides.isEmpty || !_heroPageController.hasClients) return;
      try {
        if (_heroPageController.positions.isEmpty) return;
        if (_heroPageController.position.haveDimensions) {
          _heroPageController.animateToPage(
            _heroRawPage + 1,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      } catch (e) {
        // Ignore animation errors during page transitions
      }
    });
  }

  void _startFeatureAutoSlide() {
    _featureTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _featureCards.isEmpty || !_featureCardPageController.hasClients) return;
      try {
        if (_featureCardPageController.positions.isEmpty) return;
        if (_featureCardPageController.position.haveDimensions) {
          _featureCardPageController.animateToPage(
            _featureRawPage + 1,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      } catch (e) {
        // Ignore animation errors during page transitions
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    if (_isLoading) return const ShimmerHomeTabSkeleton();

    // Show error/retry when loading failed and no data loaded
    if (_hasError && _apiHeroSlides == null && _apiArticles == null) {
      final isNoInternet = _lastErrorMessage == 'no_internet';
      final errorIcon = isNoInternet ? Icons.wifi_off_rounded : Icons.cloud_off_rounded;
      final errorTitle = isNoInternet
          ? (langCode == 'fr' ? 'Pas de connexion internet' : 'No internet connection')
          : (langCode == 'fr' ? 'Serveur temporairement indisponible' : 'Server temporarily unavailable');
      final errorSubtitle = isNoInternet
          ? (langCode == 'fr' ? 'Vérifiez votre connexion et réessayez' : 'Check your connection and try again')
          : (langCode == 'fr' ? 'Veuillez réessayer dans un moment' : 'Please try again in a moment');

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(errorIcon, size: 72,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white38 : Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                errorTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                  _loadData();
                },
                icon: const Icon(Icons.refresh),
                label: Text(langCode == 'fr' ? 'Réessayer' : 'Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
        await _loadData();
      },
      color: AppColors.burundiGreen,
      child: CustomScrollView(
      slivers: [
        // Hero Slideshow
        SliverToBoxAdapter(
          child: _buildHeroSlideshow(context, l10n),
        ),

        // Announcement Banner
        if (_announcementBanner != null && !_announcementDismissed)
          SliverToBoxAdapter(
            child: _buildAnnouncementBanner(context, langCode),
          ),

        // Profile Completion Prompt
        if (_showProfilePrompt && !_profilePromptDismissed && isAuth)
          SliverToBoxAdapter(
            child: _buildProfilePromptCard(context, langCode),
          ),

        // Welcome Banner
        SliverToBoxAdapter(
          child: _buildWelcomeBanner(context),
        ),

        // Feature Cards Slideshow
        if (_featureCards.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildFeatureCardsSection(context),
          ),

        // Quick Access Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(context, l10n.translate('quick_access')),
                const SizedBox(height: 12),
                _buildQuickAccessGrid(context, l10n),
              ],
            ),
          ),
        ),

        // Upcoming Events Section
        if (_apiEventCards != null && _apiEventCards!.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
              child: _buildSectionTitle(
                context,
                langCode == 'fr' ? 'Prochains Événements' : 'Upcoming Events',
                showSeeAll: true,
                onSeeAll: () => Navigator.pushNamed(context, '/events'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Builder(
                builder: (context) {
                  final total = _apiEventCards!.length;
                  final freeShown = isAuth ? total : (total < 2 ? total : 2);
                  final itemCount = isAuth ? total : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) {
                        return const LoginGateCarouselCard(width: 260, height: 200);
                      }
                      final event = _apiEventCards![index];
                      return EventCard(
                        event: event,
                        langCode: langCode,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => EventDetailScreen(event: event),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],

        // Latest Magazines Section
        if (_apiMagazines != null && _apiMagazines!.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
              child: _buildMagazineSectionTitle(context, langCode),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: Builder(
                builder: (context) {
                  final total = _apiMagazines!.length;
                  final freeShown = isAuth ? total : (total < 2 ? total : 2);
                  final itemCount = isAuth ? total : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) {
                        return const LoginGateCarouselCard(width: 160, height: 220);
                      }
                      final magazine = _apiMagazines![index];
                      return _buildMagazineCard(context, magazine, langCode, isAuth);
                    },
                  );
                },
              ),
            ),
          ),
        ],

        // Trending Section
        if (_trendingItems != null && _trendingItems!.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
              child: _buildSectionTitle(context, langCode == 'fr' ? 'Tendances' : 'Trending', showSeeAll: false),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: Builder(
                builder: (context) {
                  final capped = _trendingItems!.length > 5 ? 5 : _trendingItems!.length;
                  final freeShown = isAuth ? capped : (capped < 2 ? capped : 2);
                  final itemCount = isAuth ? capped : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) {
                        return const LoginGateCarouselCard(width: 240, height: 110);
                      }
                      final item = _trendingItems![index];
                      return _buildTrendingCard(item, index + 1, langCode, isAuth);
                    },
                  );
                },
              ),
            ),
          ),
        ],

        // Latest News Section
        if (_newsItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
              child: _buildSectionTitle(context, l10n.translate('latest_news'), showSeeAll: true),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: Builder(
                builder: (context) {
                  final total = _newsItems.length;
                  final freeShown = isAuth ? total : (total < 2 ? total : 2);
                  final itemCount = isAuth ? total : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) {
                        return const LoginGateCarouselCard(width: 280, height: 260);
                      }
                      final article = _newsItems[index];
                      return NewsCard(
                        article: article,
                        langCode: langCode,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => ArticleDetailScreen(article: article),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],

        // News Section
        if (_articles.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
              child: _buildSectionTitle(
                context,
                langCode == 'fr' ? 'Actualités' : 'News',
                showSeeAll: true,
                onSeeAll: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const ArticlesScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: Builder(
                builder: (context) {
                  final total = _articles.length;
                  final freeShown = isAuth ? total : (total < 2 ? total : 2);
                  final itemCount = isAuth ? total : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) {
                        return const LoginGateCarouselCard(width: 280, height: 260);
                      }
                      final article = _articles[index];
                      return NewsCard(
                        article: article,
                        langCode: langCode,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => ArticleDetailScreen(article: article),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],

        // Priority Agendas Section
        if (_apiPriorityAgendas != null && _apiPriorityAgendas!.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
              child: _buildSectionTitle(context, 'Priority Agendas'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPriorityAgendasSection(context, isAuth),
            ),
          ),
        ],

        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    ),
    );
  }

  Widget _buildAnnouncementBanner(BuildContext context, String langCode) {
    final banner = _announcementBanner!;
    final text = langCode == 'fr'
        ? (banner['text_fr'] ?? banner['text'] ?? '')
        : (banner['text'] ?? '');
    final bgColorHex = banner['background_color'] as String? ?? '#409843';
    final bgColor = _hexToColor(bgColorHex);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _announcementDismissed = true),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePromptCard(BuildContext context, String langCode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = langCode != 'fr';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1B3A1C), const Color(0xFF2D4A2E)]
                : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.burundiGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.burundiGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                color: AppColors.burundiGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Complete Your Profile' : 'Compl\u00e9tez votre profil',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEn
                        ? 'Add your details for a personalised experience'
                        : 'Ajoutez vos informations pour une exp\u00e9rience personnalis\u00e9e',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: () => DeepLinkRouter().navigate('/profile-completion'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isEn ? 'Go' : 'Aller'),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                setState(() => _profilePromptDismissed = true);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('profile_prompt_dismissed', true);
              },
              child: Icon(
                Icons.close,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;


    // Only show if user is authenticated
    if (!authProvider.isAuthenticated) {
      return const SizedBox.shrink();
    }

    // Get time-based greeting
    final hour = DateTime.now().hour;
    String greeting;

    if (hour >= 5 && hour < 12) {
      greeting = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    final userName = authProvider.userName ?? 'User';
    final isVerified = authProvider.isVerified;
    final badgeType = authProvider.badgeType;

    final greetingColor = isDark ? const Color(0xFF8FB7A3) : const Color(0xFF4A7C5D);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting,',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFamily: 'HeatherGreen',
              color: greetingColor,
            ),
          ),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    userName,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'HeatherGreen',
                      color: greetingColor,
                    ),
                  ),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                VerifiedBadge(badgeType: badgeType, size: 20),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSlideshow(BuildContext context, AppLocalizations l10n) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 400,
      width: screenWidth,
      child: Stack(
        children: [
          // Slideshow
          PageView.builder(
            controller: _heroPageController,
            onPageChanged: (index) {
              setState(() => _heroRawPage = index);
            },
            itemBuilder: (context, index) {
              if (_heroSlides.isEmpty) return const SizedBox.shrink();
              final slide = _heroSlides[index % _heroSlides.length];
              final imagePath = slide['image'] as String;
              final isNetwork = slide['isNetwork'] == true;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Background image — network or asset
                  if (isNetwork)
                    CachedNetworkImage(
                      imageUrl: imagePath,
                      fit: BoxFit.cover,
                      width: screenWidth,
                      height: 400,
                      placeholder: (context, url) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF409843), Color(0xFF2D6E31)],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF409843), Color(0xFF2D6E31)],
                          ),
                        ),
                        child: const Center(child: Icon(Icons.image, size: 64, color: Colors.white54)),
                      ),
                    )
                  else
                    Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      width: screenWidth,
                      height: 400,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF409843), Color(0xFF2D6E31)],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image, size: 64, color: Colors.white54),
                                const SizedBox(height: 8),
                                Text(
                                  imagePath.split('/').last,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  // Dark gradient overlay for better text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.2, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App bar row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48),
                      Row(
                        children: [
                          // Notification bell with unread badge
                          IconButton(
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.notifications_outlined, color: Colors.white),
                                ),
                                if (_unreadBadgeCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.burundiRed,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      child: Text(
                                        _unreadBadgeCount > 99 ? '99+' : '$_unreadBadgeCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: () async {
                              await Navigator.pushNamed(context, '/notifications');
                              // Small delay to ensure server has processed mark-as-read
                              await Future.delayed(const Duration(milliseconds: 300));
                              _loadUnreadCount();
                            },
                          ),
                          // Theme toggle
                          Consumer<ThemeProvider>(
                            builder: (context, themeProvider, _) {
                              return IconButton(
                                icon: Icon(
                                  themeProvider.isDarkMode
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  color: Colors.white,
                                ),
                                onPressed: () => themeProvider.toggleTheme(),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.auGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getHeroText('badge'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _getHeroText('title_line1'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_getHeroText('title_line2')} ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.auGold, Color(0xFFFFD700)],
                        ).createShader(bounds),
                        child: Text(
                          _getHeroText('year'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Slide label
                  Text(
                    _heroSlides.isNotEmpty ? (_heroSlides[_heroRawPage % _heroSlides.length]['label'] ?? '') : '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Zigzag + Dot indicators
                  Row(
                    children: [
                      CustomPaint(
                        size: const Size(60, 10),
                        painter: ZigzagLinePainter(),
                      ),
                      const SizedBox(width: 15),
                      if (_heroSlides.isNotEmpty)
                        ...List.generate(_heroSlides.length, (index) {
                          final activeIndex = _heroRawPage % _heroSlides.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            width: activeIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: activeIndex == index
                                  ? AppColors.auGold
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCardsSection(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _featureCardPageController,
            onPageChanged: (index) {
              setState(() => _featureRawPage = index);
            },
            itemBuilder: (context, index) {
              if (_featureCards.isEmpty) return const SizedBox.shrink();
              final card = _featureCards[index % _featureCards.length];
              final gradientColors = card['gradient'] as List<Color>;
              final imageUrl = card['imageUrl'] as String?;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: GestureDetector(
                  onTap: () => _handleFeatureCardTap(context, card),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background image or gradient fallback
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: gradientColors,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: gradientColors,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: gradientColors,
                              ),
                            ),
                          ),
                        // Gradient overlay using backend colors for text readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                gradientColors[0].withValues(alpha: 0.4),
                                gradientColors[1].withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                        // Pattern overlay
                        CustomPaint(
                          size: const Size(double.infinity, 180),
                          painter: CardPatternPainter(),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      card['title'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontFamily: 'HeatherGreen',
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black45,
                                            blurRadius: 3,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      card['description'] as String,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        fontSize: 13,
                                        height: 1.4,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black38,
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: _buildCardIcon(card, 40),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicators
        if (_featureCards.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_featureCards.length, (index) {
              final activeIndex = _featureRawPage % _featureCards.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: activeIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: activeIndex == index
                      ? AppColors.burundiGreen
                      : AppColors.burundiGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, AppLocalizations l10n) {
    final langCode = Localizations.localeOf(context).languageCode;
    final authProvider = context.read<AuthProvider>();
    final isLoggedIn = authProvider.isAuthenticated;
    final verificationProvider = context.read<VerificationProvider>();
    final isVerified = authProvider.isVerified || verificationProvider.isProfileVerified;
    final verificationRequestStatus = verificationProvider.requestStatus;
    final showVerification = isLoggedIn && !isVerified;
    final List<Map<String, dynamic>> items = [];

    // Auto-inject Youth Dialogue into Quick Access based on settings
    if (_ydSettings != null && _ydSettings!['is_visible'] == true) {
      final ydIsOpen = _ydSettings!['is_registration_open'] == true;
      final ydTitle = langCode == 'fr'
          ? (_ydSettings!['quick_access_title_fr'] as String? ?? '').isNotEmpty
              ? _ydSettings!['quick_access_title_fr'] as String
              : _ydSettings!['quick_access_title_en'] as String? ?? 'Youth Dialogue'
          : _ydSettings!['quick_access_title_en'] as String? ?? 'Youth Dialogue';
      final ydIconUrl = _ydSettings!['quick_access_icon_url'] as String? ?? '';
      final ydClosedMsg = langCode == 'fr'
          ? (_ydSettings!['registration_closed_message_fr'] as String? ?? '').isNotEmpty
              ? _ydSettings!['registration_closed_message_fr'] as String
              : _ydSettings!['registration_closed_message'] as String? ?? 'Registration is currently closed.'
          : _ydSettings!['registration_closed_message'] as String? ?? 'Registration is currently closed.';

      items.add(<String, dynamic>{
        'title': ydTitle,
        'icon': Icons.groups_rounded,
        'iconImageUrl': ydIconUrl.isNotEmpty ? Environment.fixMediaUrl(ydIconUrl) : '',
        'hasLiveDot': false,
        'badgeText': '',
        'badgeColor': '',
        'locked': !ydIsOpen,
        'onTap': ydIsOpen
            ? () => Navigator.pushNamed(context, '/youth-dialogue')
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ydClosedMsg),
                    backgroundColor: AppColors.auGold,
                  ),
                );
              },
      });
    }

    // Use API data if available (with visibility_rule filtering)
    if (_quickAccessItems != null && _quickAccessItems!.isNotEmpty) {
      final filteredApiItems = _quickAccessItems!.where((menuItem) {
        final rule = menuItem['visibility_rule'] as String? ?? '';
        if (rule.isEmpty) return true; // everyone
        if (rule == 'youth_dialogue_accepted') return _ydEligible;
        return true;
      }).toList();
      items.addAll(filteredApiItems.map((menuItem) {
        final title = langCode == 'fr' && menuItem['title_fr'] != null && (menuItem['title_fr'] as String).isNotEmpty
            ? menuItem['title_fr'] as String
            : menuItem['title_en'] as String;
        final iconName = menuItem['icon_name'] as String;
        final icon = _getIconFromName(iconName);
        final actionType = menuItem['action_type'] as String;
        final actionValue = menuItem['action_value'] as String;
        final hasLiveDot = menuItem['has_live_indicator'] as bool? ?? false;

        final badgeText = menuItem['badge_text'] as String? ?? '';
        final badgeColor = menuItem['badge_color'] as String? ?? '';

        return <String, dynamic>{
          'title': title,
          'icon': icon,
          'hasLiveDot': hasLiveDot,
          'badgeText': badgeText,
          'badgeColor': badgeColor,
          'onTap': () {
            if (actionType == 'route') {
              if (actionValue.startsWith('/')) {
                Navigator.pushNamed(context, actionValue);
              }
            } else if (actionType == 'url') {
              final uri = Uri.tryParse(actionValue);
              if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        };
      }));
    }

    // Build a set of action values already provided by the API to avoid duplicates
    final existingActionValues = <String>{};
    final existingTitles = <String>{};
    if (_quickAccessItems != null) {
      for (final item in _quickAccessItems!) {
        final av = item['action_value'] as String? ?? '';
        if (av.isNotEmpty) existingActionValues.add(av);
        final t = (item['title_en'] as String? ?? '').toLowerCase();
        final tFr = (item['title_fr'] as String? ?? '').toLowerCase();
        if (t.isNotEmpty) existingTitles.add(t);
        if (tFr.isNotEmpty) existingTitles.add(tFr);
      }
    }

    // Helper to check if a hardcoded item already exists in the API response
    bool isDuplicate(String actionValue, String titleEn, String titleFr) {
      if (existingActionValues.contains(actionValue)) return true;
      if (existingTitles.contains(titleEn.toLowerCase())) return true;
      if (existingTitles.contains(titleFr.toLowerCase())) return true;
      return false;
    }

    // Append hardcoded quick access items (only if not already in the API response)
    final hardcodedItems = <Map<String, dynamic>>[
      // --- New items ---
      if (!isDuplicate('/magazine', 'Magazine', 'Magazine'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Magazines' : 'Magazines',
          'icon': Icons.menu_book_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => widget.onSwitchTab?.call(1),
        },
      if (!isDuplicate('/live-feeds', 'Live Feeds', 'En direct'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'En direct' : 'Live Feeds',
          'icon': Icons.live_tv_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/live-feeds'),
        },
      if (!isDuplicate('/events', 'Events', '\u00c9v\u00e9nements'))
        <String, dynamic>{
          'title': langCode == 'fr' ? '\u00c9v\u00e9nements' : 'Events',
          'icon': Icons.event_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/events'),
        },
      if (!isDuplicate('/resources', 'Resources', 'Ressources'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Ressources' : 'Resources',
          'icon': Icons.folder_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/resources'),
        },
      if (showVerification && !isDuplicate('/verification-request', 'Get Verified', 'Vérification'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Vérification' : 'Get Verified',
          'icon': Icons.verified_rounded,
          'hasLiveDot': false,
          'badgeText': verificationRequestStatus == 'pending'
              ? (langCode == 'fr' ? 'En cours' : 'Pending')
              : '',
          'badgeColor': verificationRequestStatus == 'pending' ? '#FF9800' : '',
          'onTap': () => Navigator.pushNamed(context, '/verification-request'),
        },
      if (!isDuplicate('/support', 'Support', 'Assistance'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Assistance' : 'Support',
          'icon': Icons.support_agent_rounded,
          'hasLiveDot': false,
          'badgeText': isLoggedIn ? '' : (langCode == 'fr' ? 'Connexion' : 'Sign in'),
          'badgeColor': isLoggedIn ? '' : '#9E9E9E',
          'locked': !isLoggedIn,
          'onTap': isLoggedIn
              ? () => _showSupportOptions(context)
              : () => Navigator.pushNamed(context, '/auth'),
        },
      if (!isDuplicate('/news', 'News', 'Actualités'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Actualités' : 'News',
          'icon': Icons.article_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => widget.onSwitchTab?.call(2),
        },
      if (!isDuplicate('/translate', 'Phrasebook', 'Guide'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Guide' : 'Phrasebook',
          'icon': Icons.menu_book_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/translate'),
        },
      if (!isDuplicate('/weather', 'Weather', 'Météo'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Météo' : 'Weather',
          'icon': Icons.cloud_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/weather'),
        },
      if (!isDuplicate('/calendar', 'Calendar', 'Calendrier'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Calendrier' : 'Calendar',
          'icon': Icons.calendar_month_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/events'),
        },
      // --- Existing items ---
      if (!isDuplicate('/gallery', 'Gallery', 'Galerie'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Galerie' : 'Gallery',
          'icon': Icons.photo_library_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/gallery'),
        },
      if (!isDuplicate('/videos', 'Videos', 'Vid\u00e9os'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Vid\u00e9os' : 'Videos',
          'icon': Icons.play_circle_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/videos'),
        },
      if (!isDuplicate('/social-media', 'Follow Us', 'Suivez-nous'))
        <String, dynamic>{
          'title': langCode == 'fr' ? 'Suivez-nous' : 'Follow Us',
          'icon': Icons.share_rounded,
          'hasLiveDot': false,
          'badgeText': '',
          'badgeColor': '',
          'onTap': () => Navigator.pushNamed(context, '/social-media'),
        },
    ];
    items.addAll(hardcodedItems);

    return QuickAccessGrid(items: items);
  }

  Widget _buildPriorityAgendasSection(BuildContext context, bool isAuth) {
    // Use API data if available, otherwise show empty
    final agendas = _apiPriorityAgendas ?? [];

    final langCode = Localizations.localeOf(context).languageCode;

    // Theme colors per agenda for fallback backgrounds
    final Map<String, List<Color>> slugColors = {
      'water-sanitation': [const Color(0xFF0077B6), const Color(0xFF00B4D8)],
      'arise-initiative': [const Color(0xFFB8860B), const Color(0xFFDAA520)],
      'peace-security': [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
    };

    // Agenda-specific labels
    final Map<String, Map<String, String>> slugLabels = {
      'water-sanitation': {'en': 'SDG 6', 'fr': 'ODD 6', 'icon_label': 'water_drop'},
      'arise-initiative': {'en': 'AU 2063', 'fr': 'UA 2063', 'icon_label': 'trending_up'},
      'peace-security': {'en': 'APSA', 'fr': 'AAPS', 'icon_label': 'shield'},
    };

    // Login gate: 1 free, then banner, then blurred
    final totalCount = LoginGate.itemCountFor(
      actualCount: agendas.length,
      isAuthenticated: isAuth,
      freeItems: LoginGate.agendaFreeItems,
    );

    Widget buildAgendaCard(Map<String, dynamic> agenda) {
        final slug = agenda['slug'] as String?;
        final title = langCode == 'fr' ? (agenda['title_fr'] ?? agenda['title']) : agenda['title'];
        final description = langCode == 'fr' ? (agenda['description_fr'] ?? agenda['description']) : agenda['description'];
        final heroImage = agenda['hero_image'];
        final hasImage = heroImage != null && heroImage.toString().isNotEmpty;
        final fallbackColors = (slug != null && slugColors.containsKey(slug))
            ? slugColors[slug]!
            : [AppColors.burundiGreen, AppColors.auGold];
        final label = (slug != null && slugLabels.containsKey(slug))
            ? (langCode == 'fr' ? slugLabels[slug]!['fr']! : slugLabels[slug]!['en']!)
            : '';

        return InkWell(
            onTap: () {
              final agendaSlug = agenda['slug'] as String?;
              if (agendaSlug != null) {
                Navigator.pushNamed(context, '/$agendaSlug');
              }
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: fallbackColors[0].withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: fallbackColors[1].withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background - hero image or themed gradient
                    if (hasImage)
                      CachedNetworkImage(
                        imageUrl: Environment.fixMediaUrl(heroImage.toString()),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: fallbackColors,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: fallbackColors,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              fallbackColors[0],
                              Color.lerp(fallbackColors[0], fallbackColors[1], 0.5)!,
                              fallbackColors[1],
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),

                    // Color-tinted overlay for depth (uses theme color instead of pure black)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            fallbackColors[0].withValues(alpha: hasImage ? 0.5 : 0.15),
                            Colors.black.withValues(alpha: hasImage ? 0.55 : 0.25),
                          ],
                        ),
                      ),
                    ),

                    // Glossy shimmer highlight (diagonal)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: const Alignment(-1.0, -1.0),
                              end: const Alignment(0.0, 0.0),
                              colors: [
                                Colors.white.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Badge label (top-left)
                    if (label.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: fallbackColors[1].withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Content
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, label.isNotEmpty ? 32 : 16, 16, 16),
                      child: Row(
                        children: [
                          // Icon with glow effect
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.25),
                                  Colors.white.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: fallbackColors[1].withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getIconFromAgenda(agenda),
                              size: 30,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: fallbackColors[1].withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title as String,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black38,
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  description as String,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    height: 1.35,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom accent strip
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              fallbackColors[1],
                              fallbackColors[0],
                              fallbackColors[1],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        );
    }

    return Column(
      children: List.generate(totalCount, (index) {
        final slot = LoginGate.slotFor(
          index: index,
          actualCount: agendas.length,
          isAuthenticated: isAuth,
          freeItems: LoginGate.agendaFreeItems,
        );
        switch (slot) {
          case LoginGateSlot.free:
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: buildAgendaCard(agendas[index]),
            );
          case LoginGateSlot.banner:
            return const LoginGateBanner(
              margin: EdgeInsets.only(bottom: 14),
            );
          case LoginGateSlot.blurred:
            final dataIndex = LoginGate.dataIndexFor(index, LoginGate.agendaFreeItems);
            if (dataIndex == null || dataIndex >= agendas.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: LockedContentWrap(
                locked: true,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                child: buildAgendaCard(agendas[dataIndex]),
              ),
            );
          case LoginGateSlot.hidden:
            return const SizedBox.shrink();
        }
      }),
    );
  }

  /// Shows uploaded icon image if available, otherwise falls back to Material icon.
  Widget _buildCardIcon(Map<String, dynamic> card, double size) {
    final iconImageUrl = card['iconImageUrl'] as String? ?? '';
    if (iconImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: Environment.fixMediaUrl(iconImageUrl),
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (_, _) => Icon(
          card['icon'] as IconData? ?? Icons.stars,
          color: Colors.white,
          size: size,
        ),
        errorWidget: (_, _, _) => Icon(
          card['icon'] as IconData? ?? Icons.stars,
          color: Colors.white,
          size: size,
        ),
      );
    }
    return Icon(
      card['icon'] as IconData? ?? Icons.stars,
      color: Colors.white,
      size: size,
    );
  }

  void _handleFeatureCardTap(BuildContext context, Map<String, dynamic> card) {
    final actionType = card['actionType'] as String?;
    final actionValue = card['actionValue'] as String?;

    // Special overrides: external URL or a different app route
    if (actionType == 'url' && actionValue != null && actionValue.isNotEmpty) {
      final uri = Uri.tryParse(actionValue);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (actionType == 'route' && actionValue != null && actionValue.isNotEmpty && actionValue != '/feature-detail') {
      if (actionValue.startsWith('/')) {
        Navigator.pushNamed(context, actionValue);
      }
      return;
    }

    // Link to event with registration: action_type='event' navigates to event detail
    if (actionType == 'event' && actionValue != null && actionValue.isNotEmpty) {
      // Try to find the event in loaded event cards
      final eventId = int.tryParse(actionValue);
      if (eventId != null && _apiEventCards != null) {
        final matchingEvent = _apiEventCards!.where((e) => e.id == eventId).toList();
        if (matchingEvent.isNotEmpty) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => EventDetailScreen(event: matchingEvent.first),
            ),
          );
          return;
        }
      }
      // Fallback: navigate to calendar
      Navigator.pushNamed(context, '/calendar');
      return;
    }

    // Default: always open the detail page
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => FeatureCardDetailScreen(cardData: card),
      ),
    );
  }

  IconData _getIconFromName(String iconName) {
    // Map common icon names to IconData
    final iconMap = {
      'stars': Icons.stars,
      'travel_explore': Icons.travel_explore,
      'gavel': Icons.gavel,
      'security': Icons.security,
      'public': Icons.public,
      'handshake': Icons.handshake,
      'groups': Icons.groups,
      'policy': Icons.policy,
      'auto_stories': Icons.auto_stories,
      'campaign': Icons.campaign,
      'flag': Icons.flag,
      'workspace_premium': Icons.workspace_premium,
      // Quick access icons
      'play_circle_filled': Icons.play_circle_filled_rounded,
      'folder_copy': Icons.folder_copy_rounded,
      'article': Icons.article_rounded,
      'translate': Icons.translate_rounded,
      'cloud': Icons.cloud_rounded,
      'calendar_month': Icons.calendar_month_rounded,
      'live_tv': Icons.live_tv,
      'menu_book': Icons.menu_book,
    };

    return iconMap[iconName] ?? Icons.stars;
  }

  IconData _getIconFromAgenda(Map<String, dynamic> agenda) {
    final iconName = agenda['icon_name'] as String?;
    final iconMap = {
      'water_drop': Icons.water_drop,
      'trending_up': Icons.trending_up,
      'security': Icons.security,
      'public': Icons.public,
      'groups': Icons.groups,
      'gavel': Icons.gavel,
      'handshake': Icons.handshake,
      'landscape': Icons.landscape,
      'school': Icons.school,
      'health_and_safety': Icons.health_and_safety,
      'agriculture': Icons.agriculture,
      'business': Icons.business,
    };
    return iconMap[iconName] ?? Icons.star;
  }

  Widget _buildTrendingCard(Map<String, dynamic> item, int rank, String langCode, bool isAuth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = item['content_title']?.toString() ?? (langCode == 'fr' ? 'Contenu' : 'Content');
    final contentType = item['content_type']?.toString() ?? 'article';

    // Rank colors
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = AppColors.auGold;
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/trending'),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rank <= 3
                ? rankColor.withValues(alpha: 0.4)
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: rankColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.trending_up_rounded, size: 16, color: AppColors.burundiGreen),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              contentType.substring(0, 1).toUpperCase() + contentType.substring(1),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMagazineSectionTitle(BuildContext context, String langCode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.burundiGreen, AppColors.auGold],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              langCode == 'fr' ? 'Derniers Magazines' : 'Latest Magazines',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            // Switch to the Magazines tab (index 1)
            widget.onSwitchTab?.call(1);
          },
          child: Row(
            children: [
              Text(
                langCode == 'fr' ? 'Voir tout' : 'See All',
                style: const TextStyle(color: AppColors.burundiGreen),
              ),
              const Icon(Icons.chevron_right, color: AppColors.burundiGreen, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMagazineCard(BuildContext context, MagazineEdition magazine, String langCode, bool isAuth) {
    final title = magazine.getTitle(langCode);
    return GestureDetector(
      onTap: () {
        final url = magazine.openablePdfUrl;
        if (url.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(langCode == 'fr'
                  ? 'PDF pas encore disponible.'
                  : 'PDF not available yet.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => PdfViewerScreen(
              pdfUrl: url,
              title: title,
              magazineId: magazine.id,
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: magazine.coverImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: magazine.coverImageUrl,
                      width: 140,
                      height: 170,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 140,
                        height: 170,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 140,
                        height: 170,
                        color: Colors.grey[300],
                        child: const Icon(Icons.menu_book, size: 40, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 140,
                      height: 170,
                      color: Colors.grey[300],
                      child: const Icon(Icons.menu_book, size: 40, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 6),
            // Title
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, {bool showSeeAll = false, VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.burundiGreen, AppColors.auGold],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (showSeeAll)
          TextButton(
            onPressed: onSeeAll ?? () => widget.onSwitchTab?.call(2),
            child: const Row(
              children: [
                Text(
                  'See All',
                  style: TextStyle(color: AppColors.burundiGreen),
                ),
                Icon(Icons.chevron_right, color: AppColors.burundiGreen, size: 18),
              ],
            ),
          ),
      ],
    );
  }

  void _showSupportOptions(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = context.read<LanguageProvider>().languageCode;

    // Fetch live agent status from backend
    bool liveAgentOnline = false;
    try {
      final settings = await ApiService().getSettings();
      if (settings != null) {
        liveAgentOnline = settings.liveAgentOnline;
      }
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                langCode == 'fr' ? 'Comment souhaitez-vous nous contacter ?' : 'How would you like to reach us?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Email Support — always available
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.email_rounded, color: AppColors.burundiGreen, size: 28),
                ),
                title: Text(
                  langCode == 'fr' ? 'Support par email' : 'Email Support',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(langCode == 'fr' ? 'Nous répondons sous 24 heures' : 'We respond within 24 hours'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/support-tickets');
                },
              ),
              const SizedBox(height: 8),

              // Live Agent — only active when admin toggled ON
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: liveAgentOnline
                        ? AppColors.burundiGreen.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: liveAgentOnline ? AppColors.burundiGreen : Colors.grey,
                    size: 28,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      langCode == 'fr' ? 'Agent en direct' : 'Live Agent',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: liveAgentOnline
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: liveAgentOnline ? Colors.green : Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        liveAgentOnline
                            ? (langCode == 'fr' ? 'EN LIGNE' : 'ONLINE')
                            : (langCode == 'fr' ? 'HORS LIGNE' : 'OFFLINE'),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  liveAgentOnline
                      ? (langCode == 'fr' ? 'Discutez avec un agent maintenant' : 'Chat with a support agent now')
                      : (langCode == 'fr' ? 'Aucun agent disponible pour le moment' : 'No agents available right now'),
                  style: TextStyle(color: liveAgentOnline ? null : Colors.grey),
                ),
                trailing: liveAgentOnline ? const Icon(Icons.chevron_right) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                enabled: liveAgentOnline,
                onTap: liveAgentOnline
                    ? () async {
                        Navigator.pop(ctx);
                        try {
                          final api = ApiService();
                          final result = await api.createTicket(
                            'Live Chat Support',
                            'Started a live chat session.',
                          );
                          if (context.mounted) {
                            Navigator.pushNamed(
                              context,
                              '/ticket-conversation',
                              arguments: result['id'],
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to start live chat: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
