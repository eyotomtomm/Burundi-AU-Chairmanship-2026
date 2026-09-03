import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_network_image.dart';

class MaintenanceScreen extends StatefulWidget {
  final Map<String, dynamic>? maintenanceData;

  const MaintenanceScreen({super.key, this.maintenanceData});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  bool _isRetrying = false;
  Timer? _countdownTimer;
  Timer? _autoRetryTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _startCountdown();

    // Auto-retry every 30 seconds
    _autoRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _silentRetry();
    });
  }

  bool _countdownRetried = false;

  void _startCountdown() {
    _updateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final data = widget.maintenanceData?['active'];
    if (data != null && data['ends_at'] != null) {
      try {
        final endsAt = DateTime.parse(data['ends_at']).toLocal();
        final now = DateTime.now();
        final diff = endsAt.difference(now);
        if (mounted) {
          setState(() {
            _remaining = diff.isNegative ? Duration.zero : diff;
          });
        }
        // Countdown crossed zero: one immediate retry; the 30s timer keeps going.
        if (diff.isNegative && !_countdownRetried) {
          _countdownRetried = true;
          _silentRetry();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _autoRetryTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? get _activeData => widget.maintenanceData?['active'];

  String? get _imageUrl => _activeData?['image_url'] as String?;

  String _getTitle(bool isFrench) {
    final data = _activeData;
    if (data != null) {
      final title = isFrench
          ? (data['title_fr'] ?? data['title'] ?? '')
          : (data['title'] ?? '');
      if ((title as String).isNotEmpty) return title;
    }
    return AppLocalizations.of(context).translate('mt_title');
  }

  String _getDescription(bool isFrench) {
    final data = _activeData;
    if (data != null) {
      final desc = isFrench
          ? (data['description_fr'] ?? data['description'] ?? '')
          : (data['description'] ?? '');
      if ((desc as String).isNotEmpty) return desc;
    }
    return AppLocalizations.of(context).translate('mt_desc');
  }

  String? _getContactEmail() => _activeData?['contact_email'] as String?;

  Future<void> _launchEmail(String email) async {
    final l10n = AppLocalizations.of(context);
    final subject = Uri.encodeComponent(l10n.translate('mt_mail_subject'));
    final body = Uri.encodeComponent(l10n.translate('mt_mail_body'));
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _copyEmail(email);
      }
    } catch (_) {
      if (mounted) {
        _copyEmail(email);
      }
    }
  }

  Future<void> _copyEmail(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppLocalizations.of(context).translate('mt_email_copied')}: $email',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.auGold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Navigate to the correct screen after maintenance ends.
  /// If the user was already authenticated, go home; otherwise go to auth.
  void _navigateAfterMaintenance() {
    if (!mounted) return;
    final isAuth = context.read<AuthProvider>().isAuthenticated;
    Navigator.of(context).pushReplacementNamed(isAuth ? '/home' : '/auth');
  }

  Future<void> _silentRetry() async {
    try {
      final status = await ApiService().getMaintenanceStatus();
      if (!mounted) return;
      if (status['in_maintenance'] != true) {
        _navigateAfterMaintenance();
      }
    } catch (_) {}
  }

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    try {
      final status = await ApiService().getMaintenanceStatus();
      if (!mounted) return;
      if (status['in_maintenance'] != true) {
        _navigateAfterMaintenance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('mt_still_maintenance'),
            ),
            backgroundColor: AppColors.burundiRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Unreachable server is not "maintenance over" — stay here.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('mt_server_unreachable'),
            ),
            backgroundColor: AppColors.burundiRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  String _formatCountdown(Duration d) {
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m';
    }
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isFrench = context.watch<LanguageProvider>().isFrench;
    final l10n = AppLocalizations.of(context);
    final contactEmail = _getContactEmail();
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Ds.bg(context),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _LanguageToggle(
                        isFrench: isFrench,
                        onToggle: () =>
                            context.read<LanguageProvider>().toggleLanguage(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(36, 24, 36, 32),
                    children: [
                      // Admin-supplied artwork, when one is configured.
                      if (hasImage)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Ds.rCard),
                            child: AppNetworkImage(
                              imageUrl: _imageUrl!,
                              hero: true,
                              height: 160,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                        ),

                      // Pulsing gold badge
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Opacity(
                            opacity: 0.75 + (_pulseController.value * 0.25),
                            child: child,
                          ),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Ds.goldTintOf(context),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.engineering_rounded,
                              size: 44,
                              color: Ds.goldDeep,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _getTitle(isFrench),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Ds.ink(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _getDescription(isFrench),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: Ds.body(context),
                        ),
                      ),

                      if (_remaining.inSeconds > 0) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Ds.goldTintOf(context),
                              borderRadius: BorderRadius.circular(Ds.rTile),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 20,
                                  color: Ds.goldDeep,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _formatCountdown(_remaining),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Ds.goldInk,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      Center(
                        child: _isRetrying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Ds.green,
                                ),
                              )
                            : DsOutlineButton(
                                l10n.translate('try_again'),
                                radius: Ds.rPill,
                                onTap: _retry,
                              ),
                      ),

                      if (contactEmail != null && contactEmail.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        DsTileGroup(
                          margin: EdgeInsets.zero,
                          children: [
                            DsTile(
                              icon: Icons.mail_rounded,
                              title: l10n.translate('contact_us'),
                              subtitle: contactEmail,
                              onTap: () => _launchEmail(contactEmail),
                            ),
                            DsTile(
                              icon: Icons.content_copy_rounded,
                              title: l10n.translate('mt_copy_email'),
                              chevron: false,
                              onTap: () => _copyEmail(contactEmail),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final bool isFrench;
  final VoidCallback onToggle;

  const _LanguageToggle({required this.isFrench, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).translate('language'),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Ds.surface(context),
            borderRadius: BorderRadius.circular(Ds.rPill),
            boxShadow: Ds.shadow(context),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 16, color: Ds.green),
              const SizedBox(width: 6),
              Text(
                isFrench ? 'FR' : 'EN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Ds.ink(context),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.swap_horiz_rounded,
                size: 14,
                color: Ds.muted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
