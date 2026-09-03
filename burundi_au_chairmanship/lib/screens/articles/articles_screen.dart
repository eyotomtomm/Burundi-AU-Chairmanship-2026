import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../services/content_cache_service.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/login_gate.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/async_content_view.dart';
import '../../widgets/sliver_async_content_view.dart';
import '../../services/like_service.dart';
import '../news/article_detail_screen.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  List<Article>? _articles;
  bool _isLoading = true;
  bool _hasError = false;
  int? _selectedCategoryId;
  final LikeService _likeService = LikeService();
  // Featured articles ride a horizontal carousel rather than stacking.
  final PageController _featuredController = PageController();
  int _featuredPage = 0;
  Timer? _featuredTimer;
  VoidCallback? _removeLikeListener;


  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key.startsWith('article:') && mounted) setState(() {});
    });
    _loadArticles();
    _loadCategories();
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    _featuredTimer?.cancel();
    _featuredController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService().getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadArticles() async {
    try {
      final articles = await ApiService().getArticles();
      if (!mounted) return;
      ContentCacheService().cacheArticles(ContentCacheService.keyArticles, articles);
      setState(() {
        _articles = articles;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      final cached = ContentCacheService().getArticles(ContentCacheService.keyArticles);
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _articles = cached;
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

  List<Article> _filterArticles(List<Article> articles) {
    if (_selectedCategoryId == null) return articles;
    return articles.where((a) => a.category?.id == _selectedCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    final AsyncContentState contentState;
    if (_isLoading) {
      contentState = AsyncContentState.loading;
    } else if (_hasError) {
      contentState = AsyncContentState.error;
    } else if ((_articles ?? []).isEmpty) {
      contentState = AsyncContentState.empty;
    } else {
      contentState = AsyncContentState.content;
    }

    final allArticles = _articles ?? [];
    final filtered = _filterArticles(allArticles);
    final featured = allArticles.where((a) => a.isFeatured).toList();

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: contentState != AsyncContentState.content
          ? CustomScrollView(
              slivers: [
                _buildSliverAppBar(l10n, langCode),
                SliverAsyncContentView(
                  state: contentState,
                  loadingWidget: const ShimmerArticleListSkeleton(),
                  emptyIcon: Icons.article_outlined,
                  emptyMessage: langCode == 'fr' ? 'Les articles arrivent bientôt' : 'Articles coming soon',
                  onRetry: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                    });
                    _loadArticles();
                  },
                  child: const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                await _loadArticles();
                _loadCategories();
              },
              child: CustomScrollView(
                key: const PageStorageKey<String>('articles_scroll'),
                slivers: [
                  _buildSliverAppBar(l10n, langCode),

                  if (featured.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildFeaturedCarousel(featured, langCode, l10n),
                    ),

                  filtered.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.article_outlined, size: 56, color: isDark ? Colors.white24 : Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    langCode == 'fr' ? 'Les articles arrivent bientôt' : 'Articles coming soon',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final slot = LoginGate.slotFor(
                                  index: index,
                                  actualCount: filtered.length,
                                  isAuthenticated: isAuth,
                                );
                                switch (slot) {
                                  case LoginGateSlot.free:
                                    return _buildArticleRow(filtered[index], langCode);
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
                                      child: _buildArticleRow(filtered[dataIndex], langCode),
                                    );
                                  case LoginGateSlot.hidden:
                                    return const SizedBox.shrink();
                                }
                              },
                              childCount: LoginGate.itemCountFor(
                                actualCount: filtered.length,
                                isAuthenticated: isAuth,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  /// Green header carrying the category filters, as on the News tab.
  Widget _buildSliverAppBar(AppLocalizations l10n, String langCode) {
    return SliverToBoxAdapter(
      child: DsHeader(
        title: langCode == 'fr' ? 'Actualités' : 'News',
        large: true,
        bottomPad: 16,
        bottom: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DsFilterChip(
                  l10n.translate('all_categories'),
                  selected: _selectedCategoryId == null,
                  onGreen: true,
                  onTap: () => setState(() => _selectedCategoryId = null),
                ),
              ),
              for (final cat in _categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DsFilterChip(
                    cat.getDisplayName(langCode),
                    selected: _selectedCategoryId == cat.id,
                    onGreen: true,
                    onTap: () => setState(() => _selectedCategoryId = cat.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _articleImage(Article article) => CachedNetworkImage(
        imageUrl: Environment.fixMediaUrl(article.imageUrl),
        fit: BoxFit.cover,
        placeholder: (_, _) => const DsImagePlaceholder(radius: 0),
        errorWidget: (_, _, _) =>
            const DsImagePlaceholder(radius: 0, icon: Icons.article_rounded),
      );

  /// Featured articles slide horizontally; a single one just renders flat.
  Widget _buildFeaturedCarousel(
      List<Article> featured, String langCode, AppLocalizations l10n) {
    if (featured.length == 1) {
      return _buildFeaturedCard(featured.first, langCode, l10n);
    }

    _startFeaturedAutoSlide(featured.length);

    return Column(
      children: [
        SizedBox(
          // Fixed so every page is the same height regardless of headline length.
          height: 372,
          child: PageView.builder(
            controller: _featuredController,
            itemCount: featured.length,
            onPageChanged: (i) => setState(() => _featuredPage = i),
            itemBuilder: (context, index) =>
                _buildFeaturedCard(featured[index], langCode, l10n),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(featured.length, (i) {
              final active = i == _featuredPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Ds.green : Ds.outline(context),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Advances the featured carousel every few seconds, wrapping at the end.
  void _startFeaturedAutoSlide(int count) {
    if (_featuredTimer != null || count <= 1) return;
    _featuredTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_featuredController.hasClients) return;
      final next = (_featuredPage + 1) % count;
      _featuredController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget _buildFeaturedCard(Article article, String langCode, AppLocalizations l10n) {
    _likeService.seed(EntityType.article, article.id,
        isLiked: article.isLiked,
        likeCount: article.likeCount,
        recentLikers: article.recentLikers);
    final ls = _likeService.getState(EntityType.article, article.id);

    return DsCard(
      margin: const EdgeInsets.all(16),
      featured: true,
      clip: true,
      onTap: () => _openDetail(article),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 190, width: double.infinity, child: _articleImage(article)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsPill(l10n.translate('featured').toUpperCase()),
                    const SizedBox(width: 8),
                    Text(DateFormat('MMM d · HH:mm').format(article.publishDate),
                        style: Ds.meta(context)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  article.getTitle(langCode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -0.3,
                      color: Ds.ink(context)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                        ls.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 17,
                        color: ls.isLiked ? Ds.red : Ds.muted(context)),
                    const SizedBox(width: 5),
                    Text('${ls.likeCount}', style: Ds.meta(context)),
                    const SizedBox(width: 14),
                    Icon(Icons.mode_comment_outlined,
                        size: 17, color: Ds.muted(context)),
                    const SizedBox(width: 5),
                    Text('${article.commentCount}', style: Ds.meta(context)),
                    const Spacer(),
                    Icon(Icons.visibility_rounded, size: 17, color: Ds.muted(context)),
                    const SizedBox(width: 5),
                    Text('${article.viewCount}', style: Ds.meta(context)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleRow(Article article, String langCode) {
    final catLabel = article.category?.getDisplayName(langCode) ?? '';
    final when = DateFormat('MMM d').format(article.publishDate);

    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: () => _openDetail(article),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Ds.rTile),
            child: SizedBox(width: 92, height: 78, child: _articleImage(article)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.getTitle(langCode),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: Ds.ink(context)),
                ),
                const SizedBox(height: 5),
                Text([if (catLabel.isNotEmpty) catLabel, when].join(' · '),
                    style: Ds.meta(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(Article article) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ArticleDetailScreen(
          article: article,
          scrollToComments: false,
        ),
      ),
    );
  }
}
