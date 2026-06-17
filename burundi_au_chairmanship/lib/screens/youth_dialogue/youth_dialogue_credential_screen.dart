import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  bool _isDownloading = false;
  String? _error;
  YouthDialogueCredential? _credential;

  @override
  void initState() {
    super.initState();
    _loadCredential();
    ApiService().youthDialogueLogActivity('credential_viewed', 'youth_dialogue_credential');
  }

  Future<void> _loadCredential() async {
    // Try cached data first for instant display
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('yd_credential_cache');
      if (cached != null && _credential == null) {
        final cachedData = jsonDecode(cached) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _credential = YouthDialogueCredential.fromJson(cachedData);
            _isLoading = false;
          });
        }
      }
    } catch (_) {}

    // Fetch fresh data
    try {
      final data = await ApiService().youthDialogueCredential();
      if (!mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('yd_credential_cache', jsonEncode(data));
      } catch (_) {}
      setState(() {
        _credential = YouthDialogueCredential.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_credential == null) {
        setState(() {
          _error = 'Failed to load credential.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await ApiService().downloadCredentialPdf();
      final dir = await getTemporaryDirectory();
      final code = _credential?.participantCode ?? 'credential';
      final file = File('${dir.path}/YD-IDCard-$code.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Youth Dialogue ID Card - $code',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Digital ID Card'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
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

  String _formatEventDates(YouthDialogueCredential cred) {
    final start = cred.eventStartDate;
    final end = cred.eventEndDate;
    if (start == null && end == null) return '';
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (start != null && end != null) {
      if (start.month == end.month && start.year == end.year) {
        return '${start.day} – ${end.day} ${months[start.month]} ${start.year}';
      }
      return '${start.day} ${months[start.month]} – ${end.day} ${months[end.month]} ${end.year}';
    }
    final d = start ?? end!;
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Color _parseHexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Widget _buildCredential(bool isDark) {
    final cred = _credential!;
    final qrData = cred.qrData;
    final eventDates = _formatEventDates(cred);
    final roleColor = _parseHexColor(cred.roleColor);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Revoked banner
          if (cred.isRevoked)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credential Revoked',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('This credential is no longer valid.',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── The ID Card ──────────────────────────────────
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: roleColor.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Header with gradient + logos ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        HSLColor.fromColor(roleColor).withLightness((HSLColor.fromColor(roleColor).lightness * 0.6).clamp(0.0, 1.0)).toColor(),
                        roleColor,
                        HSLColor.fromColor(roleColor).withLightness((HSLColor.fromColor(roleColor).lightness * 1.15).clamp(0.0, 1.0)).toColor(),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Logos row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/images/youth_dialogue/dialogue_logo_en.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.groups, color: AppColors.burundiGreen, size: 32),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/images/youth_dialogue/b4_africa_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.public, color: AppColors.burundiGreen, size: 32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Badge label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: const Text(
                          'YOUTH DIALOGUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Burundi AU Chairmanship 2025-2026',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Gold accent line ──
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.auGold, Color(0xFFFFD54F), AppColors.auGold],
                    ),
                  ),
                ),

                // ── Photo + Name + Role + Event Date ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(
                    children: [
                      // Photo
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.auGold, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: roleColor.withValues(alpha: 0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: roleColor, width: 3),
                          ),
                          child: ClipOval(
                            child: cred.idPhotoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: cred.idPhotoUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 400,
                                    placeholder: (_, __) => _photoPlaceholder(isDark),
                                    errorWidget: (_, __, ___) => _photoPlaceholder(isDark),
                                  )
                                : _photoPlaceholder(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Name
                      Text(
                        '${cred.firstName} ${cred.lastName}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1a1a1a),
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // ── Info fields: Role + Event Date ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222222) : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _detailRow(Icons.badge_rounded, 'Role', cred.role, isDark, accentColor: roleColor),
                        if (eventDates.isNotEmpty) ...[
                          Divider(height: 20, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          _detailRow(Icons.calendar_today_rounded, 'Event Date', eventDates, isDark, accentColor: roleColor),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── QR Code section ──
                if (qrData.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          'SCAN TO VERIFY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: roleColor.withValues(alpha: 0.2), width: 2),
                          ),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 150,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF1a1a1a),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF1a1a1a),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Participant code badge ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          roleColor.withValues(alpha: 0.1),
                          roleColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: roleColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      cred.participantCode,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: roleColor,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),

                // ── Footer ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    children: [
                      Divider(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/b4africa_logo.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Burundi Be 4 Africa 2026',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white30 : Colors.black26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Download PDF button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadPdf,
              icon: _isDownloading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
              label: Text(
                _isDownloading ? 'Downloading...' : 'Download PDF',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                disabledBackgroundColor: AppColors.burundiGreen.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _photoPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
      child: const Icon(Icons.person, size: 48, color: Colors.grey),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, bool isDark, {Color? accentColor}) {
    final accent = accentColor ?? AppColors.burundiGreen;
    return Row(
      children: [
        Icon(icon, size: 18, color: accent.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500)),
        const Spacer(),
        Flexible(
          child: Text(value, textAlign: TextAlign.end,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        ),
      ],
    );
  }
}
