import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late AnimationController _pulseController;
  late AnimationController _patternController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _patternController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _patternController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String _getTitle(bool isFrench) {
    final data = widget.maintenanceData?['active'];
    if (data != null) {
      final title = isFrench
          ? (data['title_fr'] ?? data['title'] ?? '')
          : (data['title'] ?? '');
      if (title.isNotEmpty) return title;
    }
    return isFrench ? 'Maintenance en cours' : 'Under Maintenance';
  }

  String _getDescription(bool isFrench) {
    final data = widget.maintenanceData?['active'];
    if (data != null) {
      final desc = isFrench
          ? (data['description_fr'] ?? data['description'] ?? '')
          : (data['description'] ?? '');
      if (desc.isNotEmpty) return desc;
    }
    return isFrench
        ? 'Nous effectuons une maintenance planifiée. Veuillez réessayer bientôt.'
        : 'We are performing scheduled maintenance. Please try again shortly.';
  }

  String? _getEstimatedEnd() {
    final data = widget.maintenanceData?['active'];
    if (data != null && data['ends_at'] != null) {
      try {
        final endsAt = DateTime.parse(data['ends_at']);
        final now = DateTime.now();
        final diff = endsAt.difference(now);
        if (diff.isNegative) return null;
        if (diff.inHours > 0) {
          return '~${diff.inHours}h ${diff.inMinutes % 60}m';
        }
        return '~${diff.inMinutes}m';
      } catch (_) {}
    }
    return null;
  }

  String? _getContactEmail() {
    final data = widget.maintenanceData?['active'];
    return data?['contact_email'] as String?;
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Support Request - Maintenance',
        'body': 'Hello,\n\nI need assistance while the app is under maintenance.\n\n',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
            content: Text('Still under maintenance. Please try again later.'),
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

  @override
  Widget build(BuildContext context) {
    final isFrench = context.watch<LanguageProvider>().isFrench;
    final estimatedEnd = _getEstimatedEnd();
    final contactEmail = _getContactEmail();
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1EB53A),
              Color(0xFF0D8C2D),
              Color(0xFF065A1A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated geometric pattern background (same as splash)
            AnimatedBuilder(
              animation: _patternController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.08,
                  child: CustomPaint(
                    size: screenSize,
                    painter: _MaintenancePatternPainter(
                      progress: _patternController.value,
                    ),
                  ),
                );
              },
            ),

            // Main content with fade-in
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // App branding at top
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.auGold.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'BURUNDI AU CHAIRMANSHIP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.burundiWhite.withValues(alpha: 0.8),
                              letterSpacing: 3,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Frosted glass card with maintenance info
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Animated maintenance icon
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      final scale =
                                          1.0 + (_pulseController.value * 0.08);
                                      final glow =
                                          _pulseController.value * 0.3;
                                      return Transform.scale(
                                        scale: scale,
                                        child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white
                                                .withValues(alpha: 0.15),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.auGold
                                                    .withValues(alpha: glow),
                                                blurRadius: 30,
                                                spreadRadius: 5,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.build_circle_outlined,
                                            size: 50,
                                            color: AppColors.auGold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 28),

                                  // Title
                                  Text(
                                    _getTitle(isFrench),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Decorative gold line
                                  Container(
                                    width: 60,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.auGold,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Description
                                  Text(
                                    _getDescription(isFrench),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Estimated time remaining
                                  if (estimatedEnd != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.auGold
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
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
                                            isFrench
                                                ? 'Temps estimé: $estimatedEnd'
                                                : 'Estimated time: $estimatedEnd',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Retry button (glossy style)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: ElevatedButton.icon(
                                onPressed: _isRetrying ? null : _retry,
                                icon: _isRetrying
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                                label: Text(
                                  _isRetrying
                                      ? (isFrench
                                          ? 'Vérification...'
                                          : 'Checking...')
                                      : (isFrench ? 'Réessayer' : 'Retry'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Email support button
                        if (contactEmail != null && contactEmail.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () => _launchEmail(contactEmail),
                              icon: const Icon(Icons.email_outlined),
                              label: Text(
                                isFrench
                                    ? 'Contacter le support'
                                    : 'Email Support',
                                style: const TextStyle(
                                  fontSize: 16,
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
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 48),

                        // Footer
                        Text(
                          'Burundi AU Chairmanship 2026',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                            letterSpacing: 2,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Geometric pattern painter matching the splash screen style
class _MaintenancePatternPainter extends CustomPainter {
  final double progress;

  _MaintenancePatternPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.auGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final spacing = 100.0;

    // Diamond grid
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final offset = Offset(x, y);
        _drawDiamond(canvas, paint, offset, 30);
      }
    }

    // Zigzag lines
    paint.strokeWidth = 1.5;
    for (double y = 0; y < size.height; y += spacing * 1.5) {
      final path = Path();
      path.moveTo(0, y);
      for (double x = 0; x < size.width; x += 40) {
        final peakY = y + ((x ~/ 40) % 2 == 0 ? -20 : 20);
        path.lineTo(x + 20, peakY);
        path.lineTo(x + 40, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawDiamond(Canvas canvas, Paint paint, Offset center, double s) {
    final path = Path();
    path.moveTo(center.dx, center.dy - s);
    path.lineTo(center.dx + s, center.dy);
    path.lineTo(center.dx, center.dy + s);
    path.lineTo(center.dx - s, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MaintenancePatternPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
