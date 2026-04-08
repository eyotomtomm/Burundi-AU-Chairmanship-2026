import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/image_gallery_viewer.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Map<String, dynamic> album;

  const AlbumDetailScreen({
    super.key,
    required this.album,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  List<String> _localPhotoPaths = [];
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.album['is_liked'] == true;
    _likeCount = widget.album['like_count'] ?? 0;
    _enableScreenProtection();
    _checkIfDownloaded();
    _recordView();
  }

  void _recordView() {
    final id = widget.album['id'];
    if (id != null) {
      ApiService().recordGalleryAlbumView(id.toString()).catchError((_) => <String, dynamic>{});
    }
  }

  Future<void> _toggleLike() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_to_like'))),
      );
      return;
    }
    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    setState(() {
      _isLiked = !wasLiked;
      _likeCount = prevCount + (wasLiked ? -1 : 1);
    });
    try {
      final result = await ApiService().toggleGalleryAlbumLike(widget.album['id'].toString());
      if (mounted) {
        setState(() {
          _isLiked = result['is_liked'] == true;
          _likeCount = result['like_count'] ?? _likeCount;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = wasLiked;
        _likeCount = prevCount;
      });
    }
  }

  /// Enable screenshot and screen recording prevention
  Future<void> _enableScreenProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      if (kDebugMode) debugPrint('Screen protection error: $e');
    }
  }

  /// Disable screen protection when leaving
  Future<void> _disableScreenProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      if (kDebugMode) debugPrint('Screen protection disable error: $e');
    }
  }

  /// Check if album is already downloaded
  Future<void> _checkIfDownloaded() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final albumDir = Directory('${directory.path}/albums/${widget.album['id']}');

      if (await albumDir.exists()) {
        final files = albumDir.listSync();
        if (files.isNotEmpty) {
          setState(() {
            _isDownloaded = true;
            _localPhotoPaths = files
                .whereType<File>()
                .map((f) => f.path)
                .toList();
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Check download error: $e');
    }
  }

  /// Download album for offline viewing
  Future<void> _downloadAlbum() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final albumDir = Directory('${directory.path}/albums/${widget.album['id']}');

      // Create album directory
      if (!await albumDir.exists()) {
        await albumDir.create(recursive: true);
      }

      // Get photos from album
      final photos = widget.album['photos'] as List? ?? [];
      final dio = Dio();
      final downloadedPaths = <String>[];

      for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final photoUrl = Environment.fixMediaUrl(photo['image'] ?? '');
        final fileName = 'photo_${photo['id']}.jpg';
        final filePath = '${albumDir.path}/$fileName';

        try {
          await dio.download(
            photoUrl,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                final photoProgress = received / total;
                final totalProgress = (i + photoProgress) / photos.length;
                setState(() {
                  _downloadProgress = totalProgress;
                });
              }
            },
          );
          downloadedPaths.add(filePath);
        } catch (e) {
          if (kDebugMode) debugPrint('Failed to download photo ${photo['id']}: $e');
        }
      }

      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
        _localPhotoPaths = downloadedPaths;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Album downloaded! Available offline.'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Delete downloaded album
  Future<void> _deleteDownload() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final albumDir = Directory('${directory.path}/albums/${widget.album['id']}');

      if (await albumDir.exists()) {
        await albumDir.delete(recursive: true);
      }

      setState(() {
        _isDownloaded = false;
        _localPhotoPaths = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloaded album deleted'),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Open fullscreen photo viewer with swipe support
  void _openPhotoViewer(int initialIndex) {
    final photos = widget.album['photos'] as List? ?? [];
    final langCode = Localizations.localeOf(context).languageCode;

    // Build image URLs: prefer local files if downloaded, otherwise network
    final imageUrls = <String>[];
    final captions = <String>[];

    for (final photo in photos) {
      // Use network URL - CachedNetworkImage handles caching automatically
      imageUrls.add(Environment.fixMediaUrl(photo['image'] ?? ''));

      // Get caption in current language
      final caption = langCode == 'fr'
          ? (photo['caption_fr'] ?? photo['caption'] ?? '')
          : (photo['caption'] ?? '');
      captions.add(caption?.toString() ?? '');
    }

    ImageGalleryViewer.show(
      context,
      images: imageUrls,
      initialIndex: initialIndex,
      captions: captions,
      heroTagPrefix: 'album_${widget.album['id']}',
    );
  }

  @override
  void dispose() {
    _disableScreenProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.album['photos'] as List? ?? [];
    final langCode = Localizations.localeOf(context).languageCode;
    final title = langCode == 'fr'
        ? (widget.album['title_fr'] ?? widget.album['title'])
        : widget.album['title'];

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Album'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        actions: [
          // Like button
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : Colors.white,
            ),
            tooltip: _isLiked ? 'Unlike' : 'Like',
            onPressed: _toggleLike,
          ),
          // Download button
          if (!_isDownloaded && !_isDownloading)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download for offline',
              onPressed: _downloadAlbum,
            ),
          // Downloaded indicator / delete button
          if (_isDownloaded)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_done, color: AppColors.auGold),
              tooltip: 'Downloaded',
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteDownload();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.error),
                    title: Text('Delete download'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          // Photo Grid
          GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return _buildPhotoTile(photo, index);
            },
          ),

          // Download progress overlay
          if (_isDownloading)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download, size: 48, color: AppColors.burundiGreen),
                      const SizedBox(height: 16),
                      const Text(
                        'Downloading album...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.burundiGreen),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Screenshot protection warning
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

  Widget _buildPhotoTile(Map<String, dynamic> photo, int index) {
    final photoId = photo['id'];
    final isLocalAvailable = _localPhotoPaths.any((p) => p.contains('photo_$photoId'));

    Widget imageWidget;
    if (isLocalAvailable && _isDownloaded) {
      final localPath = _localPhotoPaths.firstWhere((p) => p.contains('photo_$photoId'));
      imageWidget = Image.file(
        File(localPath),
        fit: BoxFit.cover,
      );
    } else {
      final imageUrl = Environment.fixMediaUrl(photo['image'] ?? '');
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _openPhotoViewer(index);
      },
      child: Hero(
        tag: 'album_${widget.album['id']}_$index',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
            if (isLocalAvailable)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.offline_pin, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Fullscreen photo viewer with swipe support (legacy, kept for reference)
class _PhotoViewerScreen extends StatefulWidget {
  final List photos;
  final int initialIndex;
  final bool isDownloaded;
  final List<String> localPhotoPaths;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
    required this.isDownloaded,
    required this.localPhotoPaths,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _enableScreenProtection();
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

  @override
  void dispose() {
    _disableScreenProtection();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Photo PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return GestureDetector(
                onTap: _toggleUI,
                child: _buildPhotoView(photo),
              );
            },
          ),

          // Top bar
          if (_showUI)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text(
                          '${_currentIndex + 1} / ${widget.photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom caption
          if (_showUI && widget.photos[_currentIndex]['caption'] != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.photos[_currentIndex]['caption'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoView(Map<String, dynamic> photo) {
    final photoId = photo['id'];
    final isLocalAvailable = widget.localPhotoPaths.any((p) => p.contains('photo_$photoId'));

    if (isLocalAvailable && widget.isDownloaded) {
      final localPath = widget.localPhotoPaths.firstWhere((p) => p.contains('photo_$photoId'));
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.file(
            File(localPath),
            fit: BoxFit.contain,
          ),
        ),
      );
    } else {
      final imageUrl = Environment.fixMediaUrl(photo['image'] ?? '');
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
