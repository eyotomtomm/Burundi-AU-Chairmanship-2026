import 'dart:async';
import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Firebase-style slide-down in-app notification banner.
///
/// Shown when a push arrives while the app is foregrounded. Call
/// [InAppBanner.show] from the FCM foreground handler and it will:
///  - slide down from the top with a rounded card
///  - show title, body, and optional image thumbnail
///  - auto-dismiss after [duration]
///  - swipe up to dismiss immediately
///  - tap to invoke [onTap]
///
/// Banners are queued so rapid arrivals stack instead of clobbering.
class InAppBanner {
  static final Queue<_BannerRequest> _queue = Queue<_BannerRequest>();
  static OverlayEntry? _currentEntry;
  static _BannerWidgetState? _currentState;

  static void show(
    BuildContext context, {
    required String title,
    String? body,
    String? imageUrl,
    String? notificationId,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final request = _BannerRequest(
      title: title,
      body: body,
      imageUrl: imageUrl,
      notificationId: notificationId,
      onTap: onTap,
      duration: duration,
    );

    _queue.add(request);
    if (_currentEntry == null) {
      _showNext(overlay);
    }
  }

  static void _showNext(OverlayState overlay) {
    if (_queue.isEmpty) return;
    final request = _queue.removeFirst();

    final entry = OverlayEntry(
      builder: (ctx) => _BannerWidget(
        request: request,
        onDismissed: () {
          _currentEntry?.remove();
          _currentEntry = null;
          _currentState = null;
          if (_queue.isNotEmpty) {
            _showNext(overlay);
          }
        },
        stateCallback: (s) => _currentState = s,
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// Dismiss the currently visible banner, if any. Useful for tests or
  /// when navigation preempts the banner.
  static void dismissCurrent() {
    _currentState?._dismiss();
  }
}

class _BannerRequest {
  final String title;
  final String? body;
  final String? imageUrl;
  final String? notificationId;
  final VoidCallback? onTap;
  final Duration duration;

  _BannerRequest({
    required this.title,
    this.body,
    this.imageUrl,
    this.notificationId,
    this.onTap,
    required this.duration,
  });
}

class _BannerWidget extends StatefulWidget {
  final _BannerRequest request;
  final VoidCallback onDismissed;
  final ValueChanged<_BannerWidgetState> stateCallback;

  const _BannerWidget({
    required this.request,
    required this.onDismissed,
    required this.stateCallback,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoDismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    widget.stateCallback(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _autoDismissTimer = Timer(widget.request.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  void _handleTap() {
    _autoDismissTimer?.cancel();
    try {
      widget.request.onTap?.call();
    } finally {
      _dismiss();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final borderAccent = theme.colorScheme.primary;
    final titleStyle = TextStyle(
      color: isDark ? Colors.white : const Color(0xFF0F172A),
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );
    final bodyStyle = TextStyle(
      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
      fontSize: 13,
      height: 1.3,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Dismissible(
                key: ValueKey(
                  widget.request.notificationId ??
                      widget.request.title.hashCode,
                ),
                direction: DismissDirection.up,
                onDismissed: (_) => _dismiss(),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _handleTap,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                          left: BorderSide(color: borderAccent, width: 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.5 : 0.15),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.request.imageUrl != null &&
                              widget.request.imageUrl!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: widget.request.imageUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorWidget: (ctx, url, err) => Container(
                                    width: 44,
                                    height: 44,
                                    color: borderAccent.withValues(alpha: 0.15),
                                    child: Icon(
                                      Icons.notifications,
                                      color: borderAccent,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: borderAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.notifications_active,
                                  color: borderAccent,
                                  size: 22,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.request.title,
                                  style: titleStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.request.body != null &&
                                    widget.request.body!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.request.body!,
                                    style: bodyStyle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF94A3B8),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: _dismiss,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
