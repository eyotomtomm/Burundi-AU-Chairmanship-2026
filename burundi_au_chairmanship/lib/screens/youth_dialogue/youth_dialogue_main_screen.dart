import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../models/event_registration_model.dart';
import '../../models/youth_dialogue_model.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/confetti_overlay.dart';
import 'youth_dialogue_apply_screen.dart';

class YouthDialogueMainScreen extends StatefulWidget {
  const YouthDialogueMainScreen({super.key});

  @override
  State<YouthDialogueMainScreen> createState() => _YouthDialogueMainScreenState();
}

class _YouthDialogueMainScreenState extends State<YouthDialogueMainScreen> {
  bool _isLoading = true;
  String? _error;
  bool _hasApplication = false;
  YouthDialogueApplication? _application;
  Map<String, dynamic>? _settings;
  List<RegistrationFormField> _formFields = [];
  bool _showApprovalBanner = false;
  DateTime? _lastChecked;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    ApiService().youthDialogueLogActivity('screen_visit', 'youth_dialogue_main');
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService().youthDialogueSettings(),
        ApiService().youthDialogueStatus().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;

      final statusData = results[1];
      final hasApp = statusData['has_application'] == true;
      YouthDialogueApplication? app;
      if (hasApp) {
        app = YouthDialogueApplication.fromJson(statusData);
      }

      bool showBanner = false;
      bool showAcceptedDialog = false;
      bool showCredentialIssuedDialog = false;
      if (app != null && app.status == 'accepted') {
        final prefs = await SharedPreferences.getInstance();
        final key = 'yd_approval_banner_seen_${app.id}';
        if (!prefs.containsKey(key)) {
          showBanner = true;
          showAcceptedDialog = true;
        }
      }
      if (app != null && app.status == 'credential_issued') {
        final prefs = await SharedPreferences.getInstance();
        final key = 'yd_credential_issued_seen_${app.id}';
        if (!prefs.containsKey(key)) {
          showCredentialIssuedDialog = true;
        }
      }

      setState(() {
        _settings = results[0];
        final rawFields = _settings?['form_fields'] as List<dynamic>? ?? [];
        _formFields = rawFields
            .map((f) => RegistrationFormField.fromJson(f as Map<String, dynamic>))
            .where((f) => f.isActive)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        _hasApplication = hasApp;
        _application = app;
        _showApprovalBanner = showBanner;
        _lastChecked = DateTime.now();
        _isLoading = false;
      });

      // Show confetti + congratulations dialog for first-time accepted users
      if (showAcceptedDialog && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ConfettiOverlay.show(context);
            _showAcceptedDialog();
          }
        });
      }

      // Show confetti + notification for first-time credential_issued users
      if (showCredentialIssuedDialog && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ConfettiOverlay.show(context);
            _showCredentialIssuedDialog();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    await _loadData();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _dismissApprovalBanner() async {
    if (_application == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('yd_approval_banner_seen_${_application!.id}', true);
    setState(() => _showApprovalBanner = false);
  }

  String _t(String enKey, String frKey, bool isFr) {
    if (_settings == null) return '';
    final val = isFr ? _settings![frKey] : null;
    if (val != null && val.toString().isNotEmpty) return val.toString();
    return _settings![enKey]?.toString() ?? '';
  }

  List<String> _parseLines(String enKey, String frKey, bool isFr) {
    final text = _t(enKey, frKey, isFr);
    if (text.isEmpty) return [];
    return text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  }

  /// Returns the programme title from admin settings, falling back to 'Continental Dialogue'.
  String _programmeTitle(bool isFr) {
    if (_settings == null) return 'Continental Dialogue';
    final title = _t('programme_title', 'programme_title_fr', isFr);
    return title.isNotEmpty ? title : 'Continental Dialogue';
  }

  String? _formatDateRange(bool isFr) {
    final startStr = _settings?['start_date']?.toString() ?? '';
    final endStr = _settings?['end_date']?.toString() ?? '';
    if (startStr.isEmpty) return null;
    final start = DateTime.tryParse(startStr);
    if (start == null) return null;
    final locale = isFr ? 'fr' : 'en';
    final end = endStr.isNotEmpty ? DateTime.tryParse(endStr) : null;
    if (end != null) {
      if (start.month == end.month && start.year == end.year) {
        return '${DateFormat('MMM d', locale).format(start)}–${DateFormat('d, y', locale).format(end)}';
      }
      return '${DateFormat('MMM d', locale).format(start)} – ${DateFormat('MMM d, y', locale).format(end)}';
    }
    return DateFormat('MMM d, y', locale).format(start);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(_programmeTitle(isFr)),
          backgroundColor: AppColors.burundiGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(_programmeTitle(isFr)),
          backgroundColor: AppColors.burundiGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _buildError(isDark),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.burundiGreen,
        edgeOffset: 100,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeroAppBar(isDark, isFr),
            SliverToBoxAdapter(child: _buildInfoBar(isDark, isFr)),
            SliverToBoxAdapter(child: _buildAboutSection(isDark, isFr)),
            SliverToBoxAdapter(child: _buildHighlightsSection(isDark, isFr)),
            SliverToBoxAdapter(child: _buildEligibilitySection(isDark, isFr)),
            SliverToBoxAdapter(child: _buildSideEventsSection(isDark, isFr)),
            SliverToBoxAdapter(child: _buildPromotionalVideo(isDark, isFr)),
            SliverToBoxAdapter(child: _buildMediaGallery(isDark, isFr)),
            if (_hasApplication) ...[
              SliverToBoxAdapter(child: _buildApplicationStatusSection(isDark, isFr)),
            ],
            SliverToBoxAdapter(child: _buildSupportSection(isDark, isFr)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDark, isFr),
    );
  }

  // ── Hero SliverAppBar ──────────────────────────────────────
  Widget _buildHeroAppBar(bool isDark, bool isFr) {
    final bannerUrl = _settings?['banner_image_url']?.toString() ?? '';
    final title = _t('programme_title', 'programme_title_fr', isFr);
    final tagline = _t('event_tagline', 'event_tagline_fr', isFr);
    final dateRange = _formatDateRange(isFr);
    final location = _settings?['location']?.toString() ?? '';

    // Language-specific local logos
    final dialogueLogo = isFr
        ? 'assets/images/youth_dialogue/dialogue_logo_fr.png'
        : 'assets/images/youth_dialogue/dialogue_logo_en.png';
    const b4AfricaLogo = 'assets/images/youth_dialogue/b4_africa_logo.png';

    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      backgroundColor: AppColors.burundiGreen,
      foregroundColor: Colors.white,
      actions: [
        _buildLanguageToggle(),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background: banner image or rich gradient
            if (bannerUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: Environment.fixMediaUrl(bannerUrl),
                fit: BoxFit.cover,
                memCacheWidth: 1200,
                placeholder: (_, __) => _buildGradientBackground(''),
                errorWidget: (_, __, ___) => _buildGradientBackground(''),
              )
            else
              _buildGradientBackground(''),
            // Subtle pattern overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
            // ── Logos centered in upper area ──
            Positioned(
              left: 0,
              right: 0,
              top: 80,
              child: Column(
                children: [
                  // Dual logo row: Dialogue Logo + divider + B4 Africa
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Dialogue logo (EN or FR)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          dialogueLogo,
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Elegant divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Container(
                          width: 1.5, height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.1),
                                Colors.white.withValues(alpha: 0.6),
                                Colors.white.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // B4 Africa logo
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          b4AfricaLogo,
                          height: 90,
                          width: 120,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Title + tagline + chips at bottom ──
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                    ),
                  ),
                  if (tagline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        tagline,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                        ),
                      ),
                    ),
                  if (dateRange != null || location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (dateRange != null)
                            _buildHeroChip(Icons.calendar_today_rounded, dateRange),
                          if (location.isNotEmpty)
                            _buildHeroChip(Icons.location_on_rounded, location),
                        ],
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

  Widget _buildGradientBackground(String logoUrl) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.burundiGreen,
            AppColors.burundiGreen.withValues(alpha: 0.8),
            const Color(0xFF1B5E20),
          ],
        ),
      ),
      child: logoUrl.isNotEmpty
          ? Center(
              child: Opacity(
                opacity: 0.15,
                child: Image.network(
                  Environment.fixMediaUrl(logoUrl),
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Language Toggle ────────────────────────────────────────
  Widget _buildLanguageToggle() {
    final langProvider = context.watch<LanguageProvider>();
    final currentLang = langProvider.languageCode.toUpperCase();
    final otherLang = langProvider.isEnglish ? 'FR' : 'EN';

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () {
          langProvider.toggleLanguage();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate_rounded, size: 16, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Text(
                otherLang,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info Bar ────────────────────────────────────────────────
  Widget _buildInfoBar(bool isDark, bool isFr) {
    final dateRange = _formatDateRange(isFr);
    final location = _settings?['location']?.toString() ?? '';
    final venueName = _t('venue_name', 'venue_name_fr', isFr);
    final venueAddress = _t('venue_address', 'venue_address_fr', isFr);

    if (dateRange == null && location.isEmpty && venueName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          if (dateRange != null)
            _buildInfoRow(
              isDark,
              icon: Icons.calendar_today_rounded,
              color: AppColors.burundiGreen,
              label: isFr ? 'Date' : 'Date',
              value: dateRange,
            ),
          if (location.isNotEmpty) ...[
            if (dateRange != null) _buildInfoDivider(isDark),
            _buildInfoRow(
              isDark,
              icon: Icons.location_on_rounded,
              color: AppColors.burundiRed,
              label: isFr ? 'Lieu' : 'Location',
              value: location,
              onTap: () => _openMaps(location),
            ),
          ],
          if (venueName.isNotEmpty) ...[
            if (dateRange != null || location.isNotEmpty) _buildInfoDivider(isDark),
            _buildInfoRow(
              isDark,
              icon: Icons.business_rounded,
              color: AppColors.auGold,
              label: isFr ? 'Lieu de l\'événement' : 'Venue',
              value: venueName + (venueAddress.isNotEmpty ? '\n$venueAddress' : ''),
              onTap: venueAddress.isNotEmpty ? () => _openMaps('$venueName, $venueAddress') : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(bool isDark, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.open_in_new_rounded, size: 16, color: isDark ? Colors.white30 : Colors.black26),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }

  Widget _buildInfoDivider(bool isDark) {
    return Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06));
  }

  void _openMaps(String query) {
    final encoded = Uri.encodeComponent(query);
    launchUrl(Uri.parse('https://maps.google.com/?q=$encoded'), mode: LaunchMode.externalApplication);
  }

  // ── About Section ──────────────────────────────────────────
  Widget _buildAboutSection(bool isDark, bool isFr) {
    final description = _t('description', 'description_fr', isFr);
    if (description.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 8),
              Text(
                isFr ? 'À propos' : 'About the Event',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ── Key Highlights ─────────────────────────────────────────
  Widget _buildHighlightsSection(bool isDark, bool isFr) {
    final items = _parseLines('key_highlights', 'key_highlights_fr', isFr);
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 20, color: AppColors.auGold),
              const SizedBox(width: 8),
              Text(
                isFr ? 'Points forts' : 'Key Highlights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  child: const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.burundiGreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Eligibility Criteria ───────────────────────────────────
  Widget _buildEligibilitySection(bool isDark, bool isFr) {
    final items = _parseLines('eligibility_criteria', 'eligibility_criteria_fr', isFr);
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 8),
              Text(
                isFr ? 'Critères d\'éligibilité' : 'Eligibility',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white54 : Colors.black45,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Side Events ────────────────────────────────────────────
  Widget _buildSideEventsSection(bool isDark, bool isFr) {
    final lines = _parseLines('side_events_info', 'side_events_info_fr', isFr);
    if (lines.isEmpty) return const SizedBox.shrink();

    final events = lines.map((line) {
      final parts = line.split(' | ');
      return (title: parts[0].trim(), description: parts.length > 1 ? parts.sublist(1).join(' | ').trim() : '');
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.event_note_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 8),
                Text(
                  isFr ? 'Événements parallèles' : 'Side Events',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return Container(
                  width: 220,
                  margin: EdgeInsets.only(right: index < events.length - 1 ? 12 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.burundiGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.celebration_rounded, size: 16, color: AppColors.burundiGreen),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            event.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Application Status Section ─────────────────────────────
  Widget _buildApplicationStatusSection(bool isDark, bool isFr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.assignment_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 8),
                Text(
                  isFr ? 'Votre candidature' : 'Your Application',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusStepper(isDark),
          const SizedBox(height: 16),
          if (_showApprovalBanner)
            _buildApprovalBanner(isDark),
          if (_application!.status == 'documents_rejected')
            _buildActionRequiredBanner(isDark),
          _buildStatusView(isDark),
        ],
      ),
    );
  }

  // ── Bottom Apply/View Bar ──────────────────────────────────
  Widget _buildBottomBar(bool isDark, bool isFr) {
    final isOpen = _settings?['is_registration_open'] ?? true;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _hasApplication
          ? SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_application!.status == 'credential_issued') {
                    Navigator.pushNamed(context, '/youth-dialogue-credential').then((_) => _loadData());
                  } else if (['accepted', 'documents_pending', 'documents_rejected'].contains(_application!.status)) {
                    Navigator.pushNamed(context, '/youth-dialogue-documents').then((_) => _loadData());
                  } else {
                    _navigateToStatusPage(isFr);
                  }
                },
                icon: Icon(
                  _application!.status == 'credential_issued'
                      ? Icons.badge_rounded
                      : ['accepted', 'documents_pending', 'documents_rejected'].contains(_application!.status)
                          ? Icons.upload_rounded
                          : Icons.assignment_outlined,
                  color: Colors.white,
                ),
                label: Text(
                  _application!.status == 'credential_issued'
                      ? (isFr ? 'Voir la carte d\'identité' : 'View ID Card')
                      : ['accepted', 'documents_pending', 'documents_rejected'].contains(_application!.status)
                          ? (isFr ? 'Gérer les documents' : 'Manage Documents')
                          : (isFr ? 'Voir le statut' : 'View Status'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _application!.status == 'credential_issued'
                      ? Colors.purple
                      : AppColors.burundiGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            )
          : !isOpen
              ? Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, size: 20, color: AppColors.auGold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _t('registration_closed_message', 'registration_closed_message_fr', isFr),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final isFrLocal = Localizations.localeOf(context).languageCode == 'fr';
                      final privacyPolicy = _t('privacy_policy', 'privacy_policy_fr', isFrLocal);
                      if (privacyPolicy.isNotEmpty) {
                        final agreed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _YDPrivacyPolicyScreen(
                              policyText: privacyPolicy,
                              isFr: isFrLocal,
                            ),
                          ),
                        );
                        if (agreed != true || !mounted) return;
                      }
                      if (!mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => YouthDialogueApplyScreen(formFields: _formFields, programmeTitle: _programmeTitle(isFr)),
                        ),
                      );
                      _loadData();
                    },
                    icon: const Icon(Icons.edit_document, color: Colors.white),
                    label: Text(
                      isFr ? 'Postuler Maintenant' : 'Apply Now',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burundiGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
    );
  }

  // ── Accepted Congratulations Dialog ─────────────────────────
  void _showAcceptedDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration icon with animated feel
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38a169), Color(0xFF2D6E31)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.burundiGreen.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.celebration_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                isFr ? 'Félicitations !' : 'Congratulations!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isFr
                    ? 'Votre candidature au Dialogue Continental a été acceptée !'
                    : 'Your Continental Dialogue application has been accepted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFr
                    ? 'Veuillez télécharger vos documents requis pour poursuivre le processus.'
                    : 'Please upload your required documents to continue the process.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _dismissApprovalBanner();
                    if (!mounted) return;
                    await Navigator.pushNamed(context, '/youth-dialogue-documents');
                    _loadData();
                  },
                  icon: const Icon(Icons.upload_rounded, color: Colors.white),
                  label: Text(
                    isFr ? 'Télécharger les documents' : 'Upload Documents',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burundiGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _dismissApprovalBanner();
                },
                child: Text(
                  isFr ? 'Plus tard' : 'Later',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Credential Issued Congratulations Dialog ──────────────────
  Future<void> _dismissCredentialIssuedDialog() async {
    if (_application == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('yd_credential_issued_seen_${_application!.id}', true);
  }

  void _showCredentialIssuedDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Verified icon
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.verified_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                isFr ? 'Félicitations !' : 'Congratulations!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isFr
                    ? 'Vos documents ont été vérifiés et votre carte d\'identité numérique est prête !'
                    : 'Your documents have been verified and your Digital ID is ready!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFr
                    ? 'Consultez votre email pour plus de détails sur vos accréditations.'
                    : 'Check your email for more details about your credential.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _dismissCredentialIssuedDialog();
                    if (!mounted) return;
                    await Navigator.pushNamed(context, '/youth-dialogue-credential');
                    _loadData();
                  },
                  icon: const Icon(Icons.badge_rounded, color: Colors.white),
                  label: Text(
                    isFr ? 'Voir la carte d\'identité' : 'View ID Card',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _dismissCredentialIssuedDialog();
                },
                child: Text(
                  isFr ? 'Plus tard' : 'Later',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigate to full status page ──────────────────────────────
  void _navigateToStatusPage(bool isFr) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _YDStatusPage(application: _application!, isFr: isFr),
    )).then((_) => _loadData());
  }

  Widget _buildNextStep(String number, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: AppColors.burundiGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.burundiGreen)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
          ),
        ],
      ),
    );
  }

  // ── Status Stepper — 5-step pipeline ────────────────────────
  Widget _buildStatusStepper(bool isDark) {
    final isFrLocal = Localizations.localeOf(context).languageCode == 'fr';
    final steps = [
      {'label': isFrLocal ? 'Inscrit' : 'Applied'},
      {'label': isFrLocal ? 'Révision' : 'Review'},
      {'label': isFrLocal ? 'Documents' : 'Documents'},
      {'label': isFrLocal ? 'Vérification' : 'Verification'},
      {'label': isFrLocal ? 'Identifiant' : 'Digital ID'},
    ];

    final status = _application!.status;
    final isRejected = status == 'rejected';
    final isDocsRejected = status == 'documents_rejected';

    // Map status → current step (0-4)
    int currentStep;
    switch (status) {
      case 'submitted':
      case 'under_review':
        currentStep = 1;
        break;
      case 'accepted':
      case 'documents_pending':
      case 'documents_rejected':
        currentStep = 2;
        break;
      case 'documents_submitted':
      case 'documents_under_review':
        currentStep = 3;
        break;
      case 'credential_issued':
        currentStep = 4;
        break;
      case 'rejected':
        currentStep = 1;
        break;
      default:
        currentStep = 0;
    }

    // state: 1 = done, 0 = current, 2 = rejected, -1 = pending
    int getStepState(int stepIdx) {
      if (isRejected && stepIdx == 1) return 2;
      if (isRejected && stepIdx > 1) return -1;
      if (isDocsRejected && stepIdx == 2) return 2;
      if (stepIdx < currentStep) return 1;
      if (stepIdx == currentStep) return 0;
      return -1;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIdx = i ~/ 2;
                final state = getStepState(stepIdx);
                final nextState = getStepState(stepIdx + 1);
                final lineGreen = state == 1 && (nextState == 1 || nextState == 0);
                return Expanded(
                  child: Container(
                    height: 2,
                    color: lineGreen
                        ? AppColors.burundiGreen
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                );
              }
              final stepIdx = i ~/ 2;
              final state = getStepState(stepIdx);
              final isCompleted = state == 1;
              final isCurrent = state == 0;
              final isFailed = state == 2;

              return Column(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppColors.burundiGreen
                          : isCurrent
                              ? AppColors.burundiGreen.withValues(alpha: 0.15)
                              : isFailed
                                  ? AppColors.burundiRed
                                  : (isDark ? const Color(0xFF333333) : const Color(0xFFE8E8E8)),
                      border: isCurrent
                          ? Border.all(color: AppColors.burundiGreen, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : isFailed
                              ? const Icon(Icons.close, size: 16, color: Colors.white)
                              : isCurrent
                                  ? Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.burundiGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.map((s) {
              final stepIdx = steps.indexOf(s);
              final state = getStepState(stepIdx);
              final isCompleted = state == 1;
              final isCurrent = state == 0;
              return SizedBox(
                width: 52,
                child: Text(
                  s['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCompleted || isCurrent
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white30 : Colors.black26),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── One-time Approval Banner ────────────────────────────────
  Widget _buildApprovalBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38a169), Color(0xFF2D6E31)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.burundiGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration_rounded, size: 40, color: Colors.white),
          const SizedBox(height: 12),
          const Text('Congratulations!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Your application has been accepted.\nPlease upload your documents to proceed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _dismissApprovalBanner();
                    if (!mounted) return;
                    await Navigator.pushNamed(context, '/youth-dialogue-documents');
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.burundiGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Upload Documents', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _dismissApprovalBanner,
                child: const Text('Dismiss', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Persistent Action-Required Banner ───────────────────────
  Widget _buildActionRequiredBanner(bool isDark) {
    final rejectedDocs = _application!.documents.where((d) => d.status == 'rejected').toList();
    final typeLabels = {
      'passport': 'Passport', 'national_id': 'National ID',
      'photo': 'Photo', 'cv': 'CV',
    };
    final names = rejectedDocs.map((d) => typeLabels[d.documentType] ?? d.documentType).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.burundiRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.pushNamed(context, '/youth-dialogue-documents');
            _loadData();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.burundiRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.burundiRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Action Required', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.red[200] : AppColors.burundiRed)),
                      const SizedBox(height: 2),
                      Text('Re-upload: ${names.join(", ")}', style: TextStyle(fontSize: 12,
                        color: isDark ? Colors.red[300] : AppColors.burundiRed.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: isDark ? Colors.red[200] : AppColors.burundiRed),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: isDark ? Colors.white38 : Colors.black26),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadData(); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.burundiGreen),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Support Section ─────────────────────────────────────────
  Widget _buildSupportSection(bool isDark, bool isFr) {
    final supportNote = _t('support_note', 'support_note_fr', isFr);
    final email = _settings?['support_email']?.toString() ?? '';
    final phone = _settings?['support_phone']?.toString() ?? '';
    final chatUrl = _settings?['live_chat_url']?.toString() ?? '';

    if (email.isEmpty && phone.isEmpty && chatUrl.isEmpty && supportNote.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_rounded, size: 22,
                color: isDark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 8),
              Text(isFr ? 'Support' : 'Support',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          if (supportNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(supportNote,
              style: TextStyle(fontSize: 13, height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54)),
          ],
          const SizedBox(height: 16),
          // Quick contact chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (email.isNotEmpty)
                _buildContactChip(isDark, icon: Icons.email_outlined, label: isFr ? 'Email' : 'Email',
                  onTap: () => launchUrl(Uri.parse('mailto:$email'))),
              if (phone.isNotEmpty)
                _buildContactChip(isDark, icon: Icons.phone_outlined, label: isFr ? 'Appeler' : 'Call',
                  onTap: () => launchUrl(Uri.parse('tel:$phone'))),
              if (chatUrl.isNotEmpty)
                _buildContactChip(isDark, icon: Icons.chat_bubble_outline_rounded,
                  label: isFr ? 'Chat' : 'Live Chat',
                  onTap: () => launchUrl(Uri.parse(chatUrl), mode: LaunchMode.inAppBrowserView)),
            ],
          ),
          const SizedBox(height: 16),
          // Full Contact Support button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/contact-support'),
              icon: const Icon(Icons.headset_mic_rounded, size: 18),
              label: Text(isFr ? 'Contacter le support' : 'Contact Support'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.burundiGreen,
                side: BorderSide(color: AppColors.burundiGreen.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactChip(bool isDark, {
    required IconData icon, required String label, required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF5F7F5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.burundiGreen),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  // ── Status View Switch ──────────────────────────────────────
  Widget _buildStatusView(bool isDark) {
    final app = _application!;

    switch (app.status) {
      case 'submitted':
      case 'under_review':
        return _buildWaitingCard(isDark, app,
          'Application Under Review',
          'Your application is being reviewed by our team. We will notify you once a decision has been made.',
          Icons.hourglass_top_rounded, AppColors.auGold);

      case 'rejected':
        return _buildRejectedCard(isDark, app);

      case 'accepted':
      case 'documents_pending':
        return _buildDocumentsNeeded(isDark, app);

      case 'documents_submitted':
      case 'documents_under_review':
        return _buildWaitingCard(isDark, app,
          'Documents Under Verification',
          'Your documents are being verified by our team. You will be notified once the review is complete.',
          Icons.fact_check_rounded, Colors.blue);

      case 'documents_rejected':
        return _buildDocumentsRejected(isDark, app);

      case 'credential_issued':
        return _buildCredentialReady(isDark, app);

      default:
        return _buildWaitingCard(isDark, app, app.status, 'Status: ${app.status}',
          Icons.info_outline, Colors.grey);
    }
  }

  // ── Waiting Card with timestamp ─────────────────────────────
  Widget _buildWaitingCard(bool isDark, YouthDialogueApplication app,
      String title, String message, IconData icon, Color color) {
    final lastCheckedStr = _lastChecked != null
        ? '${_lastChecked!.hour.toString().padLeft(2, '0')}:${_lastChecked!.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5,
              color: isDark ? Colors.white60 : Colors.black54)),
          const SizedBox(height: 16),
          if (lastCheckedStr.isNotEmpty)
            Text('Last checked at $lastCheckedStr',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.black26)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isRefreshing ? null : _refreshStatus,
            icon: _isRefreshing
                ? SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                : Icon(Icons.refresh, size: 18, color: color),
            label: Text(
              _isRefreshing ? 'Checking...' : 'Check Status',
              style: TextStyle(color: _isRefreshing ? color.withValues(alpha: 0.5) : color),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(bool isDark, YouthDialogueApplication app) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.burundiRed.withValues(alpha: 0.1), shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel_rounded, size: 36, color: AppColors.burundiRed),
          ),
          const SizedBox(height: 16),
          Text('Application Not Approved', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          if (app.rejectionReason != null && app.rejectionReason!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.burundiRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.burundiRed.withValues(alpha: 0.2)),
              ),
              child: Text(app.rejectionReason!,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, height: 1.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentsNeeded(bool isDark, YouthDialogueApplication app) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle,
            ),
            child: const Icon(Icons.upload_file_rounded, size: 36, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          Text('Upload Your Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text('Please upload the required documents to continue your application.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, '/youth-dialogue-documents');
                _loadData();
              },
              icon: const Icon(Icons.upload_rounded, color: Colors.white),
              label: const Text('Upload Documents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsRejected(bool isDark, YouthDialogueApplication app) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.burundiRed),
              const SizedBox(width: 8),
              Text('Documents Need Attention', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          if (app.documentsRejectionNotes != null && app.documentsRejectionNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.burundiRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(app.documentsRejectionNotes!,
                style: const TextStyle(fontSize: 13, color: AppColors.burundiRed)),
            ),
          ],
          const SizedBox(height: 16),
          ...app.documents.map((doc) => _buildDocRow(doc, isDark)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, '/youth-dialogue-documents');
                _loadData();
              },
              icon: const Icon(Icons.edit_document, color: Colors.white),
              label: const Text('Fix Documents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(YouthDialogueDocument doc, bool isDark) {
    final typeLabels = {
      'passport': 'Passport Copy', 'national_id': 'National ID',
      'photo': 'Passport Photo', 'cv': 'CV / Resume',
      'recommendation': 'Recommendation', 'other': 'Other',
    };
    final statusColors = {
      'pending': AppColors.auGold, 'approved': AppColors.burundiGreen, 'rejected': AppColors.burundiRed,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: statusColors[doc.status] ?? Colors.grey, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeLabels[doc.documentType] ?? doc.documentType,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87)),
                if (doc.status == 'rejected' && doc.rejectionReason != null)
                  Text(doc.rejectionReason!, style: const TextStyle(fontSize: 12, color: AppColors.burundiRed)),
              ],
            ),
          ),
          Text(doc.status.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: statusColors[doc.status] ?? Colors.grey)),
        ],
      ),
    );
  }

  // ── Promotional Video ────────────────────────────────────
  Widget _buildPromotionalVideo(bool isDark, bool isFr) {
    final promoData = _settings?['promotional_video'];
    if (promoData == null) return const SizedBox.shrink();

    final promo = YouthDialogueMedia.fromJson(promoData as Map<String, dynamic>);
    final title = (isFr && promo.titleFr.isNotEmpty) ? promo.titleFr : promo.title;
    final hasYouTube = promo.externalUrl.contains('youtube.com') || promo.externalUrl.contains('youtu.be');

    String? ytThumb;
    if (hasYouTube) {
      final ytId = _extractYouTubeId(promo.externalUrl);
      if (ytId != null) {
        ytThumb = 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';
      }
    }

    final thumbUrl = promo.thumbnailUrl.isNotEmpty
        ? Environment.fixMediaUrl(promo.thumbnailUrl)
        : (ytThumb ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 8),
                Text(
                  isFr ? 'Vidéo promotionnelle' : 'Promotional Video',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onTap: () {
                if (promo.externalUrl.isNotEmpty) {
                  _playVideo(promo.externalUrl, title);
                }
              },
              child: Stack(
                children: [
                  if (thumbUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumbUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      placeholder: (_, __) => Container(height: 200, color: isDark ? Colors.grey[900] : Colors.grey[200]),
                      errorWidget: (_, __, ___) => Container(
                        height: 200,
                        color: isDark ? Colors.grey[900] : Colors.grey[200],
                        child: const Center(child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white54)),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      color: isDark ? Colors.grey[900] : Colors.grey[800],
                      child: const Center(child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white54)),
                    ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (title.isNotEmpty)
                    Positioned(
                      left: 16, bottom: 12, right: 16,
                      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 8)])),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractYouTubeId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu\.be/)([^"&?/\s]{11})',
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  void _playVideo(String url, String title) {
    final ytId = YoutubePlayer.convertUrlToId(url);
    if (ytId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _YDYouTubePlayerScreen(videoId: ytId, title: title),
        ),
      );
    } else {
      // Non-YouTube URL — fall back to external browser
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // ── Media Gallery ───────────────────────────────────────────
  Widget _buildMediaGallery(bool isDark, bool isFr) {
    final mediaList = _settings?['media'] as List<dynamic>? ?? [];
    final galleryItems = mediaList
        .map((m) => YouthDialogueMedia.fromJson(m as Map<String, dynamic>))
        .where((m) => !m.isPromotional)
        .toList();

    if (galleryItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.photo_library_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 8),
                Text(
                  isFr ? 'Éditions précédentes' : 'Past Editions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: galleryItems.length,
              itemBuilder: (context, index) {
                final item = galleryItems[index];
                final title = (isFr && item.titleFr.isNotEmpty) ? item.titleFr : item.title;
                final imgUrl = item.thumbnailUrl.isNotEmpty
                    ? Environment.fixMediaUrl(item.thumbnailUrl)
                    : (item.fileUrl.isNotEmpty ? Environment.fixMediaUrl(item.fileUrl) : '');

                return Container(
                  width: 200,
                  margin: EdgeInsets.only(right: index < galleryItems.length - 1 ? 12 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () {
                        if (item.externalUrl.isNotEmpty) {
                          _playVideo(item.externalUrl, title);
                        } else if (item.fileUrl.isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: CachedNetworkImage(
                                  imageUrl: Environment.fixMediaUrl(item.fileUrl),
                                  fit: BoxFit.contain,
                                  memCacheWidth: 1200,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: Stack(
                        children: [
                          if (imgUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: imgUrl,
                              width: 200, height: 160,
                              fit: BoxFit.cover,
                              memCacheWidth: 400,
                              placeholder: (_, __) => Container(color: isDark ? Colors.grey[900] : Colors.grey[200]),
                              errorWidget: (_, __, ___) => Container(
                                color: isDark ? Colors.grey[900] : Colors.grey[200],
                                child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                              ),
                            )
                          else
                            Container(
                              width: 200, height: 160,
                              color: isDark ? Colors.grey[900] : Colors.grey[200],
                              child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                            ),
                          if (item.mediaType == 'video')
                            const Positioned(
                              top: 8, right: 8,
                              child: Icon(Icons.play_circle_fill, size: 28, color: Colors.white),
                            ),
                          Positioned(
                            left: 0, right: 0, bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (title.isNotEmpty)
                                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 12,
                                      fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (item.editionTag.isNotEmpty)
                                    Text(item.editionTag, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialReady(bool isDark, YouthDialogueApplication app) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 16)],
            ),
            child: const Icon(Icons.badge_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text('Your ID Card is Ready!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          if (app.participantCode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(app.participantCode!,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  fontFamily: 'monospace', color: Colors.purple, letterSpacing: 2)),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/youth-dialogue-credential'),
              icon: const Icon(Icons.credit_card_rounded, color: Colors.white),
              label: const Text('View ID Card', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lightweight In-App YouTube Player ──────────────────────────
class _YDYouTubePlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const _YDYouTubePlayerScreen({required this.videoId, required this.title});

  @override
  State<_YDYouTubePlayerScreen> createState() => _YDYouTubePlayerScreenState();
}

class _YDYouTubePlayerScreenState extends State<_YDYouTubePlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        controlsVisibleAtStart: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.burundiGreen,
        progressColors: const ProgressBarColors(
          playedColor: AppColors.burundiGreen,
          handleColor: AppColors.auGold,
        ),
      ),
      builder: (context, player) {
        if (isLandscape) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(child: player),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => _controller.toggleFullScreenMode(),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(widget.title, style: const TextStyle(fontSize: 16)),
          ),
          body: Column(
            children: [
              player,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.burundiGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_rounded, size: 16, color: AppColors.burundiGreen),
                            SizedBox(width: 6),
                            Text('Continental Dialogue', style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.burundiGreen)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Privacy Policy Acceptance Screen ──────────────────────────
class _YDPrivacyPolicyScreen extends StatefulWidget {
  final String policyText;
  final bool isFr;

  const _YDPrivacyPolicyScreen({required this.policyText, required this.isFr});

  @override
  State<_YDPrivacyPolicyScreen> createState() => _YDPrivacyPolicyScreenState();
}

class _YDPrivacyPolicyScreenState extends State<_YDPrivacyPolicyScreen> {
  bool _agreed = false;
  bool _scrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (!_scrolledToBottom) setState(() => _scrolledToBottom = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = widget.isFr;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(isFr ? 'Politique de Confidentialité' : 'Privacy Policy'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2E1A) : AppColors.burundiGreen.withValues(alpha: 0.06),
              border: Border(bottom: BorderSide(
                color: isDark ? Colors.white10 : AppColors.burundiGreen.withValues(alpha: 0.15),
              )),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.burundiGreen, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFr
                        ? 'Veuillez lire et accepter la politique de confidentialité pour continuer.'
                        : 'Please read and accept the privacy policy to continue.',
                    style: TextStyle(
                      fontSize: 13, height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Policy text
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                  ),
                  child: SelectableText(
                    widget.policyText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Scroll hint
          if (!_scrolledToBottom)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                  Text(
                    isFr ? 'Faites défiler pour lire la suite' : 'Scroll down to read more',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ],
              ),
            ),

          // Agreement + Continue
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE0E0E0))),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _scrolledToBottom ? () => setState(() => _agreed = !_agreed) : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: Checkbox(
                            value: _agreed,
                            onChanged: _scrolledToBottom ? (v) => setState(() => _agreed = v ?? false) : null,
                            activeColor: AppColors.burundiGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isFr
                                ? 'J\'ai lu et j\'accepte la politique de confidentialité des données'
                                : 'I have read and agree to the Data Privacy Policy',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: _scrolledToBottom
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? Colors.white30 : Colors.black26),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _agreed ? () => Navigator.pop(context, true) : null,
                      icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                      label: Text(
                        isFr ? 'Continuer vers la candidature' : 'Continue to Application',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burundiGreen,
                        disabledBackgroundColor: (isDark ? Colors.white10 : Colors.black12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Full-page status view — tracks the real application pipeline:
//   Applied → Under Review → Documents → Verification → Digital ID
// ═══════════════════════════════════════════════════════════════════
class _YDStatusPage extends StatelessWidget {
  final YouthDialogueApplication application;
  final bool isFr;

  const _YDStatusPage({required this.application, required this.isFr});

  // Pipeline steps in order
  static const _pipeline = [
    'submitted',        // 0 — Applied
    'under_review',     // 1 — Under Review
    'documents',        // 2 — Documents Upload (accepted/documents_pending/documents_submitted)
    'verification',     // 3 — Verification (documents_under_review)
    'credential_issued',// 4 — Digital ID
  ];

  int _currentStep() {
    switch (application.status) {
      case 'submitted':
      case 'under_review':
        return 1;
      case 'accepted':
      case 'documents_pending':
        return 2;
      case 'documents_submitted':
      case 'documents_under_review':
        return 3;
      case 'documents_rejected':
        return 2; // back to documents — re-upload needed
      case 'credential_issued':
        return 4;
      case 'rejected':
        return 1; // rejected at review stage
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = application.status;
    final step = _currentStep();
    final isRejected = status == 'rejected';
    final isDocsRejected = status == 'documents_rejected';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(isFr ? 'Statut de candidature' : 'Application Status'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Hero status icon ──
            _buildHeroIcon(isDark, status, step),
            const SizedBox(height: 28),

            // ── Reference card ──
            if (application.referenceId != null && application.referenceId!.isNotEmpty)
              _buildReferenceCard(isDark),

            // ── Pipeline tracker ──
            const SizedBox(height: 20),
            _buildPipeline(isDark, step, isRejected, isDocsRejected),

            // ── What happens next ──
            const SizedBox(height: 20),
            _buildNextSteps(isDark, status, step),

            // ── Rejection details ──
            if (isRejected && application.rejectionReason != null && application.rejectionReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildRejectionCard(isDark),
              ),

            // ── Docs rejection details ──
            if (isDocsRejected && application.documentsRejectionNotes != null && application.documentsRejectionNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildDocsRejectionCard(isDark),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Hero icon + title + subtitle ──
  Widget _buildHeroIcon(bool isDark, String status, int step) {
    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;

    if (status == 'rejected') {
      icon = Icons.cancel_rounded;
      color = Colors.red;
      title = isFr ? 'Candidature non retenue' : 'Application Not Accepted';
      subtitle = isFr
          ? 'Malheureusement, votre candidature n\'a pas été retenue par le comité de sélection.'
          : 'Unfortunately, your application was not selected by the review committee.';
    } else if (step <= 1) {
      // submitted / under_review
      icon = Icons.hourglass_top_rounded;
      color = Colors.orange;
      title = isFr ? 'Candidature en cours de révision' : 'Application Under Review';
      subtitle = isFr
          ? 'Notre comité examine votre candidature. Vous serez notifié dès qu\'une décision sera prise.'
          : 'Our committee is reviewing your application. You\'ll be notified once a decision is made.';
    } else if (step == 2) {
      // documents phase
      icon = Icons.upload_file_rounded;
      color = Colors.blue;
      title = isFr ? 'Documents requis' : 'Documents Required';
      subtitle = isFr
          ? 'Votre candidature a été acceptée! Veuillez soumettre les documents requis.'
          : 'Your application has been accepted! Please submit the required documents.';
    } else if (step == 3) {
      // verification
      icon = Icons.verified_user_outlined;
      color = Colors.orange;
      title = isFr ? 'Vérification en cours' : 'Verification In Progress';
      subtitle = isFr
          ? 'Nos équipes vérifient vos documents. Vous serez notifié une fois la vérification terminée.'
          : 'Our team is verifying your documents. You\'ll be notified once verification is complete.';
    } else {
      // credential_issued
      icon = Icons.badge_rounded;
      color = Colors.purple;
      title = isFr ? 'Identifiant numérique prêt' : 'Digital ID Ready';
      subtitle = isFr
          ? 'Votre identifiant numérique a été émis. Vous pouvez le consulter à tout moment.'
          : 'Your Digital ID has been issued. You can view it anytime.';
    }

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          ),
          child: Icon(icon, size: 40, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black54,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Reference number + date card ──
  Widget _buildReferenceCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.burundiGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.confirmation_number_outlined, size: 20, color: AppColors.burundiGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFr ? 'Numéro de référence' : 'Reference Number',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                ),
                const SizedBox(height: 2),
                Text(
                  application.referenceId!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (application.createdAt != null)
            Text(
              _formatDate(application.createdAt!),
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45),
            ),
        ],
      ),
    );
  }

  // ── Pipeline tracker — 5 real steps ──
  Widget _buildPipeline(bool isDark, int currentStep, bool isRejected, bool isDocsRejected) {
    final steps = [
      {'icon': Icons.app_registration_rounded, 'en': 'Applied', 'fr': 'Inscrit(e)'},
      {'icon': Icons.rate_review_outlined, 'en': 'Under Review', 'fr': 'En révision'},
      {'icon': Icons.upload_file_rounded, 'en': 'Documents', 'fr': 'Documents'},
      {'icon': Icons.verified_outlined, 'en': 'Verification', 'fr': 'Vérification'},
      {'icon': Icons.badge_rounded, 'en': 'Digital ID', 'fr': 'Identifiant'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr ? 'Progression' : 'Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(steps.length, (i) {
            final isDone = i < currentStep;
            final isActive = i == currentStep;
            final isPending = i > currentStep;
            final isLast = i == steps.length - 1;

            // Special: rejected at review step
            final isRejectedHere = isRejected && i == 1;
            // Special: docs rejected → step 2 shows warning
            final isDocsRejectedHere = isDocsRejected && i == 2;

            final Color circleColor;
            final Color iconColor;
            final IconData displayIcon;

            if (isRejectedHere) {
              circleColor = Colors.red;
              iconColor = Colors.white;
              displayIcon = Icons.close_rounded;
            } else if (isDocsRejectedHere) {
              circleColor = Colors.orange;
              iconColor = Colors.white;
              displayIcon = Icons.refresh_rounded;
            } else if (isDone) {
              circleColor = AppColors.burundiGreen;
              iconColor = Colors.white;
              displayIcon = Icons.check_rounded;
            } else if (isActive) {
              circleColor = Colors.orange;
              iconColor = Colors.orange;
              displayIcon = steps[i]['icon'] as IconData;
            } else {
              circleColor = isDark ? Colors.white12 : Colors.black12;
              iconColor = isDark ? Colors.white24 : Colors.black26;
              displayIcon = steps[i]['icon'] as IconData;
            }

            // Connector color
            final connectorDone = isDone && !isRejectedHere;

            return Column(
              children: [
                Row(
                  children: [
                    // Circle
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isDone || isRejectedHere || isDocsRejectedHere)
                            ? circleColor
                            : circleColor.withValues(alpha: isActive ? 0.15 : 0.3),
                        border: isActive && !isRejectedHere && !isDocsRejectedHere
                            ? Border.all(color: circleColor, width: 2.5)
                            : null,
                      ),
                      child: Icon(displayIcon, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 14),
                    // Label + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFr ? steps[i]['fr'] as String : steps[i]['en'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: (isDone || isActive) ? FontWeight.w600 : FontWeight.w400,
                              color: isPending && !isRejected
                                  ? (isDark ? Colors.white30 : Colors.black38)
                                  : isRejectedHere
                                      ? Colors.red
                                      : isDocsRejectedHere
                                          ? Colors.orange
                                          : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          // Extra label for rejected / docs rejected
                          if (isRejectedHere)
                            Text(
                              isFr ? 'Non retenue' : 'Not accepted',
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          if (isDocsRejectedHere)
                            Text(
                              isFr ? 'Re-téléchargement nécessaire' : 'Re-upload required',
                              style: const TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                        ],
                      ),
                    ),
                    // Spinning indicator for active step
                    if (isActive && !isRejected && !isDocsRejected)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange.withValues(alpha: 0.7),
                        ),
                      ),
                    if (isDone && !isRejectedHere)
                      const Icon(Icons.check_circle, size: 18, color: AppColors.burundiGreen),
                  ],
                ),
                // Connector line
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 17),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 2,
                        height: 28,
                        decoration: BoxDecoration(
                          color: connectorDone
                              ? AppColors.burundiGreen.withValues(alpha: 0.4)
                              : isRejectedHere
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── What happens next ──
  Widget _buildNextSteps(bool isDark, String status, int step) {
    final List<Map<String, String>> items;

    if (status == 'rejected') {
      items = [
        {
          'icon': 'email',
          'en': 'A notification has been sent to your email with details.',
          'fr': 'Une notification a été envoyée à votre email avec les détails.',
        },
      ];
    } else if (step <= 1) {
      items = [
        {
          'icon': 'review',
          'en': 'Our committee is reviewing your application.',
          'fr': 'Notre comité examine votre candidature.',
        },
        {
          'icon': 'accept',
          'en': 'If accepted, you\'ll be asked to upload required documents (passport, CV, etc.).',
          'fr': 'Si accepté(e), vous devrez télécharger les documents requis (passeport, CV, etc.).',
        },
        {
          'icon': 'notify',
          'en': 'You\'ll receive an email notification when the status changes.',
          'fr': 'Vous recevrez un email de notification lorsque le statut changera.',
        },
      ];
    } else if (step == 2) {
      items = [
        {
          'icon': 'upload',
          'en': 'Upload your required documents from the main screen.',
          'fr': 'Téléchargez vos documents requis depuis l\'écran principal.',
        },
        {
          'icon': 'verify',
          'en': 'Our team will verify each document you submit.',
          'fr': 'Notre équipe vérifiera chaque document soumis.',
        },
        {
          'icon': 'fix',
          'en': 'If a document is rejected, you\'ll only need to re-upload that specific document.',
          'fr': 'Si un document est refusé, vous ne devrez re-télécharger que ce document spécifique.',
        },
      ];
    } else if (step == 3) {
      items = [
        {
          'icon': 'verify',
          'en': 'Our team is verifying your documents.',
          'fr': 'Notre équipe vérifie vos documents.',
        },
        {
          'icon': 'fix',
          'en': 'If any document has an issue, you\'ll be asked to re-upload only that document with an explanation.',
          'fr': 'Si un document pose problème, vous devrez re-télécharger uniquement ce document avec une explication.',
        },
        {
          'icon': 'id',
          'en': 'Once verified, your Digital ID will be issued automatically.',
          'fr': 'Une fois vérifié, votre identifiant numérique sera émis automatiquement.',
        },
      ];
    } else {
      items = [
        {
          'icon': 'id',
          'en': 'Your Digital ID is available for the duration of the event.',
          'fr': 'Votre identifiant numérique est disponible pour la durée de l\'événement.',
        },
      ];
    }

    final iconMap = {
      'review': Icons.rate_review_outlined,
      'accept': Icons.how_to_reg_outlined,
      'notify': Icons.notifications_active_outlined,
      'email': Icons.email_outlined,
      'upload': Icons.cloud_upload_outlined,
      'verify': Icons.fact_check_outlined,
      'fix': Icons.build_outlined,
      'id': Icons.badge_outlined,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr ? 'Prochaines étapes' : 'What Happens Next',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  iconMap[item['icon']] ?? Icons.arrow_forward_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isFr ? item['fr']! : item['en']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Rejection reason card ──
  Widget _buildRejectionCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: isDark ? 0.25 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.red.shade300),
              const SizedBox(width: 8),
              Text(
                isFr ? 'Motif' : 'Reason',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            application.rejectionReason!,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Documents rejection card ──
  Widget _buildDocsRejectionCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: isDark ? 0.25 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade300),
              const SizedBox(width: 8),
              Text(
                isFr ? 'Documents à corriger' : 'Documents to Fix',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            application.documentsRejectionNotes!,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isFr
                ? 'Veuillez re-télécharger uniquement le(s) document(s) concerné(s).'
                : 'Please re-upload only the affected document(s).',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = isFr
        ? ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc']
        : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
