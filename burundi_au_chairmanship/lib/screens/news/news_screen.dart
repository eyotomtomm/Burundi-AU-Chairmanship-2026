import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import 'article_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<Article>> _articlesFuture;
  int? _selectedCategoryId; // null = all
  int _featuredPage = 0;
  final _featuredController = PageController(viewportFraction: 0.92);

  static const _accent = AppColors.auGold;
  static const _accentDark = Color(0xFFB8960E);

  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _articlesFuture = _loadArticles();
    _loadCategories();
  }

  @override
  void dispose() {
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
    } catch (_) {
      // Categories will remain empty; chips won't show
    }
  }

  Future<List<Article>> _loadArticles() async {
    try {
      return await ApiService().getArticles();
    } catch (_) {
      return MagazineData.getMockArticles();
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

    return Scaffold(
      body: FutureBuilder<List<Article>>(
        future: _articlesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(l10n),
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          final allArticles = snapshot.data ?? MagazineData.getMockArticles();
          final filtered = _filterArticles(allArticles);
          final featured = allArticles.where((a) => a.isFeatured).toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _articlesFuture = _loadArticles();
              });
              _loadCategories();
            },
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(l10n),

                // Featured articles carousel (multiple)
                if (featured.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedCarousel(featured, langCode, isDark, l10n),
                  ),

                // Category filter chips
                SliverToBoxAdapter(
                  child: _buildCategoryChips(l10n, langCode),
                ),

                // Article list
                filtered.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Text(
                            l10n.translate('no_data'),
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildArticleCard(context, filtered[index], langCode, isDark, l10n);
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(AppLocalizations l10n) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          l10n.translate('news'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.auGold, _accentDark],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCarousel(List<Article> featured, String langCode, bool isDark, AppLocalizations l10n) {
    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _featuredController,
            itemCount: featured.length,
            onPageChanged: (i) => setState(() => _featuredPage = i),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                child: _buildFeaturedCard(featured[index], langCode, isDark, l10n),
              );
            },
          ),
        ),
        if (featured.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(featured.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _featuredPage == i ? 20 : 8,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _featuredPage == i ? _accent : _accent.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildFeaturedCard(Article article, String langCode, bool isDark, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _openDetail(article),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: article.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: _accent.withValues(alpha: 0.2)),
              errorWidget: (_, __, ___) => Container(
                color: _accent.withValues(alpha: 0.2),
                child: const Icon(Icons.article_rounded, size: 48, color: Colors.white54),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            // Featured badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.translate('featured').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            // Content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.getTitle(langCode),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatChip(Icons.visibility_rounded, '${article.viewCount}', Colors.white70),
                      const SizedBox(width: 12),
                      _buildStatChip(Icons.chat_bubble_outline_rounded, '${article.commentCount}', Colors.white70),
                      const SizedBox(width: 12),
                      _buildStatChip(Icons.favorite_rounded, '${article.likeCount}', Colors.white70),
                      const Spacer(),
                      Text(
                        article.author,
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(AppLocalizations l10n, String langCode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                l10n.translate('all_categories'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _selectedCategoryId == null ? Colors.white : _accent,
                ),
              ),
              selected: _selectedCategoryId == null,
              selectedColor: _accent,
              backgroundColor: _accent.withValues(alpha: 0.08),
              side: BorderSide(
                color: _selectedCategoryId == null ? _accent : _accent.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (_) {
                setState(() => _selectedCategoryId = null);
              },
            ),
          ),
          // Dynamic category chips
          ..._categories.map((cat) {
            final isSelected = _selectedCategoryId == cat.id;
            final chipColor = cat.parsedColor;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  cat.getDisplayName(langCode),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : chipColor,
                  ),
                ),
                selected: isSelected,
                selectedColor: chipColor,
                backgroundColor: chipColor.withValues(alpha: 0.08),
                side: BorderSide(
                  color: isSelected ? chipColor : chipColor.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (_) {
                  setState(() => _selectedCategoryId = cat.id);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, Article article, String langCode, bool isDark, AppLocalizations l10n) {
    final catColor = article.category?.parsedColor ?? AppColors.burundiGreen;
    final catLabel = article.category?.getDisplayName(langCode) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _openDetail(article),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with category badge
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.burundiGreen.withValues(alpha: 0.1),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.burundiGreen.withValues(alpha: 0.1),
                      child: const Icon(Icons.article_rounded, size: 48, color: AppColors.burundiGreen),
                    ),
                  ),
                  // Category badge on image
                  if (catLabel.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          catLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    article.getTitle(langCode),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Author + date row
                  Row(
                    children: [
                      Icon(Icons.person_rounded, size: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        article.author,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.schedule_rounded, size: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(article.publishDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Engagement stats row
                  Row(
                    children: [
                      _buildStatChip(
                        Icons.visibility_rounded,
                        '${article.viewCount}',
                        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 14),
                      _buildStatChip(
                        Icons.chat_bubble_outline_rounded,
                        '${article.commentCount}',
                        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 14),
                      _buildStatChip(
                        article.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        '${article.likeCount}',
                        article.isLiked ? AppColors.burundiRed : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }

  void _openDetail(Article article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );
  }
}
