import 'package:flutter/material.dart';

import '../../../config/app_ds.dart';

/// The floating bottom bar: a white pill with a raised circle that slides to
/// whichever tab is selected, and a notch cut out of the bar beneath it.
///
/// Home sits at [homeIndex] — the middle slot — so the resting state has the
/// circle dead centre and it travels out from there.
///
/// The slide is driven by an explicit controller rather than an implicit
/// animation so two cases stay distinguishable: changing tab *animates*, while
/// a width change (rotation, split view) *snaps* — sliding the circle across
/// the screen because the device turned would look like a glitch.
class HomeNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<HomeNavItem> items;
  final int homeIndex;

  const HomeNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.homeIndex = 2,
  });

  static const double barHeight = 62;

  @override
  State<HomeNavBar> createState() => _HomeNavBarState();
}

class _HomeNavBarState extends State<HomeNavBar>
    with SingleTickerProviderStateMixin {
  static const double _raised = 56;
  static const double _sideMargin = 14;

  /// Measured from the screen edge rather than the home-indicator inset, so
  /// the bar sits low without floating. Enough gap for its rounded bottom
  /// corners to read as a floating pill, not so much that it drifts up.
  static const double _bottomMargin = 18;
  static const double _hPad = 10;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late Animation<double> _slide = AlwaysStoppedAnimation<double>(
    widget.currentIndex.toDouble(),
  );

  double _from = 0;
  double _barWidth = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.currentIndex.toDouble();
    _slide = AlwaysStoppedAnimation<double>(_from);
  }

  @override
  void didUpdateWidget(covariant HomeNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Start from wherever the circle actually is, so a fast double-tap
      // continues from mid-flight instead of jumping back.
      _from = _slide.value;
      _slide = Tween<double>(begin: _from, end: widget.currentIndex.toDouble())
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Room for the circle to stand proud of the bar without being clipped.
      height: HomeNavBar.barHeight + _bottomMargin + (_raised / 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth - (_sideMargin * 2);
          // A width change means the geometry moved under us (rotation, resize):
          // settle the circle at its slot instead of animating across.
          if (_barWidth != 0 &&
              _barWidth != barWidth &&
              _controller.isAnimating) {
            _controller.stop();
            _slide = AlwaysStoppedAnimation<double>(
              widget.currentIndex.toDouble(),
            );
          }
          _barWidth = barWidth;

          final slot = (barWidth - (_hPad * 2)) / widget.items.length;
          double centreOf(double i) => _hPad + slot * (i + 0.5);

          return AnimatedBuilder(
            animation: _slide,
            builder: (context, _) {
              // One value drives the cut-out and the circle, so they can never
              // drift apart mid-flight.
              final notchX = centreOf(_slide.value);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Content fades out before it reaches the bar, so a white
                  // card scrolling underneath never merges into it.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Ds.bg(context).withValues(alpha: 0),
                              Ds.bg(context).withValues(alpha: 0.85),
                              Ds.bg(context),
                            ],
                            stops: const [0, 0.55, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _sideMargin,
                    right: _sideMargin,
                    bottom: _bottomMargin,
                    height: HomeNavBar.barHeight,
                    child: PhysicalShape(
                      clipper: _NotchClipper(notchX),
                      color: Ds.surface(context),
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.28),
                      child: CustomPaint(
                        foregroundPainter: _NotchOutlinePainter(
                          notchX,
                          Ds.hairline(context),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _hPad,
                          ),
                          child: Row(
                            children: [
                              for (var i = 0; i < widget.items.length; i++)
                                _item(context, i),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _sideMargin + notchX - (_raised / 2),
                    bottom:
                        _bottomMargin +
                        HomeNavBar.barHeight -
                        (_raised / 2) -
                        6,
                    child: _raisedButton(context),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _item(BuildContext context, int index) {
    final item = widget.items[index];
    final active = widget.currentIndex == index;

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: item.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(Ds.rTile),
          onTap: () => widget.onTap(index),
          // The active slot is covered by the raised circle, so only its label
          // shows through — its icon would sit behind the button.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!active) ...[
                Icon(item.icon, size: 22, color: Ds.muted(context)),
                const SizedBox(height: 3),
              ] else
                const SizedBox(height: 25),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? Ds.green : Ds.body(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _raisedButton(BuildContext context) {
    return Semantics(
      button: true,
      selected: true,
      label: widget.items[widget.currentIndex].label,
      child: GestureDetector(
        onTap: () => widget.onTap(widget.currentIndex),
        child: Container(
          width: _raised,
          height: _raised,
          decoration: BoxDecoration(
            color: Ds.green,
            shape: BoxShape.circle,
            border: Border.all(color: Ds.bg(context), width: 3),
            boxShadow: Ds.shadowLg(context),
          ),
          // Keyed on the index so the icon pops as the circle arrives.
          child: TweenAnimationBuilder<double>(
            key: ValueKey(widget.currentIndex),
            tween: Tween<double>(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Icon(
              widget.items[widget.currentIndex].icon,
              size: 26,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class HomeNavItem {
  final IconData icon;
  final String label;
  const HomeNavItem(this.icon, this.label);
}

/// The bar's silhouette: a rounded pill with a circular bite taken out of the
/// top at [notchCentreX], so the raised button nests into it.
class _NotchClipper extends CustomClipper<Path> {
  final double notchCentreX;
  static const double _notchRadius = 34;
  static const double _corner = 28;

  const _NotchClipper(this.notchCentreX);

  @override
  Path getClip(Size size) {
    final bar = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(_corner),
        ),
      );
    final notch = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(notchCentreX, 0), radius: _notchRadius),
      );
    return Path.combine(PathOperation.difference, bar, notch);
  }

  @override
  bool shouldReclip(covariant _NotchClipper oldClipper) =>
      oldClipper.notchCentreX != notchCentreX;
}

/// Traces the bar's edge, notch included, so the pill keeps a visible outline
/// where a white card scrolls behind it.
class _NotchOutlinePainter extends CustomPainter {
  final double notchCentreX;
  final Color colour;

  const _NotchOutlinePainter(this.notchCentreX, this.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colour;
    canvas.drawPath(_NotchClipper(notchCentreX).getClip(size), paint);
  }

  @override
  bool shouldRepaint(covariant _NotchOutlinePainter old) =>
      old.notchCentreX != notchCentreX || old.colour != colour;
}
