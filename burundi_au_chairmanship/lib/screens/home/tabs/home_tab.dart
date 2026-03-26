import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/verified_badge.dart';
import '../../../models/api_models.dart';
import '../../../models/magazine_model.dart';
import '../../../models/event_registration_model.dart';
import '../../../services/api_service.dart';
import '../../news/article_detail_screen.dart';
import '../../feature_card/feature_card_detail_screen.dart';
import '../../events/event_detail_screen.dart';
import '../../priority_agenda_detail_screen.dart';
import '../painters/zigzag_line_painter.dart';
import '../painters/card_pattern_painter.dart';
import '../widgets/quick_access_grid.dart';
import '../widgets/news_card.dart';
import '../widgets/feature_item.dart';
import '../widgets/event_card.dart';
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
  List<Map<String, dynamic>>? _apiFeatureCards;
  List<Map<String, dynamic>>? _apiPriorityAgendas;
  List<EventRegistrationModel>? _apiEventCards;
  Map<String, String>? _heroTextContent;
  List<Map<String, dynamic>>? _quickAccessItems;
  int _unreadBadgeCount = 0;
  Timer? _badgeTimer;
  bool _isLoading = true;

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

  String _getHeroText(String key) {
    if (_heroTextContent != null && _heroTextContent!.containsKey(key)) {
      return _heroTextContent![key]!;
    }
    // No fallback - return empty string
    return '';
  }

  /// Parse hex color string like "#1EB53A" into a Color
  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.isEmpty) return const Color(0xFF1EB53A);
    if (hex.length == 6) hex = 'FF$hex';
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return const Color(0xFF1EB53A);
    return Color(parsed);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _startHeroAutoSlide();
    _startFeatureAutoSlide();
    // Poll unread count every 60 seconds
    _badgeTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadUnreadCount());
  }

  Future<void> _loadUnreadCount() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;
    try {
      final api = ApiService();
      final count = await api.getUnreadSupportCount();
      if (mounted) setState(() => _unreadBadgeCount = count);
    } catch (_) {
      // Silently fail - badge is non-critical
    }
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService();
      final homeFeed = await api.getHomeFeed();
      if (!mounted) return;

      // Parse hero slides
      final heroSlides = (homeFeed['hero_slides'] as List<dynamic>?)
          ?.map((j) => HeroSlide.fromJson(j as Map<String, dynamic>))
          .toList();

      // Parse articles
      final articles = (homeFeed['articles'] as List<dynamic>?)
          ?.map((j) => Article.fromJson(j as Map<String, dynamic>))
          .toList();

      // Parse feature cards from API into the map format the UI expects
      final langCode = mounted ? Localizations.localeOf(context).languageCode : 'en';
      final featureCardIcons = [Icons.stars, Icons.travel_explore, Icons.gavel, Icons.auto_stories];
      final rawCards = homeFeed['feature_cards'] as List<dynamic>? ?? [];
      final featureCards = rawCards.asMap().entries.map((entry) {
        final j = entry.value as Map<String, dynamic>;
        final gradStart = _hexToColor(j['gradient_start'] ?? '#1EB53A');
        final gradEnd = _hexToColor(j['gradient_end'] ?? '#4CAF50');

        // Parse icon from icon_name or use fallback
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
          // Rich content fields for detail page
          'gradient_start': j['gradient_start'] ?? '#1EB53A',
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
          // Keep raw title fields for detail screen localization
          'title_raw': j['title'] ?? '',
          'title_fr': j['title_fr'] ?? '',
        };
      }).toList();

      // Fetch priority agendas
      final priorityAgendas = await api.getPriorityAgendas();

      // Fetch hero text content
      final heroTextData = await api.getHeroTextContent();
      final heroTextMap = <String, String>{};
      for (final item in heroTextData) {
        final key = item['key'] as String;
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

      // Fetch quick access menu
      final quickAccessMenu = await api.getQuickAccessMenu();

      setState(() {
        _apiHeroSlides = heroSlides;
        _apiArticles = articles;
        _apiFeatureCards = featureCards;
        _apiPriorityAgendas = priorityAgendas;
        _apiEventCards = eventCards;
        _heroTextContent = heroTextMap;
        _quickAccessItems = quickAccessMenu;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load home feed data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
      if (!mounted || _heroSlides.isEmpty) return;
      _heroPageController.animateToPage(
        _heroRawPage + 1,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _startFeatureAutoSlide() {
    _featureTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _featureCards.isEmpty) return;
      _featureCardPageController.animateToPage(
        _featureRawPage + 1,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;

    if (_isLoading) return const ShimmerHomeTabSkeleton();

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadData();
      },
      color: AppColors.burundiGreen,
      child: CustomScrollView(
      slivers: [
        // Hero Slideshow
        SliverToBoxAdapter(
          child: _buildHeroSlideshow(context, l10n),
        ),

        // Welcome Banner
        SliverToBoxAdapter(
          child: _buildWelcomeBanner(context),
        ),

        // Feature Cards Slideshow
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
              child: _buildSectionTitle(context, langCode == 'fr' ? 'Prochains Événements' : 'Upcoming Events'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _apiEventCards!.length,
                itemBuilder: (context, index) {
                  final event = _apiEventCards![index];
                  return EventCard(
                    event: event,
                    langCode: langCode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(event: event),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],

        // Latest News Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
            child: _buildSectionTitle(context, l10n.translate('latest_news'), showSeeAll: true),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _articles.length,
              itemBuilder: (context, index) {
                final article = _articles[index];
                return NewsCard(
                  article: article,
                  langCode: langCode,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArticleDetailScreen(article: article),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),

        // Priority Agendas Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
            child: _buildSectionTitle(context, 'Priority Agendas'),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildPriorityAgendasSection(context),
          ),
        ),

        // Features Grid
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
            child: _buildSectionTitle(context, l10n.translate('explore_features')),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildListDelegate([
              FeatureItem(
                title: 'Gallery',
                subtitle: 'Browse photo albums',
                icon: Icons.photo_library_rounded,
                color: AppColors.burundiGreen,
                onTap: () => Navigator.pushNamed(context, '/gallery'),
              ),
              FeatureItem(
                title: 'Videos',
                subtitle: 'Watch highlights & speeches',
                icon: Icons.play_circle_rounded,
                color: AppColors.burundiRed,
                onTap: () => Navigator.pushNamed(context, '/videos'),
              ),
              FeatureItem(
                title: 'Social Media',
                subtitle: 'Connect with us online',
                icon: Icons.share_rounded,
                color: AppColors.auGold,
                onTap: () => Navigator.pushNamed(context, '/social-media'),
              ),
            ]),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
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
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good Evening';
    } else {
      greeting = 'Good Night';
    }

    final userName = authProvider.userName ?? 'User';
    final isVerified = authProvider.isVerified;
    final badgeType = authProvider.badgeType;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'HeatherGreen',
                  color: isDark ? const Color(0xFF8FB7A3) : const Color(0xFF4A7C5D), // Heather green (more visible)
                ),
                children: [
                  TextSpan(text: '$greeting, '),
                  TextSpan(
                    text: userName,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8FB7A3) : const Color(0xFF4A7C5D), // Heather green (more visible)
                      fontWeight: FontWeight.w700,
                      fontFamily: 'HeatherGreen',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isVerified) ...[
            const SizedBox(width: 6),
            VerifiedBadge(badgeType: badgeType, size: 20),
          ],
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
                            colors: [Color(0xFF1EB53A), Color(0xFF065A1A)],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF1EB53A), Color(0xFF065A1A)],
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
                              colors: [Color(0xFF1EB53A), Color(0xFF065A1A)],
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
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.menu, color: Colors.white),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'news':
                              Navigator.pushNamed(context, '/news');
                              break;
                            case 'magazine':
                              Navigator.pushNamed(context, '/magazine');
                              break;
                            case 'calendar':
                              Navigator.pushNamed(context, '/calendar');
                              break;
                            case 'live_feeds':
                              Navigator.pushNamed(context, '/live-feeds');
                              break;
                            case 'resources':
                              Navigator.pushNamed(context, '/resources');
                              break;
                            case 'weather':
                              Navigator.pushNamed(context, '/weather');
                              break;
                            case 'translate':
                              Navigator.pushNamed(context, '/translate');
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'news', child: ListTile(leading: Icon(Icons.article), title: Text('News'), dense: true, contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'magazine', child: ListTile(leading: Icon(Icons.auto_stories), title: Text('Magazine'), dense: true, contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'calendar', child: ListTile(leading: Icon(Icons.calendar_month), title: Text('Calendar'), dense: true, contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'live_feeds', child: ListTile(leading: Icon(Icons.live_tv), title: Text('Live Feeds'), dense: true, contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'resources', child: ListTile(leading: Icon(Icons.folder), title: Text('Resources'), dense: true, contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'weather', child: ListTile(leading: Icon(Icons.cloud), title: Text('Weather'), dense: true, contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'translate', child: ListTile(leading: Icon(Icons.translate), title: Text('Translate'), dense: true, contentPadding: EdgeInsets.zero)),
                        ],
                      ),
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
                        // Dark gradient overlay for better text readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.75),
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
    // Use API data if available
    if (_quickAccessItems != null && _quickAccessItems!.isNotEmpty) {
      final langCode = Localizations.localeOf(context).languageCode;
      final items = _quickAccessItems!.map((menuItem) {
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
                launchUrl(uri);
              }
            }
          },
        };
      }).toList();

      return QuickAccessGrid(items: items);
    }

    // No fallback - show empty state
    return const SizedBox.shrink();
  }

  Widget _buildPriorityAgendasSection(BuildContext context) {
    // Use API data if available, otherwise show empty
    final agendas = _apiPriorityAgendas ?? [];

    final langCode = Localizations.localeOf(context).languageCode;

    // Theme colors per agenda for fallback backgrounds
    final Map<String, List<Color>> slugColors = {
      'water-sanitation': [const Color(0xFF0077B6), const Color(0xFF00B4D8)],
      'arise-initiative': [const Color(0xFFB8860B), const Color(0xFFDAA520)],
      'peace-security': [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
    };

    return Column(
      children: agendas.map((agenda) {
        final slug = agenda['slug'] as String?;
        final title = langCode == 'fr' ? (agenda['title_fr'] ?? agenda['title']) : agenda['title'];
        final description = langCode == 'fr' ? (agenda['description_fr'] ?? agenda['description']) : agenda['description'];
        final heroImage = agenda['hero_image'];
        final hasImage = heroImage != null && heroImage.toString().isNotEmpty;
        final fallbackColors = (slug != null && slugColors.containsKey(slug))
            ? slugColors[slug]!
            : [AppColors.burundiGreen, AppColors.auGold];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PriorityAgendaDetailScreen(agenda: agenda),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: fallbackColors[0].withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
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
                            colors: fallbackColors,
                          ),
                        ),
                      ),

                    // Dark overlay for text readability (stronger on images)
                    if (hasImage)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.black.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.black.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Icon(
                              _getIconFromAgenda(agenda),
                              size: 32,
                              color: Colors.white,
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  description as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 16,
                            ),
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
      }).toList(),
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

    // Default: always open the detail page
    Navigator.push(
      context,
      MaterialPageRoute(
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

  Widget _buildSectionTitle(BuildContext context, String title, {bool showSeeAll = false}) {
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
            onPressed: () => Navigator.pushNamed(context, '/news'),
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
}
