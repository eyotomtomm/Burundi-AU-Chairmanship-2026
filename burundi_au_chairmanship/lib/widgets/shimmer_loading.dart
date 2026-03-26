import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable shimmer loading placeholders for the app.
/// Grey boxes with a light sweep animation to indicate content is loading.
class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const ShimmerLoading({super.key, required this.child, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: dark ? Colors.grey[700]! : Colors.grey[100]!,
      child: child,
    );
  }
}

/// A single shimmer box with rounded corners.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Skeleton Builders ───────────────────────────────────────────────

/// Hero slideshow skeleton (full-width banner)
class ShimmerHeroSkeleton extends StatelessWidget {
  const ShimmerHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            const ShimmerBox(height: 400, radius: 0),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (_) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feature card carousel skeleton
class ShimmerFeatureCardsSkeleton extends StatelessWidget {
  const ShimmerFeatureCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(height: 16, width: 120, radius: 4),
            const SizedBox(height: 12),
            const ShimmerBox(height: 180, radius: 16),
          ],
        ),
      ),
    );
  }
}

/// Quick access grid skeleton (2 rows of 4 icons)
class ShimmerQuickAccessSkeleton extends StatelessWidget {
  const ShimmerQuickAccessSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(height: 16, width: 100, radius: 4),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 8,
              itemBuilder: (_, _) => Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const ShimmerBox(height: 10, width: 50, radius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal card carousel skeleton (events, news)
class ShimmerHorizontalCardsSkeleton extends StatelessWidget {
  final double cardHeight;
  final double cardWidth;
  final int count;

  const ShimmerHorizontalCardsSkeleton({
    super.key,
    this.cardHeight = 200,
    this.cardWidth = 280,
    this.count = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SizedBox(
        height: cardHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: count,
          itemBuilder: (_, _) => Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: cardHeight * 0.6, radius: 12),
                const SizedBox(height: 8),
                ShimmerBox(height: 14, width: cardWidth * 0.7, radius: 4),
                const SizedBox(height: 6),
                ShimmerBox(height: 10, width: cardWidth * 0.5, radius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// News / article list skeleton (vertical list)
class ShimmerArticleListSkeleton extends StatelessWidget {
  final int count;

  const ShimmerArticleListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const ShimmerBox(height: 80, width: 80, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(height: 14, radius: 4),
                        SizedBox(height: 8),
                        ShimmerBox(height: 10, width: 180, radius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(height: 10, width: 100, radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Magazine grid skeleton (2-column grid of cards)
class ShimmerMagazineGridSkeleton extends StatelessWidget {
  final int count;

  const ShimmerMagazineGridSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: count,
          itemBuilder: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: ShimmerBox(height: 200, radius: 12)),
              const SizedBox(height: 8),
              const ShimmerBox(height: 12, radius: 4),
              const SizedBox(height: 4),
              const ShimmerBox(height: 10, width: 80, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agenda card list skeleton
class ShimmerAgendaListSkeleton extends StatelessWidget {
  final int count;

  const ShimmerAgendaListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(height: 16, radius: 4),
                        SizedBox(height: 8),
                        ShimmerBox(height: 12, width: 160, radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Location / embassy list skeleton
class ShimmerLocationListSkeleton extends StatelessWidget {
  final int count;

  const ShimmerLocationListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(height: 14, radius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(height: 10, width: 150, radius: 4),
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
}

/// Video grid skeleton (2-column)
class ShimmerVideoGridSkeleton extends StatelessWidget {
  final int count;

  const ShimmerVideoGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: count,
          itemBuilder: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const ShimmerBox(height: double.infinity, radius: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const ShimmerBox(height: 12, radius: 4),
              const SizedBox(height: 4),
              const ShimmerBox(height: 10, width: 80, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ticket / generic list item skeleton
class ShimmerListItemSkeleton extends StatelessWidget {
  final int count;

  const ShimmerListItemSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 14, width: 200, radius: 4),
                    SizedBox(height: 10),
                    ShimmerBox(height: 10, radius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(height: 10, width: 140, radius: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Calendar event list skeleton
class ShimmerCalendarSkeleton extends StatelessWidget {
  final int count;

  const ShimmerCalendarSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(height: 14, radius: 4),
                        SizedBox(height: 8),
                        ShimmerBox(height: 10, width: 120, radius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(height: 10, width: 80, radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live feeds screen skeleton
class ShimmerLiveFeedsSkeleton extends StatelessWidget {
  const ShimmerLiveFeedsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 80),
            // Featured card
            const ShimmerBox(height: 220, radius: 16),
            const SizedBox(height: 24),
            // Section title
            const ShimmerBox(height: 16, width: 140, radius: 4),
            const SizedBox(height: 12),
            // Horizontal cards
            SizedBox(
              height: 160,
              child: Row(
                children: List.generate(
                  3,
                  (_) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ShimmerBox(height: 100, radius: 12),
                          SizedBox(height: 8),
                          ShimmerBox(height: 12, radius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(height: 10, width: 60, radius: 4),
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
}

/// Home tab full-page shimmer (hero + features + quick access + news)
class ShimmerHomeTabSkeleton extends StatelessWidget {
  const ShimmerHomeTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
            const ShimmerBox(height: 400, radius: 0),
            const SizedBox(height: 16),
            // Welcome banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(height: 20, width: 200, radius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(height: 14, width: 280, radius: 4),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Feature card
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ShimmerBox(height: 180, radius: 16),
            ),
            const SizedBox(height: 20),
            // Quick access
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(height: 16, width: 100, radius: 4),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      4,
                      (_) => Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const ShimmerBox(height: 10, width: 50, radius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // News section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(height: 16, width: 120, radius: 4),
                  const SizedBox(height: 12),
                  ...List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: const [
                          ShimmerBox(height: 80, width: 80, radius: 10),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShimmerBox(height: 14, radius: 4),
                                SizedBox(height: 8),
                                ShimmerBox(height: 10, width: 180, radius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
