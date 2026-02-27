import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../config/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _recordView();
  }

  Future<void> _recordView() async {
    if (widget.magazineId != null) {
      try {
        await ApiService().post(
          'magazines/${widget.magazineId}/record_view/',
          {},
        );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.pdfUrl.replaceAll('127.0.0.1', 'localhost');

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
        ],
      ),
    );
  }
}
