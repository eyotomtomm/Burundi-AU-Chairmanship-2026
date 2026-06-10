import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../config/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../models/magazine_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/login_gate.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/liked_by_avatars.dart';
import '../../../services/like_service.dart';
import '../../magazine/pdf_viewer_screen.dart';
import '../../news/article_detail_screen.dart';

class MagazineTab extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const MagazineTab({super.key, this.onBackToHome});

  @override
  State<MagazineTab> createState() => _MagazineTabState();
}

class _MagazineTabState extends State<MagazineTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MagazineEdition>? _editions;
  List<Article>? _articles;
  bool _isLoading = true;
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  // Page flip controller for magazines
  late PageController _magazinePageController;
  int _currentMagazinePage = 0;

  // Featured carousel auto-slide
  late PageController _featuredPageController;
  int _currentFeaturedPage = 0;
  Timer? _featuredAutoSlideTimer;

  // Search & filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedYear;
  int? _selectedMonth;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
    _magazinePageController = PageController();
    _featuredPageController = PageController();
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key.startsWith('magazine:') && mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _featuredAutoSlideTimer?.cancel();
    _removeLikeListener?.call();
    _tabController.dispose();
    _searchController.dispose();
    _magazinePageController.dispose();
    _featuredPageController.dispose();
    super.dispose();
  }

  void _startFeaturedAutoSlide(int itemCount) {
    _featuredAutoSlideTimer?.cancel();
    if (itemCount <= 1) return;
    _featuredAutoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_featuredPageController.hasClients) return;
      final nextPage = (_currentFeaturedPage + 1) % itemCount;
      _featuredPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
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

  void _toggleLike(MagazineEdition edition) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_to_like'))),
      );
      return;
    }
    _likeService.seed(
      EntityType.magazine, edition.id,
      isLiked: edition.isLiked,
      likeCount: edition.likeCount,
      recentLikers: edition.recentLikers,
    );
    _likeService.toggle(EntityType.magazine, edition.id);
  }

  void _openPdf(BuildContext context, MagazineEdition edition) {
    final langCode = context.read<LanguageProvider>().languageCode;
    final url = edition.openablePdfUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF not available yet. Please check back later.'),
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
          title: edition.getTitle(langCode),
          magazineId: edition.id,
        ),
      ),
    );
  }

  List<MagazineEdition> get _filteredEditions {
    var list = _editions ?? [];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) =>
          e.title.toLowerCase().contains(q) ||
          e.titleFr.toLowerCase().contains(q)).toList();
    }
    if (_selectedYear != null) {
      list = list.where((e) => e.publishDate.year == _selectedYear).toList();
    }
    if (_selectedMonth != null) {
      list = list.where((e) => e.publishDate.month == _selectedMonth).toList();
    }
    return list;
  }

  List<Article> get _filteredArticles {
    var list = _articles ?? [];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) =>
          a.title.toLowerCase().contains(q) ||
          a.titleFr.toLowerCase().contains(q)).toList();
    }
    if (_selectedCategory != null) {
      list = list.where((a) => a.category?.name == _selectedCategory).toList();
    }
    return list;
  }

  Set<int> get _availableYears {
    return (_editions ?? []).map((e) => e.publishDate.year).toSet();
  }

  Set<String> get _availableCategories {
    return (_articles ?? [])
        .where((a) => a.category != null)
        .map((a) => a.category!.name)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) return const ShimmerMagazineGridSkeleton();

    final editions = _editions ?? [];
    if (editions.isEmpty && (_articles ?? []).isEmpty) {
      return Center(
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
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _loadData();
        },
        color: AppColors.burundiGreen,
        child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Gradient app bar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            automaticallyImplyLeading: false,
            leading: widget.onBackToHome != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: widget.onBackToHome,
                  )
                : null,
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
                    colors: [AppColors.burundiGreen, Color(0xFF2D6E31)],
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: isDark ? AppColors.darkSurface : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.burundiGreen,
                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : Colors.grey[600],
                  indicatorColor: AppColors.burundiGreen,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_stories, size: 18),
                          const SizedBox(width: 6),
                          Text(l10n.translate('magazines')),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.article_outlined, size: 18),
                          const SizedBox(width: 6),
                          Text(l10n.translate('articles')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: l10n.translate('search'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Filter chips
            _buildFilterChips(langCode, isDark),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMagazinesGrid(context, langCode, isDark),
                  _buildArticlesList(context, langCode, isDark, theme),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildFilterChips(String langCode, bool isDark) {
    final isMagazineTab = _tabController.index == 0;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: isMagazineTab
            ? _buildMagazineFilters(isDark)
            : _buildArticleFilters(langCode, isDark),
      ),
    );
  }

  List<Widget> _buildMagazineFilters(bool isDark) {
    final chips = <Widget>[];
    // Year chips
    final years = _availableYears.toList()..sort((a, b) => b.compareTo(a));
    for (final year in years) {
      final selected = _selectedYear == year;
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text('$year'),
          selected: selected,
          onSelected: (val) => setState(() => _selectedYear = val ? year : null),
          selectedColor: AppColors.burundiGreen.withValues(alpha: 0.2),
          checkmarkColor: AppColors.burundiGreen,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.burundiGreen : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
          side: BorderSide(
            color: selected ? AppColors.burundiGreen : Colors.transparent,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    // Month chips
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (int i = 0; i < months.length; i++) {
      final monthNum = i + 1;
      final selected = _selectedMonth == monthNum;
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(months[i]),
          selected: selected,
          onSelected: (val) => setState(() => _selectedMonth = val ? monthNum : null),
          selectedColor: AppColors.auGold.withValues(alpha: 0.2),
          checkmarkColor: AppColors.auGold,
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.auGold : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
          side: BorderSide(
            color: selected ? AppColors.auGold : Colors.transparent,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    return chips;
  }

  List<Widget> _buildArticleFilters(String langCode, bool isDark) {
    final cats = _availableCategories.toList()..sort();
    // "All" chip
    final allSelected = _selectedCategory == null;
    final chips = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: const Text('All'),
          selected: allSelected,
          onSelected: (_) => setState(() => _selectedCategory = null),
          selectedColor: AppColors.burundiGreen.withValues(alpha: 0.2),
          checkmarkColor: AppColors.burundiGreen,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: allSelected ? FontWeight.bold : FontWeight.normal,
            color: allSelected ? AppColors.burundiGreen : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
          side: BorderSide(color: allSelected ? AppColors.burundiGreen : Colors.transparent),
          visualDensity: VisualDensity.compact,
        ),
      ),
    ];
    for (final cat in cats) {
      final selected = _selectedCategory == cat;
      // Find matching category to get color
      final catObj = (_articles ?? [])
          .where((a) => a.category?.name == cat)
          .map((a) => a.category)
          .first;
      final catColor = catObj?.parsedColor ?? AppColors.burundiGreen;
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(catObj?.getDisplayName(langCode) ?? cat),
          selected: selected,
          onSelected: (val) => setState(() => _selectedCategory = val ? cat : null),
          selectedColor: catColor.withValues(alpha: 0.2),
          checkmarkColor: catColor,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? catColor : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
          side: BorderSide(color: selected ? catColor : Colors.transparent),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    return chips;
  }

  Widget _buildMagazinesGrid(BuildContext context, String langCode, bool isDark) {
    final filtered = _filteredEditions;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No magazines found', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    // Separate featured from rest — featured also appear in grid below
    final featured = filtered.where((e) => e.isFeatured).toList();
    final rest = filtered; // show all magazines including featured
    final isAuth = context.watch<AuthProvider>().isAuthenticated;
    // Total pages for 2-per-view carousel (guests see only 1 page)
    final pageCount = isAuth
        ? (rest.length / 2).ceil()
        : (rest.isEmpty ? 0 : 1);

    // Start auto-slide for featured carousel (only if not already running)
    if (featured.length > 1 && _featuredAutoSlideTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startFeaturedAutoSlide(featured.length);
      });
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Featured Hero Carousel
        if (featured.isNotEmpty)
          _buildFeaturedCarousel(context, featured, langCode, isDark),

        // 2-per-view carousel
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 310,
            child: PageView.builder(
              controller: _magazinePageController,
              onPageChanged: (index) {
                setState(() => _currentMagazinePage = index);
              },
              itemCount: pageCount,
              itemBuilder: (context, pageIndex) {
                final startIdx = pageIndex * 2;
                final endIdx = (startIdx + 2).clamp(0, rest.length);
                final pageMags = rest.sublist(startIdx, endIdx);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: pageMags.map((mag) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildMagazineCard(context, mag, langCode, isDark),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          // Page indicator dots
          if (pageCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pageCount, (index) {
                  final isActive = index == _currentMagazinePage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.burundiGreen
                          : AppColors.burundiGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
        // Login gate banner for guests — replaces any remaining magazine content.
        if (!isAuth) const LoginGateBanner(),
      ],
    );
  }

  Widget _buildFeaturedCarousel(BuildContext context, List<MagazineEdition> featured, String langCode, bool isDark) {
    if (featured.length == 1) {
      return _buildFeaturedHero(context, featured.first, langCode, isDark);
    }
    return Column(
      children: [
        SizedBox(
          height: 236, // 220 card + 8 top margin + 8 breathing room
          child: PageView.builder(
            controller: _featuredPageController,
            onPageChanged: (index) {
              setState(() => _currentFeaturedPage = index);
            },
            itemCount: featured.length,
            itemBuilder: (context, index) {
              return _buildFeaturedHero(context, featured[index], langCode, isDark);
            },
          ),
        ),
        // Dot indicators
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(featured.length, (index) {
              final isActive = index == _currentFeaturedPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.auGold
                      : AppColors.auGold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedHero(BuildContext context, MagazineEdition magazine, String langCode, bool isDark) {
    _likeService.seed(EntityType.magazine, magazine.id, isLiked: magazine.isLiked, likeCount: magazine.likeCount, recentLikers: magazine.recentLikers);
    final mLikeState = _likeService.getState(EntityType.magazine, magazine.id);
    return GestureDetector(
      onTap: () => _openPdf(context, magazine),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: magazine.coverImageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: AppColors.burundiGreen.withValues(alpha: 0.2),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ),
                errorWidget: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.burundiGreen, Color(0xFF2D6E31)],
                    ),
                  ),
                  child: const Center(child: Icon(Icons.auto_stories, size: 48, color: Colors.white54)),
                ),
              ),
              // Dark gradient overlay
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
              // Featured badge
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.auGold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
                  ),
                ),
              ),
              // Bottom content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        magazine.getTitle(langCode),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                          fontFamily: 'HeatherGreen', height: 1.2,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM yyyy').format(magazine.publishDate),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _flipCardStat(Icons.visibility, '${magazine.viewCount}'),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _toggleLike(magazine),
                            child: _flipCardStat(
                              mLikeState.isLiked ? Icons.favorite : Icons.favorite_border,
                              '${mLikeState.likeCount}',
                              iconColor: mLikeState.isLiked ? Colors.red : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          LikedByAvatars(
                            likers: mLikeState.recentLikers,
                            totalLikes: mLikeState.likeCount,
                            avatarRadius: 10,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.burundiGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.menu_book, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  langCode == 'fr' ? 'Lire' : 'Read Now',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildMagazineCard(BuildContext context, MagazineEdition magazine, String langCode, bool isDark) {
    _likeService.seed(EntityType.magazine, magazine.id, isLiked: magazine.isLiked, likeCount: magazine.likeCount, recentLikers: magazine.recentLikers);
    final mLikeState = _likeService.getState(EntityType.magazine, magazine.id);
    return GestureDetector(
      onTap: () => _openPdf(context, magazine),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: magazine.coverImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: AppColors.burundiGreen.withValues(alpha: 0.1),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.burundiGreen.withValues(alpha: 0.08),
                        child: const Center(child: Icon(Icons.auto_stories, size: 36, color: AppColors.burundiGreen)),
                      ),
                    ),
                  ),
                  // Info button
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => _showMagInfo(context, magazine, langCode),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline, size: 14, color: AppColors.burundiGreen),
                      ),
                    ),
                  ),
                  if (magazine.hasPdf)
                    Positioned(
                      bottom: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.burundiRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            // Title and stats
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      magazine.getTitle(langCode),
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM yyyy').format(magazine.publishDate),
                      style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLike(magazine),
                          child: Icon(
                            mLikeState.isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 14, color: mLikeState.isLiked ? Colors.red : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text('${mLikeState.likeCount}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LikedByAvatars(
                            likers: mLikeState.recentLikers,
                            totalLikes: mLikeState.likeCount,
                            avatarRadius: 8,
                            overlap: 6,
                          ),
                        ),
                      ],
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

  Widget _flipCardStat(IconData icon, String value, {Color? iconColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor ?? Colors.white70),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showMagInfo(BuildContext context, MagazineEdition magazine, String langCode) {
    _likeService.seed(EntityType.magazine, magazine.id, isLiked: magazine.isLiked, likeCount: magazine.likeCount, recentLikers: magazine.recentLikers);
    final mLikeState = _likeService.getState(EntityType.magazine, magazine.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Portrait image gallery (cover + additional images)
              if (magazine.coverImageUrl.isNotEmpty || magazine.images.isNotEmpty)
                SizedBox(
                  height: 280,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 1 + magazine.images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final imageUrl = index == 0
                          ? magazine.coverImageUrl
                          : magazine.images[index - 1].imageUrl;
                      final caption = index == 0
                          ? null
                          : magazine.images[index - 1].getCaption(langCode);
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: caption != null && caption.isNotEmpty ? 250 : 280,
                              width: 190,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                width: 190,
                                height: caption != null && caption.isNotEmpty ? 250 : 280,
                                decoration: BoxDecoration(
                                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, _, _) => Container(
                                width: 190,
                                height: caption != null && caption.isNotEmpty ? 250 : 280,
                                decoration: BoxDecoration(
                                  color: AppColors.burundiGreen.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_stories, size: 40, color: AppColors.burundiGreen),
                                    SizedBox(height: 8),
                                    Text('Magazine', style: TextStyle(color: AppColors.burundiGreen)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (caption != null && caption.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: SizedBox(
                                width: 190,
                                child: Text(
                                  caption,
                                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                magazine.getTitle(langCode),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'HeatherGreen'),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('MMMM dd, yyyy').format(magazine.publishDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 14),
              // Stats row
              Row(
                children: [
                  _infoStat(Icons.visibility, '${magazine.viewCount}', 'Views'),
                  const SizedBox(width: 16),
                  _infoStat(Icons.favorite, '${mLikeState.likeCount}', 'Likes'),
                  if (magazine.pageCount > 0) ...[
                    const SizedBox(width: 16),
                    _infoStat(Icons.description, '${magazine.pageCount}', 'Pages'),
                  ],
                  if (magazine.fileSize.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    _infoStat(Icons.storage, magazine.fileSize, 'Size'),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                magazine.getDescription(langCode),
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openPdf(context, magazine);
                  },
                  icon: const Icon(Icons.menu_book),
                  label: Text(magazine.hasPdf ? 'Read Magazine' : 'PDF Not Available'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burundiGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.burundiGreen),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildArticlesList(BuildContext context, String langCode, bool isDark, ThemeData theme) {
    final filtered = _filteredArticles;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No articles found', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    Widget buildArticleTile(Article article) {
      final catColor = article.category?.parsedColor ?? AppColors.info;
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
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
              // Image / category color
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
                            child: Text(
                              article.category?.getDisplayName(langCode) ?? '',
                              style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('d/M/yyyy').format(article.publishDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        setState(() => _isLoading = true);
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: LoginGate.itemCountFor(
          actualCount: filtered.length,
          isAuthenticated: isAuth,
        ),
        itemBuilder: (context, index) {
          final slot = LoginGate.slotFor(
            index: index,
            actualCount: filtered.length,
            isAuthenticated: isAuth,
          );
          switch (slot) {
            case LoginGateSlot.free:
              return buildArticleTile(filtered[index]);
            case LoginGateSlot.banner:
              return const LoginGateBanner(
                margin: EdgeInsets.only(bottom: 12),
              );
            case LoginGateSlot.blurred:
              final dataIndex = LoginGate.dataIndexFor(index, LoginGate.defaultFreeItems);
              if (dataIndex == null || dataIndex >= filtered.length) {
                return const SizedBox.shrink();
              }
              return LockedContentWrap(
                locked: true,
                child: buildArticleTile(filtered[dataIndex]),
              );
            case LoginGateSlot.hidden:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
