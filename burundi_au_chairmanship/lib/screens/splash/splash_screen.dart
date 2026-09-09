import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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
import '../../main.dart' show navigatorKey;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Cinzel — Roman inscriptional capitals. One family carries the whole crest;
/// weight and tracking do the work instead of a second typeface.
/// Splash typography.
///
/// Cinzel is a Roman inscriptional face: every splash line came out looking
/// like the same carved plaque, so the lines here use the system face with
/// real tracking and the hierarchy comes from size and weight instead.
TextStyle _carved({
  required double size,
  required double weight,
  required Color color,
  double height = 1.0,
}) =>
    TextStyle(
      fontSize: size,
      height: height,
      color: color,
      fontWeight: FontWeight.values[
          ((weight / 100).clamp(1, 9)).round() - 1],
    );

/// Supporting lines: overline, quote, loading label.
TextStyle _splashSupport({
  required double size,
  required FontWeight weight,
  required Color color,
  double height = 1.0,
  double tracking = 0.3,
}) =>
    TextStyle(
      fontSize: size,
      height: height,
      color: color,
      fontWeight: weight,
      letterSpacing: tracking,
    );

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Drives the staggered entrance of the crest, wordmark, drum and quote.
  late AnimationController _intro;

  /// Slow highlight sweeping across the gold "AFRICAN UNION" wordmark.
  late AnimationController _sheen;

  /// Shares the drum's 1800ms phrase so the loading dots pulse on the beat.
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _intro = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _sheen = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    );
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _startAnimations();
  }

  void _startAnimations() async {
    FlutterNativeSplash.remove();

    // Start animations immediately — every staggered item is invisible at frame 0
    _intro.forward();
    _sheen.repeat();
    _pulse.repeat();

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
    } catch (e) {
      // Hard ceiling reached — proceed with whatever we have
      if (kDebugMode) print('Splash max duration reached — proceeding ($e)');
    }
    // Startup navigation must survive this State being disposed mid-splash.
    // Routing through the widget's own context and bailing out on `mounted`
    // meant a disposed splash aborted here silently and left the app sitting
    // on the splash forever, with no crash and no log. Use the global
    // navigator key instead so the app always lands somewhere.
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final navContext = navigatorKey.currentContext;

    // Re-sync language with backend + FCM topics on every cold start.
    if (navContext != null) {
      // Safe across the await: this is the navigator's context, not this
      // State's, so it stays valid even after the splash is disposed.
      // ignore: use_build_context_synchronously
      unawaited(navContext.read<LanguageProvider>().ensureSynced(authProvider));
    }

    // Start presence heartbeat so "users online now" reflects real usage.
    HeartbeatService.instance.start();

    // Check maintenance result from the parallel fetch
    if (maintenanceStatus != null && maintenanceStatus!['in_maintenance'] == true) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => MaintenanceScreen(maintenanceData: maintenanceStatus!),
        ),
      );
      return;
    }

    // Show onboarding on first launch (SharedPreferences is fast — ~1ms)
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(AppConstants.onboardingKey) ?? false;
    if (!onboardingDone) {
      final result = await navigator.push(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      if (result == true) {
        await prefs.setBool(AppConstants.onboardingKey, true);
      }
    }

    // Navigate based on authentication status.
    if (authProvider.isAuthenticated) {
      // Block unverified users — they must complete email verification first
      if (authProvider.requiresEmailVerification) {
        navigator.pushReplacementNamed('/email-verification');
      } else {
        navigator.pushReplacementNamed('/home');
      }
    } else {
      // If user previously chose to continue as guest, skip auth screen
      final isGuest = prefs.getBool('guest_mode') ?? false;
      navigator.pushReplacementNamed(isGuest ? '/home' : '/auth');
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _sheen.dispose();
    _pulse.dispose();
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
                opacity: 0.16,
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
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 30),

                        // Eyebrow. Small caps carry the wide tracking; the
                        // wordmark below deliberately does not.
                        _Rise(
                          parent: _intro,
                          begin: 0.00,
                          end: 0.42,
                          child: _Tracked(
                            'REPUBLIC OF BURUNDI',
                            spacing: 5.5,
                            style: _splashSupport(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.92),
                              tracking: 0.6,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Wordmark — the one loud element. Large type needs
                        // tight tracking, not the eyebrow's wide tracking.
                        _Rise(
                          parent: _intro,
                          begin: 0.08,
                          end: 0.50,
                          child: AnimatedBuilder(
                            animation: _sheen,
                            builder: (context, child) => ShaderMask(
                              shaderCallback: (bounds) {
                                final x = _sheen.value;
                                return LinearGradient(
                                  colors: const [
                                    Colors.white,
                                    Color(0xFFFFFFFF),
                                    Colors.white,
                                  ],
                                  stops: [
                                    (x - 0.2).clamp(0.0, 0.98),
                                    x.clamp(0.01, 0.99),
                                    (x + 0.2).clamp(0.02, 1.0),
                                  ],
                                ).createShader(bounds);
                              },
                              child: child,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              child: _Tracked(
                                'AFRICAN UNION',
                                spacing: 1.5,
                                style: _carved(
                                  size: 29,
                                  weight: 700,
                                  color: Colors.white,
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Hairline rule with a single diamond at its centre —
                        // quieter than the pair of diamonds that used to flank
                        // the line, and it separates wordmark from subline.
                        _Rise(
                          parent: _intro,
                          begin: 0.14,
                          end: 0.56,
                          child: SizedBox(
                            width: 210,
                            child: Row(
                              children: [
                                const Expanded(child: _GoldRule(fadeLeft: true)),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10),
                                  child: _buildDiamondIcon(),
                                ),
                                const Expanded(child: _GoldRule()),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subline — steps down hard from the wordmark instead
                        // of competing with it.
                        _Rise(
                          parent: _intro,
                          begin: 0.18,
                          end: 0.60,
                          child: _Tracked(
                            'CHAIRMANSHIP',
                            spacing: 4.5,
                            style: _splashSupport(
                              size: 12.5,
                              weight: FontWeight.w500,
                              color: AppColors.burundiWhite
                                  .withValues(alpha: 0.82),
                              tracking: 0.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Animated Karyenda drum — arrives last and largest,
                        // so the beat starts once the titles have settled.
                        _Rise(
                          parent: _intro,
                          begin: 0.24,
                          end: 0.78,
                          lift: 26,
                          child: const KaryendaDrumAnimated(
                            size: 170,
                            playing: true,
                          ),
                        ),

                        const SizedBox(height: 26),

                        // Ambassador's quote
                        _Rise(
                          parent: _intro,
                          begin: 0.52,
                          end: 0.94,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 292),
                              child: Text(
                                '\u201CThe sacred drums resound from Burundi, the heart of Africa, so does our commitment to guide our continent toward the Africa we want.\u201D',
                                textAlign: TextAlign.center,
                                style: _splashSupport(
                                  size: 12.5,
                                  weight: FontWeight.w400,
                                  color: AppColors.burundiWhite
                                      .withValues(alpha: 0.78),
                                  height: 1.75,
                                  tracking: 0.2,
                                ).copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Loading indicator
                        _Rise(
                          parent: _intro,
                          begin: 0.64,
                          end: 1.00,
                          child: _buildLoadingIndicator(),
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

  Widget _buildDiamondIcon() {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(color: Colors.white),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Each dot trails the one before it, so the row reads as a
              // travelling pulse rather than three separate blinks.
              final phase = (_pulse.value - i * 0.14) % 1.0;
              final lift = math.exp(-phase * 6);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Transform.translate(
                  offset: Offset(0, -5 * lift),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white
                          .withValues(alpha: 0.55 + 0.45 * lift),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Centred all-caps text with tracking. Flutter appends letter-spacing after
/// the final glyph too, which pushes centred text visibly off-axis; the left
/// pad cancels that out.
class _Tracked extends StatelessWidget {
  final String text;
  final double spacing;
  final TextStyle style;

  const _Tracked(this.text, {required this.spacing, required this.style});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: spacing),
        child: Text(text, style: style.copyWith(letterSpacing: spacing)),
      );
}

/// A 1px gold rule that fades out towards the far end.
class _GoldRule extends StatelessWidget {
  final bool fadeLeft;
  const _GoldRule({this.fadeLeft = false});

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.white.withValues(alpha: 0.0),
      Colors.white.withValues(alpha: 0.5),
    ];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadeLeft ? colors : colors.reversed.toList(),
        ),
      ),
    );
  }
}

/// Fades and lifts a splash element into place over a slice of [parent],
/// so the screen assembles itself instead of appearing all at once.
class _Rise extends StatelessWidget {
  final Animation<double> parent;
  final double begin;
  final double end;
  final double lift;
  final Widget child;

  const _Rise({
    required this.parent,
    required this.begin,
    required this.end,
    required this.child,
    this.lift = 18,
  });

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(
      parent: parent,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, lift * (1 - a.value)),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

class _SplashPatternPainter extends CustomPainter {
  const _SplashPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Draw the motif into a layer so the mask below can fade it as one piece.
    canvas.saveLayer(rect, Paint());

    // The imigongo lattice reads as texture behind the drum; white keeps it
    // in the flag's palette instead of tinting the whole field gold.
    final gold = Colors.white;
    final outer = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final inner = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    // Sparse imigongo lattice — alternate rows shift half a cell so it reads
    // as woven rather than as a square grid. Wider spacing and thinner strokes
    // than a literal imigongo panel: this is texture, not the subject.
    const cell = 116.0;
    var row = 0;
    for (double y = -cell; y < size.height + cell; y += cell * 0.68) {
      final shift = row.isEven ? 0.0 : cell / 2;
      for (double x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + shift, y);
        _diamond(canvas, outer, c, 25);
        _diamond(canvas, inner, c, 11);
      }
      row++;
    }

    // Chevron bands frame the top and bottom only. Running them through the
    // middle was what made the field read as busy behind the drum.
    final chevron = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (final y in [size.height * 0.10, size.height * 0.90]) {
      final path = Path()..moveTo(-cell, y);
      var up = true;
      for (double x = -cell; x < size.width + cell; x += 30) {
        path.lineTo(x + 15, y + (up ? -15 : 15));
        path.lineTo(x + 30, y);
        up = !up;
      }
      canvas.drawPath(path, chevron);
    }

    // Hold the middle right back so the drum and the wordmark own the centre,
    // and let the pattern carry the corners.
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = RadialGradient(
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.35),
            Colors.white,
          ],
          stops: const [0.28, 0.62, 1.0],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _diamond(Canvas canvas, Paint paint, Offset c, double s) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - s)
        ..lineTo(c.dx + s, c.dy)
        ..lineTo(c.dx, c.dy + s)
        ..lineTo(c.dx - s, c.dy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashPatternPainter oldDelegate) => false;
}
