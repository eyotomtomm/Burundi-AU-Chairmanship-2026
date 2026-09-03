import 'package:flutter/material.dart';

/// Fullscreen video overlay: a scrimmed back arrow, and optionally the title.
///
/// The arrow stays on screen for as long as the video does. It used to fade
/// out after 4s and come back on tap, but the tap never reached us over a
/// platform view (the YouTube webview eats it), so rotating into fullscreen
/// left no way out.
///
/// Only the arrow takes taps — the gradient strip lets them through to the
/// player controls underneath.
class FullscreenBackButton extends StatelessWidget {
  final VoidCallback onBack;
  final String? title;

  const FullscreenBackButton({super.key, required this.onBack, this.title});

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    final topInset = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Stack(
        children: [
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.black54, Colors.transparent],
                  stops: [0.0, 0.65, 1.0],
                ),
              ),
              padding: EdgeInsets.fromLTRB(70, topInset + 8, 16, 24),
              child: hasTitle
                  ? Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    )
                  : const SizedBox(height: 24),
            ),
          ),
          Positioned(
            left: 10,
            top: topInset + 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
