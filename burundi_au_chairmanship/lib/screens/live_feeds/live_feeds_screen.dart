import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/translate_button.dart';
import 'video_player_screen.dart';
import 'youtube_player_screen.dart';
import 'in_app_webview_screen.dart';

class LiveFeedsScreen extends StatefulWidget {
  const LiveFeedsScreen({super.key});

  @override
  State<LiveFeedsScreen> createState() => _LiveFeedsScreenState();
}

class _LiveFeedsScreenState extends State<LiveFeedsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<ApiLiveFeed> _liveFeeds = [];
  List<ApiLiveFeed> _upcomingFeeds = [];
  List<ApiLiveFeed> _recordedFeeds = [];
  bool _isLoading = true;
  String? _error;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);

    // Pulsing animation for live indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData();

    // Update countdown every minute
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getLiveFeeds(status: 'live'),
        api.getLiveFeeds(status: 'upcoming'),
        api.getLiveFeeds(status: 'recorded'),
      ]);
      if (!mounted) return;
      setState(() {
        _liveFeeds = results[0];
        _upcomingFeeds = results[1];
        _recordedFeeds = results[2];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Rebuild when app returns from background (e.g., after calendar app closes)
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          // Force rebuild to ensure UI is properly restored
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: _isLoading
          ? const ShimmerLiveFeedsSkeleton()
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _loadData();
              },
              color: AppColors.burundiGreen,
              child: CustomScrollView(
              slivers: [
                // Hero App Bar
                _buildHeroAppBar(isDark, l10n),

                // Live Now featured section
                if (_liveFeeds.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.sensors,
                    title: l10n.translate('live'),
                    subtitle: '${_liveFeeds.length} stream${_liveFeeds.length > 1 ? 's' : ''} active',
                    color: AppColors.burundiRed,
                    isDark: isDark,
                    isLive: true,
                  ),
                  SliverToBoxAdapter(
                    child: _buildFeaturedLiveCard(_liveFeeds.first, isDark, l10n),
                  ),
                  if (_liveFeeds.length > 1)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _liveFeeds.length - 1,
                          itemBuilder: (context, index) =>
                              _buildSmallLiveCard(_liveFeeds[index + 1], isDark, l10n),
                        ),
                      ),
                    ),
                ],

                // Upcoming section
                if (_upcomingFeeds.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.upcoming,
                    title: l10n.translate('upcoming'),
                    subtitle: '${_upcomingFeeds.length} scheduled',
                    color: AppColors.auGold,
                    isDark: isDark,
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildUpcomingCard(
                          _upcomingFeeds[index], isDark, l10n),
                      childCount: _upcomingFeeds.length,
                    ),
                  ),
                ],

                // Recorded section
                if (_recordedFeeds.isNotEmpty) ...[
                  _buildSectionHeader(
                    icon: Icons.video_library_rounded,
                    title: l10n.translate('recorded'),
                    subtitle: '${_recordedFeeds.length} video${_recordedFeeds.length > 1 ? 's' : ''}',
                    color: AppColors.burundiGreen,
                    isDark: isDark,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildRecordedCard(
                            _recordedFeeds[index], isDark, l10n),
                        childCount: _recordedFeeds.length,
                      ),
                    ),
                  ),
                ],

                // Empty state
                if (_liveFeeds.isEmpty &&
                    _upcomingFeeds.isEmpty &&
                    _recordedFeeds.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState(isDark, l10n)),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
            ),
    );
  }

  // ── Hero App Bar ──────────────────────────────────────────────────────

  Widget _buildHeroAppBar(bool isDark, AppLocalizations l10n) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.burundiGreen,
      foregroundColor: Colors.white,
      actions: const [TranslateButton()],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          l10n.liveFeeds,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A5C2A),
                AppColors.burundiGreen,
                Color(0xFF2ECC71),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Center icon
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.live_tv_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'AU Summit 2026',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────

  SliverToBoxAdapter _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    bool isLive = false,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isLive
                  ? AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Icon(
                        icon,
                        size: 20,
                        color: color.withValues(alpha: _pulseAnimation.value),
                      ),
                    )
                  : Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: 8),
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) => Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.burundiRed
                                  .withValues(alpha: _pulseAnimation.value),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.burundiRed
                                      .withValues(alpha: _pulseAnimation.value * 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
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

  // ── Featured Live Card (large, prominent) ─────────────────────────────

  Widget _buildFeaturedLiveCard(
      ApiLiveFeed feed, bool isDark, AppLocalizations l10n) {
    final langCode = Localizations.localeOf(context).languageCode;

    return GestureDetector(
      onTap: () => _openFeed(feed),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.burundiRed.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Thumbnail / background
              SizedBox(
                height: 220,
                width: double.infinity,
                child: feed.thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: feed.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B1A1A), Color(0xFFCE1126)],
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF8B1A1A), Color(0xFFCE1126)],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.live_tv, size: 56, color: Colors.white38),
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF8B1A1A), Color(0xFFCE1126)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.live_tv, size: 56, color: Colors.white38),
                        ),
                      ),
              ),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // LIVE badge (top-left)
              Positioned(
                top: 12,
                left: 12,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.burundiRed,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.burundiRed
                              .withValues(alpha: _pulseAnimation.value * 0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                                alpha: _pulseAnimation.value),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.translate('live').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Viewer count (top-right)
              if (feed.viewerCount > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_outlined,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _formatViewerCount(feed.viewerCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Platform badge (below LIVE badge) for external platforms
              if (feed.isExternalPlatform)
                Positioned(
                  top: 48,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPlatformColor(feed.streamType),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getPlatformIcon(feed.streamType),
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          feed.platformName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Play/Join button
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: feed.isExternalPlatform
                          ? _getPlatformColor(feed.streamType).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Icon(
                      feed.isExternalPlatform ? Icons.open_in_new_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),

              // Bottom content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feed.getTitle(langCode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.burundiRed.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              l10n.translate('watch_now').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (feed.viewerCount > 0) ...[
                            const SizedBox(width: 10),
                            Text(
                              '${_formatViewerCount(feed.viewerCount)} watching',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small live cards (horizontal scroll) ──────────────────────────────

  Widget _buildSmallLiveCard(
      ApiLiveFeed feed, bool isDark, AppLocalizations l10n) {
    final langCode = Localizations.localeOf(context).languageCode;

    return GestureDetector(
      onTap: () => _openFeed(feed),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              feed.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: feed.thumbnail,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.burundiRed.withValues(alpha: 0.3)),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.burundiRed.withValues(alpha: 0.3),
                        child: const Icon(Icons.live_tv,
                            color: Colors.white38, size: 32),
                      ),
                    )
                  : Container(
                      color: AppColors.burundiRed.withValues(alpha: 0.3),
                      child: const Icon(Icons.live_tv,
                          color: Colors.white38, size: 32),
                    ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),

              // LIVE dot
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.burundiRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

              // Play icon
              Center(
                child: Icon(Icons.play_circle_filled,
                    color: Colors.white.withValues(alpha: 0.8), size: 36),
              ),

              // Title
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  feed.getTitle(langCode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Upcoming Card ─────────────────────────────────────────────────────

  Widget _buildUpcomingCard(
      ApiLiveFeed feed, bool isDark, AppLocalizations l10n) {
    final langCode = Localizations.localeOf(context).languageCode;
    final countdown = feed.scheduledTime != null
        ? _getCountdown(feed.scheduledTime!)
        : null;

    return GestureDetector(
      onTap: () => _openFeed(feed),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.auGold.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    feed.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: feed.thumbnail,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: AppColors.auGold.withValues(alpha: 0.15),
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.auGold.withValues(alpha: 0.15),
                              child: const Icon(Icons.upcoming,
                                  color: AppColors.auGold, size: 28),
                            ),
                          )
                        : Container(
                            color: AppColors.auGold.withValues(alpha: 0.15),
                            child: const Icon(Icons.upcoming,
                                color: AppColors.auGold, size: 28),
                          ),
                    // Schedule overlay
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: Center(
                        child: Icon(
                          feed.isExternalPlatform
                              ? _getPlatformIcon(feed.streamType)
                              : Icons.schedule,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    // Platform badge on thumbnail
                    if (feed.isExternalPlatform)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPlatformColor(feed.streamType),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            feed.platformName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feed.getTitle(langCode),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (countdown != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.auGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 13, color: AppColors.auGold),
                          const SizedBox(width: 4),
                          Text(
                            countdown,
                            style: const TextStyle(
                              color: AppColors.auGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (feed.scheduledTime != null)
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 13,
                            color:
                                isDark ? Colors.white54 : Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(feed.scheduledTime!),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _addToCalendar(feed),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.auGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.auGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              size: 14, color: AppColors.auGold),
                          const SizedBox(width: 4),
                          Text(
                            'Set Reminder',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.auGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  // ── Recorded Card (grid item) ─────────────────────────────────────────

  Widget _buildRecordedCard(
      ApiLiveFeed feed, bool isDark, AppLocalizations l10n) {
    final langCode = Localizations.localeOf(context).languageCode;

    return GestureDetector(
      onTap: () => _openFeed(feed),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    feed.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: feed.thumbnail,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: AppColors.burundiGreen
                                  .withValues(alpha: 0.1),
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.burundiGreen
                                  .withValues(alpha: 0.1),
                              child: const Icon(Icons.videocam_rounded,
                                  color: AppColors.burundiGreen, size: 32),
                            ),
                          )
                        : Container(
                            color:
                                AppColors.burundiGreen.withValues(alpha: 0.1),
                            child: const Icon(Icons.videocam_rounded,
                                color: AppColors.burundiGreen, size: 32),
                          ),

                    // Dark overlay for play
                    Container(
                      color: Colors.black.withValues(alpha: 0.15),
                    ),

                    // Play icon center
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),

                    // Platform badge (top-left) for external platforms
                    if (feed.isExternalPlatform)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getPlatformColor(feed.streamType),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getPlatformIcon(feed.streamType),
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                feed.platformName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Duration badge
                    if (feed.parsedDuration != null)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(feed.parsedDuration!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Title + meta
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feed.getTitle(langCode),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF1A1A2E),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 12,
                            color:
                                isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 3),
                        Text(
                          _formatViewerCount(feed.viewerCount),
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        if (feed.scheduledTime != null) ...[
                          const Spacer(),
                          Text(
                            _formatShortDate(feed.scheduledTime!),
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.burundiGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.live_tv_rounded,
                size: 56,
                color: AppColors.burundiGreen.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _error != null ? 'Could not load feeds' : 'No Streams Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error != null
                  ? 'Please check your connection and try again.'
                  : 'Check back later for live coverage\nof AU Summit events.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadData();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _formatViewerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String? _getCountdown(DateTime time) {
    final diff = time.difference(DateTime.now());
    if (diff.isNegative) return null;

    if (diff.inDays > 0) {
      return 'In ${diff.inDays}d ${diff.inHours.remainder(24)}h';
    } else if (diff.inHours > 0) {
      return 'In ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    } else {
      return 'In ${diff.inMinutes}m';
    }
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _formatShortDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _openFeed(ApiLiveFeed feed) {
    if (feed.streamUrl.isEmpty) return;

    if (feed.isYouTube) {
      // YouTube → embedded YouTube player
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => YouTubePlayerScreen(feed: feed),
        ),
      );
    } else if (feed.isZoom || feed.isTeams || feed.isWebex || feed.isGoogleMeet) {
      // Meeting platforms → show credentials if available, then in-app WebView
      if (feed.meetingId.isNotEmpty || feed.passcode.isNotEmpty) {
        _showMeetingCredentials(feed);
      } else {
        _openInWebView(feed);
      }
    } else if (feed.streamType == 'external') {
      // Generic external links → in-app WebView
      _openInWebView(feed);
    } else {
      // Direct video streams (MP4/HLS) → chewie player
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => VideoPlayerScreen(feed: feed),
        ),
      );
    }
  }

  void _openInWebView(ApiLiveFeed feed) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => InAppWebViewScreen(feed: feed),
      ),
    );
  }

  void _showMeetingCredentials(ApiLiveFeed feed) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getPlatformIcon(feed.streamType),
                    color: _getPlatformColor(feed.streamType),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Join on ${feed.platformName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (feed.meetingId.isNotEmpty) ...[
                _buildCredentialRow(
                  'Meeting ID',
                  feed.meetingId,
                  Icons.tag,
                  isDark,
                ),
                const SizedBox(height: 8),
              ],
              if (feed.passcode.isNotEmpty) ...[
                _buildCredentialRow(
                  'Passcode',
                  feed.passcode,
                  Icons.lock_outline,
                  isDark,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openInWebView(feed);
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: Text('Join ${feed.platformName}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getPlatformColor(feed.streamType),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCredentialRow(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }

  /// Add event to device calendar (iOS Calendar, Google Calendar, Outlook, etc.)
  Future<void> _addToCalendar(ApiLiveFeed feed) async {
    if (feed.scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No scheduled time available for this event'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final langCode = Localizations.localeOf(context).languageCode;
      final startTime = feed.scheduledTime!;
      final endTime = startTime.add(const Duration(hours: 2)); // Default 2-hour event

      final event = Event(
        title: feed.getTitle(langCode),
        description: feed.getDescription(langCode).isNotEmpty
            ? feed.getDescription(langCode)
            : 'Burundi AU Chairmanship Live Event',
        location: 'Burundi AU Chairmanship App - Live Feeds',
        startDate: startTime,
        endDate: endTime,
        allDay: false,
        iosParams: const IOSParams(
          reminder: Duration(minutes: 30), // Remind 30 minutes before
          url: 'https://burundi.gov.bi', // Optional: Add app deep link
        ),
        androidParams: const AndroidParams(
          emailInvites: [], // Optional: Add email invites
        ),
      );

      final result = await Add2Calendar.addEvent2Cal(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result
                        ? 'Reminder added to your calendar!'
                        : 'Please check your calendar app to complete',
                  ),
                ),
              ],
            ),
            backgroundColor: result ? AppColors.success : AppColors.info,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reminder: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Open YouTube video or recorded stream
  IconData _getPlatformIcon(String streamType) {
    switch (streamType) {
      case 'zoom': return Icons.videocam;
      case 'teams': return Icons.groups;
      case 'webex': return Icons.video_call;
      case 'meet': return Icons.video_camera_front;
      case 'youtube': return Icons.play_arrow;
      default: return Icons.open_in_new;
    }
  }

  Color _getPlatformColor(String streamType) {
    switch (streamType) {
      case 'zoom': return const Color(0xFF2D8CFF);
      case 'teams': return const Color(0xFF6264A7);
      case 'webex': return const Color(0xFF00BCF2);
      case 'meet': return const Color(0xFF00897B);
      case 'youtube': return const Color(0xFFFF0000);
      default: return AppColors.burundiGreen;
    }
  }

}
