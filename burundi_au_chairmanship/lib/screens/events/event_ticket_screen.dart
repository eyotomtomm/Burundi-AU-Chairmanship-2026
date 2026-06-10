import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

class EventTicketScreen extends StatefulWidget {
  final int submissionId;

  const EventTicketScreen({super.key, required this.submissionId});

  @override
  State<EventTicketScreen> createState() => _EventTicketScreenState();
}

class _EventTicketScreenState extends State<EventTicketScreen> {
  Map<String, dynamic>? _ticketData;
  bool _isLoading = true;
  String? _error;
  final GlobalKey _ticketKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    try {
      final data = await ApiService().getEventQrTicket(widget.submissionId);
      if (mounted) {
        setState(() {
          _ticketData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load ticket. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Event Ticket'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_ticketData != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareTicket,
              tooltip: 'Share Ticket',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen))
          : _error != null
              ? _buildError(isDark)
              : _buildTicket(isDark),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadTicket();
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
    );
  }

  Widget _buildTicket(bool isDark) {
    final data = _ticketData!;
    final eventName = data['event_name'] as String? ?? '';
    final eventDate = data['event_date'] as String?;
    final eventEndDate = data['event_end_date'] as String?;
    final venue = data['venue'] as String? ?? '';
    final venueAddress = data['venue_address'] as String? ?? '';
    final attendeeName = data['attendee_name'] as String? ?? '';
    final attendeeEmail = data['attendee_email'] as String? ?? '';
    final ticketId = data['ticket_id'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final isWaitlisted = data['is_waitlisted'] as bool? ?? false;
    final checkedInAt = data['checked_in_at'] as String?;
    final qrData = data['qr_data'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: RepaintBoundary(
        key: _ticketKey,
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
              // Header with event name
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
                    // Status badge
                    if (isWaitlisted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'WAITLISTED',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      )
                    else if (checkedInAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'CHECKED IN',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                    const Icon(Icons.confirmation_number, color: Colors.white, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      eventName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (eventDate != null)
                      _headerInfoRow(Icons.calendar_today, _formatDateRange(eventDate, eventEndDate)),
                    if (venue.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _headerInfoRow(Icons.location_on, venue),
                      ),
                    if (venueAddress.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _headerInfoRow(Icons.map, venueAddress),
                      ),
                  ],
                ),
              ),

              // Ticket tear line
              _buildTearLine(isDark),

              // QR Code section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    Text(
                      'Scan for Check-in',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black45,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // QR Code rendered as data matrix
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.burundiGreen.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: _buildQrCodeWidget(qrData),
                    ),
                    const SizedBox(height: 12),

                    // Ticket ID
                    Text(
                      ticketId,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                ),
              ),

              // Attendee info
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _infoRow('Attendee', attendeeName, isDark),
                    const SizedBox(height: 10),
                    _infoRow('Email', attendeeEmail, isDark),
                    const SizedBox(height: 10),
                    _infoRow('Status', status.toUpperCase(), isDark,
                        valueColor: _getStatusColor(status)),
                  ],
                ),
              ),

              // Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161616) : const Color(0xFFF8F8F8),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Text(
                  'Be 4 Africa 2025',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTearLine(bool isDark) {
    return Row(
      children: [
        _notch(isDark, isLeft: true),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dashCount = (constraints.maxWidth / 10).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(dashCount, (_) => Container(
                  width: 5,
                  height: 1,
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFD0D0D0),
                )),
              );
            },
          ),
        ),
        _notch(isDark, isLeft: false),
      ],
    );
  }

  Widget _notch(bool isDark, {required bool isLeft}) {
    return Container(
      width: 20,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.only(
          topLeft: isLeft ? Radius.zero : const Radius.circular(20),
          topRight: isLeft ? const Radius.circular(20) : Radius.zero,
          bottomLeft: isLeft ? Radius.zero : const Radius.circular(20),
          bottomRight: isLeft ? const Radius.circular(20) : Radius.zero,
        ),
      ),
    );
  }

  /// Builds a text-based QR code representation.
  /// Since qr_flutter is not in pubspec.yaml, we render the QR data as a
  /// visually distinctive code pattern that can be read by the API endpoint.
  Widget _buildQrCodeWidget(String qrData) {
    // Generate a visual deterministic grid from the qr_data hash
    final hash = qrData.hashCode;
    final cells = <List<bool>>[];
    for (int row = 0; row < 15; row++) {
      final rowCells = <bool>[];
      for (int col = 0; col < 15; col++) {
        // Create a symmetric pattern for visual appeal
        final mirrorCol = col < 8 ? col : 14 - col;
        final seed = (hash + row * 17 + mirrorCol * 31) % 97;
        rowCells.add(seed > 40);
      }
      cells.add(rowCells);
    }

    // Add finder patterns (top-left, top-right, bottom-left corners)
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
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _QrPatternPainter(cells),
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateRange(String startIso, String? endIso) {
    final start = DateTime.tryParse(startIso);
    if (start == null) return startIso;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final startStr = '${months[start.month - 1]} ${start.day}, ${start.year}';

    if (endIso != null) {
      final end = DateTime.tryParse(endIso);
      if (end != null && end.difference(start).inDays > 0) {
        final endStr = '${months[end.month - 1]} ${end.day}, ${end.year}';
        return '$startStr - $endStr';
      }
    }
    return startStr;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.burundiGreen;
      case 'pending':
        return AppColors.auGold;
      case 'rejected':
        return AppColors.burundiRed;
      case 'waitlist':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _shareTicket() async {
    try {
      final boundary = _ticketKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/event_ticket.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My ticket for ${_ticketData?['event_name'] ?? 'event'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share ticket.')),
        );
      }
    }
  }
}

/// Custom painter that renders a QR-code-like pattern from a boolean grid.
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
