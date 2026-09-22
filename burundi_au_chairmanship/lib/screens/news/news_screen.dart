import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
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
import 'article_detail_screen.dart';
import '../../services/read_service.dart';

class NewsScreen extends StatefulWidget {
  final bool isTab;
  final VoidCallback? onBackToHome;
  const NewsScreen({super.key, this.isTab = false, this.onBackToHome});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Article>? _articles;
  bool _isLoading = true;
  bool _hasError = false;
  int? _selectedCategoryId; // null = all
  final LikeService _likeService = LikeService();
  // Featured articles ride a horizontal carousel rather than stacking.
  final PageController _featuredController = PageController();
  int _featuredPage = 0;
  Timer? _featuredTimer;
  VoidCallback? _removeLikeListener;
  // The server pages at 20; the next page loads as the reader nears the end.
  final ScrollController _scroll = ScrollController();
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;


  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    ReadService.instance.addListener(_onReadChanged);
    ReadService.instance.load();
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key.startsWith('article:') && mounted) setState(() {});
    });
    _scroll.addListener(_onScroll);
    _loadArticles();
    _loadCategories();
  }

  @override
  void dispose() {
    ReadService.instance.removeListener(_onReadChanged);
    _removeLikeListener?.call();
    _featuredTimer?.cancel();
    _featuredController.dispose();
    _scroll.dispose();
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
    } catch (_) {
      // Categories will remain empty; chips won't show
    }
  }

  Future<void> _loadArticles() async {
    final categoryId = _selectedCategoryId;
    try {
      final page = await ApiService().getNews(categoryId: categoryId);
      // A chip tapped mid-request owns the list now.
      if (!mounted || categoryId != _selectedCategoryId) return;
      if (categoryId == null) {
        ContentCacheService().cacheArticles(ContentCacheService.keyNews, page.articles);
      }
      setState(() {
        _articles = page.articles;
        _page = 1;
        _hasMore = page.hasMore;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || categoryId != _selectedCategoryId) return;
      _hasMore = false;
      // Fall back to cache, which only ever holds the unfiltered first page.
      final cached = categoryId == null
          ? ContentCacheService().getArticles(ContentCacheService.keyNews)
          : null;
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

  void _onScroll() {
    // Guests see a handful of rows behind the login gate; more pages buy nothing.
    if (!_scroll.hasClients || !_hasMore || _loadingMore || _isLoading) return;
    if (!context.read<AuthProvider>().isAuthenticated) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final categoryId = _selectedCategoryId;
    setState(() => _loadingMore = true);
    try {
      final next = await ApiService().getNews(categoryId: categoryId, page: _page + 1);
      if (!mounted || categoryId != _selectedCategoryId) return;
      final seen = {for (final a in _articles ?? <Article>[]) a.id};
      setState(() {
        _page += 1;
        _articles = [
          ...?_articles,
          ...next.articles.where((a) => !seen.contains(a.id)),
        ];
        _hasMore = next.hasMore;
      });
    } catch (_) {
      // Stop asking rather than retrying every scroll frame; pull to refresh starts over.
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectCategory(int? id) {
    if (id == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = id;
      _isLoading = true;
      _hasError = false;
      _hasMore = false;
      _loadingMore = false;
    });
    _loadArticles();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
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
    // The newest few featured posts also get hero cards on top. They stay in
    // the list below: pulling them out left gaps in the dateline, and a reader
    // scrolling for a post from last week has no reason to look in a carousel.
    final featured = allArticles.where((a) => a.isFeatured).take(5).toList();
    final listArticles = allArticles;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: contentState != AsyncContentState.content
          ? CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(l10n, langCode)),
                SliverAsyncContentView(
                  state: contentState,
                  loadingWidget: const ShimmerArticleListSkeleton(),
                  emptyIcon: Icons.article_outlined,
                  emptyMessage: langCode == 'fr'
                      ? 'Les articles arrivent bientôt'
                      : 'Articles coming soon',
                  onRetry: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                    });
                    _loadArticles();
                  },
                  child: const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
                SliverToBoxAdapter(
                    child: SizedBox(height: Ds.navSpace(context))),
              ],
            )
          : RefreshIndicator(
              color: Ds.green,
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
                key: const PageStorageKey<String>('news_scroll'),
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(l10n, langCode)),

                  if (featured.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildFeaturedCarousel(featured, langCode, l10n)),

                  if (listArticles.isEmpty && featured.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                        child: Column(
                          children: [
                            Icon(Icons.article_outlined,
                                size: 56, color: Ds.muted(context)),
                            const SizedBox(height: 16),
                            Text(
                              langCode == 'fr'
                                  ? 'Les articles arrivent bientôt'
                                  : 'Articles coming soon',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Ds.ink(context)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final slot = LoginGate.slotFor(
                              index: index,
                              actualCount: listArticles.length,
                              isAuthenticated: isAuth,
                            );
                            switch (slot) {
                              case LoginGateSlot.free:
                                return _buildArticleRow(listArticles[index], langCode);
                              case LoginGateSlot.banner:
                                return const LoginGateBanner(
                                    margin: EdgeInsets.only(bottom: 10));
                              case LoginGateSlot.blurred:
                                final dataIndex = LoginGate.dataIndexFor(
                                    index, LoginGate.defaultFreeItems);
                                if (dataIndex == null ||
                                    dataIndex >= listArticles.length) {
                                  return const SizedBox.shrink();
                                }
                                return LockedContentWrap(
                                  locked: true,
                                  child: _buildArticleRow(
                                      listArticles[dataIndex], langCode),
                                );
                              case LoginGateSlot.hidden:
                                return const SizedBox.shrink();
                            }
                          },
                          childCount: LoginGate.itemCountFor(
                            actualCount: listArticles.length,
                            isAuthenticated: isAuth,
                          ),
                        ),
                      ),
                    ),
                  if (_loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Ds.green),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                      child: SizedBox(height: Ds.navSpace(context))),
                ],
              ),
            ),
    );
  }

  /// Green header with the category filters carried inside it, per the comp.
  Widget _buildHeader(AppLocalizations l10n, String langCode) {
    return DsHeader(
      title: l10n.translate('news'),
      large: true,
      bottomPad: 16,
      showBack: !widget.isTab || widget.onBackToHome != null,
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
                onTap: () => _selectCategory(null),
              ),
            ),
            for (final cat in _categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DsFilterChip(
                  cat.getDisplayName(langCode),
                  selected: _selectedCategoryId == cat.id,
                  onGreen: true,
                  onTap: () => _selectCategory(cat.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _articleImage(Article article, {BoxFit fit = BoxFit.cover, bool hero = false}) {
    return AppNetworkImage(
      imageUrl: Environment.fixMediaUrl(article.imageUrl),
      fit: fit,
      hero: hero,
      placeholder: (_, _) => const DsImagePlaceholder(radius: 0),
      errorWidget: (_, _, _) =>
          const DsImagePlaceholder(radius: 0, icon: Icons.article_rounded),
    );
  }

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
          SizedBox(height: 190, width: double.infinity, child: _articleImage(article, hero: true)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsPill(l10n.translate('featured').toUpperCase()),
                    const SizedBox(width: 8),
                    Text(DateFormat.MMMd(langCode).add_Hm().format(article.publishDate),
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
    final l10n = AppLocalizations.of(context);
    final catLabel = article.category?.getDisplayName(langCode) ?? '';
    final when = DateFormat.MMMd(langCode).format(article.publishDate);
    final read = ReadService.instance.isRead(article.id);

    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: () => _openDetail(article),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Ds.rTile),
                child: SizedBox(width: 92, height: 78, child: _articleImage(article)),
              ),
              // A read item recedes rather than disappears — still findable,
              // clearly behind you.
              if (read)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Ds.rTile),
                      child: Container(
                        color: Ds.bg(context).withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.isFeatured || read)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        if (article.isFeatured)
                          _rowBadge(
                            l10n.translate('featured'),
                            Ds.goldInk,
                            Ds.goldTintOf(context),
                            Icons.star_rounded,
                          ),
                        if (article.isFeatured && read) const SizedBox(width: 6),
                        if (read)
                          _rowBadge(
                            l10n.translate('read'),
                            Ds.muted(context),
                            Ds.subtle(context),
                            Icons.check_rounded,
                          ),
                      ],
                    ),
                  ),
                Text(
                  article.getTitle(langCode),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: read ? FontWeight.w500 : FontWeight.w600,
                      height: 1.35,
                      color: read ? Ds.body(context) : Ds.ink(context)),
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

  /// Small status chip used on a list row.
  Widget _rowBadge(String label, Color ink, Color fill, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Ds.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ink),
          const SizedBox(width: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }

  void _onReadChanged() {
    if (mounted) setState(() {});
  }

  void _openDetail(Article article) {
    ReadService.instance.markRead(article.id);
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
