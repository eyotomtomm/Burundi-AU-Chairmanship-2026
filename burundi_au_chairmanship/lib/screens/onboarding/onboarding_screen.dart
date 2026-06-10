import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';

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

  /// Hardcoded bilingual fallback steps — used when the API returns nothing.
  static List<Map<String, dynamic>> _fallbackSteps(String lang) {
    final isFr = lang == 'fr';
    return [
      {
        'icon': Icons.celebration_rounded,
        'title': isFr ? 'Bienvenue sur Be 4 Africa' : 'Welcome to Be 4 Africa',
        'description': isFr
            ? 'Votre compagnon pour la Présidence de l\'Union Africaine 2026. Faisons le tour !'
            : 'Your companion for the African Union Chairmanship 2026. Let\'s show you around!',
      },
      {
        'icon': Icons.article_rounded,
        'title': isFr ? 'Actualités & Articles' : 'News & Articles',
        'description': isFr
            ? 'Restez informé des derniers articles et annonces'
            : 'Stay updated with the latest articles and announcements',
      },
      {
        'icon': Icons.event_rounded,
        'title': isFr ? 'Événements' : 'Events',
        'description': isFr
            ? 'Parcourez les événements à venir, inscrivez-vous et obtenez des billets'
            : 'Browse upcoming events, register, and get tickets',
      },
      {
        'icon': Icons.auto_stories_rounded,
        'title': isFr ? 'Magazine Numérique' : 'Digital Magazine',
        'description': isFr
            ? 'Lisez le magazine numérique et les articles en vedette'
            : 'Read the digital magazine and featured articles',
      },
      {
        'icon': Icons.live_tv_rounded,
        'title': isFr ? 'Diffusions en Direct' : 'Live Feeds',
        'description': isFr
            ? 'Regardez les diffusions en direct et le contenu vidéo'
            : 'Watch live streams and video content',
      },
      {
        'icon': Icons.translate_rounded,
        'title': isFr ? 'Traduction' : 'Translate',
        'description': isFr
            ? 'Traduisez le contenu entre les langues instantanément'
            : 'Translate content between languages instantly',
      },
      {
        'icon': Icons.photo_library_rounded,
        'title': isFr ? 'Galerie' : 'Gallery',
        'description': isFr
            ? 'Explorez les albums photos des événements et sommets'
            : 'Explore photo albums from events and summits',
      },
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
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    l10n.skip,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.burundiGreen,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (step['image'] != null && step['image'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              step['image'],
                              height: 260,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => _buildIconPlaceholder(step),
                            ),
                          )
                        else
                          _buildIconPlaceholder(step),
                        const SizedBox(height: 40),
                        Text(
                          step['title'] ?? '',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step['description'] ?? '',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i ? AppColors.burundiGreen : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Action button
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLastPage
                      ? _completeOnboarding
                      : () => _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burundiGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isLastPage
                        ? (widget.isReplay ? l10n.close : l10n.getStarted)
                        : l10n.next,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPlaceholder(Map<String, dynamic> step) {
    // Use the step's icon if available (from fallback steps), otherwise default
    final IconData icon = step['icon'] is IconData ? step['icon'] : Icons.star;

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.burundiGreen.withValues(alpha: 0.1),
            const Color(0xFFFFB74D).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Icon(
        icon,
        size: 80,
        color: AppColors.burundiGreen.withValues(alpha: 0.5),
      ),
    );
  }
}
