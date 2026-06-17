import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnouncementBanner extends StatefulWidget {
  final Map<String, dynamic> banner;
  final String langCode;
  final VoidCallback onDismiss;

  const AnnouncementBanner({
    super.key,
    required this.banner,
    required this.langCode,
    required this.onDismiss,
  });

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  static const _typeColors = {
    'info': Color(0xFF409843),
    'success': Color(0xFF409843),
    'warning': Color(0xFFE65100),
    'error': Color(0xFFC62828),
    'urgent': Color(0xFFC62828),
  };

  static const _typeIcons = {
    'info': Icons.info_outline_rounded,
    'success': Icons.check_circle_outline_rounded,
    'warning': Icons.warning_amber_rounded,
    'error': Icons.error_outline_rounded,
    'urgent': Icons.notification_important_rounded,
  };

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    _parseEndsAt();
    if (_endsAt != null) {
      _updateRemaining();
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateRemaining(),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _parseEndsAt() {
    final raw = widget.banner['ends_at'];
    if (raw == null) return;
    _endsAt = DateTime.tryParse(raw.toString())?.toLocal();
  }

  void _updateRemaining() {
    if (_endsAt == null) return;
    final diff = _endsAt!.difference(DateTime.now());
    if (mounted) setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  String _formatCountdown(Duration d) {
    if (d.inDays > 0) {
      final h = d.inHours % 24;
      return '${d.inDays}d ${h}h';
    }
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.langCode == 'fr'
        ? (widget.banner['title_fr'] ?? widget.banner['title'] ?? '')
        : (widget.banner['title'] ?? '');
    final message = widget.langCode == 'fr'
        ? (widget.banner['message_fr'] ?? widget.banner['message'] ?? '')
        : (widget.banner['message'] ?? '');
    final bannerType = widget.banner['banner_type'] as String? ?? 'info';
    final bgColor = _typeColors[bannerType] ?? const Color(0xFF409843);
    final icon = _typeIcons[bannerType] ?? Icons.campaign;
    final isDismissible = widget.banner['is_dismissible'] ?? true;

    final linkUrl = (widget.banner['link_url'] as String? ?? '').trim();
    final actionUrl = (widget.banner['action_url'] as String? ?? '').trim();
    final targetUrl = actionUrl.isNotEmpty ? actionUrl : linkUrl;
    final hasAction = targetUrl.isNotEmpty;

    final actionText = widget.langCode == 'fr'
        ? (widget.banner['action_text_fr'] ?? widget.banner['action_text'] ?? '')
        : (widget.banner['action_text'] ?? '');

    final showCountdown = _endsAt != null && _remaining > Duration.zero;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        onTap: hasAction ? () => _handleTap(context, targetUrl) : null,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _AfricanPatternPainter(baseColor: bgColor),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: icon + title + countdown + dismiss
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title.toString().isNotEmpty)
                                Text(
                                  title.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (showCountdown)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, color: Colors.white.withValues(alpha: 0.9), size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCountdown(_remaining),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isDismissible == true)
                          GestureDetector(
                            onTap: widget.onDismiss,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8, top: 2),
                              child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.8), size: 18),
                            ),
                          ),
                      ],
                    ),
                    // Message
                    if (message.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5, left: 30),
                        child: Text(
                          message.toString(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // Action button
                    if (hasAction && actionText.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 30),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionText.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String url) {
    if (url.startsWith('/')) {
      Navigator.pushNamed(context, url);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Paints subtle African-inspired geometric patterns on the banner background.
class _AfricanPatternPainter extends CustomPainter {
  final Color baseColor;
  _AfricanPatternPainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    // Zigzag border pattern along the top
    final zigzag = Path();
    const step = 12.0;
    const amp = 6.0;
    for (double x = 0; x < size.width + step; x += step) {
      final y = (x ~/ step) % 2 == 0 ? 0.0 : amp;
      if (x == 0) {
        zigzag.moveTo(x, y);
      } else {
        zigzag.lineTo(x, y);
      }
    }
    canvas.drawPath(zigzag, paint);

    // Zigzag along the bottom
    final zigzagBottom = Path();
    for (double x = 0; x < size.width + step; x += step) {
      final y = (x ~/ step) % 2 == 0 ? size.height : size.height - amp;
      if (x == 0) {
        zigzagBottom.moveTo(x, y);
      } else {
        zigzagBottom.lineTo(x, y);
      }
    }
    canvas.drawPath(zigzagBottom, paint);

    // Diamond pattern on the right side
    const diamondSize = 16.0;
    const cols = 3;
    const rows = 3;
    final startX = size.width - (cols * diamondSize * 1.3) - 8;
    final startY = (size.height - (rows * diamondSize * 0.8)) / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = startX + c * diamondSize * 1.3;
        final cy = startY + r * diamondSize * 0.8;
        final diamond = Path()
          ..moveTo(cx, cy - diamondSize / 3)
          ..lineTo(cx + diamondSize / 3, cy)
          ..lineTo(cx, cy + diamondSize / 3)
          ..lineTo(cx - diamondSize / 3, cy)
          ..close();
        canvas.drawPath(diamond, paint);
        if ((r + c) % 2 == 0) {
          canvas.drawPath(diamond, fillPaint);
        }
      }
    }

    // Concentric triangles on the left side (behind icon area)
    final triPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 3; i++) {
      final s = 20.0 + i * 10.0;
      final ox = -2.0 + i * 2.0;
      final oy = size.height / 2;
      final tri = Path()
        ..moveTo(ox, oy - s / 2)
        ..lineTo(ox + s * 0.866, oy)
        ..lineTo(ox, oy + s / 2)
        ..close();
      canvas.drawPath(tri, triPaint);
    }

    // Small dot grid pattern in the middle area
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const dotSpacing = 18.0;
    const dotRadius = 1.2;
    final midStart = size.width * 0.3;
    final midEnd = size.width * 0.65;
    for (double x = midStart; x < midEnd; x += dotSpacing) {
      for (double y = dotSpacing; y < size.height - dotSpacing / 2; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_AfricanPatternPainter oldDelegate) =>
      oldDelegate.baseColor != baseColor;
}
