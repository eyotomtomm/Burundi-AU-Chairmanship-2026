import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';

class QrScanResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final String? mode;
  final String? programmeName;

  const QrScanResultScreen({super.key, required this.result, this.mode, this.programmeName});

  bool get _isYdMode => mode == 'youth_dialogue';

  Color _parseHexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isValid = result['valid'] == true;
    final isDuplicate = result['is_duplicate'] == true;
    final scanCount = result['scan_count'] as int? ?? 0;
    final personName = result['person_name'] as String? ?? '';
    final eventTitle = result['event_title'] as String? ?? '';
    final programme = result['programme'] as String? ?? '';
    final qrStatus = result['status'] as String? ?? '';
    final detail = result['detail'] as String? ?? '';
    final qrType = result['type'] as String? ?? '';
    final checkedInAt = result['checked_in_at'] as String?;
    final details = result['details'] as Map<String, dynamic>?;

    final showYdCredential = _isYdMode && qrType == 'youth_dialogue' && details != null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_isYdMode ? 'Credential Result' : 'Scan Result'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            if (showYdCredential)
              _buildYdCredentialCard(context, isDark, isValid, personName, qrStatus, details, detail)
            else ...[
              // Generic status icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isValid
                      ? AppColors.burundiGreen.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                ),
                child: Icon(
                  isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 64,
                  color: isValid ? AppColors.burundiGreen : Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 20),

              // Status text
              Text(
                isValid ? 'VERIFIED' : 'INVALID',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: isValid ? AppColors.burundiGreen : Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),

              if (!isValid && detail.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),

              if (personName.isNotEmpty) ...[
                Text(
                  personName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
              ],

              if (eventTitle.isNotEmpty)
                Text(
                  eventTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),

              if (programme.isNotEmpty)
                Text(
                  programme,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),

              const SizedBox(height: 24),

              // Generic info card
              if (isValid || personName.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (qrType.isNotEmpty)
                        _infoRow('Type', qrType == 'event' ? 'Event Ticket' : (programmeName ?? 'Continental Dialogue'), isDark),
                      if (qrStatus.isNotEmpty)
                        _infoRow('Status', qrStatus.toUpperCase(), isDark,
                            valueColor: _statusColor(qrStatus)),
                      if (checkedInAt != null)
                        _infoRow('Checked In', _formatDateTime(checkedInAt), isDark),
                      if (details != null) ...[
                        if (details['email'] != null)
                          _infoRow('Email', details['email'] as String, isDark),
                        if (details['organization'] != null)
                          _infoRow('Organization', details['organization'] as String, isDark),
                        if (details['participant_code'] != null)
                          _infoRow('Code', details['participant_code'] as String, isDark),
                        if (details['nationality'] != null)
                          _infoRow('Nationality',
                              '${details['nationality_flag'] ?? ''} ${details['nationality']}', isDark),
                        if (details['is_proxy'] == true)
                          _infoRow('Registration', 'Proxy', isDark, valueColor: Colors.orange),
                        if (details['is_waitlisted'] == true)
                          _infoRow('Waitlist', 'Yes', isDark, valueColor: Colors.orange),
                      ],
                    ],
                  ),
                ),
            ],

            // Scan count badge
            if (scanCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDuplicate
                      ? (scanCount >= 3 ? Colors.red.shade50 : Colors.orange.shade50)
                      : AppColors.burundiGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDuplicate
                        ? (scanCount >= 3 ? Colors.red.shade300 : Colors.orange.shade300)
                        : AppColors.burundiGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Scanned $scanCount time${scanCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDuplicate
                        ? (scanCount >= 3 ? Colors.red.shade800 : Colors.orange.shade800)
                        : AppColors.burundiGreen,
                  ),
                ),
              ),
            ],

            // Duplicate warning (escalating severity)
            if (isDuplicate) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scanCount >= 3 ? Colors.red.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scanCount >= 3 ? Colors.red.shade300 : Colors.orange.shade200,
                    width: scanCount >= 3 ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      scanCount >= 3 ? Icons.gpp_bad_rounded : Icons.warning_amber_rounded,
                      color: scanCount >= 3 ? Colors.red.shade700 : Colors.orange.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scanCount >= 3
                                ? 'Multiple Duplicate Scans'
                                : 'Duplicate Scan Detected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: scanCount >= 3 ? Colors.red.shade900 : Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scanCount >= 3
                                ? 'This credential has been scanned $scanCount times. '
                                  'This is unusual — please verify the person\'s identity manually.'
                                : 'This code has been scanned $scanCount time${scanCount == 1 ? '' : 's'}. '
                                  'It may have already been used for check-in.',
                            style: TextStyle(
                              fontSize: 13,
                              color: scanCount >= 3 ? Colors.red.shade800 : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Reset & Scan Again button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Reset & Scan Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYdCredentialCard(
    BuildContext context,
    bool isDark,
    bool isValid,
    String personName,
    String qrStatus,
    Map<String, dynamic> details,
    String detail,
  ) {
    final statusColor = isValid ? AppColors.burundiGreen : Colors.red.shade700;
    final idPhotoUrl = details['id_photo_url'] as String? ?? '';
    final role = details['role'] as String? ?? 'Participant';
    final roleColorHex = details['role_color'] as String? ?? '#4CAF50';
    final roleColor = _parseHexColor(roleColorHex);
    final nationality = details['nationality'] as String? ?? '';
    final nationalityFlag = details['nationality_flag'] as String? ?? '';
    final organization = details['organization'] as String? ?? '';
    final email = details['email'] as String? ?? '';
    final participantCode = details['participant_code'] as String? ?? '';
    final referenceId = details['reference_id'] as String? ?? '';
    final credentialIssuedAt = details['credential_issued_at'] as String?;
    final eventStartDate = details['event_start_date'] as String?;
    final eventEndDate = details['event_end_date'] as String?;
    final eventLocation = details['event_location'] as String? ?? '';
    final revokedReason = details['revoked_reason'] as String? ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status color
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isValid ? 'VERIFIED' : qrStatus.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (!isValid && detail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: statusColor),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Photo with border ring
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isValid ? roleColor : Colors.red.shade400,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: idPhotoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: idPhotoUrl,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: const Icon(Icons.person, size: 48, color: Colors.grey),
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: const Icon(Icons.person, size: 48, color: Colors.grey),
                            ),
                          )
                        : Container(
                            width: 104,
                            height: 104,
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            child: const Icon(Icons.person, size: 48, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Full name
                Text(
                  personName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? roleColor : HSLColor.fromColor(roleColor).withLightness(0.3).toColor(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Divider
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 12),

                // Info rows
                if (nationality.isNotEmpty)
                  _credentialRow(Icons.flag_rounded, 'Nationality', '$nationalityFlag $nationality', isDark),
                if (organization.isNotEmpty)
                  _credentialRow(Icons.business_rounded, 'Organization', organization, isDark),
                if (eventStartDate != null || eventEndDate != null)
                  _credentialRow(Icons.calendar_today_rounded, 'Event Dates',
                      _formatEventDates(eventStartDate, eventEndDate), isDark),
                if (eventLocation.isNotEmpty)
                  _credentialRow(Icons.location_on_rounded, 'Location', eventLocation, isDark),
                if (email.isNotEmpty)
                  _credentialRow(Icons.email_rounded, 'Email', email, isDark),
                if (participantCode.isNotEmpty)
                  _credentialRow(Icons.confirmation_number_rounded, 'Participant Code', participantCode, isDark),
                if (referenceId.isNotEmpty)
                  _credentialRow(Icons.tag_rounded, 'Reference ID', referenceId, isDark),
                if (credentialIssuedAt != null)
                  _credentialRow(Icons.verified_rounded, 'Credential Issued', _formatDateTime(credentialIssuedAt), isDark),
                if (revokedReason.isNotEmpty)
                  _credentialRow(Icons.block_rounded, 'Revocation Reason', revokedReason, isDark,
                      valueColor: Colors.red.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(IconData icon, String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'valid':
        return AppColors.burundiGreen;
      case 'pending':
        return AppColors.auGold;
      case 'rejected':
      case 'revoked':
        return Colors.red;
      case 'waitlist':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatEventDates(String? startDate, String? endDate) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    String formatDate(String iso) {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }

    if (startDate != null && endDate != null) {
      return '${formatDate(startDate)} – ${formatDate(endDate)}';
    } else if (startDate != null) {
      return formatDate(startDate);
    } else if (endDate != null) {
      return 'Until ${formatDate(endDate)}';
    }
    return '';
  }
}
