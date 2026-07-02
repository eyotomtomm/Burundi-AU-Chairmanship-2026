import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../widgets/login_gate.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/translate_button.dart';
import 'video_detail_screen.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  String selectedCategory = 'all';
  List<Map<String, dynamic>> _allVideos = [];
  bool _isLoading = true;

  final Map<String, String> categoryLabels = {
    'all': 'All Videos',
    'live_recorded': 'Live Recorded',
    'highlight': 'Highlights',
    'speech': 'Speeches',
    'documentary': 'Documentaries',
    'interview': 'Interviews',
    'event': 'Events',
    'cultural': 'Cultural',
  };

  @override
  void initState() {
    super.initState();
    _enableScreenProtection();
    _loadVideos();
  }

  @override
  void dispose() {
    _disableScreenProtection();
    super.dispose();
  }

  Future<void> _enableScreenProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      if (kDebugMode) debugPrint('Screen protection error: $e');
    }
  }

  Future<void> _disableScreenProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      if (kDebugMode) debugPrint('Screen protection disable error: $e');
    }
  }

  Future<void> _loadVideos() async {
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getVideos(),
        api.getLiveFeeds(status: 'recorded'),
      ]);

      final videos = results[0] as List<Map<String, dynamic>>;
      final recordedFeeds = results[1] as List<ApiLiveFeed>;

      // Convert recorded live feeds to video format
      final liveRecordedVideos = recordedFeeds.map((feed) => <String, dynamic>{
        'id': feed.id,
        'title': feed.title,
        'title_fr': feed.titleFr,
        'description': feed.description,
        'description_fr': feed.descriptionFr,
        'video_url': feed.streamUrl,
        'thumbnail': feed.thumbnail,
        'category': 'live_recorded',
        'duration': feed.duration,
        'view_count': feed.viewerCount,
        'like_count': 0,
        'is_featured': false,
        '_is_live_recorded': true,
      }).toList();

      if (mounted) {
        setState(() {
          _allVideos = [...videos, ...liveRecordedVideos];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load videos: $e');
      if (mounted) {
        setState(() {
          _allVideos = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get filteredVideos {
    if (selectedCategory == 'all') return _allVideos;
    return _allVideos.where((v) => v['category'] == selectedCategory).toList();
  }

  String _formatViewCount(dynamic count) {
    if (count == null) return '0';
    final n = count is int ? count : int.tryParse(count.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _playVideo(Map<String, dynamic> video) {
    // Record view
    final id = video['id'];
    if (id != null) {
      ApiService().recordVideoView(id.toString()).catchError((_) => <String, dynamic>{});
    }

    // Navigate to video detail screen
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => VideoDetailScreen(
          video: video,
          scrollToComments: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuth = context.watch<AuthProvider>().isAuthenticated;
    final langCode = Localizations.localeOf(context).languageCode;

    if (_isLoading) {
      return const Scaffold(body: ShimmerVideoGridSkeleton());
    }

    if (_allVideos.isEmpty) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: AppColors.burundiRed,
              actions: const [TranslateButton()],
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Videos',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.burundiRed,
                        AppColors.burundiRed.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        langCode == 'fr' ? 'Vidéos en préparation' : 'Videos being prepared',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        langCode == 'fr'
                            ? 'Les vidéos du sommet seront publiées ici prochainement.'
                            : 'Summit videos will be published here soon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await _loadVideos();
            },
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: AppColors.burundiRed,
                  actions: const [TranslateButton()],
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Videos',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.burundiRed,
                            AppColors.burundiRed.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Category Filter
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categoryLabels.entries.map((entry) {
                          final isSelected = selectedCategory == entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(entry.value),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  selectedCategory = entry.key;
                                });
                              },
                              selectedColor: AppColors.burundiRed,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Empty filtered state
                if (filteredVideos.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off_outlined, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              langCode == 'fr'
                                  ? 'Aucune vidéo dans cette catégorie'
                                  : 'No videos in this category',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Video List
                if (filteredVideos.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final slot = LoginGate.slotFor(
                            index: index,
                            actualCount: filteredVideos.length,
                            isAuthenticated: isAuth,
                          );
                          switch (slot) {
                            case LoginGateSlot.free:
                              return _buildVideoCard(filteredVideos[index], isDark);
                            case LoginGateSlot.banner:
                              return const LoginGateBanner(
                                margin: EdgeInsets.only(bottom: 16),
                              );
                            case LoginGateSlot.blurred:
                              final dataIndex = LoginGate.dataIndexFor(index, LoginGate.defaultFreeItems);
                              if (dataIndex == null || dataIndex >= filteredVideos.length) {
                                return const SizedBox.shrink();
                              }
                              return LockedContentWrap(
                                locked: true,
                                child: _buildVideoCard(filteredVideos[dataIndex], isDark),
                              );
                            case LoginGateSlot.hidden:
                              return const SizedBox.shrink();
                          }
                        },
                        childCount: LoginGate.itemCountFor(
                          actualCount: filteredVideos.length,
                          isAuthenticated: isAuth,
                        ),
                      ),
                    ),
                  ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
              ],
            ),
          ),
          // Protected content badge
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Text(
                    'Protected content',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video, bool isDark) {
    final thumbnailUrl = video['thumbnail'] as String?;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white54 : Colors.grey[600]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _playVideo(video),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: Environment.fixMediaUrl(thumbnailUrl),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _videoThumbnailPlaceholder(),
                            errorWidget: (context, url, error) => _videoThumbnailPlaceholder(),
                          )
                        : _videoThumbnailPlaceholder(),
                  ),
                ),

                // Play Button Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Duration Badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      video['duration'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Live Recorded Badge
                if (video['_is_live_recorded'] == true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sensors, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Live Recorded',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Featured Badge
                if (video['is_featured'] == true && video['_is_live_recorded'] != true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.auGold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Featured',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye, size: 14, color: subtextColor),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatViewCount(video['view_count'])} views',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtextColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.favorite, size: 14, color: subtextColor),
                      const SizedBox(width: 4),
                      Text(
                        _formatViewCount(video['like_count']),
                        style: TextStyle(fontSize: 12, color: subtextColor),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(video['category'] ?? '').withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          categoryLabels[video['category']] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getCategoryColor(video['category'] ?? ''),
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _videoThumbnailPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_outline, size: 60, color: Colors.white38),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'live_recorded':
        return const Color(0xFFE53935);
      case 'highlight':
        return AppColors.burundiGreen;
      case 'speech':
        return AppColors.auGold;
      case 'documentary':
        return AppColors.info;
      case 'interview':
        return AppColors.burundiRed;
      case 'event':
        return Colors.purple;
      case 'cultural':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
