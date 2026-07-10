import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../config/app_colors.dart';
import '../../models/fact_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';

const _gold = Color(0xFFFCD116);

const _palettes = [
  [Color(0xFF0E2E11), Color(0xFF1A4A1E), Color(0xFF8A7010)],
  [Color(0xFF3D0A0E), Color(0xFF5E1218), Color(0xFF8A7010)],
  [Color(0xFF0C2410), Color(0xFF1C3E20), Color(0xFF2E5432)],
  [Color(0xFF2E0808), Color(0xFF4A1010), Color(0xFF6B4A12)],
  [Color(0xFF0A1F0D), Color(0xFF163A1A), Color(0xFF5A1515)],
];

class FactDetailScreen extends StatefulWidget {
  final int factId;
  final Fact? fact;

  const FactDetailScreen({super.key, required this.factId, this.fact});

  @override
  State<FactDetailScreen> createState() => _FactDetailScreenState();
}

class _FactDetailScreenState extends State<FactDetailScreen> {
  Fact? _fact;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fact = widget.fact;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await ApiService().getFactDetail(widget.factId);
      if (mounted) setState(() { _fact = detail; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<LanguageProvider>().languageCode;
    final fact = _fact;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading && fact == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F6F2),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(CupertinoIcons.back, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen)),
      );
    }

    if (_error != null && fact == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F6F2),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text(_error!, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38))),
      );
    }

    if (fact == null) return const SizedBox.shrink();

    final palette = _palettes[widget.factId % _palettes.length];
    final categoryColor = fact.category?.parsedColor ?? AppColors.burundiGreen;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F6F2),
      body: CustomScrollView(
        slivers: [
          // Hero header with gradient
          SliverAppBar(
            expandedHeight: fact.image.isNotEmpty ? 300 : 220,
            pinned: true,
            backgroundColor: palette[0],
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  final text = fact.isQuote
                      ? '"${fact.getContent(langCode)}"\n\u2014 ${fact.authorName}'
                      : '${fact.getTitle(langCode)}\n\n${fact.getContent(langCode)}';
                  Share.share(text);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image or gradient
                  if (fact.image.isNotEmpty)
                    Image.network(
                      fact.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: palette,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: palette,
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),

                  // Dark gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Gold accent strip at bottom
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          _gold.withValues(alpha: 0.0),
                          _gold.withValues(alpha: 0.6),
                          _gold.withValues(alpha: 0.0),
                        ]),
                      ),
                    ),
                  ),

                  // Category + type badges at bottom
                  Positioned(
                    left: 20, right: 20, bottom: 20,
                    child: Row(
                      children: [
                        if (fact.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _gold.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              fact.category!.getDisplayName(langCode),
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: _gold, letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                fact.isQuote ? Icons.format_quote_rounded : Icons.auto_awesome,
                                size: 13, color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fact.isQuote
                                    ? (langCode == 'fr' ? 'Citation' : 'Quote')
                                    : (langCode == 'fr' ? 'Fait' : 'Fact'),
                                style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70,
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

          // Content body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 60),
              child: fact.isQuote
                  ? _buildQuoteContent(fact, langCode, categoryColor, isDark)
                  : _buildFactContent(fact, langCode, categoryColor, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteContent(Fact fact, String langCode, Color categoryColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Opening quote mark
        Text(
          '\u201C',
          style: TextStyle(
            fontSize: 56, height: 0.6, fontWeight: FontWeight.w900,
            color: categoryColor.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 8),

        // Quote text
        Text(
          fact.getContent(langCode),
          style: TextStyle(
            fontSize: 22, fontStyle: FontStyle.italic,
            height: 1.7, letterSpacing: -0.2,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),

        // Author
        if (fact.authorName.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : categoryColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: categoryColor.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.person_rounded, size: 24, color: categoryColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fact.authorName,
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (fact.authorTitle.isNotEmpty)
                        Text(
                          fact.getAuthorTitle(langCode),
                          style: TextStyle(
                            fontSize: 13, height: 1.4,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFactContent(Fact fact, String langCode, Color categoryColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          fact.getTitle(langCode),
          style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
            height: 1.3, letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 20),

        // Content
        Text(
          fact.getContent(langCode),
          style: TextStyle(
            fontSize: 16, height: 1.8,
            color: isDark ? Colors.white.withValues(alpha: 0.75) : Colors.black.withValues(alpha: 0.65),
          ),
        ),

        // Source
        if (fact.source.isNotEmpty) ...[
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : categoryColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: categoryColor.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_rounded, size: 18, color: categoryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Source',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: categoryColor, letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fact.getSource(langCode),
                        style: TextStyle(
                          fontSize: 13, height: 1.4,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
