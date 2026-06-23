import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

class YdScanHistoryScreen extends StatefulWidget {
  const YdScanHistoryScreen({super.key});

  @override
  State<YdScanHistoryScreen> createState() => _YdScanHistoryScreenState();
}

class _YdScanHistoryScreenState extends State<YdScanHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _scans = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final results = await ApiService().youthDialogueScanHistory();
      if (!mounted) return;
      setState(() {
        _scans = results.cast<Map<String, dynamic>>();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load scan history.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen))
          : _error != null
              ? _buildError(isDark)
              : _scans.isEmpty
                  ? _buildEmpty(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: AppColors.burundiGreen,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _scans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => _buildScanCard(_scans[index], isDark),
                      ),
                    ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: isDark ? Colors.white30 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() { _isLoading = true; _error = null; });
              _loadHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.burundiGreen),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            'No scans yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scanned credentials will appear here.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(Map<String, dynamic> scan, bool isDark) {
    final personName = scan['person_name'] as String? ?? 'Unknown';
    final participantCode = scan['participant_code'] as String? ?? '';
    final role = scan['role'] as String? ?? '';
    final scannedBy = scan['scanned_by'] as String? ?? '';
    final scannedAt = scan['scanned_at'] as String?;
    final isDuplicate = scan['is_duplicate'] == true;
    final scanCount = scan['scan_count'] as int? ?? 1;

    final cardColor = isDuplicate
        ? (scanCount >= 3 ? Colors.red.shade50 : Colors.orange.shade50)
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isDuplicate
        ? (scanCount >= 3 ? Colors.red.shade200 : Colors.orange.shade200)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark && !isDuplicate ? const Color(0xFF1E1E1E) : cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDuplicate
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + duplicate badge
          Row(
            children: [
              Expanded(
                child: Text(
                  personName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark && !isDuplicate ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (isDuplicate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scanCount >= 3 ? Colors.red.shade600 : Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    scanCount >= 3 ? 'DUPLICATE x$scanCount' : 'DUPLICATE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'FIRST SCAN',
                    style: TextStyle(
                      color: AppColors.burundiGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Detail row: participant code + role
          Row(
            children: [
              if (participantCode.isNotEmpty) ...[
                Icon(Icons.confirmation_number_rounded, size: 14,
                    color: isDark && !isDuplicate ? Colors.white38 : Colors.black38),
                const SizedBox(width: 4),
                Text(
                  participantCode,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: isDark && !isDuplicate ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              if (role.isNotEmpty) ...[
                Icon(Icons.badge_rounded, size: 14,
                    color: isDark && !isDuplicate ? Colors.white38 : Colors.black38),
                const SizedBox(width: 4),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark && !isDuplicate ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Bottom row: scanned by + timestamp
          Row(
            children: [
              if (scannedBy.isNotEmpty) ...[
                Icon(Icons.person_outline_rounded, size: 14,
                    color: isDark && !isDuplicate ? Colors.white30 : Colors.black26),
                const SizedBox(width: 4),
                Text(
                  scannedBy,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark && !isDuplicate ? Colors.white38 : Colors.black38,
                  ),
                ),
                const Spacer(),
              ],
              if (scannedAt != null) ...[
                Icon(Icons.access_time_rounded, size: 14,
                    color: isDark && !isDuplicate ? Colors.white30 : Colors.black26),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(scannedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark && !isDuplicate ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
