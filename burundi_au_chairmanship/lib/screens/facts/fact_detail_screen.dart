import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../../models/fact_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';

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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(fact != null
            ? (fact.isQuote ? (langCode == 'fr' ? 'Citation' : 'Quote') : (langCode == 'fr' ? 'Fait' : 'Fact'))
            : ''),
        actions: [
          if (fact != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                final text = fact.isQuote
                    ? '"${fact.getContent(langCode)}"\n-- ${fact.authorName}'
                    : '${fact.getTitle(langCode)}\n\n${fact.getContent(langCode)}';
                Share.share(text);
              },
            ),
        ],
      ),
      body: _isLoading && fact == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && fact == null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : fact == null
                  ? const SizedBox.shrink()
                  : _buildContent(fact, langCode),
    );
  }

  Widget _buildContent(Fact fact, String langCode) {
    final categoryColor = fact.category?.parsedColor ?? const Color(0xFF1EB53A);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (fact.image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                fact.image,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (fact.image.isNotEmpty) const SizedBox(height: 16),

          // Badges
          Row(
            children: [
              if (fact.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fact.category!.getDisplayName(langCode),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: categoryColor),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fact.isQuote
                      ? Colors.deepPurple.withValues(alpha: 0.1)
                      : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      fact.isQuote ? Icons.format_quote_rounded : Icons.lightbulb_outline_rounded,
                      size: 14,
                      color: fact.isQuote ? Colors.deepPurple : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fact.isQuote ? (langCode == 'fr' ? 'Citation' : 'Quote') : (langCode == 'fr' ? 'Fait' : 'Fact'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fact.isQuote ? Colors.deepPurple : Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content
          if (fact.isQuote) ...[
            Icon(Icons.format_quote_rounded, size: 36, color: categoryColor.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              fact.getContent(langCode),
              style: TextStyle(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                height: 1.6,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            if (fact.authorName.isNotEmpty) ...[
              Divider(color: categoryColor.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              Text(
                fact.authorName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: categoryColor),
              ),
              if (fact.authorTitle.isNotEmpty)
                Text(
                  fact.getAuthorTitle(langCode),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
            ],
          ] else ...[
            Text(
              fact.getTitle(langCode),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              fact.getContent(langCode),
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            if (fact.source.isNotEmpty) ...[
              const SizedBox(height: 20),
              Divider(color: categoryColor.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.source_outlined, size: 16, color: categoryColor),
                  const SizedBox(width: 6),
                  Text(
                    langCode == 'fr' ? 'Source' : 'Source',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: categoryColor),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fact.getSource(langCode),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
