import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../models/magazine_model.dart';
import '../../../services/api_service.dart';
import '../../../services/content_cache_service.dart';
import '../../../widgets/login_gate.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/async_content_view.dart';
import '../../../widgets/liked_by_avatars.dart';
import '../../../services/like_service.dart';
import '../../magazine/magazine_detail_screen.dart';

class MagazineTab extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const MagazineTab({super.key, this.onBackToHome});

  @override
  State<MagazineTab> createState() => _MagazineTabState();
}

class _MagazineTabState extends State<MagazineTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MagazineEdition>? _editions;
  bool _isLoading = true;
  bool _hasError = false;
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
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
      final editions = await api.getMagazines();
      if (!mounted) return;
      // Cache on success
      ContentCacheService().cacheMagazines(editions);
      setState(() {
        _editions = editions;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Fall back to cache
      final cached = ContentCacheService().getMagazines();
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _editions = cached;
          _isLoading = false;
          _hasError = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
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

  void _openMagazineDetail(BuildContext context, MagazineEdition edition) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => MagazineDetailScreen(
          magazine: edition,
          scrollToComments: false,
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

  Set<int> get _availableYears {
    return (_editions ?? []).map((e) => e.publishDate.year).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine state for AsyncContentView
    final AsyncContentState contentState;
    if (_isLoading) {
      contentState = AsyncContentState.loading;
    } else if (_hasError) {
      contentState = AsyncContentState.error;
    } else if ((_editions ?? []).isEmpty) {
      contentState = AsyncContentState.empty;
    } else {
      contentState = AsyncContentState.content;
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Gradient app bar — always visible
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
                  ],
                ),
              ),
            ),
          ),
        ],
        body: contentState != AsyncContentState.content
            ? AsyncContentView(
                state: contentState,
                loadingWidget: const ShimmerMagazineGridSkeleton(),
                emptyIcon: Icons.auto_stories,
                emptyMessage: l10n.noData,
                onRetry: () {
                  setState(() { _isLoading = true; _hasError = false; });
                  _loadData();
                },
                onRefresh: () async {
                  setState(() { _isLoading = true; _hasError = false; });
                  await _loadData();
                },
                child: const SizedBox.shrink(),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  HapticFeedback.mediumImpact();
                  await _loadData();
                },
                color: AppColors.burundiGreen,
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.md, AppSpacing.pagePadding, 0),
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
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        children: _buildMagazineFilters(isDark),
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
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: pageMags.map((mag) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
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
      onTap: () => _openMagazineDetail(context, magazine),
      child: Container(
        margin: EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.sm, AppSpacing.pagePadding, 0),
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
                imageUrl: Environment.fixMediaUrl(magazine.coverImageUrl),
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
                              mLikeState.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              '${mLikeState.likeCount}',
                              iconColor: mLikeState.isLiked ? Colors.red : null,
                              label: 'Like',
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
      onTap: () => _openMagazineDetail(context, magazine),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
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
                      imageUrl: Environment.fixMediaUrl(magazine.coverImageUrl),
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
                  // Info button — navigates to detail screen
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => _openMagazineDetail(context, magazine),
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
                padding: EdgeInsets.all(AppSpacing.sm),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                mLikeState.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 16, color: mLikeState.isLiked ? Colors.red : Colors.grey,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${mLikeState.likeCount}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mLikeState.isLiked ? Colors.red : Colors.grey[600]),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Like',
                                style: TextStyle(fontSize: 10, color: mLikeState.isLiked ? Colors.red : Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
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

  Widget _flipCardStat(IconData icon, String value, {Color? iconColor, String? label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.white70),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: iconColor ?? Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: iconColor ?? Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

}
