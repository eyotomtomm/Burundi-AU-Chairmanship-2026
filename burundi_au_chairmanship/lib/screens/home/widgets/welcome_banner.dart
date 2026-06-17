import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/verified_badge.dart';

class WelcomeBanner extends StatefulWidget {
  final Map<String, dynamic>? countdownConfig;

  const WelcomeBanner({super.key, this.countdownConfig});

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _parseCountdown();
  }

  @override
  void didUpdateWidget(WelcomeBanner old) {
    super.didUpdateWidget(old);
    if (old.countdownConfig != widget.countdownConfig) {
      _timer?.cancel();
      _parseCountdown();
    }
  }

  void _parseCountdown() {
    final config = widget.countdownConfig;
    if (config == null || config['countdown_enabled'] != true) {
      _targetDate = null;
      return;
    }
    final raw = config['countdown_target_date'];
    if (raw == null) return;
    _targetDate = DateTime.tryParse(raw.toString())?.toLocal();
    if (_targetDate != null) {
      _updateRemaining();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
    }
  }

  void _updateRemaining() {
    if (_targetDate == null) return;
    final diff = _targetDate!.difference(DateTime.now());
    if (mounted) setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!authProvider.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    final userName = authProvider.userName ?? 'User';
    final isVerified = authProvider.isVerified;
    final badgeType = authProvider.badgeType;
    final greetingColor = isDark ? const Color(0xFF8FB7A3) : const Color(0xFF4A7C5D);

    final showCountdown = _targetDate != null && _remaining > Duration.zero;
    final config = widget.countdownConfig;
    final locale = Localizations.localeOf(context).languageCode;
    final countdownLabel = locale == 'fr'
        ? (config?['countdown_label_fr'] ?? config?['countdown_label'] ?? '')
        : (config?['countdown_label'] ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Greeting (left side)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'HeatherGreen',
                    color: greetingColor,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          userName,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'HeatherGreen',
                            color: greetingColor,
                          ),
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      VerifiedBadge(badgeType: badgeType, size: 20),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Countdown (right side)
          if (showCountdown) ...[
            const SizedBox(width: 12),
            _buildCountdown(countdownLabel.toString(), isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdown(String label, bool isDark) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    final bgColor = isDark ? const Color(0xFF1A3A2A) : const Color(0xFF409843);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: bgColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _countdownUnit(days.toString(), 'D', bgColor),
              _divider(bgColor),
              _countdownUnit(hours.toString().padLeft(2, '0'), 'H', bgColor),
              _divider(bgColor),
              _countdownUnit(minutes.toString().padLeft(2, '0'), 'M', bgColor),
              _divider(bgColor),
              _countdownUnit(seconds.toString().padLeft(2, '0'), 'S', bgColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countdownUnit(String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _divider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
