import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_ds.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../widgets/ds/ds_widgets.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  List<_PhrasebookCategory> _categories = [];
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;

  static const Map<String, IconData> _iconMap = {
    'waving_hand': Icons.waving_hand_rounded,
    'explore': Icons.explore_rounded,
    'account_balance': Icons.account_balance_rounded,
    'tag': Icons.tag_rounded,
    'restaurant': Icons.restaurant_rounded,
    'flight': Icons.flight_rounded,
    'theater_comedy': Icons.theater_comedy_rounded,
    'business_center': Icons.business_center_rounded,
    'translate': Icons.translate_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fetchPhrases();
  }

  Future<void> _fetchPhrases() async {
    try {
      final data = await ApiService().get('phrasebook/');
      final List<dynamic> items = data is List ? data : [];
      setState(() {
        _categories = items.map((cat) {
          final phrases = (cat['phrases'] as List<dynamic>? ?? [])
              .map((p) => _Phrase(
                    kirundi: p['kirundi'] ?? '',
                    english: p['english'] ?? '',
                    french: p['french'] ?? '',
                  ))
              .toList();
          return _PhrasebookCategory(
            key: cat['category'] ?? '',
            label: cat['label'] ?? '',
            icon: _iconMap[cat['icon']] ?? Icons.translate_rounded,
            phrases: phrases,
          );
        }).toList();
        _selectedIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load phrasebook.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: Text(l10n.translate('phrasebook'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 48, color: Ds.muted(context)),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Ds.body(context))),
                      const SizedBox(height: 16),
                      DsOutlineButton('Retry', radius: Ds.rPill, onTap: () {
                        setState(() { _loading = true; _error = null; });
                        _fetchPhrases();
                      }),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? Center(
                      child: Text(AppLocalizations.of(context).translate('no_phrases_available'),
                          style: TextStyle(color: Ds.body(context))))
                  : _buildPhrasebook(),
    );
  }

  Widget _buildPhrasebook() {
    final selected = _categories[_selectedIndex];
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    // The phrasebook goes one way: from the language you read the app in,
    // into Kirundi — the phrase you'd actually say out loud.
    final yourLangLabel = fr ? 'FRANÇAIS' : 'ENGLISH';
    final otherLangLabel = fr ? 'ENGLISH' : 'FRANÇAIS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Direction explainer, so the card layout reads unambiguously.
        DsCard(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  fr ? 'Français' : 'English',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Ds.ink(context)),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Ds.tint(context), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded,
                    size: 20, color: Ds.green),
              ),
              const Expanded(
                child: Text(
                  'Kirundi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Ds.green),
                ),
              ),
            ],
          ),
        ),
        DsFootnote(fr
            ? 'Appuyez sur une phrase pour copier le kirundi.'
            : 'Tap a phrase to copy the Kirundi.'),

        // Category chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_categories.length, (i) {
                final cat = _categories[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DsFilterChip(
                    cat.label,
                    selected: _selectedIndex == i,
                    onTap: () => setState(() => _selectedIndex = i),
                  ),
                );
              }),
            ),
          ),
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: selected.phrases.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final phrase = selected.phrases[index];
              final yours = fr ? phrase.french : phrase.english;
              final other = fr ? phrase.english : phrase.french;
              return _phraseCard(
                yourLangLabel: yourLangLabel,
                yours: yours,
                otherLangLabel: otherLangLabel,
                other: other,
                kirundi: phrase.kirundi,
                copiedMessage: fr ? 'Copié' : 'Copied',
              );
            },
          ),
        ),
      ],
    );
  }

  /// One phrase: what you mean on white, what you say on green.
  Widget _phraseCard({
    required String yourLangLabel,
    required String yours,
    required String otherLangLabel,
    required String other,
    required String kirundi,
    required String copiedMessage,
  }) {
    return DsCard(
      clip: true,
      onTap: () {
        Clipboard.setData(ClipboardData(text: kirundi));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$copiedMessage: $kirundi'),
            backgroundColor: Ds.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(yourLangLabel, style: Ds.groupLabel(context)),
                const SizedBox(height: 5),
                Text(yours,
                    style: TextStyle(
                        fontSize: 16, height: 1.4, color: Ds.ink(context))),
                if (other.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('$otherLangLabel · $other',
                      style: TextStyle(fontSize: 12, color: Ds.muted(context))),
                ],
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Ds.green,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KIRUNDI',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Colors.white.withValues(alpha: 0.7))),
                      const SizedBox(height: 5),
                      Text(kirundi,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                              color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.content_copy_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.85)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhrasebookCategory {
  final String key;
  final String label;
  final IconData icon;
  final List<_Phrase> phrases;

  _PhrasebookCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.phrases,
  });
}

class _Phrase {
  final String kirundi;
  final String english;
  final String french;

  _Phrase({required this.kirundi, required this.english, required this.french});
}
