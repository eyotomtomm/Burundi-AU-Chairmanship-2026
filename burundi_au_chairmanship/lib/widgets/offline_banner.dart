import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// A persistent banner that monitors connectivity and shows online/offline status.
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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkConnectivity());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline && !_showReconnected) return const SizedBox.shrink();

    final isReconnected = _showReconnected && !_isOffline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: isReconnected ? AppColors.burundiGreen : AppColors.burundiRed,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReconnected ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              isReconnected ? 'Back online' : 'No internet connection',
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
