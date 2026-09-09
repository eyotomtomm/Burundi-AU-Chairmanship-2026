import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_generated.dart';
import '../../widgets/app_network_image.dart';
import '../../config/app_ds.dart';

class OnboardingScreen extends StatefulWidget {
  /// When true, shows "Close" instead of "Get Started" and skips the
  /// completeOnboarding API call (used from the More tab "App Guide").
  final bool isReplay;

  const OnboardingScreen({super.key, this.isReplay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ApiService _api = ApiService();
  final PageController _pageCtrl = PageController();
  List<Map<String, dynamic>> _steps = [];
  bool _loading = true;
  int _currentPage = 0;

  /// Map icon_name strings from the API to Material icons.
  static const Map<String, IconData> _iconMap = {
    'celebration': Icons.celebration_rounded,
    'article': Icons.article_rounded,
    'event': Icons.event_rounded,
    'auto_stories': Icons.auto_stories_rounded,
    'live_tv': Icons.live_tv_rounded,
    'translate': Icons.translate_rounded,
    'photo_library': Icons.photo_library_rounded,
    'groups': Icons.groups_rounded,
    'campaign': Icons.campaign_rounded,
    'podcasts': Icons.podcasts_rounded,
    'video_library': Icons.video_library_rounded,
    'school': Icons.school_rounded,
    'forum': Icons.forum_rounded,
    'star': Icons.star_rounded,
    'explore': Icons.explore_rounded,
    'bookmark': Icons.bookmark_rounded,
    'favorite': Icons.favorite_rounded,
    'notifications': Icons.notifications_rounded,
    'public': Icons.public_rounded,
    'verified': Icons.verified_rounded,
  };

  /// Hardcoded bilingual fallback steps — used when the API returns nothing.
  static List<Map<String, dynamic>> _fallbackSteps(String lang) {
    final g = lookupAppLocalizationsGenerated(Locale(lang));
    return [
      {'icon': Icons.celebration_rounded, 'title': g.onboarding_welcome, 'description': g.onboarding_welcome_desc},
      {'icon': Icons.article_rounded, 'title': g.onboarding_news, 'description': g.onboarding_news_desc},
      // Explore is the newest surface, so it is flagged and carried near the
      // front where a returning reader will actually meet it.
      {'icon': Icons.forum_rounded, 'title': g.onboarding_explore, 'description': g.onboarding_explore_desc, 'is_new': true},
      {'icon': Icons.event_rounded, 'title': g.onboarding_events, 'description': g.onboarding_events_desc},
      {'icon': Icons.auto_stories_rounded, 'title': g.onboarding_magazine, 'description': g.onboarding_magazine_desc},
      {'icon': Icons.live_tv_rounded, 'title': g.onboarding_live, 'description': g.onboarding_live_desc},
      {'icon': Icons.translate_rounded, 'title': g.onboarding_translate, 'description': g.onboarding_translate_desc},
      {'icon': Icons.photo_library_rounded, 'title': g.onboarding_gallery, 'description': g.onboarding_gallery_desc},
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    try {
      final apiSteps = await _api.getOnboardingSteps();
      if (apiSteps.isNotEmpty) {
        _steps = apiSteps;
      }
    } catch (_) {}

    // Use fallback when API returned nothing
    if (_steps.isEmpty) {
      final lang = mounted
          ? Localizations.localeOf(context).languageCode
          : 'en';
      _steps = _fallbackSteps(lang);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _completeOnboarding() async {
    if (!widget.isReplay) {
      try {
        await _api.completeOnboarding();
      } catch (_) {}
    }
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, true);
    }
  }

  /// Resolve the correct image URL based on dark/light mode.
  String? _resolveImage(Map<String, dynamic> step, bool isDark) {
    if (isDark) {
      final dark = step['image_dark']?.toString() ?? '';
      if (dark.isNotEmpty) return dark;
    }
    final light = step['image']?.toString() ?? '';
    return light.isNotEmpty ? light : null;
  }

  /// Resolve an IconData from the step — either from fallback 'icon' key
  /// or from the API 'icon_name' string.
  IconData _resolveIcon(Map<String, dynamic> step) {
    if (step['icon'] is IconData) return step['icon'];
    final name = step['icon_name']?.toString() ?? '';
    return _iconMap[name] ?? Icons.star_rounded;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.burundiGreen,
          ),
        ),
      );
    }

    final isLastPage = _currentPage == _steps.length - 1;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // Where you are, and the way out. A counter beats a row of dots
            // when there are eight steps to get through.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    '${_currentPage + 1} ${l10n.translate('guide_step_of')} ${_steps.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Ds.muted(context),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      widget.isReplay ? l10n.close : l10n.skip,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Ds.green,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Ds.rPill),
                child: LinearProgressIndicator(
                  value: _steps.isEmpty ? 0 : (_currentPage + 1) / _steps.length,
                  minHeight: 4,
                  backgroundColor: Ds.subtle(context),
                  valueColor: const AlwaysStoppedAnimation<Color>(Ds.green),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final s = _steps[index];
                  final imageUrl = _resolveImage(s, isDark);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1.18,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Ds.rCard + 4),
                            child: imageUrl != null
                                ? AppNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    hero: true,
                                    errorWidget: (_, _, _) => _buildIconPlaceholder(s),
                                  )
                                : _buildIconPlaceholder(s),
                          ),
                        ),
                        const SizedBox(height: 26),
                        if (s['is_new'] == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: Ds.goldTintOf(context),
                              borderRadius: BorderRadius.circular(Ds.rPill),
                            ),
                            child: Text(
                              l10n.translate('guide_new_badge').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Ds.goldInk,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          s['title'] ?? '',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.5,
                            color: Ds.ink(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s['description'] ?? '',
                          style: TextStyle(
                            fontSize: 15.5,
                            color: Ds.body(context),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  // Only offered once there is somewhere to go back to.
                  if (_currentPage > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: TextButton(
                        onPressed: () => _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        ),
                        child: Text(
                          l10n.translate('guide_back'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Ds.body(context),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLastPage
                            ? _completeOnboarding
                            : () => _pageCtrl.nextPage(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Ds.green,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Ds.rTile + 2)),
                        ),
                        child: Text(
                          isLastPage
                              ? (widget.isReplay ? l10n.close : l10n.getStarted)
                              : l10n.next,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The panel behind each step when the CMS has no artwork for it. A solid
  /// brand plate with the glyph carried large, rather than the old 10%-alpha
  /// wash that read as a placeholder for a missing image.

  Widget _buildIconPlaceholder(Map<String, dynamic> step) {
    final icon = _resolveIcon(step);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Ds.greenDeep, Ds.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A soft off-centre highlight so the plate is not a flat block.
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Center(child: Icon(icon, size: 84, color: Colors.white)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 4, color: Ds.gold),
          ),
        ],
      ),
    );
  }
}
