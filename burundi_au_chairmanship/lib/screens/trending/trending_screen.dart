import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_ds.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../widgets/ds/ds_widgets.dart';
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
            builder: (_) => ArticleDetailScreen(article: match.first, scrollToComments: false),
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
    final fr = langCode == 'fr';

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          DsHeader(title: fr ? 'Tendances' : 'Trending'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _loadTrending();
              },
              color: Ds.green,
              child: _buildBody(fr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool fr) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_hasError || _trendingItems.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 80),
        children: [
          Icon(_hasError ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
              size: 56, color: Ds.muted(context)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _hasError
                  ? (fr ? 'Impossible de charger les tendances' : 'Could not load trending content')
                  : (fr ? 'Aucun contenu tendance pour le moment' : 'No trending content right now'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Ds.body(context)),
            ),
          ),
          if (_hasError) ...[
            const SizedBox(height: 20),
            Center(
              child: DsOutlineButton(fr ? 'Réessayer' : 'Try again',
                  radius: Ds.rPill, onTap: _loadTrending),
            ),
          ],
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _trendingItems.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _trendingItems.length) {
          return DsFootnote(
              fr ? 'Mis à jour toutes les heures' : 'Updated hourly',
              center: true);
        }
        return _buildTrendingCard(_trendingItems[index], index + 1, fr);
      },
    );
  }

  Widget _buildTrendingCard(Map<String, dynamic> item, int rank, bool fr) {
    final contentType = (item['content_type'] ?? 'article').toString();
    final contentTitle = (item['content_title'] ?? (fr ? 'Contenu' : 'Content')).toString();
    final score = (item['score'] as num?)?.toDouble() ?? 0;
    final contentId = item['content_id'] as int? ?? 0;

    // Top three ranks are colour-coded like the comp: red, gold, then green.
    final rankColor = switch (rank) {
      1 => Ds.red,
      2 => Ds.goldDeep,
      _ => Ds.green,
    };

    final typeLabel = contentType.isEmpty
        ? ''
        : contentType[0].toUpperCase() + contentType.substring(1);

    return DsCard(
      onTap: contentType == 'article' ? () => _navigateToArticle(contentId) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: rankColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contentTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ds.cardTitle(context)),
                const SizedBox(height: 3),
                Text('$typeLabel · ${score.toStringAsFixed(0)} ${fr ? "vues" : "reads"}',
                    style: Ds.meta(context)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Ds.chevron),
        ],
      ),
    );
  }
}
