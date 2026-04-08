import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';

class EventCheckInScreen extends StatefulWidget {
  final int eventId;
  final String eventName;

  const EventCheckInScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventCheckInScreen> createState() => _EventCheckInScreenState();
}

class _EventCheckInScreenState extends State<EventCheckInScreen>
    with SingleTickerProviderStateMixin {
  bool _isCheckedIn = false;
  bool _isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String get _checkInCode {
    final userId = context.read<AuthProvider>().userId ?? 0;
    return 'CHECK-${widget.eventId}-$userId';
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _performCheckIn() async {
    setState(() => _isLoading = true);

    try {
      await ApiService().eventCheckIn(
        widget.eventId,
        qrCode: _checkInCode,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isCheckedIn = true;
      });

      _pulseController.stop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Check-in successful!'),
          backgroundColor: AppColors.burundiGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.burundiRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Check-in failed. Please try again.'),
          backgroundColor: AppColors.burundiRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _copyCheckInCode() {
    Clipboard.setData(ClipboardData(text: _checkInCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Check-in code copied!'),
        backgroundColor: AppColors.auGold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = context.watch<LanguageProvider>().languageCode;
    final isFrench = langCode == 'fr';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          isFrench ? 'Enregistrement' : 'Event Check-In',
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Event name card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.burundiGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_available,
                      color: AppColors.burundiGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.eventName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Status indicator
            _buildStatusBadge(isDark, isFrench),

            const SizedBox(height: 28),

            // QR code placeholder / check-in code display
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isCheckedIn ? 1.0 : _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isCheckedIn
                        ? AppColors.burundiGreen
                        : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                    width: _isCheckedIn ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isCheckedIn
                              ? AppColors.burundiGreen
                              : AppColors.auGold)
                          .withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // QR-style grid placeholder
                    if (!_isCheckedIn) ...[
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
                            width: 2,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _QRPlaceholderPainter(
                            color: isDark ? Colors.white24 : Colors.black12,
                            accentColor: AppColors.burundiGreen.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.qr_code_2,
                              size: 64,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.burundiGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 80,
                          color: AppColors.burundiGreen,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _isCheckedIn
                          ? (isFrench ? 'Enregistre' : 'Checked In')
                          : (isFrench ? 'Pret pour l\'enregistrement' : 'Ready to Check In'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isCheckedIn
                            ? AppColors.burundiGreen
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Check-in code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    isFrench ? 'Code d\'enregistrement' : 'Check-In Code',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _copyCheckInCode,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _checkInCode,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.copy,
                          size: 20,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFrench ? 'Appuyez pour copier' : 'Tap to copy',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Check-in button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _isCheckedIn) ? null : _performCheckIn,
                icon: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isCheckedIn ? Icons.check : Icons.login),
                label: Text(
                  _isCheckedIn
                      ? (isFrench ? 'Deja enregistre' : 'Already Checked In')
                      : (isFrench ? 'S\'enregistrer' : 'Check In'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCheckedIn ? Colors.grey : AppColors.burundiGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: _isCheckedIn
                      ? (isDark ? const Color(0xFF333333) : Colors.grey.shade300)
                      : AppColors.burundiGreen.withValues(alpha: 0.5),
                  disabledForegroundColor: _isCheckedIn
                      ? (isDark ? Colors.white54 : Colors.black38)
                      : Colors.white70,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark, bool isFrench) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _isCheckedIn
            ? AppColors.burundiGreen.withValues(alpha: 0.12)
            : AppColors.auGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isCheckedIn
              ? AppColors.burundiGreen.withValues(alpha: 0.3)
              : AppColors.auGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isCheckedIn ? Icons.check_circle : Icons.pending,
            size: 20,
            color: _isCheckedIn ? AppColors.burundiGreen : AppColors.auGold,
          ),
          const SizedBox(width: 8),
          Text(
            _isCheckedIn
                ? (isFrench ? 'Enregistre avec succes' : 'Successfully Checked In')
                : (isFrench ? 'En attente d\'enregistrement' : 'Pending Check-In'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isCheckedIn ? AppColors.burundiGreen : AppColors.auGold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws a stylized QR-code-like grid pattern as a placeholder
class _QRPlaceholderPainter extends CustomPainter {
  final Color color;
  final Color accentColor;

  _QRPlaceholderPainter({required this.color, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cellSize = size.width / 10;

    // Draw a pseudo-QR grid pattern
    final pattern = [
      [1, 1, 1, 0, 1, 0, 1, 1, 1, 0],
      [1, 0, 1, 0, 0, 1, 1, 0, 1, 0],
      [1, 1, 1, 0, 1, 0, 1, 1, 1, 0],
      [0, 0, 0, 0, 1, 1, 0, 0, 0, 0],
      [1, 0, 1, 1, 0, 0, 1, 0, 1, 1],
      [0, 1, 0, 1, 0, 1, 0, 1, 0, 1],
      [1, 1, 1, 0, 1, 0, 1, 1, 1, 0],
      [1, 0, 1, 0, 0, 1, 1, 0, 1, 0],
      [1, 1, 1, 0, 1, 0, 1, 1, 1, 1],
      [0, 0, 0, 1, 0, 1, 0, 0, 0, 1],
    ];

    for (int row = 0; row < pattern.length; row++) {
      for (int col = 0; col < pattern[row].length; col++) {
        if (pattern[row][col] == 1) {
          // Use accent color for corner markers
          final isCorner = (row < 3 && col < 3) ||
              (row < 3 && col > 6) ||
              (row > 6 && col < 3);
          paint.color = isCorner ? accentColor : color;

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                col * cellSize + 1,
                row * cellSize + 1,
                cellSize - 2,
                cellSize - 2,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QRPlaceholderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accentColor != accentColor;
}
