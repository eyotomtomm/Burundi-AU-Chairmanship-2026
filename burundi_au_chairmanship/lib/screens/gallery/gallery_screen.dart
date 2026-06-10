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
import '../../services/api_service.dart';
import '../../widgets/login_gate.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/translate_button.dart';
import 'album_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Map<String, dynamic>> albums = [];
  bool _isLoading = true;

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
        setState(() {
          albums = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load gallery albums: $e');
      if (mounted) {
        setState(() {
          albums = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = context.watch<AuthProvider>().isAuthenticated;
    final featuredAlbums = albums.where((a) => a['is_featured'] == true).toList();

    if (_isLoading) {
      return const Scaffold(body: ShimmerVideoGridSkeleton());
    }

    if (albums.isEmpty) {
      return Scaffold(body: _buildEmptyState(context));
    }

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await _loadAlbums();
            },
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: AppColors.burundiGreen,
                  actions: const [TranslateButton()],
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Photo Gallery',
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
                            AppColors.burundiGreen,
                            AppColors.burundiGreen.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Featured Albums
                if (featuredAlbums.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Icon(Icons.star, color: AppColors.auGold, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Featured Albums',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final slot = LoginGate.slotFor(
                            index: index,
                            actualCount: featuredAlbums.length,
                            isAuthenticated: isAuth,
                          );
                          switch (slot) {
                            case LoginGateSlot.free:
                              return _buildFeaturedAlbumCard(featuredAlbums[index], isAuth);
                            case LoginGateSlot.banner:
                              return const LoginGateBanner(
                                margin: EdgeInsets.only(bottom: 16),
                              );
                            case LoginGateSlot.blurred:
                              final dataIndex = LoginGate.dataIndexFor(index, LoginGate.defaultFreeItems);
                              if (dataIndex == null || dataIndex >= featuredAlbums.length) {
                                return const SizedBox.shrink();
                              }
                              return LockedContentWrap(
                                locked: true,
                                child: _buildFeaturedAlbumCard(featuredAlbums[dataIndex], isAuth),
                              );
                            case LoginGateSlot.hidden:
                              return const SizedBox.shrink();
                          }
                        },
                        childCount: LoginGate.itemCountFor(
                          actualCount: featuredAlbums.length,
                          isAuthenticated: isAuth,
                        ),
                      ),
                    ),
                  ),
                ],

                // All Albums
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: const Text(
                      'All Albums',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final slot = LoginGate.slotFor(
                          index: index,
                          actualCount: albums.length,
                          isAuthenticated: isAuth,
                        );
                        switch (slot) {
                          case LoginGateSlot.free:
                            return _buildAlbumGridItem(albums[index], isAuth);
                          case LoginGateSlot.banner:
                            return const LoginGateBanner(
                              margin: EdgeInsets.only(bottom: 12),
                            );
                          case LoginGateSlot.blurred:
                            final dataIndex = LoginGate.dataIndexFor(index, LoginGate.defaultFreeItems);
                            if (dataIndex == null || dataIndex >= albums.length) {
                              return const SizedBox.shrink();
                            }
                            return LockedContentWrap(
                              locked: true,
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              child: _buildAlbumGridItem(albums[dataIndex], isAuth),
                            );
                          case LoginGateSlot.hidden:
                            return const SizedBox.shrink();
                        }
                      },
                      childCount: LoginGate.itemCountFor(
                        actualCount: albums.length,
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

  Widget _buildEmptyState(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          pinned: true,
          backgroundColor: AppColors.burundiGreen,
          actions: const [TranslateButton()],
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'Photo Gallery',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.burundiGreen,
                    AppColors.burundiGreen.withValues(alpha: 0.8),
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
                  Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    langCode == 'fr' ? 'Galerie en préparation' : 'Gallery being prepared',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    langCode == 'fr'
                        ? 'Les photos du sommet seront publiées ici prochainement.'
                        : 'Summit photos will be published here soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverImage(String? coverUrl, {double iconSize = 50}) {
    if (coverUrl != null && coverUrl.isNotEmpty) {
      final fixedUrl = Environment.fixMediaUrl(coverUrl);
      return CachedNetworkImage(
        imageUrl: fixedUrl,
        fit: BoxFit.cover,
        memCacheWidth: 600,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: Icon(Icons.photo_library, size: iconSize, color: Colors.grey),
        ),
      );
    }
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.photo_library, size: iconSize, color: Colors.grey),
    );
  }

  Widget _buildFeaturedAlbumCard(Map<String, dynamic> album, bool isAuth) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => AlbumDetailScreen(album: album),
                ),
              );
            },
            child: Stack(
              children: [
                // Cover Image
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildCoverImage(album['cover_image']),
                ),

                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.photo, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${album['photo_count'] ?? 0}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.visibility, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${album['view_count'] ?? 0}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.favorite, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${album['like_count'] ?? 0}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Featured Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.auGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Featured',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumGridItem(Map<String, dynamic> album, bool isAuth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => AlbumDetailScreen(album: album),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCoverImage(album['cover_image'], iconSize: 40),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.photo, color: Colors.white70, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${album['photo_count'] ?? 0}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.visibility, color: Colors.white70, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${album['view_count'] ?? 0}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.favorite, color: Colors.white70, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${album['like_count'] ?? 0}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
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
}
