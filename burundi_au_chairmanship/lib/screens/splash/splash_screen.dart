import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../widgets/african_pattern.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/heartbeat_service.dart';
import '../../services/splash_preloader.dart';
import '../maintenance/maintenance_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    // Start animations immediately — frame 0 is invisible (opacity 0, scale 0.85)
    _fadeController.forward();
    _scaleController.forward();

    // Start preloading home-feed data in parallel with the splash animation
    SplashPreloader.instance.startPreload();

    // Run auth init, maintenance check, data preload, and minimum visual duration
    // all in parallel so the user pays max(~2.5s, auth, maintenance, preload)
    // instead of sequentially. splashMaxDuration is a hard ceiling.
    final authProvider = context.read<AuthProvider>();
    Map<String, dynamic>? maintenanceStatus;

    try {
      await Future.wait([
        Future.delayed(AppConstants.splashMinDuration),
        authProvider.initialized.timeout(const Duration(seconds: 10)).catchError((_) {
          if (kDebugMode) print('Auth init timed out in splash — proceeding');
        }),
        SplashPreloader.instance.waitForCriticalData(AppConstants.splashMaxDuration)
            .catchError((_) => null),
        ApiService()
            .getMaintenanceStatus()
            .timeout(const Duration(seconds: 5)) // Must resolve before splashMaxDuration
            .then((status) {
          maintenanceStatus = status;
          if (kDebugMode) print('Maintenance check: in_maintenance=${status['in_maintenance']}');
          return status;
        }).catchError((e) {
          if (kDebugMode) print('Maintenance check failed: $e');
          return <String, dynamic>{};
        }),
      ]).timeout(AppConstants.splashMaxDuration);
    } catch (_) {
      // Hard ceiling reached — proceed with whatever we have
      if (kDebugMode) print('Splash max duration reached — proceeding');
    }
    if (!mounted) return;

    // Re-sync language with backend + FCM topics on every cold start.
    unawaited(context.read<LanguageProvider>().ensureSynced(authProvider));

    // Start presence heartbeat so "users online now" reflects real usage.
    HeartbeatService.instance.start();

    // Check maintenance result from the parallel fetch
    if (maintenanceStatus != null && maintenanceStatus!['in_maintenance'] == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MaintenanceScreen(maintenanceData: maintenanceStatus!),
        ),
      );
      return;
    }
    if (!mounted) return;

    // App update check removed from splash — HomeScreen already runs it
    // via _checkForAppUpdate() in addPostFrameCallback, so it no longer
    // blocks navigation here.

    // Show onboarding on first launch (SharedPreferences is fast — ~1ms)
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(AppConstants.onboardingKey) ?? false;
    if (!onboardingDone) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      if (result == true) {
        await prefs.setBool(AppConstants.onboardingKey, true);
      }
      if (!mounted) return;
    }

    // Navigate based on authentication status.
    // Only require isAuthenticated — profile data may be partially cached
    // and that's OK; it will be refreshed in the background once the user
    // reaches the home screen.
    if (authProvider.isAuthenticated) {
      // Block unverified users — they must complete email verification first
      if (authProvider.requiresEmailVerification) {
        Navigator.of(context).pushReplacementNamed('/email-verification');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Color(0xFF409843),
              Color(0xFF357E39),
              Color(0xFF2D6E31),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative pattern — hidden from screen readers
            ExcludeSemantics(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(
                  size: screenSize,
                  painter: const _SplashPatternPainter(),
                ),
              ),
            ),

            // Main content
            Semantics(
              label: 'Republic of Burundi, African Union Chairmanship 2026. Loading application.',
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          const SizedBox(height: 30),

                          // Republic of Burundi text
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.auGold.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              'REPUBLIC OF BURUNDI',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.burundiWhite.withValues(alpha: 0.95),
                                letterSpacing: 4,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // African Union text
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [AppColors.auGold, Color(0xFFFFD700)],
                            ).createShader(bounds),
                            child: Text(
                              'AFRICAN UNION',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 3,
                              ),
                            ),
                          ),

                          // Chairmanship 2026
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildDiamondIcon(),
                              const SizedBox(width: 15),
                              Text(
                                'CHAIRMANSHIP 2026',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.burundiWhite,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: 15),
                              _buildDiamondIcon(),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Animated Gishora Drum
                          const KaryendaDrumAnimated(
                            size: 160,
                            playing: true,
                          ),

                          const SizedBox(height: 20),

                          // Ambassador's quote
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              '"The sacred drums resound from Burundi, the heart of Africa, so does our commitment to guide our continent toward the Africa we want."',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.burundiWhite.withValues(alpha: 0.85),
                                height: 1.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Loading indicator
                          _buildLoadingIndicator(),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
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

  Widget _buildDiamondIcon() {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.auGold,
          border: Border.all(color: AppColors.burundiWhite, width: 1),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.auGold.withValues(alpha: 0.8),
                ),
              ),
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 12,
                  height: 12,
                  color: AppColors.auGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'Loading...',
          style: TextStyle(
            color: AppColors.burundiWhite.withValues(alpha: 0.7),
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _SplashPatternPainter extends CustomPainter {
  const _SplashPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.auGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final spacing = 100.0;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final offset = Offset(x, y);
        _drawDiamond(canvas, paint, offset, 30);
      }
    }

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
  bool shouldRepaint(covariant _SplashPatternPainter oldDelegate) => false;
}
