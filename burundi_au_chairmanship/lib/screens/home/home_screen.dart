import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/magazine_model.dart';
import '../../models/location_model.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(onSwitchTab: (index) => setState(() => _currentIndex = index)),
          _MagazineTab(),
          _ConsularTab(),
          _LocationsTab(),
          _MoreTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(l10n),
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              activeIcon: const Icon(Icons.home_rounded),
              label: l10n.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_stories_rounded),
              activeIcon: const Icon(Icons.auto_stories_rounded),
              label: l10n.magazine,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_rounded),
              activeIcon: const Icon(Icons.account_balance_rounded),
              label: l10n.consular,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.location_on_rounded),
              activeIcon: const Icon(Icons.location_on_rounded),
              label: l10n.locations,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.more_horiz_rounded),
              activeIcon: const Icon(Icons.more_horiz_rounded),
              label: l10n.more,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const _HomeTab({this.onSwitchTab});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final PageController _heroPageController = PageController();
  final PageController _featureCardPageController = PageController(viewportFraction: 0.85);
  Timer? _heroTimer;
  Timer? _featureTimer;
  int _heroCurrentPage = 0;
  int _featureCurrentPage = 0;

  // API data
  List<HeroSlide>? _apiHeroSlides;
  List<Article>? _apiArticles;
  List<Map<String, dynamic>>? _apiFeatureCards;

  // Computed getters
  List<Map<String, dynamic>> get _heroSlides {
    if (_apiHeroSlides != null && _apiHeroSlides!.isNotEmpty) {
      return _apiHeroSlides!.map((s) => {
        'image': s.image,
        'label': s.getLabel(Localizations.localeOf(context).languageCode),
        'isNetwork': true,
      }).toList();
    }
    // Fallback to local assets when API unavailable
    return [
      {'image': 'assets/images/AU HQ.webp', 'label': 'Unity & Progress', 'isNetwork': false},
      {'image': 'assets/images/Burundi President.jpg', 'label': 'AU Leadership', 'isNetwork': false},
      {'image': 'assets/images/au_chairmanship_3.png', 'label': 'Pan-African Vision', 'isNetwork': false},
    ];
  }

  List<Map<String, dynamic>> get _featureCards {
    if (_apiFeatureCards != null && _apiFeatureCards!.isNotEmpty) {
      return _apiFeatureCards!;
    }
    // Fallback feature cards when API is unavailable
    return [
      {
        'title': 'AU Vision 2063',
        'description': 'An integrated, prosperous and peaceful Africa, driven by its own citizens.',
        'icon': Icons.stars,
        'gradient': [const Color(0xFF1EB53A), const Color(0xFF4CAF50)],
        'imageUrl': '',
      },
      {
        'title': 'Diplomatic Relations',
        'description': 'Strengthening ties across the continent through dialogue and cooperation.',
        'icon': Icons.travel_explore,
        'gradient': [const Color(0xFFD4AF37), const Color(0xFFDAA520)],
        'imageUrl': '',
      },
      {
        'title': 'Peace & Security',
        'description': 'Building a stable and secure Africa for future generations.',
        'icon': Icons.gavel,
        'gradient': [const Color(0xFF0A5C1E), const Color(0xFF1EB53A)],
        'imageUrl': '',
      },
    ];
  }

  List<Article> get _articles {
    if (_apiArticles != null && _apiArticles!.isNotEmpty) return _apiArticles!;
    return [];
  }

  /// Parse hex color string like "#1EB53A" into a Color
  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _startHeroAutoSlide();
    _startFeatureAutoSlide();
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
        return <String, dynamic>{
          'title': langCode == 'fr' ? (j['title_fr'] ?? j['title'] ?? '') : (j['title'] ?? ''),
          'description': langCode == 'fr' ? (j['description_fr'] ?? j['description'] ?? '') : (j['description'] ?? ''),
          'icon': featureCardIcons[entry.key % featureCardIcons.length],
          'gradient': [gradStart, gradEnd],
          'imageUrl': j['image'] ?? '',
        };
      }).toList();

      setState(() {
        _apiHeroSlides = heroSlides;
        _apiArticles = articles;
        _apiFeatureCards = featureCards;
      });
    } catch (_) {
      // Fallback data will be used via computed getters
    }
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _featureTimer?.cancel();
    _heroPageController.dispose();
    _featureCardPageController.dispose();
    super.dispose();
  }

  void _startHeroAutoSlide() {
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _heroSlides.isEmpty) return;
      final nextPage = (_heroCurrentPage + 1) % _heroSlides.length;
      _heroPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _startFeatureAutoSlide() {
    _featureTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _featureCards.isEmpty) return;
      final nextPage = (_featureCurrentPage + 1) % _featureCards.length;
      _featureCardPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;

    return CustomScrollView(
      slivers: [
        // Hero Slideshow
        SliverToBoxAdapter(
          child: _buildHeroSlideshow(context, l10n),
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

        // Latest News Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
            child: _buildSectionTitle(context, l10n.translate('latest_news'), showSeeAll: true),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _articles.length,
              itemBuilder: (context, index) {
                final article = _articles[index];
                return _NewsCard(
                  title: article.getTitle(langCode),
                  subtitle: article.getContent(langCode),
                  imageUrl: article.imageUrl,
                  date: '${article.publishDate.day}/${article.publishDate.month}/${article.publishDate.year}',
                  onTap: () {},
                );
              },
            ),
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
              _FeatureItem(
                title: l10n.digitalMagazine,
                subtitle: l10n.digitalMagazineDesc,
                icon: Icons.menu_book,
                color: AppColors.burundiGreen,
                onTap: () {},
              ),
              _FeatureItem(
                title: l10n.consularServices,
                subtitle: l10n.consularServicesDesc,
                icon: Icons.account_balance,
                color: AppColors.auGold,
                onTap: () {},
              ),
              _FeatureItem(
                title: l10n.embassyLocations,
                subtitle: l10n.embassyLocationsDesc,
                icon: Icons.location_on,
                color: AppColors.info,
                onTap: () {},
              ),
              _FeatureItem(
                title: l10n.liveFeeds,
                subtitle: l10n.liveFeedsDesc,
                icon: Icons.live_tv,
                color: AppColors.burundiRed,
                onTap: () => Navigator.pushNamed(context, '/live-feeds'),
              ),
            ]),
          ),
        ),

        // More Features
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildListDelegate([
              _FeatureItem(
                title: l10n.resources,
                subtitle: l10n.resourcesDesc,
                icon: Icons.folder,
                color: AppColors.patternOrange,
                onTap: () => Navigator.pushNamed(context, '/resources'),
              ),
              _FeatureItem(
                title: l10n.quickReference,
                subtitle: l10n.quickReferenceDesc,
                icon: Icons.info,
                color: AppColors.patternBrown,
                onTap: () {},
              ),
              _FeatureItem(
                title: 'Gallery',
                subtitle: 'Photos & Videos',
                icon: Icons.photo_library,
                color: Colors.purple,
                onTap: () {},
              ),
              _FeatureItem(
                title: l10n.emergencySos,
                subtitle: l10n.emergencySosDesc,
                icon: Icons.emergency,
                color: AppColors.emergency,
                onTap: () => Navigator.pushNamed(context, '/emergency'),
                isEmergency: true,
              ),
            ]),
          ),
        ),

        // Additional Features
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
            child: _buildSectionTitle(context, 'More Services'),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _ServiceListItem(
                  title: 'Travel Advisory',
                  subtitle: 'Latest travel information and alerts',
                  icon: Icons.flight,
                  color: AppColors.burundiGreen,
                  onTap: () {},
                ),
                _ServiceListItem(
                  title: 'Cultural Events',
                  subtitle: 'Upcoming cultural programs',
                  icon: Icons.celebration,
                  color: AppColors.auGold,
                  onTap: () {},
                ),
                _ServiceListItem(
                  title: 'Business Connect',
                  subtitle: 'Trade and investment opportunities',
                  icon: Icons.business_center,
                  color: AppColors.info,
                  onTap: () {},
                ),
                _ServiceListItem(
                  title: 'Education',
                  subtitle: 'Scholarship and study information',
                  icon: Icons.school,
                  color: AppColors.patternOrange,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
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
              setState(() => _heroCurrentPage = index);
            },
            itemCount: _heroSlides.length,
            itemBuilder: (context, index) {
              final slide = _heroSlides[index];
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
                      placeholder: (_, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF1EB53A), Color(0xFF065A1A)],
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
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
                  // Dark greenish gradient overlay from bottom
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0A3D1A).withValues(alpha: 0.25),
                          const Color(0xFF0A3D1A).withValues(alpha: 0.7),
                        ],
                        stops: const [0.25, 0.55, 1.0],
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
                            case 'emergency':
                              Navigator.pushNamed(context, '/emergency');
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
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'emergency', child: ListTile(leading: Icon(Icons.emergency, color: Colors.red), title: Text('Emergency SOS'), dense: true, contentPadding: EdgeInsets.zero)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                            onPressed: () {},
                          ),
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
                    child: const Text(
                      'BURUNDI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'African Union',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Chairmanship ',
                        style: TextStyle(
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
                        child: const Text(
                          '2026',
                          style: TextStyle(
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
                    _heroCurrentPage < _heroSlides.length ? (_heroSlides[_heroCurrentPage]['label'] ?? '') : '',
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
                        painter: _ZigzagLinePainter(),
                      ),
                      const SizedBox(width: 15),
                      ...List.generate(_heroSlides.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: _heroCurrentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _heroCurrentPage == index
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
              setState(() => _featureCurrentPage = index);
            },
            itemCount: _featureCards.length,
            itemBuilder: (context, index) {
              final card = _featureCards[index];
              final gradientColors = card['gradient'] as List<Color>;
              final imageUrl = card['imageUrl'] as String?;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
                        // Dark gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.2),
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        // Pattern overlay
                        CustomPaint(
                          size: const Size(double.infinity, 180),
                          painter: _CardPatternPainter(),
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
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      card['description'] as String,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 13,
                                        height: 1.4,
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
                                child: Icon(
                                  card['icon'] as IconData,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_featureCards.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _featureCurrentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _featureCurrentPage == index
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
    final items = <Map<String, dynamic>>[
      {'title': 'SOS', 'icon': Icons.sos_rounded, 'isSos': true,
        'onTap': () => Navigator.pushNamed(context, '/emergency')},
      {'title': l10n.translate('live'), 'icon': Icons.play_circle_filled_rounded, 'hasLiveDot': true,
        'onTap': () => Navigator.pushNamed(context, '/live-feeds')},
      {'title': l10n.magazine, 'icon': Icons.auto_stories_rounded,
        'onTap': () => Navigator.pushNamed(context, '/magazine')},
      {'title': l10n.resources, 'icon': Icons.folder_copy_rounded,
        'onTap': () => Navigator.pushNamed(context, '/resources')},
      {'title': 'News', 'icon': Icons.article_rounded,
        'onTap': () => Navigator.pushNamed(context, '/news')},
      {'title': l10n.translate('translate'), 'icon': Icons.translate_rounded,
        'onTap': () => Navigator.pushNamed(context, '/translate')},
      {'title': l10n.translate('weather'), 'icon': Icons.cloud_rounded,
        'onTap': () => Navigator.pushNamed(context, '/weather')},
      {'title': l10n.translate('calendar'), 'icon': Icons.calendar_month_rounded,
        'onTap': () => Navigator.pushNamed(context, '/calendar')},
    ];

    return _QuickAccessGrid(items: items);
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
            onPressed: () {},
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

// Quick Access Grid
class _QuickAccessGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _QuickAccessGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32 - 36) / 4;

    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: items.map((item) {
        final isSos = item['isSos'] == true;
        final hasLiveDot = item['hasLiveDot'] == true;

        return GestureDetector(
          onTap: item['onTap'] as VoidCallback,
          child: SizedBox(
            width: itemWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isSos
                            ? AppColors.emergency.withValues(alpha: 0.1)
                            : AppColors.burundiGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSos
                              ? AppColors.emergency.withValues(alpha: 0.25)
                              : AppColors.burundiGreen.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSos ? AppColors.emergency : AppColors.burundiGreen,
                        size: 26,
                      ),
                    ),
                    if (hasLiveDot)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.emergency,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Feature Item Widget
class _FeatureItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isEmergency;

  const _FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isEmergency
              ? Border.all(color: color, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: (isEmergency ? color : Colors.black).withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// News Card Widget
class _NewsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String date;
  final VoidCallback onTap;

  const _NewsCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder with gradient
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.burundiGreen.withValues(alpha: 0.8),
                    AppColors.burundiGreen.withValues(alpha: 0.4),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Pattern overlay
                  CustomPaint(
                    size: const Size(260, 120),
                    painter: _CardPatternPainter(),
                  ),
                  // Image placeholder
                  Center(
                    child: Icon(
                      Icons.image,
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  // Date badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.auGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Service List Item Widget
class _ServiceListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ServiceListItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

// Custom Painters
class _ZigzagLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.auGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height / 2);
    for (double x = 0; x < size.width; x += 15) {
      final y = size.height / 2 + (((x ~/ 15) % 2 == 0) ? -4 : 4);
      path.lineTo(x + 7.5, y);
      path.lineTo(x + 15, size.height / 2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Zigzag at bottom
    final path = Path();
    path.moveTo(0, size.height - 15);
    for (double x = 0; x < size.width; x += 20) {
      path.lineTo(x + 10, size.height - 25);
      path.lineTo(x + 20, size.height - 15);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== MAGAZINE TAB ====================
class _MagazineTab extends StatefulWidget {
  @override
  State<_MagazineTab> createState() => _MagazineTabState();
}

class _MagazineTabState extends State<_MagazineTab> {
  List<MagazineEdition>? _editions;
  List<Article>? _articles;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getMagazines(),
        api.getArticles(),
      ]);
      if (!mounted) return;
      setState(() {
        _editions = results[0] as List<MagazineEdition>;
        _articles = results[1] as List<Article>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final editions = _editions ?? [];
    final articles = _articles ?? [];
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (editions.isEmpty) return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories, size: 64, color: AppColors.burundiGreen.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(l10n.noData, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadData, child: Text(l10n.retry)),
        ],
      ),
    );
    final featured = editions.first;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Gradient app bar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.digitalMagazine,
                style: const TextStyle(
                  fontFamily: 'HeatherGreen',
                  fontSize: 20,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.burundiGreen, Color(0xFF065A1A)],
                  ),
                ),
              ),
            ),
          ),

          // Featured Edition
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('featured_edition'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [AppColors.burundiGreen, Color(0xFF065A1A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.burundiGreen.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: const Size(double.infinity, 220),
                          painter: _CardPatternPainter(),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Cover placeholder
                              Container(
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.menu_book, color: Colors.white.withValues(alpha: 0.7), size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      'AU\nSUMMIT',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontFamily: 'HeatherGreen',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.auGold,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('FEATURED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      featured.getTitle(langCode),
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'HeatherGreen'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      featured.getDescription(langCode),
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.3),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.download, size: 16, color: AppColors.burundiGreen),
                                          SizedBox(width: 6),
                                          Text('Download', style: TextStyle(color: AppColors.burundiGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Past Editions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l10n.translate('past_editions'), style: theme.textTheme.headlineMedium),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: editions.length,
                itemBuilder: (context, index) {
                  final edition = editions[index];
                  final colors = [
                    [AppColors.burundiGreen, const Color(0xFF4CAF50)],
                    [AppColors.burundiRed, const Color(0xFFE57373)],
                    [AppColors.auGold, const Color(0xFFFFD54F)],
                  ];
                  final gradientColors = colors[index % colors.length];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_stories, color: Colors.white.withValues(alpha: 0.8), size: 36),
                          const SizedBox(height: 10),
                          Text(
                            edition.getTitle(langCode),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${edition.publishDate.day}/${edition.publishDate.month}/${edition.publishDate.year}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Articles
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(l10n.translate('articles'), style: theme.textTheme.headlineMedium),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final article = articles[index];
                final categoryColors = {
                  'Politics': AppColors.burundiGreen,
                  'Economy': AppColors.auGold,
                  'Culture': AppColors.burundiRed,
                };
                final catColor = categoryColors[article.category] ?? AppColors.info;
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Image placeholder
                      Container(
                        width: 100,
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [catColor, catColor.withValues(alpha: 0.6)]),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                        ),
                        child: Center(
                          child: Icon(Icons.article, color: Colors.white.withValues(alpha: 0.6), size: 32),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(article.category, style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${article.publishDate.day}/${article.publishDate.month}/${article.publishDate.year}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                article.getTitle(langCode),
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                article.getContent(langCode),
                                style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: articles.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ==================== CONSULAR TAB ====================
class _ConsularTab extends StatelessWidget {
  static const _services = [
    {'title': 'Visa Services', 'description': 'Apply for tourist, business, or transit visas', 'icon': Icons.card_membership},
    {'title': 'Passport Services', 'description': 'New passports, renewals, and replacements', 'icon': Icons.badge},
    {'title': 'Citizen Registration', 'description': 'Birth, marriage, and civil registration', 'icon': Icons.how_to_reg},
    {'title': 'Travel Advisory', 'description': 'Current travel alerts and safety info', 'icon': Icons.flight_takeoff},
    {'title': 'Appointments', 'description': 'Schedule consular service appointments', 'icon': Icons.calendar_month},
    {'title': 'Legal Assistance', 'description': 'Notarial services and legal support', 'icon': Icons.gavel},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final serviceColors = [
      AppColors.burundiGreen,
      AppColors.burundiRed,
      AppColors.auGold,
      AppColors.info,
      const Color(0xFF7B1FA2),
      AppColors.patternBrown,
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Gradient header
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.consularServices,
                style: const TextStyle(fontFamily: 'HeatherGreen', fontSize: 20),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.burundiRed, Color(0xFF8B0000)],
                  ),
                ),
              ),
            ),
          ),

          // Service Cards Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final service = _services[index];
                  final color = serviceColors[index % serviceColors.length];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(service['icon'] as IconData, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          service['title'] as String,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            service['description'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.arrow_forward_ios, size: 14, color: color),
                        ),
                      ],
                    ),
                  );
                },
                childCount: _services.length,
              ),
            ),
          ),

          // Emergency Contacts Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l10n.translate('emergency_contacts'),
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emergency.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    _EmergencyContactRow(
                      icon: Icons.account_balance,
                      label: l10n.translate('embassy'),
                      number: AppConstants.embassyNumber,
                    ),
                    const Divider(height: 20),
                    _EmergencyContactRow(
                      icon: Icons.local_police,
                      label: l10n.translate('police'),
                      number: AppConstants.policeNumber,
                    ),
                    const Divider(height: 20),
                    _EmergencyContactRow(
                      icon: Icons.local_hospital,
                      label: l10n.translate('ambulance'),
                      number: AppConstants.ambulanceNumber,
                    ),
                    const Divider(height: 20),
                    _EmergencyContactRow(
                      icon: Icons.local_fire_department,
                      label: l10n.translate('fire_department'),
                      number: AppConstants.fireNumber,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String number;

  const _EmergencyContactRow({
    required this.icon,
    required this.label,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.emergency, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              Text(number, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('tel:$number')),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emergency.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone, color: AppColors.emergency, size: 20),
          ),
        ),
      ],
    );
  }
}

// ==================== LOCATIONS TAB ====================
class _LocationsTab extends StatefulWidget {
  @override
  State<_LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<_LocationsTab> {
  List<EmbassyLocation>? _embassies;
  List<EventLocation>? _events;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getEmbassies(),
        api.getEvents(),
      ]);
      if (!mounted) return;
      setState(() {
        _embassies = results[0] as List<EmbassyLocation>;
        _events = results[1] as List<EventLocation>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final embassies = _embassies ?? [];
    final events = _events ?? [];

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.embassyLocations),
          backgroundColor: AppColors.info,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.embassyLocations,
                style: const TextStyle(fontFamily: 'HeatherGreen', fontSize: 20),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.info, Color(0xFF0D47A1)],
                  ),
                ),
              ),
            ),
          ),

          // Map placeholder - tap to open Google Maps
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                if (embassies.isNotEmpty) {
                  final first = embassies.first;
                  launchUrl(
                    Uri.parse('https://www.google.com/maps/search/Burundi+Embassy/@${first.latitude},${first.longitude},4z'),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.all(16),
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 48, color: AppColors.burundiGreen.withValues(alpha: 0.6)),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('view_on_map'),
                        style: TextStyle(color: AppColors.burundiGreen.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to open in Maps',
                        style: TextStyle(color: AppColors.burundiGreen.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Embassies & Consulates
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l10n.translate('embassies_consulates'),
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final embassy = embassies[index];
                final isEmbassy = embassy.type == LocationType.embassy;
                final typeColor = isEmbassy ? AppColors.burundiGreen : AppColors.auGold;
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              embassy.getName(langCode),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isEmbassy ? 'Embassy' : 'Consulate',
                              style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${embassy.address}, ${embassy.city}, ${embassy.country}',
                              style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            embassy.phoneNumber,
                            style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => launchUrl(Uri.parse('tel:${embassy.phoneNumber}')),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.phone, size: 16, color: AppColors.burundiGreen),
                                    SizedBox(width: 6),
                                    Text('Call', style: TextStyle(color: AppColors.burundiGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => launchUrl(
                                Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${embassy.latitude},${embassy.longitude}'),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions, size: 16, color: AppColors.info),
                                    SizedBox(width: 6),
                                    Text('Directions', style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              childCount: embassies.length,
            ),
          ),

          // Upcoming Events
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.translate('upcoming_events'),
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final event = events[index];
                final eventColors = [AppColors.burundiGreen, AppColors.burundiRed, AppColors.auGold];
                final color = eventColors[index % eventColors.length];
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${event.eventDate.day}',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][event.eventDate.month],
                              style: TextStyle(color: color, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.getName(langCode),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.getDescription(langCode),
                              style: theme.textTheme.bodySmall?.copyWith(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: color),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.address,
                                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: events.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ==================== MORE / SETTINGS TAB ====================
class _MoreTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.settings,
                style: const TextStyle(fontFamily: 'HeatherGreen', fontSize: 20),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.auGold, Color(0xFFB8860B)],
                  ),
                ),
              ),
            ),
          ),

          // Profile header
          SliverToBoxAdapter(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final isLoggedIn = authProvider.isAuthenticated;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () {
                      if (isLoggedIn) {
                        Navigator.pushNamed(context, '/profile');
                      } else {
                        Navigator.pushNamed(context, '/auth');
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.burundiGreen.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.burundiGreen, width: 2),
                          ),
                          child: Center(
                            child: isLoggedIn && authProvider.userName != null
                                ? Text(
                                    authProvider.userName![0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.burundiGreen,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : const Icon(Icons.person, size: 32, color: AppColors.burundiGreen),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLoggedIn ? (authProvider.userName ?? 'User') : 'Guest User',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isLoggedIn ? (authProvider.userEmail ?? '') : l10n.translate('tap_to_sign_in'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Settings list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Language toggle
                    Consumer<LanguageProvider>(
                      builder: (context, langProvider, _) {
                        return ListTile(
                          leading: const Icon(Icons.language, color: AppColors.burundiGreen),
                          title: Text(l10n.translate('language')),
                          subtitle: Text(langProvider.isEnglish ? 'English' : 'Français'),
                          trailing: Switch(
                            value: langProvider.isFrench,
                            activeTrackColor: AppColors.burundiGreen,
                            onChanged: (_) => langProvider.toggleLanguage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    // Theme toggle
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return ListTile(
                          leading: Icon(
                            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            color: AppColors.auGold,
                          ),
                          title: Text(l10n.translate('theme')),
                          subtitle: Text(themeProvider.isDarkMode ? l10n.translate('dark') : l10n.translate('light')),
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            activeTrackColor: AppColors.auGold,
                            onChanged: (_) => themeProvider.toggleTheme(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // About section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: AppColors.info),
                      title: Text(l10n.translate('about')),
                      subtitle: Text('${AppConstants.appName} v${AppConstants.appVersion}'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: AppConstants.appName,
                          applicationVersion: AppConstants.appVersion,
                          applicationIcon: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.burundiGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.stars, color: Colors.white, size: 28),
                          ),
                          children: [
                            Text(AppConstants.summitTheme),
                            const SizedBox(height: 8),
                            const Text('Official application for the Burundi African Union Chairmanship 2026.'),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => launchUrl(Uri.parse('https://eyosias.dev')),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                  children: const [
                                    TextSpan(text: 'Designed and developed by '),
                                    TextSpan(
                                      text: 'Eyosias Tamene',
                                      style: TextStyle(
                                        color: AppColors.burundiGreen,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.patternBrown),
                      title: Text(l10n.translate('privacy_policy')),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => launchUrl(Uri.parse(AppConstants.websiteUrl)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.share, color: AppColors.burundiGreen),
                      title: Text(l10n.translate('share_app')),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Share link copied!'),
                            backgroundColor: AppColors.burundiGreen,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.star_outline, color: AppColors.auGold),
                      title: Text(l10n.translate('rate_app')),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you for your support!'),
                            backgroundColor: AppColors.auGold,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.headset_mic, color: AppColors.burundiRed),
                      title: Text(l10n.translate('contact_support')),
                      subtitle: const Text('support@burundi.gov.bi'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        final uri = Uri(
                          scheme: 'mailto',
                          path: 'support@burundi.gov.bi',
                          queryParameters: {
                            'subject': 'Burundi AU Chairmanship App Support',
                            'body': 'Hello,\n\nI need assistance with:\n\n',
                          },
                        );
                        launchUrl(uri);
                      },
                    ),
                    // Export Data & Delete Account - Only show if logged in
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final isLoggedIn = authProvider.isAuthenticated;
                        if (!isLoggedIn) return const SizedBox.shrink();

                        return Column(
                          children: [
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            // Export Data
                            ListTile(
                              leading: const Icon(Icons.download_outlined, color: AppColors.info),
                              title: const Text('Export My Data'),
                              subtitle: const Text('Download all your account data'),
                              trailing: const Icon(Icons.chevron_right, size: 20),
                              onTap: () async {
                                // Show loading
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                try {
                                  final api = ApiService();
                                  final data = await api.exportUserData();

                                  // Close loading
                                  if (context.mounted) {
                                    Navigator.pop(context);

                                    // Show data in dialog
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Your Data Export'),
                                        content: SingleChildScrollView(
                                          child: SelectableText(
                                            const JsonEncoder.withIndent('  ').convert(data),
                                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Close'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              // In a real app, this would save to file or share
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Data copied! You can paste it into a file.'),
                                                  backgroundColor: AppColors.success,
                                                ),
                                              );
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text('Copy'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // Close loading
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to export data: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            // Delete Account
                            ListTile(
                              leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                              subtitle: const Text('Permanently delete your account and data'),
                              trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.red),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete Account?'),
                                    content: const Text(
                                      'This will permanently delete your account and all associated data. '
                                      'This action cannot be undone.\n\n'
                                      'Are you sure you want to continue?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(dialogContext);

                                          // Show loading indicator
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (ctx) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );

                                          // Delete account
                                          final success = await authProvider.deleteAccount();

                                          // Close loading
                                          if (context.mounted) {
                                            Navigator.pop(context);

                                            if (success) {
                                              // Show success message
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Your account has been deleted.'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              // Navigate to auth screen
                                              Navigator.pushNamedAndRemoveUntil(
                                                context,
                                                '/auth',
                                                (route) => false,
                                              );
                                            } else {
                                              // Show error
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(authProvider.errorMessage ?? 'Failed to delete account'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Summit theme
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.burundiGreen.withValues(alpha: 0.1), AppColors.auGold.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.stars, color: AppColors.auGold, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.summitTheme,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Version footer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: Center(
                child: Text(
                  '${AppConstants.appName} v${AppConstants.appVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
