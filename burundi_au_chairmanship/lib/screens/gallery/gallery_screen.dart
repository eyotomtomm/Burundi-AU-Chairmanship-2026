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
import '../../services/api_service.dart';
import '../../services/content_cache_service.dart';
import '../../widgets/login_gate.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/async_content_view.dart';
import 'album_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Map<String, dynamic>> albums = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _enableScreenProtection();
    _loadAlbums();
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

  Future<void> _loadAlbums() async {
    try {
      final data = await ApiService().getGalleryAlbums();
      if (mounted) {
        ContentCacheService().cacheMapList(ContentCacheService.keyGallery, data);
        setState(() {
          albums = data;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load gallery albums: $e');
      if (mounted) {
        // Fall back to cache
        final cached = ContentCacheService().getMapList(ContentCacheService.keyGallery);
        if (cached != null && cached.isNotEmpty) {
          setState(() {
            albums = cached;
            _isLoading = false;
            _hasError = false;
          });
          return;
        }
        setState(() {
          albums = [];
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = context.watch<AuthProvider>().isAuthenticated;
    final featured = albums.where((a) => a['is_featured'] == true).toList();
    final rest = albums.where((a) => a['is_featured'] != true).toList();

    if (_isLoading || _hasError || albums.isEmpty) {
      final AsyncContentState state;
      if (_isLoading) {
        state = AsyncContentState.loading;
      } else if (_hasError) {
        state = AsyncContentState.error;
      } else {
        state = AsyncContentState.empty;
      }
      return Scaffold(
        backgroundColor: Ds.bg(context),
        appBar: AppBar(title: const Text('Gallery')),
        body: AsyncContentView(
          state: state,
          loadingWidget: const ShimmerVideoGridSkeleton(),
          emptyIcon: Icons.photo_library_outlined,
          onRetry: () {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            _loadAlbums();
          },
          onRefresh: () async {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            await _loadAlbums();
          },
          child: const SizedBox.shrink(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: const Text('Gallery')),
      body: RefreshIndicator(
        color: Ds.green,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _loadAlbums();
        },
        child: CustomScrollView(
          key: const PageStorageKey<String>('gallery_scroll'),
          slivers: [
            // Featured album spans the full width, like the comp's mosaic hero.
            if (featured.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final slot = LoginGate.slotFor(
                        index: index,
                        actualCount: featured.length,
                        isAuthenticated: isAuth,
                      );
                      switch (slot) {
                        case LoginGateSlot.free:
                          return _buildFeaturedAlbumCard(featured[index], isAuth);
                        case LoginGateSlot.banner:
                          return const LoginGateBanner(
                              margin: EdgeInsets.only(bottom: 12));
                        case LoginGateSlot.blurred:
                          final dataIndex = LoginGate.dataIndexFor(
                              index, LoginGate.defaultFreeItems);
                          if (dataIndex == null || dataIndex >= featured.length) {
                            return const SizedBox.shrink();
                          }
                          return LockedContentWrap(
                            locked: true,
                            child: _buildFeaturedAlbumCard(featured[dataIndex], isAuth),
                          );
                        case LoginGateSlot.hidden:
                          return const SizedBox.shrink();
                      }
                    },
                    childCount: LoginGate.itemCountFor(
                      actualCount: featured.length,
                      isAuthenticated: isAuth,
                    ),
                  ),
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 130,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final slot = LoginGate.slotFor(
                      index: index,
                      actualCount: rest.length,
                      isAuthenticated: isAuth,
                    );
                    switch (slot) {
                      case LoginGateSlot.free:
                        return _buildAlbumGridItem(rest[index], isAuth);
                      case LoginGateSlot.banner:
                        return const LoginGateBanner();
                      case LoginGateSlot.blurred:
                        final dataIndex =
                            LoginGate.dataIndexFor(index, LoginGate.defaultFreeItems);
                        if (dataIndex == null || dataIndex >= rest.length) {
                          return const SizedBox.shrink();
                        }
                        return LockedContentWrap(
                          locked: true,
                          borderRadius: const BorderRadius.all(Radius.circular(14)),
                          child: _buildAlbumGridItem(rest[dataIndex], isAuth),
                        );
                      case LoginGateSlot.hidden:
                        return const SizedBox.shrink();
                    }
                  },
                  childCount: LoginGate.itemCountFor(
                    actualCount: rest.length,
                    isAuthenticated: isAuth,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dark caption chip the comp overlays on each tile.
  Widget _captionChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _buildCoverImage(String? coverUrl, {double iconSize = 50}) {
    if (coverUrl != null && coverUrl.isNotEmpty) {
      final fixedUrl = Environment.fixMediaUrl(coverUrl);
      return CachedNetworkImage(
        imageUrl: fixedUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const DsImagePlaceholder(radius: 0, icon: Icons.photo_library_rounded),
        errorWidget: (context, url, error) =>
            const DsImagePlaceholder(radius: 0, icon: Icons.photo_library_rounded),
      );
    }
    return const DsImagePlaceholder(radius: 0, icon: Icons.photo_library_rounded);
  }

  Widget _buildFeaturedAlbumCard(Map<String, dynamic> album, bool isAuth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Ds.rCard),
        child: Material(
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) =>
                    AlbumDetailScreen(album: album, scrollToComments: false),
              ),
            ),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCoverImage(album['cover_image']),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _captionChip(
                          '${album['title'] ?? ''} · ${album['photo_count'] ?? 0} photos'),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: DsPill('FEATURED', tone: DsTone.white, dense: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumGridItem(Map<String, dynamic> album, bool isAuth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => AlbumDetailScreen(album: album)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCoverImage(album['cover_image'], iconSize: 40),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _captionChip(
                      '${album['title'] ?? ''} · ${album['photo_count'] ?? 0}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
