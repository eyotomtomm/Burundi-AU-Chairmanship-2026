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

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  double _currentZoom = 1.0;

  // Download management
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _enableScreenProtection();
    _checkIfDownloaded();
    _recordView();
  }

  /// Enable screenshot and screen recording prevention
  Future<void> _enableScreenProtection() async {
    try {
      // Prevent screenshots (works on both Android and iOS)
      await ScreenProtector.protectDataLeakageOn();

      // Prevent screen recording (works on both Android and iOS)
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      // Screen protection might not work on all devices/emulators
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

  /// Check if magazine is already downloaded
  Future<void> _checkIfDownloaded() async {
    if (widget.magazineId == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/magazines/${widget.magazineId}.pdf';
      final file = File(filePath);

      if (await file.exists()) {
        setState(() {
          _isDownloaded = true;
          _localFilePath = filePath;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Check download error: $e');
    }
  }

  /// Download magazine for offline viewing
  Future<void> _downloadMagazine() async {
    if (widget.magazineId == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final magazinesDir = Directory('${directory.path}/magazines');

      // Create magazines directory if it doesn't exist
      if (!await magazinesDir.exists()) {
        await magazinesDir.create(recursive: true);
      }

      final filePath = '${magazinesDir.path}/${widget.magazineId}.pdf';
      final url = Environment.fixMediaUrl(widget.pdfUrl);

      // Download with progress
      final dio = Dio();
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
    _disableScreenProtection(); // Re-enable screenshots when leaving
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = Environment.fixMediaUrl(widget.pdfUrl);

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
          // PDF Viewer - Use local file if downloaded, otherwise network
          if (_localFilePath != null && _isDownloaded)
            Builder(
              builder: (context) {
                final localPath = _localFilePath!; // Safe due to null check above
                return SfPdfViewer.file(
                  File(localPath),
                  key: _pdfViewerKey,
                  controller: _pdfViewerController,
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
                setState(() {
                  _currentPage = details.newPageNumber - 1;
                });
              },
              onZoomLevelChanged: (details) {
                setState(() {
                  _currentZoom = details.newZoomLevel;
                });
              },
                );
              },
            )
          else
            SfPdfViewer.network(
              url,
              key: _pdfViewerKey,
              controller: _pdfViewerController,
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
                setState(() {
                  _currentPage = details.newPageNumber - 1;
                });
              },
              onZoomLevelChanged: (details) {
                setState(() {
                  _currentZoom = details.newZoomLevel;
                });
              },
            ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.burundiGreen),
                  SizedBox(height: 16),
                  Text('Loading PDF...', style: TextStyle(color: Colors.grey)),
                ],
              ),
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
                        'Downloading magazine...',
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

          // Screenshot protection warning (optional - shows when viewing)
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
