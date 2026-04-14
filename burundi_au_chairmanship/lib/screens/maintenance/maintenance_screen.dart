import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';

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

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
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
        // If countdown reached zero, auto-retry
        if (diff.isNegative) {
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
    return isFrench ? 'Maintenance en cours' : 'Under Maintenance';
  }

  String _getDescription(bool isFrench) {
    final data = _activeData;
    if (data != null) {
      final desc = isFrench
          ? (data['description_fr'] ?? data['description'] ?? '')
          : (data['description'] ?? '');
      if ((desc as String).isNotEmpty) return desc;
    }
    return isFrench
        ? 'Nous effectuons une maintenance planifiée. Veuillez réessayer bientôt.'
        : 'We are performing scheduled maintenance. Please try again shortly.';
  }

  String? _getContactEmail() => _activeData?['contact_email'] as String?;

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Support Request - Maintenance',
        'body':
            'Hello,\n\nI need assistance while the app is under maintenance.\n\n',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _copyEmail(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    final isFrench = context.read<LanguageProvider>().isFrench;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFrench ? 'Email copié: $email' : 'Email copied: $email',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.auGold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _silentRetry() async {
    try {
      final status = await ApiService().getMaintenanceStatus();
      if (!mounted) return;
      if (status['in_maintenance'] != true) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (_) {}
  }

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    try {
      final status = await ApiService().getMaintenanceStatus();
      if (!mounted) return;
      if (status['in_maintenance'] != true) {
        Navigator.of(context).pushReplacementNamed('/auth');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Still under maintenance. Please try again later.'),
            backgroundColor: AppColors.burundiRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
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
    final contactEmail = _getContactEmail();
    final screenSize = MediaQuery.of(context).size;
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: Image or gradient
            if (hasImage)
              CachedNetworkImage(
                imageUrl: _imageUrl!,
                fit: BoxFit.cover,
                width: screenSize.width,
                height: screenSize.height,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF101c2e),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.auGold,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    _buildGradientBackground(),
              )
            else
              _buildGradientBackground(),

            // Dark overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: hasImage ? 0.3 : 0.0),
                    Colors.black.withValues(alpha: hasImage ? 0.7 : 0.0),
                  ],
                ),
              ),
            ),

            // Content overlay at bottom
            SafeArea(
              child: Column(
                children: [
                  // Top bar with language toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _LanguageToggle(
                          isFrench: isFrench,
                          onToggle: () => context
                              .read<LanguageProvider>()
                              .toggleLanguage(),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Bottom card with info
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Pulsing icon
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity:
                                        0.6 + (_pulseController.value * 0.4),
                                    child: Icon(
                                      Icons.build_circle_outlined,
                                      size: 40,
                                      color: AppColors.auGold,
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 16),

                              // Title
                              Text(
                                _getTitle(isFrench),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Gold divider
                              Container(
                                width: 50,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: AppColors.auGold,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Description
                              Text(
                                _getDescription(isFrench),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color:
                                      Colors.white.withValues(alpha: 0.85),
                                ),
                              ),

                              // Countdown timer
                              if (_remaining.inSeconds > 0) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.auGold
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.auGold
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 20,
                                        color: AppColors.auGold,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _formatCountdown(_remaining),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          fontFeatures: [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Copyable contact email chip
                              if (contactEmail != null &&
                                  contactEmail.isNotEmpty) ...[
                                InkWell(
                                  onTap: () => _copyEmail(contactEmail),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.mail_outline_rounded,
                                          size: 18,
                                          color: AppColors.auGold,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isFrench
                                                    ? 'Nous contacter'
                                                    : 'Contact us',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              SelectableText(
                                                contactEmail,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.content_copy_rounded,
                                          size: 18,
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Buttons row
                              Row(
                                children: [
                                  // Retry button
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            _isRetrying ? null : _retry,
                                        icon: _isRetrying
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.refresh_rounded,
                                                size: 20),
                                        label: Text(
                                          _isRetrying
                                              ? (isFrench
                                                  ? 'Vérif...'
                                                  : 'Checking...')
                                              : (isFrench
                                                  ? 'Réessayer'
                                                  : 'Retry'),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.2),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: BorderSide(
                                              color: Colors.white
                                                  .withValues(alpha: 0.25),
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Email button
                                  if (contactEmail != null &&
                                      contactEmail.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      height: 48,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _launchEmail(contactEmail),
                                        icon: const Icon(
                                            Icons.email_outlined,
                                            size: 18),
                                        label: Text(
                                          isFrench ? 'Contact' : 'Email',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.auGold,
                                          side: BorderSide(
                                            color: AppColors.auGold
                                                .withValues(alpha: 0.5),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
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

  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF101c2e),
            Color(0xFF1a2d47),
            Color(0xFF0f1923),
          ],
        ),
      ),
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _MaintenancePatternPainter(),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final bool isFrench;
  final VoidCallback onToggle;

  const _LanguageToggle({
    required this.isFrench,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          child: InkWell(
            onTap: onToggle,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.language_rounded,
                    size: 16,
                    color: AppColors.auGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFrench ? 'FR' : 'EN',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaintenancePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.auGold.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const spacing = 100.0;
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final path = Path();
        path.moveTo(x, y - 25);
        path.lineTo(x + 25, y);
        path.lineTo(x, y + 25);
        path.lineTo(x - 25, y);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
