import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../services/api_service.dart';
import '../services/deep_link_router.dart';

class PromotionalSplashOverlay extends StatefulWidget {
  final Map<String, dynamic> splash;
  final String languageCode;
  final VoidCallback onClose;

  const PromotionalSplashOverlay({
    super.key,
    required this.splash,
    required this.languageCode,
    required this.onClose,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> splash,
    required String languageCode,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return PromotionalSplashOverlay(
            splash: splash,
            languageCode: languageCode,
            onClose: () => Navigator.of(context).pop(),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<PromotionalSplashOverlay> createState() => _PromotionalSplashOverlayState();
}

class _PromotionalSplashOverlayState extends State<PromotionalSplashOverlay> {
  late int _secondsRemaining;
  Timer? _timer;

  String get _title => widget.languageCode == 'fr' && (widget.splash['title_fr'] ?? '').isNotEmpty
      ? widget.splash['title_fr']
      : widget.splash['title'] ?? '';

  String get _actionText => widget.languageCode == 'fr' && (widget.splash['action_text_fr'] ?? '').isNotEmpty
      ? widget.splash['action_text_fr']
      : widget.splash['action_text'] ?? '';

  String get _actionUrl => widget.splash['action_url'] ?? '';
  String get _imageUrl => widget.splash['image_url'] ?? '';

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.splash['auto_close_seconds'] ?? 5;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
      });
      if (_secondsRemaining <= 0) {
        timer.cancel();
        widget.onClose();
      }
    });
  }

  void _handleAction() {
    _timer?.cancel();
    final splashId = widget.splash['id'];
    if (splashId != null) {
      ApiService().trackPromotionalSplashClick(splashId).catchError((e) {
        if (kDebugMode) print('Failed to track splash click: $e');
      });
    }
    widget.onClose();
    if (_actionUrl.isNotEmpty) {
      DeepLinkRouter().navigate(_actionUrl);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen image
          if (_imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: _imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.burundiGreen),
                ),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
              ),
            ),

          // Gradient overlay at top for close button visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),

          // Gradient overlay at bottom for action button visibility
          if (_actionUrl.isNotEmpty && _actionText.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 200,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

          // Close button and countdown
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () {
                _timer?.cancel();
                widget.onClose();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_secondsRemaining > 0)
                      Text(
                        '${_secondsRemaining}s  ',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const Icon(Icons.close, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),

          // Action button at bottom
          if (_actionUrl.isNotEmpty && _actionText.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 40,
              left: 32,
              right: 32,
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _handleAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burundiGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    _actionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
