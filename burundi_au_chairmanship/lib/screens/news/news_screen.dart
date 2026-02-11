import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<Article>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _articlesFuture = _loadArticles();
  }

  Future<List<Article>> _loadArticles() async {
    try {
      return await ApiService().getArticles();
    } catch (_) {
      return MagazineData.getMockArticles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('latest_news'),
          style: GoogleFonts.oswald(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Article>>(
        future: _articlesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final articles = snapshot.data ?? MagazineData.getMockArticles();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _articlesFuture = _loadArticles();
              });
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                return _buildArticleCard(context, article, langCode, isDark);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, Article article, String langCode, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showArticleDetail(context, article, langCode),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CachedNetworkImage(
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
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.burundiGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      article.category,
                      style: GoogleFonts.oswald(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.burundiGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    article.getTitle(langCode),
                    style: GoogleFonts.oswald(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Author + Date
                  Row(
                    children: [
                      Icon(Icons.person_rounded, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        article.author,
                        style: GoogleFonts.oswald(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.schedule_rounded, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(article.publishDate),
                        style: GoogleFonts.oswald(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
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

  void _showArticleDetail(BuildContext context, Article article, String langCode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              article.getTitle(langCode),
              style: GoogleFonts.oswald(fontWeight: FontWeight.w600, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CachedNetworkImage(
                  imageUrl: article.imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    height: 220,
                    color: AppColors.burundiGreen.withValues(alpha: 0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.getTitle(langCode),
                        style: GoogleFonts.oswald(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: AppColors.burundiGreen),
                          const SizedBox(width: 6),
                          Text(article.author, style: GoogleFonts.oswald(fontSize: 14, color: AppColors.burundiGreen)),
                          const SizedBox(width: 20),
                          const Icon(Icons.schedule_rounded, size: 16, color: AppColors.burundiGreen),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMMM d, yyyy').format(article.publishDate),
                            style: GoogleFonts.oswald(fontSize: 14, color: AppColors.burundiGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        article.getContent(langCode),
                        style: GoogleFonts.oswald(
                          fontSize: 16,
                          height: 1.7,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
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
  }
}
