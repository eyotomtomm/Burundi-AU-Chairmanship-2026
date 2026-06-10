import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../models/youth_dialogue_model.dart';
import '../../services/api_service.dart';

class YouthDialogueCredentialScreen extends StatefulWidget {
  const YouthDialogueCredentialScreen({super.key});

  @override
  State<YouthDialogueCredentialScreen> createState() => _YouthDialogueCredentialScreenState();
}

class _YouthDialogueCredentialScreenState extends State<YouthDialogueCredentialScreen> {
  bool _isLoading = true;
  String? _error;
  YouthDialogueCredential? _credential;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadCredential();
    ApiService().youthDialogueLogActivity('credential_viewed', 'youth_dialogue_credential');
  }

  Future<void> _loadCredential() async {
    try {
      final data = await ApiService().youthDialogueCredential();
      if (!mounted) return;
      setState(() {
        _credential = YouthDialogueCredential.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load credential.';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareCredential() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/yd_credential.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Youth Dialogue Participant ID - ${_credential?.participantCode ?? ""}',
      );

      ApiService().youthDialogueLogActivity('credential_shared', 'youth_dialogue_credential');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share credential.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Participant ID Card'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_credential != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareCredential,
              tooltip: 'Share ID Card',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen))
          : _error != null
              ? _buildError(isDark)
              : _buildCredential(isDark),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: isDark ? Colors.white38 : Colors.black26),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadCredential(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.burundiGreen),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCredential(bool isDark) {
    final cred = _credential!;
    final qrData = cred.qrData;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Green header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.burundiGreen, Color(0xFF2D6E31)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'YOUTH DIALOGUE PARTICIPANT',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Burundi Be 4 Africa 2026',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Photo + info
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Participant photo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.burundiGreen, width: 3),
                          ),
                          child: ClipOval(
                            child: cred.idPhotoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: cred.idPhotoUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                      child: const Icon(Icons.person, size: 48, color: Colors.grey),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                      child: const Icon(Icons.person, size: 48, color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                    child: const Icon(Icons.person, size: 48, color: Colors.grey),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name
                        Text(
                          '${cred.firstName} ${cred.lastName}',
                          style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (cred.organization.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(cred.organization,
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                            textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 20),

                        // Details
                        _infoRow('Nationality', cred.nationality, isDark),
                        if (cred.position.isNotEmpty)
                          _infoRow('Position', cred.position, isDark),
                        _infoRow('Email', cred.email, isDark),

                        const SizedBox(height: 20),

                        // Divider
                        Divider(color: isDark ? Colors.white12 : Colors.black12),
                        const SizedBox(height: 16),

                        // QR Code
                        if (qrData.isNotEmpty) ...[
                          _buildQrCodeWidget(qrData),
                          const SizedBox(height: 16),
                        ],

                        // Participant code
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.burundiGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cred.participantCode,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: AppColors.burundiGreen,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161616) : const Color(0xFFF8F8F8),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Burundi Be 4 Africa 2026',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11, color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Share button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _shareCredential,
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text('Share ID Card', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black45)),
          Flexible(
            child: Text(value, textAlign: TextAlign.end,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87)),
          ),
        ],
      ),
    );
  }

  /// Builds a QR-code-like pattern (same approach as event_ticket_screen.dart)
  Widget _buildQrCodeWidget(String qrData) {
    final hash = qrData.hashCode;
    final cells = <List<bool>>[];
    for (int row = 0; row < 15; row++) {
      final rowCells = <bool>[];
      for (int col = 0; col < 15; col++) {
        final mirrorCol = col < 8 ? col : 14 - col;
        final seed = (hash + row * 17 + mirrorCol * 31) % 97;
        rowCells.add(seed > 40);
      }
      cells.add(rowCells);
    }

    // Add finder patterns
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        final isBorder = i == 0 || i == 4 || j == 0 || j == 4;
        final isCenter = i == 2 && j == 2;
        cells[i][j] = isBorder || isCenter;
        cells[i][14 - j] = isBorder || isCenter;
        cells[14 - i][j] = isBorder || isCenter;
      }
    }

    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(painter: _QrPatternPainter(cells)),
    );
  }
}

class _QrPatternPainter extends CustomPainter {
  final List<List<bool>> cells;
  _QrPatternPainter(this.cells);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / cells.length;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (int row = 0; row < cells.length; row++) {
      for (int col = 0; col < cells[row].length; col++) {
        if (cells[row][col]) {
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
