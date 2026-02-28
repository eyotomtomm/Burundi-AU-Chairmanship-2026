import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../../config/app_colors.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../models/api_models.dart';
import '../../../models/magazine_model.dart';
import '../../../services/api_service.dart';
import '../painters/zigzag_line_painter.dart';
import '../painters/card_pattern_painter.dart';
import '../widgets/quick_access_grid.dart';
import '../widgets/news_card.dart';
import '../widgets/feature_item.dart';

class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const HomeTab({super.key, this.onSwitchTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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
  List<Map<String, dynamic>>? _apiPriorityAgendas;

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

      // Fetch priority agendas
      final priorityAgendas = await api.getPriorityAgendas();

      setState(() {
        _apiHeroSlides = heroSlides;
        _apiArticles = articles;
        _apiFeatureCards = featureCards;
        _apiPriorityAgendas = priorityAgendas;
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
                  onTap: () {},
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
                        painter: ZigzagLinePainter(),
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
      {'title': l10n.translate('live'), 'icon': Icons.play_circle_filled_rounded, 'hasLiveDot': true,
        'onTap': () => Navigator.pushNamed(context, '/live-feeds')},
      {'title': l10n.magazine, 'icon': Icons.auto_stories_rounded,
        'onTap': () => widget.onSwitchTab?.call(1)},
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

    return QuickAccessGrid(items: items);
  }

  Widget _buildPriorityAgendasSection(BuildContext context) {
    // Map slugs to routes and icons
    final slugRoutes = {
      'water-sanitation': {'route': '/water-sanitation', 'icon': Icons.water_drop},
      'arise-initiative': {'route': '/arise-initiative', 'icon': Icons.trending_up},
      'peace-security': {'route': '/peace-security', 'icon': Icons.security},
    };

    // Use API data if available, otherwise fallback
    final agendas = _apiPriorityAgendas ?? [
      {
        'title': 'Water & Sanitation',
        'description': 'Clean water access and sanitation infrastructure for all',
        'slug': 'water-sanitation',
        'hero_image': null,
      },
      {
        'title': 'A-RISE Initiative',
        'description': 'Africa Rising Initiative for Sustainable Economy',
        'slug': 'arise-initiative',
        'hero_image': null,
      },
      {
        'title': 'Peace & Security',
        'description': 'Building a stable and secure Africa',
        'slug': 'peace-security',
        'hero_image': null,
      },
    ];

    final langCode = Localizations.localeOf(context).languageCode;

    // Theme colors per agenda for fallback backgrounds
    final slugColors = {
      'water-sanitation': [const Color(0xFF0077B6), const Color(0xFF00B4D8)],
      'arise-initiative': [const Color(0xFFB8860B), const Color(0xFFDAA520)],
      'peace-security': [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
    };

    return Column(
      children: agendas.map((agenda) {
        final slug = agenda['slug'] as String;
        final routeInfo = slugRoutes[slug];
        if (routeInfo == null) return const SizedBox.shrink();

        final title = langCode == 'fr' ? (agenda['title_fr'] ?? agenda['title']) : agenda['title'];
        final description = langCode == 'fr' ? (agenda['description_fr'] ?? agenda['description']) : agenda['description'];
        final heroImage = agenda['hero_image'];
        final hasImage = heroImage != null && heroImage.toString().isNotEmpty;
        final fallbackColors = slugColors[slug] ?? [AppColors.burundiGreen, AppColors.auGold];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, routeInfo['route'] as String),
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
                              routeInfo['icon'] as IconData,
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
