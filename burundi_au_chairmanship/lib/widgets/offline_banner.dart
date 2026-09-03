import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/api_service.dart';
import '../services/data_saver_service.dart';
import '../l10n/app_localizations.dart';

/// A persistent banner that monitors connectivity and shows online/offline status.
/// Also listens to [ApiService.authDegraded] to show a "Reconnecting..." banner
/// when Firebase token fetch fails but the device is online.
///
/// Place this at the top of a page (e.g. inside a Column or Stack).
/// It performs periodic DNS lookups to detect connectivity changes.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;
  bool _showReconnected = false;
  bool _authDegraded = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    ApiService().authDegraded.addListener(_onAuthDegradedChanged);
    _authDegraded = ApiService().authDegraded.value;
  }

  /// Poll fast (10s) only while offline; online, a cheap check every 60s.
  void _schedulePoll() {
    final seconds = (_isOffline ? 10 : 60) * DataSaverService().pollingMultiplier;
    _pollTimer?.cancel();
    _pollTimer = Timer(Duration(seconds: seconds), _checkConnectivity);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    ApiService().authDegraded.removeListener(_onAuthDegradedChanged);
    super.dispose();
  }

  void _onAuthDegradedChanged() {
    if (mounted) {
      setState(() => _authDegraded = ApiService().authDegraded.value);
    }
  }

  Future<void> _checkConnectivity() async {
    final wasOffline = _isOffline;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // We're online
        if (wasOffline && mounted) {
          setState(() {
            _isOffline = false;
            _showReconnected = true;
          });
          // Auto-hide the reconnected banner after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showReconnected = false);
          });
        } else if (mounted) {
          setState(() => _isOffline = false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _showReconnected = false;
        });
      }
    }
    if (mounted) _schedulePoll();
  }

  @override
  Widget build(BuildContext context) {
    // Offline banner takes priority over auth degradation banner
    if (_isOffline) {
      return _buildBanner(
        color: AppColors.burundiRed,
        icon: Icons.wifi_off,
        text: AppLocalizations.of(context).translate('offline_no_internet'),
      );
    }

    if (_showReconnected) {
      return _buildBanner(
        color: AppColors.burundiGreen,
        icon: Icons.wifi,
        text: AppLocalizations.of(context).translate('offline_back_online'),
      );
    }

    // Auth degraded: Firebase token failed but device is online
    if (_authDegraded) {
      return _buildBanner(
        color: const Color(0xFFD4A017), // gold
        icon: null, // use spinner instead
        text: AppLocalizations.of(context).translate('offline_reconnecting'),
        showSpinner: true,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner({
    required Color color,
    IconData? icon,
    required String text,
    bool showSpinner = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSpinner)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else if (icon != null)
              Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
