import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../painters/zigzag_line_painter.dart';
import '../../../services/data_saver_service.dart';

class HeroSlideshow extends StatelessWidget {
  final PageController pageController;
  final List<Map<String, dynamic>> heroSlides;
  final int currentRawPage;
  final int unreadBadgeCount;
  final String Function(String key) getHeroText;
  final VoidCallback onNotificationTap;
  final ValueChanged<int> onPageChanged;

  const HeroSlideshow({
    super.key,
    required this.pageController,
    required this.heroSlides,
    required this.currentRawPage,
    required this.unreadBadgeCount,
    required this.getHeroText,
    required this.onNotificationTap,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 400,
      width: screenWidth,
      child: Stack(
        children: [
          // Slideshow
          PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              if (heroSlides.isEmpty) return const SizedBox.shrink();
              final slide = heroSlides[index % heroSlides.length];
              final imagePath = slide['image'] as String;
              final isNetwork = slide['isNetwork'] == true;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (isNetwork)
                    CachedNetworkImage(
                      imageUrl: imagePath,
                      fit: BoxFit.cover,
                      memCacheWidth: DataSaverService().fullImageCacheWidth ?? 800,
                      width: screenWidth,
                      height: 400,
                      placeholder: (context, url) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF409843), Color(0xFF2D6E31)],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF409843), Color(0xFF2D6E31)],
                          ),
                        ),
                        child: const Center(child: Icon(Icons.image, size: 64, color: Colors.white54)),
                      ),
                    )
                  else
                    Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      width: screenWidth,
                      height: 400,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF409843), Color(0xFF2D6E31)],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image, size: 64, color: Colors.white54),
                                const SizedBox(height: 8),
                                Text(
                                  imagePath.split('/').last,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.2, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App bar row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48),
                      Row(
                        children: [
                          // Notification bell
                          IconButton(
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.notifications_outlined, color: Colors.white),
                                ),
                                if (unreadBadgeCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.burundiRed,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      child: Text(
                                        unreadBadgeCount > 99 ? '99+' : '$unreadBadgeCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: onNotificationTap,
                          ),
                          // Theme toggle
                          Consumer<ThemeProvider>(
                            builder: (context, themeProvider, _) {
                              return IconButton(
                                icon: Icon(
                                  themeProvider.isDarkMode
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  color: Colors.white,
                                ),
                                onPressed: () => themeProvider.toggleTheme(),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.auGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      getHeroText('badge'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    getHeroText('title_line1'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${getHeroText('title_line2')} ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.auGold, Color(0xFFFFD700)],
                        ).createShader(bounds),
                        child: Text(
                          getHeroText('year'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Slide label
                  Text(
                    heroSlides.isNotEmpty ? (heroSlides[currentRawPage % heroSlides.length]['label'] ?? '') : '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Zigzag + Dot indicators
                  Row(
                    children: [
                      CustomPaint(
                        size: const Size(60, 10),
                        painter: ZigzagLinePainter(),
                      ),
                      const SizedBox(width: 15),
                      if (heroSlides.isNotEmpty)
                        ...List.generate(heroSlides.length, (index) {
                          final activeIndex = currentRawPage % heroSlides.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            width: activeIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: activeIndex == index
                                  ? AppColors.auGold
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
