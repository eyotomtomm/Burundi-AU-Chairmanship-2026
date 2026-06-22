import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../config/app_colors.dart';
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
import '../widgets/quick_access_grid.dart';
import '../widgets/news_card.dart';
import '../widgets/event_card.dart';
import '../widgets/section_title.dart';
import '../widgets/announcement_banner.dart';
import '../widgets/profile_prompt_card.dart';
import '../widgets/welcome_banner.dart';
import '../widgets/trending_card.dart';
import '../widgets/magazine_card.dart';
import '../widgets/support_options_modal.dart';
import '../widgets/hero_slideshow.dart';
import '../widgets/feature_cards_section.dart';
import '../widgets/priority_agendas_section.dart';
import '../../scanner/qr_scanner_screen.dart';
import '../../youth_dialogue/youth_dialogue_main_screen.dart';
import '../../../widgets/login_gate.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/async_content_view.dart';

class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const HomeTab({super.key, this.onSwitchTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
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
  String _lastErrorMessage = '';

  List<Map<String, dynamic>>? _trendingItems;
  List<Map<String, dynamic>> _announcementBanners = [];
  final Set<int> _dismissedAnnouncementIds = {};
  Timer? _announcementTimer;
  Map<String, dynamic>? _appSettings;
  bool _ydEligible = false;
  Map<String, dynamic>? _ydSettings;
  bool _showProfilePrompt = false;
  bool _profilePromptDismissed = false;
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

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
    return '';
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
    _loadAnnouncementBanners();
    _loadTrendingContent();
    _startHeroAutoSlide();
    _startFeatureAutoSlide();
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
    _featureTimer?.cancel();
    _badgeTimer?.cancel();
    _announcementTimer?.cancel();
    _heroPageController.dispose();
    _featureCardPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-fetch announcements when app comes back to foreground
      _loadAnnouncementBanners();
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

  Future<void> _loadAnnouncementBanners() async {
    try {
      final banners = await ApiService().getAnnouncementBanners();
      if (!mounted) return;
      // Merge: keep showing existing banners that the API still returns,
      // add any new ones, and remove ones the backend deactivated.
      final newIds = banners.map((b) => b['id']).toSet();
      // Remove dismissed IDs that no longer exist in the API response
      _dismissedAnnouncementIds.removeWhere((id) => !newIds.contains(id));
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
        api.getQuickAccessMenu().catchError((_) => <Map<String, dynamic>>[]),
      ]).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      final homeFeed = results[0] as Map<String, dynamic>;
      _cacheHomeFeed(homeFeed);
      _applyHomeFeedData(
        homeFeed,
        results[1] as List<Map<String, dynamic>>,
        results[2] as List<Map<String, dynamic>>,
        results[3] as List<Map<String, dynamic>>,
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

  void _fetchYouthDialogueData() {
    final api = ApiService();
    final isAuth = context.read<AuthProvider>().isAuthenticated;
    api.youthDialogueSettings().then((data) {
      if (mounted) setState(() => _ydSettings = data);
    }).catchError((_) {});
    if (isAuth) {
      api.youthDialogueEligibility().then((data) {
        if (mounted) setState(() => _ydEligible = data['eligible'] == true);
      }).catchError((_) {});
    }
  }

  void _applyHomeFeedData(
    Map<String, dynamic> homeFeed,
    List<Map<String, dynamic>> priorityAgendas,
    List<Map<String, dynamic>> heroTextData,
    List<Map<String, dynamic>> quickAccessMenu,
  ) {
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

    final heroTextMap = <String, String>{};
    for (final item in heroTextData) {
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

    final settingsData = homeFeed['settings'] as Map<String, dynamic>? ?? {};
    _cacheFeatureFlags(settingsData);

    setState(() {
      _appSettings = settingsData;
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

  void _startHeroAutoSlide() {
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _heroSlides.isEmpty || !_heroPageController.hasClients) return;
      try {
        if (_heroPageController.positions.isEmpty) return;
        if (_heroPageController.position.haveDimensions) {
          _heroPageController.animateToPage(_heroRawPage + 1,
            duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
        }
      } catch (_) {}
    });
  }

  void _startFeatureAutoSlide() {
    _featureTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _featureCards.isEmpty || !_featureCardPageController.hasClients) return;
      try {
        if (_featureCardPageController.positions.isEmpty) return;
        if (_featureCardPageController.position.haveDimensions) {
          _featureCardPageController.animateToPage(_featureRawPage + 1,
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
      color: AppColors.burundiGreen,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeroSlideshow(
              pageController: _heroPageController,
              heroSlides: _heroSlides,
              currentRawPage: _heroRawPage,
              unreadBadgeCount: _unreadBadgeCount,
              getHeroText: _getHeroText,
              onNotificationTap: () async {
                await Navigator.pushNamed(context, '/notifications');
                await Future.delayed(const Duration(milliseconds: 300));
                _loadUnreadCount();
              },
              onPageChanged: (i) => setState(() => _heroRawPage = i),
            ),
          ),
          ..._announcementBanners
              .where((b) => !_dismissedAnnouncementIds.contains(b['id']))
              .map((b) => SliverToBoxAdapter(
                    key: ValueKey('announcement_${b['id']}'),
                    child: AnnouncementBanner(
                      key: ValueKey('banner_${b['id']}'),
                      banner: b,
                      langCode: langCode,
                      onDismiss: () => setState(() {
                        if (b['id'] != null) _dismissedAnnouncementIds.add(b['id'] as int);
                      }),
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
          if (_featureCards.isNotEmpty)
            SliverToBoxAdapter(
              child: FeatureCardsSection(
                pageController: _featureCardPageController,
                featureCards: _featureCards,
                currentRawPage: _featureRawPage,
                onPageChanged: (i) => setState(() => _featureRawPage = i),
                eventCards: _apiEventCards,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(title: l10n.translate('quick_access')),
                  const SizedBox(height: 12),
                  _buildQuickAccessGrid(context, l10n),
                ],
              ),
            ),
          ),
          if (_apiEventCards != null && _apiEventCards!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
                child: SectionTitle(
                  title: langCode == 'fr' ? 'Prochains Événements' : 'Upcoming Events',
                  showSeeAll: true,
                  onSeeAll: () => Navigator.pushNamed(context, '/events'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Builder(builder: (context) {
                  final total = _apiEventCards!.length;
                  final freeShown = isAuth ? total : (total < 2 ? total : 2);
                  final itemCount = isAuth ? total : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) return const LoginGateCarouselCard(width: 260, height: 200);
                      final event = _apiEventCards![index];
                      return EventCard(event: event, langCode: langCode,
                        onTap: () {
                          if (event.isYouthDialogue) {
                            Navigator.push(context, CupertinoPageRoute(builder: (_) => const YouthDialogueMainScreen()));
                          } else {
                            Navigator.push(context, CupertinoPageRoute(builder: (_) => EventDetailScreen(event: event, scrollToComments: false)));
                          }
                        });
                    },
                  );
                }),
              ),
            ),
          ],
          if (_apiMagazines != null && _apiMagazines!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
                child: MagazineSectionTitle(langCode: langCode, onSeeAll: () => widget.onSwitchTab?.call(2)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: Builder(builder: (context) {
                  final total = _apiMagazines!.length;
                  final freeShown = isAuth ? total : (total < 2 ? total : 2);
                  final itemCount = isAuth ? total : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) return const LoginGateCarouselCard(width: 160, height: 220);
                      return MagazineCard(magazine: _apiMagazines![index], langCode: langCode);
                    },
                  );
                }),
              ),
            ),
          ],
          if (_trendingItems != null && _trendingItems!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
                child: SectionTitle(title: langCode == 'fr' ? 'Tendances' : 'Trending'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 110,
                child: Builder(builder: (context) {
                  final capped = _trendingItems!.length > 5 ? 5 : _trendingItems!.length;
                  final freeShown = isAuth ? capped : (capped < 2 ? capped : 2);
                  final itemCount = isAuth ? capped : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) return const LoginGateCarouselCard(width: 240, height: 110);
                      return TrendingCard(item: _trendingItems![index], rank: index + 1, langCode: langCode,
                        onTap: () => Navigator.pushNamed(context, '/trending'));
                    },
                  );
                }),
              ),
            ),
          ],
          if (_newsItems.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
                child: SectionTitle(title: l10n.translate('latest_news'), showSeeAll: true),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 260,
                child: Builder(builder: (context) {
                  final total = _newsItems.length;
                  final freeShown = isAuth ? total : (total < 2 ? total : 2);
                  final itemCount = isAuth ? total : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) return const LoginGateCarouselCard(width: 280, height: 260);
                      final article = _newsItems[index];
                      return NewsCard(article: article, langCode: langCode,
                        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ArticleDetailScreen(article: article, scrollToComments: false))));
                    },
                  );
                }),
              ),
            ),
          ],
          if (_articles.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
                child: SectionTitle(
                  title: langCode == 'fr' ? 'Actualités' : 'News',
                  showSeeAll: true,
                  onSeeAll: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const ArticlesScreen())),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 260,
                child: Builder(builder: (context) {
                  final total = _articles.length;
                  final freeShown = isAuth ? total : (total < 2 ? total : 2);
                  final itemCount = isAuth ? total : freeShown + 1;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (!isAuth && index == freeShown) return const LoginGateCarouselCard(width: 280, height: 260);
                      final article = _articles[index];
                      return NewsCard(article: article, langCode: langCode,
                        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ArticleDetailScreen(article: article, scrollToComments: false))));
                    },
                  );
                }),
              ),
            ),
          ],
          if (_apiPriorityAgendas != null && _apiPriorityAgendas!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
                child: SectionTitle(title: 'Priority Agendas'),
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
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
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
        'hasLiveDot': false, 'badgeText': '', 'badgeColor': '',
        'locked': !ydIsOpen,
        'onTap': ydIsOpen
            ? () => Navigator.pushNamed(context, '/youth-dialogue')
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ydClosedMsg), backgroundColor: AppColors.auGold)),
      });
    }

    if (_quickAccessItems != null && _quickAccessItems!.isNotEmpty) {
      final filtered = _quickAccessItems!.where((m) {
        final rule = m['visibility_rule'] as String? ?? '';
        if (rule.isEmpty) return true;
        if (rule == 'youth_dialogue_accepted') return _ydEligible;
        return true;
      }).toList();
      items.addAll(filtered.map((m) {
        final title = langCode == 'fr' && m['title_fr'] != null && (m['title_fr'] as String).isNotEmpty
            ? m['title_fr'] as String : m['title_en'] as String;
        final icon = _getIconFromName(m['icon_name'] as String);
        final actionType = m['action_type'] as String;
        final actionValue = m['action_value'] as String;
        return <String, dynamic>{
          'title': title, 'icon': icon,
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

    bool dup(String av, String en, String fr) =>
        existingActionValues.contains(av) || existingTitles.contains(en.toLowerCase()) || existingTitles.contains(fr.toLowerCase());

    // Staff-only QR Scanner
    if (authProvider.isStaff && !dup('/qr-scanner', 'QR Scanner', 'Scanner QR')) {
      items.add(<String, dynamic>{
        'title': langCode == 'fr' ? 'Scanner QR' : 'QR Scanner',
        'icon': Icons.qr_code_scanner_rounded,
        'hasLiveDot': false, 'badgeText': langCode == 'fr' ? 'Staff' : 'Staff', 'badgeColor': '#409843',
        'onTap': () => Navigator.pushNamed(context, '/qr-scanner'),
      });
    }

    // YD Scanner — for users with the usher role
    if (authProvider.isUsher && !dup('/yd-scanner', 'YD Scanner', 'Scanner YD')) {
      items.add(<String, dynamic>{
        'title': langCode == 'fr' ? 'Scanner YD' : 'YD Scanner',
        'icon': Icons.badge_rounded,
        'hasLiveDot': false, 'badgeText': langCode == 'fr' ? 'Staff' : 'Staff', 'badgeColor': '#409843',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerScreen(mode: 'youth_dialogue'))),
      });
    }

    final hardcoded = <Map<String, dynamic>>[
      if (!dup('/magazine', 'Magazine', 'Magazine'))
        {'title': langCode == 'fr' ? 'Magazines' : 'Magazines', 'icon': Icons.menu_book_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => widget.onSwitchTab?.call(2)},
      if (!dup('/live-feeds', 'Live Feeds', 'En direct'))
        {'title': langCode == 'fr' ? 'En direct' : 'Live Feeds', 'icon': Icons.live_tv_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/live-feeds')},
      if (!dup('/events', 'Events', 'Événements'))
        {'title': langCode == 'fr' ? 'Événements' : 'Events', 'icon': Icons.event_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/events')},
      if (!dup('/resources', 'Resources', 'Ressources'))
        {'title': langCode == 'fr' ? 'Ressources' : 'Resources', 'icon': Icons.folder_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/resources')},
      if (showVerification && verificationRequestStatus != 'pending' && !dup('/verification-request', 'Get Verified', 'Vérification'))
        {'title': langCode == 'fr' ? 'Vérification' : 'Get Verified', 'icon': Icons.verified_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/verification-request')},
      if (!dup('/support', 'Support', 'Assistance'))
        {'title': langCode == 'fr' ? 'Assistance' : 'Support', 'icon': Icons.support_agent_rounded, 'hasLiveDot': false, 'badgeText': isLoggedIn ? '' : (langCode == 'fr' ? 'Connexion' : 'Sign in'), 'badgeColor': isLoggedIn ? '' : '#9E9E9E', 'locked': !isLoggedIn, 'onTap': isLoggedIn ? () => showSupportOptionsModal(context) : () => Navigator.pushNamed(context, '/auth')},
      if (!dup('/news', 'News', 'Actualités'))
        {'title': langCode == 'fr' ? 'Actualités' : 'News', 'icon': Icons.article_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => widget.onSwitchTab?.call(2)},
      if (!dup('/translate', 'Phrasebook', 'Guide'))
        {'title': langCode == 'fr' ? 'Guide' : 'Phrasebook', 'icon': Icons.menu_book_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/translate')},
      if (!dup('/weather', 'Weather', 'Météo'))
        {'title': langCode == 'fr' ? 'Météo' : 'Weather', 'icon': Icons.cloud_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/weather')},
      if (!dup('/calendar', 'Calendar', 'Calendrier'))
        {'title': langCode == 'fr' ? 'Calendrier' : 'Calendar', 'icon': Icons.calendar_month_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/events')},
      if (!dup('/gallery', 'Gallery', 'Galerie'))
        {'title': langCode == 'fr' ? 'Galerie' : 'Gallery', 'icon': Icons.photo_library_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/gallery')},
      if (!dup('/videos', 'Videos', 'Vidéos'))
        {'title': langCode == 'fr' ? 'Vidéos' : 'Videos', 'icon': Icons.play_circle_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/videos')},
      if (!dup('/social-media', 'Follow Us', 'Suivez-nous'))
        {'title': langCode == 'fr' ? 'Suivez-nous' : 'Follow Us', 'icon': Icons.share_rounded, 'hasLiveDot': false, 'badgeText': '', 'badgeColor': '', 'onTap': () => Navigator.pushNamed(context, '/social-media')},
    ];
    items.addAll(hardcoded);

    return QuickAccessGrid(items: items);
  }
}
