import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../widgets/african_pattern.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _patternController;
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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _patternController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    _scaleController.forward();

    await Future.delayed(AppConstants.splashDuration);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _patternController.dispose();
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
              Color(0xFF1EB53A),
              Color(0xFF0D8C2D),
              Color(0xFF065A1A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Subtle geometric pattern background
            AnimatedBuilder(
              animation: _patternController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.1,
                  child: CustomPaint(
                    size: screenSize,
                    painter: _SplashPatternPainter(
                      progress: _patternController.value,
                    ),
                  ),
                );
              },
            ),

            // Main content
            SafeArea(
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
                              style: GoogleFonts.oswald(
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
                              style: GoogleFonts.oswald(
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
                                style: GoogleFonts.oswald(
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
  final double progress;

  _SplashPatternPainter({required this.progress});

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
  bool shouldRepaint(covariant _SplashPatternPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
