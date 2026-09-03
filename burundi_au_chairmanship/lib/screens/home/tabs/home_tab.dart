import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../config/app_colors.dart';
import '../../../config/app_ds.dart';
import '../../../widgets/ds/ds_widgets.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../models/api_models.dart';
import '../../../models/magazine_model.dart';
import '../../../models/event_registration_model.dart';
import '../../../services/api_service.dart';
import '../../../services/splash_preloader.dart';
import '../../../services/firebase_messaging_service.dart';
import '../../../services/content_cache_service.dart';
import '../../../services/data_saver_service.dart';
import '../../../services/like_service.dart';
import '../../../utils/color_utils.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../articles/articles_screen.dart';
import '../../news/article_detail_screen.dart';
import '../../events/event_detail_screen.dart';
import '../../magazine/magazine_detail_screen.dart';
import '../../videos/video_detail_screen.dart';
import '../widgets/quick_access_grid.dart';
import '../widgets/news_card.dart';
import '../widgets/event_card.dart';
import '../widgets/section_title.dart';
import '../widgets/announcement_banner.dart';
import '../widgets/profile_prompt_card.dart';
import '../widgets/welcome_banner.dart';
import '../widgets/support_options_modal.dart';
import '../widgets/feature_cards_section.dart';
import '../widgets/priority_agendas_section.dart';
import '../widgets/facts_section.dart';
import '../../../utils/name_format.dart';
import '../../../widgets/verified_badge.dart';
import '../../facts/facts_list_screen.dart';
import '../../../models/fact_model.dart';
import '../../scanner/qr_scanner_screen.dart';
import '../../youth_dialogue/youth_dialogue_main_screen.dart';
import '../../../widgets/login_gate.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/async_content_view.dart';

/// One "New today" tile: a piece of real content plus where it goes.
class _HeroItem {
  final String image;
  final String pill;
  final DsTone tone;
  final String title;
  final String meta;
  final VoidCallback onTap;

  const _HeroItem({
    required this.image,
    required this.title,
    required this.onTap,
    this.pill = '',
    this.tone = DsTone.green,
    this.meta = '',
  });
}

class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const HomeTab({super.key, this.onSwitchTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  static const int _kLoopOffset = 10000;

  /// How many news items the home feed previews before "See all".
  static const int _kHomeNewsPreview = 3;
  static const int _kNewsPages = 3;
  // One NewsCard: 74px thumb (text column runs slightly taller) + 10 padding
  // x2 + 10 bottom margin. Scaled by the text scaler so large accessibility
  // sizes get more room rather than overflowing.
  static const double _kNewsCardHeight = 106;

  static const TextStyle _greetingStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: Colors.white);

  final PageController _heroPageController =
      PageController(initialPage: _kLoopOffset, viewportFraction: 0.66);
  Timer? _heroTimer;
  int _heroRawPage = _kLoopOffset;
  final PageController _newsPageController = PageController();
  int _newsPage = 0;

  List<HeroSlide>? _apiHeroSlides;
  List<Article>? _apiArticles;
  List<Article>? _apiNewsItems;
  List<Map<String, dynamic>>? _apiFeatureCards;
  List<MagazineEdition>? _apiMagazines;
  List<Map<String, dynamic>>? _apiVideos;
  List<Map<String, dynamic>>? _apiPriorityAgendas;
  List<EventRegistrationModel>? _apiEventCards;
  List<Fact>? _apiFacts;
  List<Fact> get _quotes =>
      _apiFacts?.where((f) => f.isQuote).toList() ?? const [];
  List<ApiLiveFeed> _apiLiveFeeds = const [];
  List<Map<String, dynamic>>? _quickAccessItems;
  Map<String, String> _quickAccessBadges = {};
  int _unreadBadgeCount = 0;
  Timer? _badgeTimer;
  bool _isLoading = true;
  bool _hasError = false;
  String _lastErrorMessage = '';

  List<Map<String, dynamic>>? _trendingItems;
  List<Map<String, dynamic>> _announcementBanners = [];
  final Set<int> _dismissedAnnouncementIds = {};
  Timer? _announcementTimer;
  Map<String, dynamic>? _appSettings;
  bool _ydEligible = false;
  bool _ydHasCredential = false;
  Map<String, dynamic>? _ydSettings;
  bool _showProfilePrompt = false;
  bool _profilePromptDismissed = false;
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  bool _isYdComingSoon() {
    if (_ydSettings == null) return false;
    final startStr = _ydSettings!['registration_start_date']?.toString() ?? '';
    if (startStr.isEmpty) return false;
    final start = DateTime.tryParse(startStr);
    if (start == null) return false;
    return DateTime.now().isBefore(start);
  }

  /// How many rail tiles admin allows for one content type (0 = hide it).
  int _railCount(String type, int fallback) {
    final v = _appSettings?['hero_rail_${type}_count'];
    return v is int ? v : (v is String ? int.tryParse(v) ?? fallback : fallback);
  }

  /// "New today" rail items, built from real content so each tile has a
  /// destination. Counts per type come from App Settings → Home Rail.
  /// Falls back to the curated hero slides when there is none.
  List<_HeroItem> get _heroItems {
    if (_appSettings?['hero_rail_enabled'] == false) return const [];
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final items = <_HeroItem>[];

    for (final feed in _apiLiveFeeds.take(_railCount('live', 2))) {
      items.add(_HeroItem(
        image: feed.thumbnail,
        pill: 'LIVE',
        tone: DsTone.red,
        title: fr && feed.titleFr.isNotEmpty ? feed.titleFr : feed.title,
        meta: fr ? 'En direct' : 'Live now',
        onTap: () => Navigator.pushNamed(context, '/live-feeds'),
      ));
    }

    for (final article in _articles.take(_railCount('news', 2))) {
      items.add(_HeroItem(
        image: article.listImage,
        pill: fr ? 'ACTU' : 'NEWS',
        tone: DsTone.gold,
        title: article.getTitle(fr ? 'fr' : 'en'),
        meta: _relativeTime(article.publishDate, fr),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) =>
                ArticleDetailScreen(article: article, scrollToComments: false),
          ),
        ),
      ));
    }

    for (final event in (_apiEventCards ?? const <EventRegistrationModel>[])
        .where((e) => !e.isEventPast)
        .take(_railCount('event', 2))) {
      final date = event.eventDate;
      items.add(_HeroItem(
        image: event.eventPoster ?? '',
        pill: fr ? 'ÉVÉNEMENT' : 'EVENT',
        tone: DsTone.white,
        title: event.getTitle(fr ? 'fr' : 'en'),
        meta: date == null
            ? ''
            : _daysUntil(date, fr),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => event.isYouthDialogue
                ? const YouthDialogueMainScreen()
                : EventDetailScreen(event: event, scrollToComments: false),
          ),
        ),
      ));
    }

    for (final mag in (_apiMagazines ?? const <MagazineEdition>[])
        .take(_railCount('magazine', 1))) {
      items.add(_HeroItem(
        image: mag.listImage,
        pill: 'MAGAZINE',
        tone: DsTone.green,
        title: mag.getTitle(fr ? 'fr' : 'en'),
        meta: _relativeTime(mag.publishDate, fr),
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => MagazineDetailScreen(magazine: mag)),
        ),
      ));
    }

    for (final video in (_apiVideos ?? const <Map<String, dynamic>>[])
        .take(_railCount('video', 1))) {
      final titleFr = video['title_fr']?.toString() ?? '';
      items.add(_HeroItem(
        image: (video['thumbnail_url'] ?? video['thumbnail'] ?? '').toString(),
        pill: fr ? 'VIDÉO' : 'VIDEO',
        tone: DsTone.neutral,
        title: fr && titleFr.isNotEmpty ? titleFr : (video['title']?.toString() ?? ''),
        meta: video['duration']?.toString() ?? '',
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) =>
                VideoDetailScreen(video: video, scrollToComments: false),
          ),
        ),
      ));
    }

    for (final card in _featureCards.take(_railCount('feature', 2))) {
      items.add(_HeroItem(
        image: card['imageUrl']?.toString() ?? '',
        pill: fr ? 'DÉCOUVRIR' : 'DISCOVER',
        tone: DsTone.white,
        title: card['title']?.toString() ?? '',
        meta: card['description']?.toString() ?? '',
        onTap: () => FeatureCardsSection.handleFeatureCardTap(context, card,
            eventCards: _apiEventCards),
      ));
    }

    if (items.isNotEmpty) return items;

    // Nothing published yet — show the admin-curated slides rather than a gap.
    return _heroSlides
        .map((s) => _HeroItem(
              image: s['image']?.toString() ?? '',
              title: s['label']?.toString() ?? '',
              onTap: () => widget.onSwitchTab?.call(1),
            ))
        .toList();
  }

  String _relativeTime(DateTime date, bool fr) {
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 24) {
      return '${fr ? "Aujourd'hui" : "Today"} · ${DateFormat('HH:mm').format(date)}';
    }
    if (diff.inDays < 7) return fr ? 'il y a ${diff.inDays} j' : '${diff.inDays}d ago';
    return DateFormat('d MMM', fr ? 'fr' : 'en').format(date);
  }

  String _daysUntil(DateTime date, bool fr) {
    final days = date.difference(DateTime.now()).inDays;
    if (days <= 0) return fr ? "Aujourd'hui" : 'Today';
    return fr ? 'dans $days j' : '$days days left';
  }

  List<Map<String, dynamic>> get _heroSlides {
    if (_apiHeroSlides != null && _apiHeroSlides!.isNotEmpty) {
      return _apiHeroSlides!.map((s) => {
        'image': s.image,
        'label': s.getLabel(Localizations.localeOf(context).languageCode),
        'isNetwork': true,
      }).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _featureCards {
    if (_apiFeatureCards != null && _apiFeatureCards!.isNotEmpty) return _apiFeatureCards!;
    return [];
  }

  List<Article> get _articles {
    return [
      ...?_apiNewsItems,
      ...?_apiArticles,
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key.startsWith('article:') && mounted) setState(() {});
    });
    // Defer _loadData to after the first frame so Localizations.localeOf(context)
    // is available (it depends on inherited widgets that aren't ready in initState).
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _loadUnreadCount();
    _loadDismissedAnnouncementIds().then((_) => _loadAnnouncementBanners());
    _loadTrendingContent();
    _startHeroAutoSlide();
    _badgeTimer = Timer.periodic(
      Duration(seconds: 60 * DataSaverService().pollingMultiplier),
      (_) => _loadUnreadCount(),
    );
    // Poll for new announcements every 2 minutes
    _announcementTimer = Timer.periodic(
      Duration(seconds: 120 * DataSaverService().pollingMultiplier),
      (_) => _loadAnnouncementBanners(),
    );
    _checkNotificationPermission();
    _checkProfileCompletion();
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    WidgetsBinding.instance.removeObserver(this);
    _heroTimer?.cancel();
    _badgeTimer?.cancel();
    _announcementTimer?.cancel();
    _heroPageController.dispose();
    _newsPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnreadCount();
      _loadAnnouncementBanners();
      // Re-render so the date and greeting match the current time of day.
      if (mounted) setState(() {});
    }
  }

  Future<void> _checkNotificationPermission() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final langCode = context.read<LanguageProvider>().languageCode;
    await FirebaseMessagingService().showPermissionDialog(context, langCode);
  }

  Future<void> _checkProfileCompletion() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('profile_prompt_dismissed') == true) return;
    final isIncomplete = (auth.userName == null || auth.userName!.isEmpty) ||
        (auth.nationality == null || auth.nationality!.isEmpty) ||
        (auth.gender == null || auth.gender!.isEmpty);
    if (isIncomplete && mounted) {
      setState(() => _showProfilePrompt = true);
      try {
        FirebaseAnalytics.instance.logEvent(name: 'profile_incomplete');
      } catch (_) {}
    }
  }

  Future<void> _loadUnreadCount() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;
    try {
      final count = await ApiService().getUnreadNotificationCount();
      if (mounted) setState(() => _unreadBadgeCount = count);
    } catch (_) {}
  }

  static const String _dismissedAnnouncementsKey = 'dismissed_announcement_ids';

  Future<void> _loadDismissedAnnouncementIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_dismissedAnnouncementsKey) ?? [];
      _dismissedAnnouncementIds.addAll(saved.map(int.parse));
    } catch (_) {}
  }

  Future<void> _saveDismissedAnnouncementIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _dismissedAnnouncementsKey,
        _dismissedAnnouncementIds.map((id) => id.toString()).toList(),
      );
    } catch (_) {}
  }

  Future<void> _loadAnnouncementBanners() async {
    try {
      final banners = await ApiService().getAnnouncementBanners();
      if (!mounted) return;
      setState(() => _announcementBanners = banners);
    } catch (_) {}
  }

  Future<void> _loadTrendingContent() async {
    try {
      final items = await ApiService().getTrendingContent();
      if (mounted) setState(() => _trendingItems = items);
    } catch (_) {}
  }

  Future<void> _cacheFeatureFlags(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('feature_newsletter_enabled', settings['newsletter_enabled'] ?? true);
    } catch (_) {}
  }

  void _cacheHomeFeed(Map<String, dynamic> homeFeed) =>
      ContentCacheService().cacheHomeFeed(homeFeed);

  Map<String, dynamic>? _loadCachedHomeFeed() =>
      ContentCacheService().getHomeFeed();

  Future<void> _loadData() async {
    // 1. Best case: splash preloader already has fresh data
    final preloaded = SplashPreloader.instance.consume();
    if (preloaded != null) {
      _cacheHomeFeed(preloaded.homeFeed);
      _applyHomeFeedData(
        preloaded.homeFeed,
        preloaded.priorityAgendas,
        preloaded.heroTextContent,
        preloaded.quickAccessMenu,
        quickAccessBadges: preloaded.quickAccessBadges,
      );
      _fetchYouthDialogueData();
      return;
    }

    // 2. Show cached data immediately so the user sees content right away,
    //    then refresh in the background.
    final cachedFeed = _loadCachedHomeFeed();
    if (cachedFeed != null) {
      _applyHomeFeedData(cachedFeed, [], [], []);
      _fetchYouthDialogueData();
      // Continue to fetch fresh data in the background (don't return)
    }

    // 3. Fetch fresh data from the network
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getHomeFeed(),
        api.getPriorityAgendas().catchError((_) => <Map<String, dynamic>>[]),
        api.getHeroTextContent().catchError((_) => <Map<String, dynamic>>[]),
        api.getQuickAccessMenuWithBadges().catchError((_) => <String, dynamic>{'items': <Map<String, dynamic>>[], 'badges': <String, String>{}}),
        api.getLiveFeeds(status: 'live').catchError((_) => <ApiLiveFeed>[]),
      ]).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      _apiLiveFeeds = (results[4] as List<ApiLiveFeed>);

      final homeFeed = results[0] as Map<String, dynamic>;
      _cacheHomeFeed(homeFeed);
      final qaData = results[3] as Map<String, dynamic>;
      _applyHomeFeedData(
        homeFeed,
        results[1] as List<Map<String, dynamic>>,
        results[2] as List<Map<String, dynamic>>,
        (qaData['items'] as List<dynamic>).cast<Map<String, dynamic>>(),
        quickAccessBadges: Map<String, String>.from(qaData['badges'] as Map? ?? {}),
      );
      _fetchYouthDialogueData();
    } catch (e, stack) {
      debugPrint('Failed to load home feed data: $e');
      Sentry.captureException(e, stackTrace: stack);
      if (!mounted) return;

      // If we already showed cached data above, don't show an error
      if (cachedFeed != null) return;

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _lastErrorMessage = e is ApiException && e.statusCode == 0
              ? 'no_internet'
              : 'server_error';
        });
      }
    }
  }

  static const _ydSettingsCacheKey = 'yd_settings_cache';
  static const _ydEligibleCacheKey = 'yd_eligible_cache';
  static const _ydHasCredentialCacheKey = 'yd_has_credential_cache';

  void _fetchYouthDialogueData() {
    final api = ApiService();
    final isAuth = context.read<AuthProvider>().isAuthenticated;

    // Load cached YD settings first so YD appears instantly
    if (_ydSettings == null) {
      SharedPreferences.getInstance().then((prefs) {
        final cached = prefs.getString(_ydSettingsCacheKey);
        if (cached != null && mounted && _ydSettings == null) {
          try {
            setState(() => _ydSettings = jsonDecode(cached) as Map<String, dynamic>);
          } catch (_) {}
        }
      });
    }

    // Load cached eligibility/credential state so tile unlocks instantly
    if (isAuth) {
      SharedPreferences.getInstance().then((prefs) {
        if (mounted) {
          final cachedEligible = prefs.getBool(_ydEligibleCacheKey) ?? false;
          final cachedCredential = prefs.getBool(_ydHasCredentialCacheKey) ?? false;
          if (cachedEligible || cachedCredential) {
            setState(() {
              _ydEligible = cachedEligible;
              _ydHasCredential = cachedCredential;
            });
          }
        }
      });
    }

    // Fetch fresh settings from API, then cache
    api.youthDialogueSettings().then((data) {
      if (mounted) setState(() => _ydSettings = data);
      // Cache for next time
      SharedPreferences.getInstance().then((prefs) {
        try { prefs.setString(_ydSettingsCacheKey, jsonEncode(data)); } catch (_) {}
      });
    }).catchError((_) {});

    if (isAuth) {
      api.youthDialogueEligibility().then((data) {
        final eligible = data['eligible'] == true;
        if (mounted) setState(() => _ydEligible = eligible);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_ydEligibleCacheKey, eligible);
        });
      }).catchError((_) {});

      api.youthDialogueStatus().then((data) {
        final hasCredential = data['has_credential'] == true;
        if (mounted) {
          setState(() => _ydHasCredential = hasCredential);
        }
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_ydHasCredentialCacheKey, hasCredential);
        });
      }).catchError((_) {});
    }
  }

  void _applyHomeFeedData(
    Map<String, dynamic> homeFeed,
    List<Map<String, dynamic>> priorityAgendas,
    List<Map<String, dynamic>> heroTextData,
    List<Map<String, dynamic>> quickAccessMenu, {
    Map<String, String> quickAccessBadges = const {},
  }) {
    final heroSlides = (homeFeed['hero_slides'] as List<dynamic>?)
        ?.map((j) => HeroSlide.fromJson(j as Map<String, dynamic>))
        .toList();
    final articles = (homeFeed['articles'] as List<dynamic>?)
        ?.map((j) => Article.fromJson(j as Map<String, dynamic>))
        .toList();
    final newsItems = (homeFeed['news_items'] as List<dynamic>?)
        ?.map((j) => Article.fromJson(j as Map<String, dynamic>))
        .toList();

    final langCode = mounted ? Localizations.localeOf(context).languageCode : 'en';
    final featureCardIcons = [Icons.stars, Icons.travel_explore, Icons.gavel, Icons.auto_stories];
    final rawCards = homeFeed['feature_cards'] as List<dynamic>? ?? [];
    final featureCards = rawCards.asMap().entries.map((entry) {
      final j = entry.value as Map<String, dynamic>;
      final gradStart = hexToColor(j['gradient_start'] ?? '#409843');
      final gradEnd = hexToColor(j['gradient_end'] ?? '#4CAF50');
      IconData icon = featureCardIcons[entry.key % featureCardIcons.length];
      final iconName = j['icon_name'] as String?;
      if (iconName != null && iconName.isNotEmpty) icon = _getIconFromName(iconName);
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

    // Use hero text from separate API call, or fall back to home feed bundle
    final heroTextSource = heroTextData.isNotEmpty
        ? heroTextData
        : (homeFeed['hero_text_content'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final heroTextMap = <String, String>{};
    for (final item in heroTextSource) {
      final key = item['key'] as String?;
      if (key == null) continue;
      heroTextMap[key] = langCode == 'fr' && item['text_fr'] != null && (item['text_fr'] as String).isNotEmpty
          ? item['text_fr'] as String
          : item['text_en'] as String;
    }

    final eventCards = (homeFeed['event_cards'] as List<dynamic>? ?? [])
        .map((j) => EventRegistrationModel.fromJson(j as Map<String, dynamic>)).toList();
    final magazines = (homeFeed['magazines'] as List<dynamic>? ?? [])
        .map((j) => MagazineEdition.fromJson(j as Map<String, dynamic>)).toList();
    final videos = (homeFeed['videos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final facts = (homeFeed['facts'] as List<dynamic>? ?? [])
        .map((j) => Fact.fromJson(j as Map<String, dynamic>)).toList();

    final settingsData = homeFeed['settings'] as Map<String, dynamic>? ?? {};
    _cacheFeatureFlags(settingsData);

    setState(() {
      _appSettings = settingsData;
      _apiHeroSlides = heroSlides;
      _apiArticles = articles;
      _apiNewsItems = newsItems;
      _apiFeatureCards = featureCards;
      _apiMagazines = magazines;
      _apiVideos = videos;
      _apiPriorityAgendas = priorityAgendas;
      _apiEventCards = eventCards
        ..sort((a, b) {
          if (a.isYouthDialogue != b.isYouthDialogue) {
            return a.isYouthDialogue ? -1 : 1;
          }
          return (a.eventDate ?? DateTime(2099)).compareTo(b.eventDate ?? DateTime(2099));
        });
      _apiFacts = facts;
      _quickAccessItems = quickAccessMenu;
      _quickAccessBadges = quickAccessBadges;
      _isLoading = false;
      _hasError = false;
    });
  }

  void _startHeroAutoSlide() {
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_heroPageController.hasClients) return;
      try {
        if (_heroPageController.positions.isEmpty) return;
        if (_heroPageController.position.haveDimensions) {
          _heroPageController.animateToPage(_heroRawPage + 1,
            duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
        }
      } catch (_) {}
    });
  }


  IconData _getIconFromName(String iconName) {
    const iconMap = {
      'stars': Icons.stars, 'travel_explore': Icons.travel_explore,
      'gavel': Icons.gavel, 'security': Icons.security,
      'public': Icons.public, 'handshake': Icons.handshake,
      'groups': Icons.groups, 'policy': Icons.policy,
      'auto_stories': Icons.auto_stories, 'campaign': Icons.campaign,
      'flag': Icons.flag, 'workspace_premium': Icons.workspace_premium,
      'play_circle_filled': Icons.play_circle_filled_rounded,
      'folder_copy': Icons.folder_copy_rounded, 'article': Icons.article_rounded,
      'translate': Icons.translate_rounded, 'cloud': Icons.cloud_rounded,
      'calendar_month': Icons.calendar_month_rounded,
      'live_tv': Icons.live_tv, 'menu_book': Icons.menu_book,
      'sos': Icons.sos, 'local_police': Icons.local_police,
      'local_fire_department': Icons.local_fire_department,
      'medical_services': Icons.medical_services,
      'local_hospital': Icons.local_hospital,
      'health_and_safety': Icons.health_and_safety,
      'support_agent': Icons.support_agent,
      'emergency': Icons.emergency, 'shield': Icons.shield,
      'phone': Icons.phone,
    };
    return iconMap[iconName] ?? Icons.stars;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    if (_isLoading) return const ShimmerHomeTabSkeleton();

    if (_hasError && _apiHeroSlides == null && _apiArticles == null) {
      final isNoInternet = _lastErrorMessage == 'no_internet';
      return AsyncContentView(
        state: AsyncContentState.error,
        errorIcon: isNoInternet ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
        errorMessage: isNoInternet ? l10n.noInternetTitle : l10n.serverErrorTitle,
        errorSubtitle: isNoInternet ? l10n.noInternetSubtitle : l10n.serverErrorSubtitle,
        onRetry: () { setState(() { _isLoading = true; _hasError = false; }); _loadData(); },
        onRefresh: () async { setState(() { _isLoading = true; _hasError = false; }); await _loadData(); },
        child: const SizedBox.shrink(),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        setState(() { _isLoading = true; _hasError = false; });
        await Future.wait([_loadData(), _loadAnnouncementBanners()]);
      },
      color: Ds.green,
      child: CustomScrollView(
        key: const PageStorageKey<String>('home_tab_scroll'),
        slivers: [
          SliverToBoxAdapter(child: _buildHomeHeader(context, l10n, langCode)),

          ..._announcementBanners
              .where((b) => !_dismissedAnnouncementIds.contains(b['id']))
              .map((b) => SliverToBoxAdapter(
                    key: ValueKey('announcement_${b['id']}'),
                    child: AnnouncementBanner(
                      key: ValueKey('banner_${b['id']}'),
                      banner: b,
                      langCode: langCode,
                      onDismiss: () {
                        if (b['id'] != null) {
                          setState(() => _dismissedAnnouncementIds.add(b['id'] as int));
                          _saveDismissedAnnouncementIds();
                        }
                      },
                    ),
                  )),
          if (_showProfilePrompt && !_profilePromptDismissed && isAuth)
            SliverToBoxAdapter(
              child: ProfilePromptCard(
                langCode: langCode,
                onDismiss: () async {
                  setState(() => _profilePromptDismissed = true);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('profile_prompt_dismissed', true);
                },
              ),
            ),
          SliverToBoxAdapter(child: WelcomeBanner(countdownConfig: _appSettings)),

          // --- Quick access ---
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                  child: SectionTitle(title: l10n.translate('quick_access')),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildQuickAccessGrid(context, l10n),
                ),
              ],
            ),
          ),

          // --- Discover Burundi (feature cards) ---
          if (_featureCards.isNotEmpty)
            SliverToBoxAdapter(
              child: FeatureCardsSection(
                featureCards: _featureCards,
                eventCards: _apiEventCards,
              ),
            ),

          // --- Quotes (quote-type facts only) ---
          if (_quotes.isNotEmpty && _appSettings?['facts_enabled'] == true) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: SectionTitle(
                  title: langCode == 'fr' ? 'Citations' : 'Quotes',
                  showSeeAll: true,
                  onSeeAll: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const FactsListScreen())),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _DiscoverRail(facts: _quotes, langCode: langCode),
            ),
          ],

          // --- Upcoming events ---
          if (_apiEventCards != null && _apiEventCards!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: SectionTitle(
                  title: _appSettings?[langCode == 'fr' ? 'section_title_events_fr' : 'section_title_events'] ?? (langCode == 'fr' ? 'À venir' : 'Upcoming events'),
                  showSeeAll: true,
                  onSeeAll: () => Navigator.pushNamed(context, '/events'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Guests see a couple of events, then a sign-in prompt.
                    final total = _apiEventCards!.length;
                    final freeShown = isAuth ? (total < 3 ? total : 3) : (total < 2 ? total : 2);
                    if (!isAuth && index == freeShown) {
                      return const LoginGateBanner(margin: EdgeInsets.only(bottom: 10));
                    }
                    final event = _apiEventCards![index];
                    return EventCard(
                      event: event,
                      langCode: langCode,
                      onTap: () {
                        if (!isAuth) {
                          Navigator.pushNamed(context, '/auth');
                          return;
                        }
                        if (event.isYouthDialogue) {
                          Navigator.push(context, CupertinoPageRoute(builder: (_) => const YouthDialogueMainScreen()));
                        } else {
                          Navigator.push(context, CupertinoPageRoute(builder: (_) => EventDetailScreen(event: event, scrollToComments: false)));
                        }
                      },
                    );
                  },
                  childCount: isAuth
                      ? (_apiEventCards!.length < 3 ? _apiEventCards!.length : 3)
                      : (_apiEventCards!.length < 2 ? _apiEventCards!.length : 2) + 1,
                ),
              ),
            ),
          ],

          // --- Latest news (news + articles are one feed) ---
          if (_articles.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: SectionTitle(
                  title: _appSettings?[langCode == 'fr' ? 'section_title_news_fr' : 'section_title_news'] ?? (langCode == 'fr' ? 'Récents' : 'Latest'),
                  showSeeAll: true,
                  onSeeAll: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const ArticlesScreen())),
                ),
              ),
            ),
            // Members swipe through 3 pages of 3; guests see 2 then a sign-in prompt.
            if (isAuth)
              SliverToBoxAdapter(child: _buildNewsPager(langCode))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= 2) {
                        return const LoginGateBanner(margin: EdgeInsets.only(bottom: 10));
                      }
                      final article = _articles[index];
                      return NewsCard(
                        article: article,
                        langCode: langCode,
                        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ArticleDetailScreen(article: article, scrollToComments: false))),
                      );
                    },
                    childCount: (_articles.length < 2 ? _articles.length : 2) + 1,
                  ),
                ),
              ),
          ],

          // --- Trending ---
          if (_trendingItems != null && _trendingItems!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: SectionTitle(
                  title: _appSettings?[langCode == 'fr' ? 'section_title_trending_fr' : 'section_title_trending'] ?? (langCode == 'fr' ? 'Tendances' : 'Trending'),
                  showSeeAll: true,
                  onSeeAll: () => Navigator.pushNamed(context, '/trending'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTrendingRow(_trendingItems![index], index + 1),
                  childCount: _trendingItems!.length > 3 ? 3 : _trendingItems!.length,
                ),
              ),
            ),
          ],

          // --- Our agenda ---
          if (_apiPriorityAgendas != null && _apiPriorityAgendas!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: SectionTitle(title: _appSettings?[langCode == 'fr' ? 'section_title_agendas_fr' : 'section_title_agendas'] ?? (langCode == 'fr' ? 'Notre agenda' : 'Our agenda')),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PriorityAgendasSection(
                  agendas: _apiPriorityAgendas!,
                  isAuthenticated: isAuth,
                  langCode: langCode,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: Ds.navSpace(context))),
        ],
      ),
    );
  }

  /// Green rounded header from the comp: greeting, avatar, and the
  /// "New today · Nouveautés" rail of hero slides.
  Widget _buildHomeHeader(
      BuildContext context, AppLocalizations l10n, String langCode) {
    final auth = context.watch<AuthProvider>();
    final fr = langCode == 'fr';
    // Verified accounts carry a real name and a title ("H.E.", "Ambassador"),
    // which must not be greeted as if the title were a first name.
    final accountName = (auth.verificationName?.isNotEmpty ?? false)
        ? auth.verificationName
        : auth.userName;
    final greetName = NameFormat.greetingName(accountName,
        title: auth.verificationTitle);
    final initials = NameFormat.initials(accountName);

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? (fr ? 'Bonjour' : 'Good morning')
        : hour < 18
            ? (fr ? 'Bon après-midi' : 'Good afternoon')
            : hour < 22
                ? (fr ? 'Bonsoir' : 'Good evening')
                : (fr ? 'Bonne nuit' : 'Good night');
    // Kirundi greeting follows the same clock as the localised one.
    final kirundi = hour < 12
        ? 'Mwaramutse'
        : hour < 22
            ? 'Mwiriwe'
            : 'Ijoro ryiza';
    final dateLine = DateFormat('EEEE d MMMM', fr ? 'fr' : 'en').format(now);

    final items = _heroItems;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 20, 20, 20),
      decoration: const BoxDecoration(
        color: Ds.green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dateLine · $kirundi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Not Flexible: two flexible children split the row
                        // between them, which ellipsised the greeting itself
                        // ("Good afte… Eyosias"). The greeting keeps its width;
                        // only the name below gives way.
                        Text(
                          greetName.isEmpty ? greeting : '$greeting,',
                          maxLines: 1,
                          style: _greetingStyle,
                        ),
                        // A long name is clipped rather than shrinking the
                        // whole greeting to an unreadable size.
                        if (greetName.isNotEmpty)
                          Flexible(
                            child: Text(
                              ' $greetName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _greetingStyle,
                            ),
                          ),
                        if (auth.isVerified) ...[
                          const SizedBox(width: 5),
                          VerifiedBadge(badgeType: auth.badgeType, size: 17),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DsHeaderAction(
                Icons.notifications_rounded,
                badge: _unreadBadgeCount,
                onTap: () async {
                  await Navigator.pushNamed(context, '/notifications');
                  _loadUnreadCount();
                },
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Ds.green)),
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final page = _heroRawPage % items.length;
              // At most 5 dots, so a long rail maps its page onto the 5 slots.
              final dots = items.length < 5 ? items.length : 5;
              final active = page * dots ~/ items.length;
              return Row(
              children: [
                Expanded(
                  child: Text(
                    fr ? 'Nouveautés' : 'New today',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Colors.white),
                  ),
                ),
                for (var i = 0; i < dots; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      width: i == active ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == active
                            ? Ds.gold
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            );
            }),
            const SizedBox(height: 10),
            SizedBox(
              height: 172,
              child: PageView.builder(
                controller: _heroPageController,
                padEnds: false,
                onPageChanged: (i) => setState(() => _heroRawPage = i),
                itemBuilder: (context, rawIndex) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _buildHeroTile(items[rawIndex % items.length]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Latest news as swipeable pages of 3 (max 3 pages / 9 articles).
  Widget _buildNewsPager(String langCode) {
    final max = _kHomeNewsPreview * _kNewsPages;
    final total = _articles.length < max ? _articles.length : max;
    final pages = (total / _kHomeNewsPreview).ceil();
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(_kNewsCardHeight) * _kHomeNewsPreview,
          child: PageView.builder(
            controller: _newsPageController,
            itemCount: pages,
            onPageChanged: (i) => setState(() => _newsPage = i),
            itemBuilder: (context, page) {
              final start = page * _kHomeNewsPreview;
              final end = (start + _kHomeNewsPreview).clamp(0, total);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final article in _articles.sublist(start, end))
                      NewsCard(
                        article: article,
                        langCode: langCode,
                        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ArticleDetailScreen(article: article, scrollToComments: false))),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (pages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: i == _newsPage ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == _newsPage ? Ds.green : Ds.ink(context).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTrendingRow(Map<String, dynamic> item, int rank) {
    final title = (item['content_title'] ?? '').toString();
    final type = (item['content_type'] ?? '').toString();
    final rankColor = switch (rank) {
      1 => Ds.red,
      2 => Ds.goldDeep,
      _ => Ds.green,
    };

    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      onTap: () => Navigator.pushNamed(context, '/trending'),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: rankColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ds.cardTitle(context)),
                if (type.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(type[0].toUpperCase() + type.substring(1),
                      style: Ds.meta(context)),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Ds.chevron),
        ],
      ),
    );
  }

  Widget _buildHeroTile(_HeroItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Ds.surface(context),
          borderRadius: BorderRadius.circular(Ds.rCard),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Ds.rCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.image.isEmpty)
                      const DsImagePlaceholder(radius: 0)
                    else
                      CachedNetworkImage(
                        imageUrl: Environment.fixMediaUrl(item.image),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const DsImagePlaceholder(radius: 0),
                        errorWidget: (_, _, _) =>
                            const DsImagePlaceholder(radius: 0),
                      ),
                    if (item.pill.isNotEmpty)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: DsPill(item.pill, tone: item.tone, dense: true),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: Ds.ink(context)),
                        ),
                      ),
                      if (item.meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Ds.muted(context))),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

    // Continental Dialogue is "present" only when it is switched on for this
    // device. Both the Dialogue tile and the SOS tile hang off this, so
    // turning Dialogue off removes Emergency with it.
    final ydPresent = _ydSettings != null &&
        _ydSettings!['is_visible'] == true &&
        _ydSettings!['is_device_banned'] != true;

    // Auto-inject Continental Dialogue into Quick Access based on settings
    // Hide entirely if device is banned from Continental Dialogue
    if (ydPresent) {
      final ydIsOpen = _ydSettings!['is_registration_open'] == true;
      final ydTitle = langCode == 'fr'
          ? (_ydSettings!['quick_access_title_fr'] as String? ?? '').isNotEmpty
              ? _ydSettings!['quick_access_title_fr'] as String
              : _ydSettings!['quick_access_title_en'] as String? ?? 'Continental Dialogue'
          : _ydSettings!['quick_access_title_en'] as String? ?? 'Continental Dialogue';
      final ydIconUrl = _ydSettings!['quick_access_icon_url'] as String? ?? '';
      final ydClosedMsg = langCode == 'fr'
          ? (_ydSettings!['registration_closed_message_fr'] as String? ?? '').isNotEmpty
              ? _ydSettings!['registration_closed_message_fr'] as String
              : _ydSettings!['registration_closed_message'] as String? ?? 'Registration is currently closed.'
          : _ydSettings!['registration_closed_message'] as String? ?? 'Registration is currently closed.';

      final isUsher = authProvider.isUsher;
      // Allow access for users who already registered (eligible or have credential)
      final canAccessYd = ydIsOpen || _ydEligible || _ydHasCredential;
      items.add(<String, dynamic>{
        'title': ydTitle,
        'icon': Icons.groups_rounded,
        'iconImageUrl': ydIconUrl.isNotEmpty ? Environment.fixMediaUrl(ydIconUrl) : '',
        'hasLiveDot': false,
        'badgeText': !isLoggedIn
            ? (langCode == 'fr' ? 'Connexion' : 'Sign in')
            : isUsher
                ? (langCode == 'fr' ? 'Scanner' : 'Scan Only')
                : ydIsOpen
                    ? (langCode == 'fr' ? 'Ouvert' : 'Open')
                    : (_ydHasCredential || _ydEligible)
                        ? (langCode == 'fr' ? 'Mon ID' : 'My ID')
                        : _isYdComingSoon()
                            ? (langCode == 'fr' ? 'Bientôt' : 'Coming Soon')
                            : (langCode == 'fr' ? 'Fermé' : 'Closed'),
        'badgeColor': !isLoggedIn ? '#9E9E9E'
            : isUsher ? '#9E9E9E'
            : ydIsOpen ? '#4CAF50'
            : (_ydHasCredential || _ydEligible) ? '#4CAF50'
            : _isYdComingSoon() ? '#FF9800'
            : '#9E9E9E',
        'locked': !isLoggedIn || isUsher || !canAccessYd,
        'onTap': !isLoggedIn
            ? () => Navigator.pushNamed(context, '/auth')
            : isUsher
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(langCode == 'fr'
                            ? 'Vous avez le rôle scanner. L\'inscription n\'est pas disponible.'
                            : 'You have the scanner role. Registration is not available.'),
                        backgroundColor: Colors.grey.shade700,
                      ),
                    );
                  }
                : canAccessYd
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

    if (_quickAccessItems != null && _quickAccessItems!.isNotEmpty) {
      // Youth Dialogue registration state (used for /youth-dialogue items)
      final ydIsOpen = _ydSettings?['is_registration_open'] == true;
      final ydClosedMsg = _ydSettings != null
          ? (langCode == 'fr'
              ? (_ydSettings!['registration_closed_message_fr'] as String? ?? '').isNotEmpty
                  ? _ydSettings!['registration_closed_message_fr'] as String
                  : _ydSettings!['registration_closed_message'] as String? ?? 'Registration is currently closed.'
              : _ydSettings!['registration_closed_message'] as String? ?? 'Registration is currently closed.')
          : 'Registration is currently closed.';

      final filtered = _quickAccessItems!.where((m) {
        final rule = m['visibility_rule'] as String? ?? '';
        if (rule == 'youth_dialogue_accepted' && !_ydEligible) return false;
        // Respect feature toggles for route-based items
        final route = m['action_value'] as String? ?? '';
        final titleEn = (m['title_en'] as String? ?? '').toLowerCase();
        if ((route == '/live-feeds' || route == '/live' || titleEn == 'live' || titleEn == 'live feeds') && _appSettings?['live_feeds_enabled'] == false) return false;
        if (route == '/discussions' && _appSettings?['discussions_enabled'] == false) return false;
        return true;
      }).toList();
      items.addAll(filtered.map((m) {
        final title = langCode == 'fr' && m['title_fr'] != null && (m['title_fr'] as String).isNotEmpty
            ? m['title_fr'] as String : m['title_en'] as String;
        final iconName = m['icon_name'] as String? ?? '';
        final icon = iconName.isNotEmpty ? _getIconFromName(iconName) : Icons.apps_rounded;
        final iconImageUrl = m['icon_image_url'] as String? ?? '';
        final actionType = m['action_type'] as String;
        final actionValue = m['action_value'] as String;
        final isYdRoute = actionValue == '/youth-dialogue';

        // Youth Dialogue items get special locked/sign-in behavior
        // Allow access for users who already registered (eligible or have credential)
        if (isYdRoute) {
          final canAccessYdRoute = ydIsOpen || _ydEligible || _ydHasCredential;
          return <String, dynamic>{
            'title': title, 'icon': icon,
            'iconImageUrl': iconImageUrl.isNotEmpty ? Environment.fixMediaUrl(iconImageUrl) : '',
            'hasLiveDot': m['has_live_indicator'] as bool? ?? false,
            'badgeText': !isLoggedIn
                ? (langCode == 'fr' ? 'Connexion' : 'Sign in')
                : (m['badge_text'] as String? ?? ''),
            'badgeColor': !isLoggedIn ? '#9E9E9E' : (m['badge_color'] as String? ?? ''),
            'locked': !isLoggedIn || !canAccessYdRoute,
            'onTap': !isLoggedIn
                ? () => Navigator.pushNamed(context, '/auth')
                : canAccessYdRoute
                    ? () => Navigator.pushNamed(context, '/youth-dialogue')
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ydClosedMsg), backgroundColor: AppColors.auGold)),
          };
        }

        return <String, dynamic>{
          'title': title, 'icon': icon,
          'iconImageUrl': iconImageUrl.isNotEmpty ? Environment.fixMediaUrl(iconImageUrl) : '',
          'hasLiveDot': m['has_live_indicator'] as bool? ?? false,
          'badgeText': m['badge_text'] as String? ?? '',
          'badgeColor': m['badge_color'] as String? ?? '',
          'onTap': () {
            if (actionType == 'route' && actionValue.startsWith('/')) {
              Navigator.pushNamed(context, actionValue);
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

    bool dup(String av, String en, String fr, [List<String> alts = const []]) =>
        existingActionValues.contains(av) || existingTitles.contains(en.toLowerCase()) || existingTitles.contains(fr.toLowerCase()) || alts.any((a) => existingTitles.contains(a.toLowerCase()));

    // Staff-only QR Scanner
    final qrScannerTitle = langCode == 'fr'
        ? (_appSettings?['qr_scanner_title_fr'] as String? ?? '').isNotEmpty
            ? _appSettings!['qr_scanner_title_fr'] as String
            : 'Scanner QR'
        : (_appSettings?['qr_scanner_title'] as String? ?? '').isNotEmpty
            ? _appSettings!['qr_scanner_title'] as String
            : 'QR Scanner';
    if (authProvider.isStaff && !dup('/qr-scanner', 'QR Scanner', 'Scanner QR')) {
      items.add(<String, dynamic>{
        'title': qrScannerTitle,
        'icon': Icons.qr_code_scanner_rounded,
        'isScanner': true,
        'hasLiveDot': false, 'badgeText': langCode == 'fr' ? 'Staff' : 'Staff', 'badgeColor': '#CE1126',
        'onTap': () => Navigator.pushNamed(context, '/qr-scanner'),
      });
    }

    // YD Scanner — for users with the usher role
    if (authProvider.isUsher && !dup('/yd-scanner', 'YD Scanner', 'Scanner YD')) {
      final ydScannerName = _ydSettings != null
          ? (langCode == 'fr'
              ? (_ydSettings!['scanner_title_fr'] as String? ?? '').isNotEmpty
                  ? _ydSettings!['scanner_title_fr'] as String
                  : (_ydSettings!['quick_access_title_fr'] as String? ?? '').isNotEmpty
                      ? _ydSettings!['quick_access_title_fr'] as String
                      : _ydSettings!['quick_access_title_en'] as String? ?? 'Continental Dialogue'
              : (_ydSettings!['scanner_title_en'] as String? ?? '').isNotEmpty
                  ? _ydSettings!['scanner_title_en'] as String
                  : _ydSettings!['quick_access_title_en'] as String? ?? 'Continental Dialogue')
          : 'Continental Dialogue';
      items.add(<String, dynamic>{
        'title': langCode == 'fr' ? 'Scanner $ydScannerName' : '$ydScannerName Scanner',
        'icon': Icons.qr_code_scanner_rounded,
        'isScanner': true,
        'hasLiveDot': false, 'badgeText': langCode == 'fr' ? 'Staff' : 'Staff', 'badgeColor': '#CE1126',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrScannerScreen(mode: 'youth_dialogue', programmeName: ydScannerName))),
      });
    }

    // Look up auto-badge from server for a given route
    String badge(String route) => _quickAccessBadges[route] ?? '';
    String badgeColor(String route) => badge(route).isNotEmpty ? '#E53935' : '';

    final hardcoded = <Map<String, dynamic>>[
      if (!dup('/magazine', 'Magazine', 'Magazine'))
        {'title': langCode == 'fr' ? 'Magazines' : 'Magazines', 'icon': Icons.menu_book_rounded, 'hasLiveDot': false, 'badgeText': badge('/magazine'), 'badgeColor': badgeColor('/magazine'), 'onTap': () => widget.onSwitchTab?.call(0)},
      if (_appSettings?['live_feeds_enabled'] != false && !dup('/live-feeds', 'Live Feeds', 'En direct', ['Live', 'Direct']))
        {'title': langCode == 'fr' ? 'En direct' : 'Live Feeds', 'icon': Icons.live_tv_rounded, 'hasLiveDot': false, 'badgeText': badge('/live-feeds'), 'badgeColor': badgeColor('/live-feeds'), 'onTap': () => Navigator.pushNamed(context, '/live-feeds')},
      if (!dup('/events', 'Events', 'Événements'))
        {'title': langCode == 'fr' ? 'Événements' : 'Events', 'icon': Icons.event_rounded, 'hasLiveDot': false, 'badgeText': badge('/calendar'), 'badgeColor': badgeColor('/calendar'), 'onTap': () => Navigator.pushNamed(context, '/events')},
      if (!dup('/resources', 'Resources', 'Ressources'))
        {'title': langCode == 'fr' ? 'Ressources' : 'Resources', 'icon': Icons.folder_rounded, 'hasLiveDot': false, 'badgeText': badge('/resources'), 'badgeColor': badgeColor('/resources'), 'onTap': () => Navigator.pushNamed(context, '/resources')},
      if (showVerification && verificationRequestStatus != 'pending' && !dup('/verification-request', 'Get Verified', 'Vérification'))
        {'title': langCode == 'fr' ? 'Vérification' : 'Get Verified', 'icon': Icons.verified_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/verification-request')},
      if (!dup('/support', 'Support', 'Assistance'))
        {'title': langCode == 'fr' ? 'Assistance' : 'Support', 'icon': Icons.support_agent_rounded, 'hasLiveDot': false, 'badgeText': isLoggedIn ? '' : (langCode == 'fr' ? 'Connexion' : 'Sign in'), 'badgeColor': isLoggedIn ? '' : '#9E9E9E', 'locked': !isLoggedIn, 'onTap': isLoggedIn ? () => showSupportOptionsModal(context) : () => Navigator.pushNamed(context, '/auth')},
      if (!dup('/news', 'News', 'Actualités'))
        {'title': langCode == 'fr' ? 'Actualités' : 'News', 'icon': Icons.article_rounded, 'hasLiveDot': false, 'badgeText': badge('/news'), 'badgeColor': badgeColor('/news'), 'onTap': () => widget.onSwitchTab?.call(1)},
      if (!dup('/translate', 'Phrasebook', 'Guide'))
        {'title': langCode == 'fr' ? 'Guide' : 'Phrasebook', 'icon': Icons.menu_book_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/translate')},
      if (!dup('/weather', 'Weather', 'Météo'))
        {'title': langCode == 'fr' ? 'Météo' : 'Weather', 'icon': Icons.cloud_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/weather')},
      if (!dup('/calendar', 'Calendar', 'Calendrier'))
        {'title': langCode == 'fr' ? 'Calendrier' : 'Calendar', 'icon': Icons.calendar_month_rounded, 'hasLiveDot': false, 'badgeText': badge('/calendar'), 'badgeColor': badgeColor('/calendar'), 'onTap': () => Navigator.pushNamed(context, '/events')},
      if (!dup('/gallery', 'Gallery', 'Galerie'))
        {'title': langCode == 'fr' ? 'Galerie' : 'Gallery', 'icon': Icons.photo_library_rounded, 'hasLiveDot': false, 'badgeText': badge('/gallery'), 'badgeColor': badgeColor('/gallery'), 'onTap': () => Navigator.pushNamed(context, '/gallery')},
      if (!dup('/videos', 'Videos', 'Vidéos'))
        {'title': langCode == 'fr' ? 'Vidéos' : 'Videos', 'icon': Icons.play_circle_rounded, 'hasLiveDot': false, 'badgeText': badge('/videos'), 'badgeColor': badgeColor('/videos'), 'onTap': () => Navigator.pushNamed(context, '/videos')},
      if (!dup('/social-media', 'Follow Us', 'Suivez-nous'))
        {'title': langCode == 'fr' ? 'Suivez-nous' : 'Follow Us', 'icon': Icons.share_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/social-media')},
      // Emergency is a Continental Dialogue facility — never a general tile.
      if (ydPresent && _ydHasCredential && !dup('/emergency', 'SOS', 'SOS'))
        {'title': 'SOS', 'icon': Icons.sos_rounded, 'isEmergency': true, 'hasLiveDot': false, 'badgeText': langCode == 'fr' ? 'Urgence' : 'Emergency', 'badgeColor': '#E53935', 'onTap': () => Navigator.pushNamed(context, '/emergency')},
    ];
    items.addAll(hardcoded);

    return QuickAccessGrid(items: items);
  }
}

/// Horizontal "Discover" rail — 158px cards, as in the comp.
class _DiscoverRail extends StatelessWidget {
  final List<Fact> facts;
  final String langCode;

  const _DiscoverRail({required this.facts, required this.langCode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: facts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => SizedBox(
          width: 158,
          child: FactCard(fact: facts[index], langCode: langCode, index: index),
        ),
      ),
    );
  }
}
