// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A full-screen swipeable image gallery viewer with zoom/pan support.
///
/// Features:
/// - Full-screen overlay with black background
/// - PageView for horizontal swiping between images
/// - InteractiveViewer for pinch-to-zoom and pan on each image
/// - Page indicator dots at the bottom
/// - Close button (X) in top-right corner
/// - Share button in top-left corner
/// - Double-tap to zoom in/out
/// - Swipe down to dismiss
/// - Image title/caption shown at the bottom with semi-transparent overlay
/// - Hero animation for smooth transition from thumbnail
/// - Uses CachedNetworkImage for loading with placeholder spinner
class ImageGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final List<String>? captions;
  final String? heroTagPrefix;

  const ImageGalleryViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.captions,
    this.heroTagPrefix,
  });

  /// Static convenience method to open the gallery viewer.
  ///
  /// [context] - Build context for navigation
  /// [images] - List of image URLs to display
  /// [initialIndex] - Index of the image to show first (default 0)
  /// [captions] - Optional list of captions for each image
  /// [heroTagPrefix] - Optional prefix for Hero animation tags
  static void show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    List<String>? captions,
    String? heroTagPrefix,
  }) {
    if (images.isEmpty) return;

    // Clamp initial index to valid range
    final clampedIndex = initialIndex.clamp(0, images.length - 1);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) =>
            ImageGalleryViewer(
          images: images,
          initialIndex: clampedIndex,
          captions: captions,
          heroTagPrefix: heroTagPrefix,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  // Swipe-down-to-dismiss tracking
  double _dragOffset = 0.0;
  double _dragScale = 1.0;
  bool _isDragging = false;

  // Double-tap-to-zoom tracking per page
  final Map<int, TransformationController> _transformControllers = {};
  final Map<int, bool> _isZoomed = {};

  // Animation for double-tap zoom
  AnimationController? _doubleTapAnimController;
  Animation<Matrix4>? _doubleTapAnimation;
  int? _animatingPage;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _doubleTapAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _doubleTapAnimController?.dispose();
    for (final controller in _transformControllers.values) {
      controller.dispose();
    }
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  TransformationController _getTransformController(int index) {
    if (!_transformControllers.containsKey(index)) {
      _transformControllers[index] = TransformationController();
      _isZoomed[index] = false;
    }
    return _transformControllers[index]!;
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  /// Handle double-tap to zoom in/out with animation
  void _handleDoubleTap(int index, TapDownDetails? details) {
    final controller = _getTransformController(index);
    final isCurrentlyZoomed = _isZoomed[index] ?? false;

    if (isCurrentlyZoomed) {
      // Zoom out: animate back to identity
      final begin = controller.value;
      final end = Matrix4.identity();

      _animatingPage = index;
      _doubleTapAnimation = Matrix4Tween(begin: begin, end: end).animate(
        CurvedAnimation(
          parent: _doubleTapAnimController!,
          curve: Curves.easeInOut,
        ),
      );
      _doubleTapAnimation!.addListener(() {
        if (_animatingPage == index) {
          controller.value = _doubleTapAnimation!.value;
        }
      });
      _doubleTapAnimController!.forward(from: 0.0).then((_) {
        _animatingPage = null;
      });

      _isZoomed[index] = false;
    } else {
      // Zoom in: 2.5x at the double-tap location
      final position = details?.localPosition ?? Offset.zero;
      const scale = 2.5;

      // Calculate the focal point offset for the zoom
      final x = -position.dx * (scale - 1);
      final y = -position.dy * (scale - 1);

      final end = Matrix4.identity()
        ..translate(x, y)
        ..scale(scale);
      final begin = controller.value;

      _animatingPage = index;
      _doubleTapAnimation = Matrix4Tween(begin: begin, end: end).animate(
        CurvedAnimation(
          parent: _doubleTapAnimController!,
          curve: Curves.easeInOut,
        ),
      );
      _doubleTapAnimation!.addListener(() {
        if (_animatingPage == index) {
          controller.value = _doubleTapAnimation!.value;
        }
      });
      _doubleTapAnimController!.forward(from: 0.0).then((_) {
        _animatingPage = null;
      });

      _isZoomed[index] = true;
    }
  }

  /// Reset zoom when page changes
  void _onPageChanged(int index) {
    // Reset the zoom on the previous page
    final prevController = _transformControllers[_currentIndex];
    if (prevController != null) {
      prevController.value = Matrix4.identity();
      _isZoomed[_currentIndex] = false;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  /// Handle vertical drag for swipe-down dismiss
  void _onVerticalDragStart(DragStartDetails details) {
    // Only allow swipe-down dismiss when not zoomed
    final zoomed = _isZoomed[_currentIndex] ?? false;
    if (zoomed) return;

    setState(() {
      _isDragging = true;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _dragOffset += details.delta.dy;
      // Scale down as user drags further
      _dragScale = (1 - (_dragOffset.abs() / 600)).clamp(0.5, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final velocity = details.primaryVelocity ?? 0;

    // Dismiss if dragged far enough or velocity is high enough
    if (_dragOffset.abs() > 100 || velocity.abs() > 700) {
      Navigator.of(context).pop();
    } else {
      // Snap back
      setState(() {
        _dragOffset = 0.0;
        _dragScale = 1.0;
        _isDragging = false;
      });
    }
  }

  String? _getCaption(int index) {
    if (widget.captions == null) return null;
    if (index < 0 || index >= widget.captions!.length) return null;
    final caption = widget.captions![index];
    return caption.isEmpty ? null : caption;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    final caption = _getCaption(_currentIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Stack(
          children: [
            // Main image page view with drag transform
            AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.identity()
                ..translate(0.0, _dragOffset)
                ..scale(_dragScale),
              transformAlignment: Alignment.center,
              child: PageView.builder(
                controller: _pageController,
                itemCount: total,
                onPageChanged: _onPageChanged,
                // Disable page swiping when zoomed
                physics: (_isZoomed[_currentIndex] ?? false)
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return _buildImagePage(index);
                },
              ),
            ),

            // Background opacity responds to drag
            if (_isDragging && _dragOffset.abs() > 0)
              IgnorePointer(
                child: Container(
                  color: Colors.black
                      .withValues(alpha: _dragScale.clamp(0.0, 1.0)),
                ),
              ),

            // Top bar: close button (right) and share button (left)
            if (_showUI)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _isDragging ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Share button (left)
                            _buildCircleButton(
                              icon: Icons.share_rounded,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Clipboard.setData(ClipboardData(
                                  text: widget.images[_currentIndex],
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Image link copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                            // Image counter
                            if (total > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_currentIndex + 1} / $total',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            // Close button (right)
                            _buildCircleButton(
                              icon: Icons.close_rounded,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom: caption + page dots
            if (_showUI)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _isDragging ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Caption
                            if (caption != null) ...[
                              Text(
                                caption,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Page indicator dots
                            if (total > 1 && total <= 20)
                              _buildPageDots(total)
                            else if (total > 20)
                              // For very large galleries, just show the counter
                              Text(
                                '${_currentIndex + 1} of $total',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
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

  Widget _buildImagePage(int index) {
    final url = widget.images[index];
    final controller = _getTransformController(index);
    TapDownDetails? lastTapDown;

    final heroTag = widget.heroTagPrefix != null
        ? '${widget.heroTagPrefix}_$index'
        : null;

    Widget imageWidget = GestureDetector(
      onTap: _toggleUI,
      onDoubleTapDown: (details) {
        lastTapDown = details;
      },
      onDoubleTap: () {
        _handleDoubleTap(index, lastTapDown);
      },
      child: InteractiveViewer(
        transformationController: controller,
        minScale: 0.5,
        maxScale: 5.0,
        panEnabled: true,
        scaleEnabled: true,
        onInteractionEnd: (details) {
          // Track zoomed state based on current scale
          final scale = controller.value.getMaxScaleOnAxis();
          setState(() {
            _isZoomed[index] = scale > 1.05;
          });
        },
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
            errorWidget: (_, _, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_rounded,
                      color: Colors.white38, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap in Hero if tag is provided
    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildPageDots(int total) {
    // Show at most 9 dots, scrolling window for larger sets
    const maxDots = 9;
    final showDots = math.min(total, maxDots);

    int startIndex;
    if (total <= maxDots) {
      startIndex = 0;
    } else {
      // Center the active dot in the visible window
      startIndex = (_currentIndex - maxDots ~/ 2).clamp(0, total - maxDots);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(showDots, (i) {
        final dotIndex = startIndex + i;
        final isActive = dotIndex == _currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
