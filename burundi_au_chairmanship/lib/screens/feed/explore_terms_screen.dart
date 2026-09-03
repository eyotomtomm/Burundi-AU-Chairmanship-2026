import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_ds.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

/// One-time gate before someone can take part in Explore.
///
/// Two conditions, both server-checked: the community terms are accepted, and
/// the profile carries a real photo and the details that make a post
/// accountable to a person.
class ExploreTermsScreen extends StatefulWidget {
  final List<String> missingFields;

  const ExploreTermsScreen({super.key, this.missingFields = const []});

  @override
  State<ExploreTermsScreen> createState() => _ExploreTermsScreenState();
}

class _ExploreTermsScreenState extends State<ExploreTermsScreen> {
  bool _agreed = false;
  bool _busy = false;

  // (icon, title key, body key) — resolved through l10n at build time.
  static const _points = [
    (Icons.badge_rounded, 'xt_point1_title', 'xt_point1_body'),
    (Icons.forum_rounded, 'xt_point2_title', 'xt_point2_body'),
    (Icons.fact_check_rounded, 'xt_point3_title', 'xt_point3_body'),
    (Icons.flag_rounded, 'xt_point4_title', 'xt_point4_body'),
  ];

  static String _label(AppLocalizations l10n, String field) => switch (field) {
        'profile_picture' => l10n.translate('xt_field_photo'),
        'date_of_birth' => l10n.translate('xt_field_dob'),
        'name' => l10n.translate('xt_field_name'),
        'nationality' => l10n.translate('xt_field_country'),
        'phone' => l10n.translate('xt_field_phone'),
        _ => field.replaceAll('_', ' '),
      };

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ApiService().acceptExploreTerms();
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final missing = widget.missingFields;
    final ready = _agreed && missing.isEmpty;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(Ds.headerHPad,
                MediaQuery.viewPaddingOf(context).top + 12, Ds.headerHPad, 24),
            decoration: const BoxDecoration(
              color: Ds.green,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context, false),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(l10n.translate('explore_terms_title'),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  l10n.translate('explore_terms_subtitle'),
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                // No French legal copy exists yet; the English text is binding.
                if (Localizations.localeOf(context).languageCode == 'fr')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(l10n.translate('explore_terms_english_prevails'),
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Ds.muted(context))),
                  ),
                for (final (icon, title, body) in _points)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Ds.surface(context),
                      borderRadius: BorderRadius.circular(Ds.rCard),
                      boxShadow: Ds.shadow(context),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Ds.tint(context),
                            borderRadius: BorderRadius.circular(Ds.rIcon),
                          ),
                          child: Icon(icon, size: 20, color: Ds.green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.translate(title),
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Ds.ink(context))),
                              const SizedBox(height: 3),
                              Text(l10n.translate(body),
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Ds.body(context))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (missing.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Ds.goldTintOf(context),
                      borderRadius: BorderRadius.circular(Ds.rCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_search_rounded,
                                size: 20, color: Ds.goldInk),
                            const SizedBox(width: 8),
                            Text(l10n.translate('explore_terms_before_posting'),
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Ds.ink(context))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${l10n.translate('xt_we_still_need')} ${missing.map((m) => _label(l10n, m)).join(', ')}. '
                          '${l10n.translate('xt_accountable')}',
                          style: TextStyle(
                              fontSize: 13, height: 1.45, color: Ds.body(context)),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/profile-completion'),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Ds.surface(context),
                              borderRadius: BorderRadius.circular(Ds.rPill),
                            ),
                            child: Text(l10n.translate('explore_terms_complete_profile'),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Ds.ink(context))),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  activeColor: Ds.green,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    l10n.translate('explore_terms_agree'),
                    style: TextStyle(
                        fontSize: 14, height: 1.4, color: Ds.ink(context)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.viewPaddingOf(context).bottom + 16),
            child: GestureDetector(
              onTap: ready && !_busy ? _accept : null,
              child: Opacity(
                opacity: ready ? 1 : 0.45,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Ds.green,
                    borderRadius: BorderRadius.circular(Ds.rPill),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(l10n.translate('explore_terms_continue'),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
