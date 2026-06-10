import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/magazine_model.dart';
import '../../services/like_service.dart';
import '../../widgets/verified_badge.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String? magazineId;
  final bool initialIsLiked;
  final int initialLikeCount;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.magazineId,
    this.initialIsLiked = false,
    this.initialLikeCount = 0,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  double _currentZoom = 1.0;

  // Download management (permanent offline save)
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localFilePath;

  // Temp-cache management (fast re-open)
  bool _isCaching = false;
  double _cacheProgress = 0.0;
  String? _cachedFilePath;
  String? _cacheError;

  // Floating overlay
  bool _showOverlay = false;
  Timer? _overlayTimer;
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;
  List<ArticleComment> _comments = [];
  bool _commentsLoading = false;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    if (widget.magazineId != null) {
      _likeService.seed(
        EntityType.magazine, widget.magazineId!,
        isLiked: widget.initialIsLiked,
        likeCount: widget.initialLikeCount,
      );
      _removeLikeListener = _likeService.addListener((key, state) {
        if (key == 'magazine:${widget.magazineId}' && mounted) setState(() {});
      });
    }
    _enableScreenProtection();
    _loadPdf();
    _recordView();
  }

  /// Load PDF: check permanent download first, then temp cache, then download to cache.
  Future<void> _loadPdf() async {
    // 1. Check if permanently downloaded
    if (widget.magazineId != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/magazines/${widget.magazineId}.pdf';
        final file = File(filePath);
        if (await file.exists()) {
          setState(() {
            _isDownloaded = true;
            _localFilePath = filePath;
            _cachedFilePath = filePath;
          });
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Check download error: $e');
      }
    }

    // 2. Check if temp-cached version exists
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheKey = widget.magazineId ?? widget.pdfUrl.hashCode.toString();
      final cachePath = '${tempDir.path}/pdf_cache/$cacheKey.pdf';
      final cacheFile = File(cachePath);
      if (await cacheFile.exists()) {
        setState(() {
          _cachedFilePath = cachePath;
        });
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Check cache error: $e');
    }

    // 3. Download to temp cache with progress
    setState(() {
      _isCaching = true;
      _cacheProgress = 0.0;
      _cacheError = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/pdf_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheKey = widget.magazineId ?? widget.pdfUrl.hashCode.toString();
      final cachePath = '${cacheDir.path}/$cacheKey.pdf';
      final url = Environment.fixMediaUrl(widget.pdfUrl);

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Accept-Encoding': 'gzip'},
      ));
      await dio.download(
        url,
        cachePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _cacheProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _cachedFilePath = cachePath;
          _isCaching = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PDF cache download error: $e');
      if (mounted) {
        setState(() {
          _isCaching = false;
          _cacheError = 'Failed to load PDF. Please check your connection.';
        });
      }
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

  /// Disable screen protection when leaving the screen
  Future<void> _disableScreenProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      if (kDebugMode) debugPrint('Screen protection disable error: $e');
    }
  }

  /// Download magazine for offline viewing (permanent)
  Future<void> _downloadMagazine() async {
    if (widget.magazineId == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final magazinesDir = Directory('${directory.path}/magazines');

      if (!await magazinesDir.exists()) {
        await magazinesDir.create(recursive: true);
      }

      final filePath = '${magazinesDir.path}/${widget.magazineId}.pdf';

      // If we already have a cached copy, just copy it
      if (_cachedFilePath != null) {
        final cachedFile = File(_cachedFilePath!);
        if (await cachedFile.exists()) {
          await cachedFile.copy(filePath);
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
            _localFilePath = filePath;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Magazine downloaded! Available offline.'),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      // Otherwise download fresh
      final url = Environment.fixMediaUrl(widget.pdfUrl);
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Accept-Encoding': 'gzip'},
      ));
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
        _localFilePath = filePath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Magazine downloaded! Available offline.'),
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

  /// Delete downloaded magazine
  Future<void> _deleteDownload() async {
    if (_localFilePath == null) return;

    try {
      final file = File(_localFilePath!);
      if (await file.exists()) {
        await file.delete();
      }

      setState(() {
        _isDownloaded = false;
        _localFilePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloaded magazine deleted'),
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

  Future<void> _recordView() async {
    if (widget.magazineId != null) {
      try {
        await ApiService().recordMagazineView(widget.magazineId!);
      } catch (_) {}
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 0.25).clamp(0.5, 4.0);
      _pdfViewerController.zoomLevel = _currentZoom;
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 0.25).clamp(0.5, 4.0);
      _pdfViewerController.zoomLevel = _currentZoom;
    });
  }

  void _resetZoom() {
    setState(() {
      _currentZoom = 1.0;
      _pdfViewerController.zoomLevel = 1.0;
    });
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    _pdfViewerController.dispose();
    _overlayTimer?.cancel();
    _disableScreenProtection();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) {
      _startAutoHideTimer();
    } else {
      _overlayTimer?.cancel();
    }
  }

  void _startAutoHideTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _toggleLike() {
    if (widget.magazineId == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to like this magazine')),
      );
      return;
    }
    _likeService.toggle(EntityType.magazine, widget.magazineId!);
    _startAutoHideTimer();
  }

  Future<void> _loadComments() async {
    if (widget.magazineId == null) return;
    setState(() => _commentsLoading = true);
    try {
      final comments = await ApiService().getMagazineComments(widget.magazineId!);
      if (mounted) setState(() { _comments = comments; _commentsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _postComment(String content, {int? parentId}) async {
    if (widget.magazineId == null) return;
    try {
      await ApiService().postMagazineComment(widget.magazineId!, content, parentId: parentId);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCommentSheet() {
    _overlayTimer?.cancel();
    _loadComments();
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.comment_outlined, size: 20, color: AppColors.burundiGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Comments (${_comments.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Comments list
                  Expanded(
                    child: _commentsLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen))
                        : _comments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                                    const SizedBox(height: 12),
                                    Text('No comments yet', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text('Be the first to share your thoughts!', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _comments.length,
                                itemBuilder: (_, i) => _buildCommentTile(_comments[i]),
                              ),
                  ),
                  // Comment input
                  if (Provider.of<AuthProvider>(context, listen: false).isAuthenticated)
                    Container(
                      padding: EdgeInsets.only(
                        left: 16, right: 8, top: 8,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              maxLines: 3,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppColors.burundiGreen),
                            onPressed: () async {
                              final text = commentController.text.trim();
                              if (text.isEmpty) return;
                              commentController.clear();
                              await _postComment(text);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ).then((_) => _startAutoHideTimer());
  }

  Widget _buildCommentTile(ArticleComment comment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.1),
            backgroundImage: comment.profilePicture != null
                ? CachedNetworkImageProvider(comment.profilePicture!)
                : null,
            child: comment.profilePicture == null
                ? Text(
                    comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.burundiGreen, fontWeight: FontWeight.bold, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                    if (comment.badgeType != null) ...[
                      const SizedBox(width: 4),
                      VerifiedBadge(badgeType: comment.badgeType!, size: 14),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                // Replies
                if (comment.replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: comment.replies.map((r) => _buildCommentTile(r)).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final likeState = widget.magazineId != null
        ? _likeService.getState(EntityType.magazine, widget.magazineId!)
        : const LikeState();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages  •  ${(_currentZoom * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        actions: [
          // Download button
          if (!_isDownloaded && !_isDownloading && widget.magazineId != null)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download for offline',
              onPressed: _downloadMagazine,
            ),
          // Downloaded indicator / delete button
          if (_isDownloaded && widget.magazineId != null)
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
          // Zoom out
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 22),
            tooltip: 'Zoom Out',
            onPressed: _currentZoom > 0.5 ? _zoomOut : null,
          ),
          // Zoom percentage / reset
          GestureDetector(
            onTap: _resetZoom,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(_currentZoom * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          // Zoom in
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 22),
            tooltip: 'Zoom In',
            onPressed: _currentZoom < 4.0 ? _zoomIn : null,
          ),
          // Bookmark
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {
              _pdfViewerKey.currentState?.openBookmarkView();
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _toggleOverlay,
        child: Stack(
        children: [
          // PDF Viewer - only show when we have a cached/downloaded file
          if (_cachedFilePath != null)
            SfPdfViewer.file(
              File(_cachedFilePath!),
              key: _pdfViewerKey,
              controller: _pdfViewerController,
              pageLayoutMode: PdfPageLayoutMode.single,
              scrollDirection: PdfScrollDirection.horizontal,
              canShowScrollHead: true,
              canShowPaginationDialog: true,
              onDocumentLoaded: (details) {
                setState(() {
                  _totalPages = details.document.pages.count;
                  _isLoading = false;
                });
              },
              onDocumentLoadFailed: (details) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to load PDF: ${details.description}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              onPageChanged: (details) {
                final newPage = details.newPageNumber - 1;
                setState(() {
                  _currentPage = newPage;
                  _showOverlay = false;
                });
                _overlayTimer?.cancel();
              },
              onZoomLevelChanged: (details) {
                setState(() {
                  _currentZoom = details.newZoomLevel;
                });
              },
            ),

          // Caching progress indicator
          if (_isCaching)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(horizontal: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 48, color: AppColors.burundiGreen),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading PDF...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: _cacheProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.burundiGreen),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_cacheProgress * 100).toInt()}%',
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // Cache error with retry
          if (_cacheError != null && !_isCaching)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(horizontal: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      _cacheError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _cacheError = null;
                        });
                        _loadPdf();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burundiGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator for SfPdfViewer document parsing
          if (_isLoading && _cachedFilePath != null && !_isCaching)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.burundiGreen),
                  SizedBox(height: 16),
                  Text('Rendering PDF...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          // Download progress overlay (permanent save)
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
                        'Saving for offline...',
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

          // Floating like/comment overlay
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _showOverlay ? 24 : -80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            likeState.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: likeState.isLiked ? Colors.red : Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${likeState.likeCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1, height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    // Comment button
                    GestureDetector(
                      onTap: _showCommentSheet,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.comment_outlined, color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            _comments.isEmpty ? 'Comment' : '${_comments.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1, height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    // Page indicator
                    Icon(Icons.security, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Protected',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                    ),
                  ],
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
