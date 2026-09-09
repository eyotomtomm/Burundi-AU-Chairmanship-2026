import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../models/fact_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../services/share_service.dart';
import '../../widgets/app_network_image.dart';
import '../../l10n/app_localizations.dart';

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

    if (_isLoading && fact == null) {
      return Scaffold(
        backgroundColor: Ds.bg(context),
        appBar: AppBar(title: const Text('')),
        body: const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green)),
      );
    }

    if (_error != null && fact == null) {
      return Scaffold(
        backgroundColor: Ds.bg(context),
        appBar: AppBar(title: const Text('')),
        body: Center(
            child: Text(_error!, style: TextStyle(color: Ds.body(context)))),
      );
    }

    if (fact == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // Hero photo with floating circular controls, per the comp.
          SizedBox(
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (fact.image.isNotEmpty)
                  AppNetworkImage(
                    imageUrl: fact.image,
                    fit: BoxFit.cover,
                    hero: true,
                    errorWidget: (_, _, _) => const DsImagePlaceholder(radius: 0),
                  )
                else
                  const DsImagePlaceholder(radius: 0),
                Positioned(
                  left: 16,
                  top: MediaQuery.paddingOf(context).top + 8,
                  child: _circleButton(Icons.arrow_back_rounded,
                      () => Navigator.pop(context),
                      MaterialLocalizations.of(context).backButtonTooltip),
                ),
                Positioned(
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + 8,
                  child: Builder(
                    builder: (btnContext) =>
                        _circleButton(Icons.share_rounded, () {
                      ShareService.item(
                        btnContext,
                        kind: 'facts',
                        id: fact.id,
                        title: fact.isQuote
                            ? '"${fact.getContent(langCode)}"\n\u2014 ${fact.authorName}'
                            : fact.getTitle(langCode),
                        note: fact.isQuote ? null : fact.getContent(langCode),
                      );
                    }, AppLocalizations.of(context).translate('share')),
                  ),
                ),
              ],
            ),
          ),

          // Title card, pulled up over the photo.
          Transform.translate(
            offset: const Offset(0, -28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DsPill(
                        (fact.category?.getDisplayName(langCode) ??
                                (fact.isQuote
                                    ? (langCode == 'fr' ? 'Citation' : 'Quote')
                                    : (langCode == 'fr' ? 'Fait' : 'Fact')))
                            .toUpperCase(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        fact.isQuote
                            ? fact.getContent(langCode)
                            : fact.getTitle(langCode),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.3,
                            color: Ds.ink(context)),
                      ),
                      if (fact.authorName.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.person_rounded,
                                size: 16, color: Ds.body(context)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                fact.authorTitle.isEmpty
                                    ? fact.authorName
                                    : '${fact.authorName} · ${fact.getAuthorTitle(langCode)}',
                                style: TextStyle(
                                    fontSize: 13, color: Ds.body(context)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                if (!fact.isQuote && fact.getContent(langCode).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                    child: Text(
                      fact.getContent(langCode),
                      style: TextStyle(
                          fontSize: 14, height: 1.65, color: Ds.body(context)),
                    ),
                  ),

                if (fact.source.isNotEmpty)
                  DsNoteBanner(
                    icon: Icons.menu_book_rounded,
                    title: 'Source',
                    subtitle: fact.getSource(langCode),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: DsPrimaryButton(
                    langCode == 'fr'
                        ? 'Voir la série'
                        : 'More in this series',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, String label) =>
      Semantics(
        button: true,
        label: label,
        child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        ),
      );
}
