import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../widgets/login_gate.dart';
import '../../widgets/shimmer_loading.dart';
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
    final isAuth = context.watch<AuthProvider>().isAuthenticated;
    final langCode = Localizations.localeOf(context).languageCode;
    final fr = langCode == 'fr';

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Ds.bg(context),
        appBar: AppBar(title: Text(fr ? 'Vidéos' : 'Videos')),
        body: const ShimmerVideoGridSkeleton(),
      );
    }

    if (_allVideos.isEmpty) {
      return Scaffold(
        backgroundColor: Ds.bg(context),
        appBar: AppBar(title: Text(fr ? 'Vidéos' : 'Videos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_outlined, size: 56, color: Ds.muted(context)),
                const SizedBox(height: 16),
                Text(
                  fr ? 'Vidéos en préparation' : 'Videos being prepared',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Ds.ink(context)),
                ),
                const SizedBox(height: 8),
                Text(
                  fr
                      ? 'Les vidéos du sommet seront publiées ici prochainement.'
                      : 'Summit videos will be published here soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5, color: Ds.body(context)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // The comp leads with one hero video, then the filtered list.
    final featured = _allVideos.firstWhere(
      (v) => v['is_featured'] == true,
      orElse: () => _allVideos.first,
    );
    final listVideos =
        filteredVideos.where((v) => v['id'] != featured['id']).toList();

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: Text(fr ? 'Vidéos' : 'Videos')),
      body: RefreshIndicator(
        color: Ds.green,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _loadVideos();
        },
        child: CustomScrollView(
          key: const PageStorageKey<String>('videos_scroll'),
          slivers: [
            SliverToBoxAdapter(child: _buildFeaturedVideoCard(featured, fr)),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categoryLabels.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DsFilterChip(
                          entry.value,
                          selected: selectedCategory == entry.key,
                          onTap: () => setState(() => selectedCategory = entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            if (listVideos.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                  child: Column(
                    children: [
                      Icon(Icons.videocam_off_outlined,
                          size: 44, color: Ds.muted(context)),
                      const SizedBox(height: 12),
                      Text(
                        fr
                            ? 'Aucune vidéo dans cette catégorie'
                            : 'No videos in this category',
                        style: TextStyle(fontSize: 14, color: Ds.body(context)),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final slot = LoginGate.slotFor(
                        index: index,
                        actualCount: listVideos.length,
                        isAuthenticated: isAuth,
                      );
                      switch (slot) {
                        case LoginGateSlot.free:
                          return _buildVideoCard(listVideos[index]);
                        case LoginGateSlot.banner:
                          return const LoginGateBanner(
                              margin: EdgeInsets.only(bottom: 10));
                        case LoginGateSlot.blurred:
                          final dataIndex = LoginGate.dataIndexFor(
                              index, LoginGate.defaultFreeItems);
                          if (dataIndex == null || dataIndex >= listVideos.length) {
                            return const SizedBox.shrink();
                          }
                          return LockedContentWrap(
                            locked: true,
                            child: _buildVideoCard(listVideos[dataIndex]),
                          );
                        case LoginGateSlot.hidden:
                          return const SizedBox.shrink();
                      }
                    },
                    childCount: LoginGate.itemCountFor(
                      actualCount: listVideos.length,
                      isAuthenticated: isAuth,
                    ),
                  ),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(Map<String, dynamic> video, {BoxFit fit = BoxFit.cover}) {
    final url = (video['thumbnail_url'] as String?)?.isNotEmpty == true
        ? video['thumbnail_url'] as String
        : video['thumbnail'] as String?;
    if (url == null || url.isEmpty) return _videoThumbnailPlaceholder();
    return CachedNetworkImage(
      imageUrl: Environment.fixMediaUrl(url),
      fit: fit,
      placeholder: (context, url) => _videoThumbnailPlaceholder(),
      errorWidget: (context, url, error) => _videoThumbnailPlaceholder(),
    );
  }

  Widget _buildFeaturedVideoCard(Map<String, dynamic> video, bool fr) {
    final duration = (video['duration'] ?? '').toString();
    return DsCard(
      margin: const EdgeInsets.all(16),
      clip: true,
      onTap: () => _playVideo(video),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumbnail(video),
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 28, color: Ds.green),
                  ),
                ),
                if (duration.isNotEmpty)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(duration,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: Ds.ink(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${fr ? "À la une" : "Featured"} · ${_formatViewCount(video['view_count'])} ${fr ? "vues" : "views"}',
                  style: Ds.meta(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video) {
    final duration = (video['duration'] ?? '').toString();
    final category = categoryLabels[video['category']] ?? '';

    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: () => _playVideo(video),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Ds.rTile),
            child: SizedBox(
              width: 120,
              height: 70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumbnail(video),
                  const Center(
                    child: Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
                  ),
                  if (video['_is_live_recorded'] == true)
                    const Positioned(
                        left: 6, top: 6, child: DsPill('LIVE', tone: DsTone.red, dense: true)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: Ds.ink(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (duration.isNotEmpty) duration,
                    if (category.isNotEmpty) category,
                  ].join(' · '),
                  style: Ds.meta(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoThumbnailPlaceholder() =>
      const DsImagePlaceholder(radius: 0, dark: true, icon: Icons.play_circle_outline);

}
