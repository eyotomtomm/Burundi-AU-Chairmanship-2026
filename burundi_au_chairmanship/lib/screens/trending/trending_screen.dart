import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/translate_button.dart';
import '../news/article_detail_screen.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  List<Map<String, dynamic>> _trendingItems = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final items = await ApiService().getTrendingContent();
      if (mounted) {
        setState(() {
          _trendingItems = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _navigateToArticle(int contentId) async {
    try {
      final articles = await ApiService().getArticles();
      final match = articles.where((a) => a.id == contentId.toString()).toList();
      if (match.isNotEmpty && mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ArticleDetailScreen(article: match.first, scrollToComments: context.read<AuthProvider>().isAuthenticated),
          ),
        );
      }
    } catch (_) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          langCode == 'fr' ? 'Tendances' : 'Trending',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [TranslateButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up_rounded, size: 64,
                          color: isDark ? Colors.white38 : Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        langCode == 'fr'
                            ? 'Impossible de charger les tendances'
                            : 'Could not load trending content',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadTrending,
                        icon: const Icon(Icons.refresh),
                        label: Text(langCode == 'fr' ? 'Reessayer' : 'Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.burundiGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _trendingItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_flat_rounded, size: 64,
                              color: isDark ? Colors.white38 : Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            langCode == 'fr'
                                ? 'Aucun contenu tendance pour le moment'
                                : 'No trending content right now',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        HapticFeedback.mediumImpact();
                        await _loadTrending();
                      },
                      color: AppColors.burundiGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _trendingItems.length,
                        itemBuilder: (context, index) {
                          final item = _trendingItems[index];
                          return _buildTrendingCard(item, index + 1, langCode, isDark);
                        },
                      ),
                    ),
    );
  }

  Widget _buildTrendingCard(Map<String, dynamic> item, int rank, String langCode, bool isDark) {
    final contentType = item['content_type'] ?? 'article';
    final contentTitle = item['content_title'] ?? (langCode == 'fr' ? 'Contenu' : 'Content');
    final score = (item['score'] as num?)?.toDouble() ?? 0;
    final contentId = item['content_id'] as int? ?? 0;

    // Choose icon based on content type
    IconData typeIcon;
    Color typeColor;
    switch (contentType) {
      case 'magazine':
        typeIcon = Icons.auto_stories_rounded;
        typeColor = AppColors.burundiRed;
        break;
      case 'video':
        typeIcon = Icons.play_circle_rounded;
        typeColor = AppColors.burundiGreen;
        break;
      default:
        typeIcon = Icons.article_rounded;
        typeColor = AppColors.burundiGreen;
    }

    // Rank badge colors
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    }

    return GestureDetector(
      onTap: () {
        if (contentType == 'article') {
          _navigateToArticle(contentId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rank <= 3
                ? rankColor.withValues(alpha: 0.4)
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rank <= 3 ? rankColor.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: rank <= 3 ? 18 : 16,
                    fontWeight: FontWeight.w800,
                    color: rankColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contentTitle.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(typeIcon, size: 14, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        contentType.toString().substring(0, 1).toUpperCase() +
                            contentType.toString().substring(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: typeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.trending_up_rounded, size: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        score.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}
