import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_ds.dart';
import '../../services/api_service.dart';

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

  static const _points = [
    (
      Icons.badge_rounded,
      'Post as yourself',
      'Your name, photo and country appear on everything you post. No anonymous accounts.',
    ),
    (
      Icons.forum_rounded,
      'Argue the point, not the person',
      'Disagree as sharply as you like. Harassment, hate and threats are removed.',
    ),
    (
      Icons.fact_check_rounded,
      'Be honest about sources',
      'Do not present rumour as fact. Misinformation about the agenda gets taken down.',
    ),
    (
      Icons.flag_rounded,
      'Reporting is on you too',
      'If you see something that breaks these terms, report it. Moderators review every report.',
    ),
  ];

  static String _label(String field) => switch (field) {
        'profile_picture' => 'a profile photo',
        'date_of_birth' => 'your date of birth',
        'name' => 'your name',
        'nationality' => 'your country',
        'phone' => 'your phone number',
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
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Welcome to Explore',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'A public space for youth policy debate. Read this once before you take part.',
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
                              Text(title,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Ds.ink(context))),
                              const SizedBox(height: 3),
                              Text(body,
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
                            Text('Before you can post',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Ds.ink(context))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We still need ${missing.map(_label).join(', ')}. '
                          'This is what keeps Explore accountable — every post has a real person behind it.',
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
                            child: Text('Complete my profile',
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
                    'I have read and agree to the Explore community terms.',
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
                      : const Text('Agree and continue',
                          style: TextStyle(
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
