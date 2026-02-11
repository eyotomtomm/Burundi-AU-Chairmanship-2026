import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../widgets/african_pattern.dart';
import 'video_player_screen.dart';

class LiveFeedsScreen extends StatefulWidget {
  const LiveFeedsScreen({super.key});

  @override
  State<LiveFeedsScreen> createState() => _LiveFeedsScreenState();
}

class _LiveFeedsScreenState extends State<LiveFeedsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ApiLiveFeed> _liveFeeds = [];
  List<ApiLiveFeed> _upcomingFeeds = [];
  List<ApiLiveFeed> _recordedFeeds = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.liveFeeds),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.auGold,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.burundiRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(l10n.translate('live')),
                ],
              ),
            ),
            Tab(text: l10n.translate('upcoming')),
            Tab(text: l10n.translate('recorded')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFeedsList(_liveFeeds, isLive: true),
                _buildFeedsList(_upcomingFeeds, isUpcoming: true),
                _buildFeedsList(_recordedFeeds, isRecorded: true),
              ],
            ),
    );
  }

  Widget _buildFeedsList(List<ApiLiveFeed> feeds, {
    bool isLive = false,
    bool isUpcoming = false,
    bool isRecorded = false,
  }) {
    final l10n = AppLocalizations.of(context);

    if (feeds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLive ? Icons.live_tv : Icons.video_library,
              size: 64,
              color: AppColors.burundiGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error != null ? 'Could not load feeds' : l10n.noData,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: () { setState(() => _isLoading = true); _loadData(); }, child: const Text('Retry')),
            ],
          ],
        ),
      );
    }

    return AfricanPatternBackground(
      opacity: 0.03,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: feeds.length,
        itemBuilder: (context, index) {
          return _buildFeedCard(feeds[index], isLive: isLive, isUpcoming: isUpcoming);
        },
      ),
    );
  }

  Widget _buildFeedCard(ApiLiveFeed feed, {bool isLive = false, bool isUpcoming = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;

    return GestureDetector(
      onTap: () => _openFeed(feed),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.burundiGreen.withValues(alpha: 0.2),
                    ),
                    child: feed.thumbnail.isNotEmpty
                        ? Image.network(
                            feed.thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 64,
                                color: AppColors.burundiGreen.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: AppColors.burundiGreen.withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                ),

                // Live badge
                if (isLive)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.burundiRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.translate('live'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Viewer count for live
                if (isLive && feed.viewerCount > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _formatViewerCount(feed.viewerCount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Duration for recorded
                if (feed.parsedDuration != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(feed.parsedDuration!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                // Play button overlay
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feed.getTitle(langCode),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feed.titleFr.isNotEmpty && langCode == 'fr' ? feed.titleFr : feed.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        isUpcoming ? Icons.schedule : Icons.access_time,
                        size: 16,
                        color: AppColors.burundiGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUpcoming && feed.scheduledTime != null
                            ? _formatUpcomingTime(feed.scheduledTime!)
                            : feed.scheduledTime != null
                                ? _formatDate(feed.scheduledTime!)
                                : '',
                        style: const TextStyle(
                          color: AppColors.burundiGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => _openFeed(feed),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLive ? AppColors.burundiRed : AppColors.burundiGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          isUpcoming
                              ? 'Set Reminder'
                              : l10n.translate('watch_now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatUpcomingTime(DateTime time) {
    final diff = time.difference(DateTime.now());
    if (diff.inHours > 0) {
      return 'Starts in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    return 'Starts in ${diff.inMinutes}m';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openFeed(ApiLiveFeed feed) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(feed: feed),
      ),
    );
  }
}
