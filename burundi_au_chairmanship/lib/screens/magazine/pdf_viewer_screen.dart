import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../services/api_service.dart';
import 'painters/page_curl_painter.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String? magazineId;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.magazineId,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> with TickerProviderStateMixin {
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

  // Page curl animation
  late AnimationController _curlController;
  bool _curlForward = true;

  // Shimmer animation
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _curlController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
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
    _pdfViewerController.dispose();
    _curlController.dispose();
    _shimmerController.dispose();
    _disableScreenProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
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
                _curlForward = newPage > _currentPage;
                setState(() {
                  _currentPage = newPage;
                });
                // Trigger page curl animation
                _curlController.forward(from: 0.0).then((_) {
                  if (mounted) _curlController.reverse();
                });
                // Trigger shimmer on page load
                _shimmerController.forward(from: 0.0);
              },
              onZoomLevelChanged: (details) {
                setState(() {
                  _currentZoom = details.newZoomLevel;
                });
              },
            ),

          // Glossy surface gradient overlay (subtle shimmer)
          if (_cachedFilePath != null && !_isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.0, -0.5),
                      end: Alignment(1.0, 0.5),
                      colors: [
                        Colors.transparent,
                        Color(0x0DFFFFFF),
                        Colors.transparent,
                        Color(0x0AFFFFFF),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // Left edge shadow (book spine effect)
          if (_cachedFilePath != null && !_isLoading)
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: 12,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x26000000),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Right edge shadow
          if (_cachedFilePath != null && !_isLoading)
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: 8,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Color(0x1A000000),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Page curl animation on swipe
          if (_cachedFilePath != null && !_isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _curlController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: PageCurlPainter(
                        progress: _curlController.value,
                        isForward: _curlForward,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Shimmer on page load
          if (_cachedFilePath != null && !_isLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    final dx = _shimmerController.value * 3.0 - 1.0;
                    return Opacity(
                      opacity: (1.0 - _shimmerController.value).clamp(0.0, 0.4),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(dx, -0.3),
                            end: Alignment(dx + 1.0, 0.3),
                            colors: const [
                              Colors.transparent,
                              Color(0x15FFFFFF),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Caching progress indicator (replaces old generic spinner)
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
}
