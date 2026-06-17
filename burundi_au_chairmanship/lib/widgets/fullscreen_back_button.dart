import 'dart:async';
import 'package:flutter/material.dart';

/// Fullscreen video overlay with back button and title.
///
/// Behaviour:
///  1. Appears on entry for 4 seconds, then fades out completely.
///  2. Tap anywhere on the screen → reappears, then fades out again.
///  3. Tap the back arrow while visible → triggers [onBack].
///  4. While hidden, taps are caught to reveal; while visible, taps on
///     the video area pass through to the player controls.
class FullscreenBackButton extends StatefulWidget {
  final VoidCallback onBack;
  final String? title;

  const FullscreenBackButton({super.key, required this.onBack, this.title});

  @override
  State<FullscreenBackButton> createState() => _FullscreenBackButtonState();
}

class _FullscreenBackButtonState extends State<FullscreenBackButton> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _reveal() {
    setState(() => _visible = true);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTitle = widget.title != null && widget.title!.isNotEmpty;

    return Positioned.fill(
      child: Column(
        children: [
          // ── Top bar overlay ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_visible) {
                _scheduleHide();
              } else {
                _reveal();
              }
            },
            child: AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.black54,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.65, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: widget.onBack,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        if (hasTitle) ...[
                          const SizedBox(width: 10),
                          // Title with proportional background box
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Rest of screen: catches taps only when overlay is hidden ──
          Expanded(
            child: IgnorePointer(
              // When visible → ignore taps here (pass through to player)
              // When hidden  → catch the tap to reveal the overlay
              ignoring: _visible,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _reveal,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
