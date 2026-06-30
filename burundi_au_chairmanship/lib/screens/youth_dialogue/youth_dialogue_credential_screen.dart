import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screen_protector/screen_protector.dart';
import '../../config/app_colors.dart';
import '../../models/youth_dialogue_model.dart';
import '../../services/api_service.dart';
import '../../widgets/confetti_overlay.dart';

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
  bool _confettiShown = false;
  String _programmeName = 'Continental Dialogue';

  @override
  void initState() {
    super.initState();
    _enableScreenProtection();
    _loadProgrammeName();
    _loadCredential();
    ApiService().youthDialogueLogActivity('credential_viewed', 'youth_dialogue_credential');
  }

  Future<void> _loadProgrammeName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('yd_settings_cache');
      if (cached != null) {
        final settings = jsonDecode(cached) as Map<String, dynamic>;
        final title = settings['programme_title']?.toString() ?? '';
        if (title.isNotEmpty && mounted) {
          setState(() => _programmeName = title);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disableScreenProtection();
    super.dispose();
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
      // Show confetti on first credential view
      _triggerConfetti();
    } catch (e) {
      if (!mounted) return;
      if (_credential == null) {
        setState(() {
          _error = 'Failed to load credential.';
          _isLoading = false;
        });
      } else {
        _triggerConfetti();
      }
    }
  }

  void _triggerConfetti() {
    if (_confettiShown || !mounted) return;
    _confettiShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ConfettiOverlay.show(context);
    });
  }

  Future<void> _downloadPdf() async {
    if (_isDownloading || _credential == null) return;
    setState(() => _isDownloading = true);
    try {
      // Try API download first
      List<int> bytes;
      try {
        bytes = await ApiService().downloadCredentialPdf();
      } catch (_) {
        // Fallback: generate PDF client-side
        bytes = await _generatePdfLocally();
      }
      final dir = await getTemporaryDirectory();
      final code = _credential?.participantCode ?? 'credential';
      final file = File('${dir.path}/YD-IDCard-$code.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: '$_programmeName ID Card - $code',
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

  /// Generates a PDF ID card locally from credential data
  Future<List<int>> _generatePdfLocally() async {
    final cred = _credential!;
    final pdf = pw.Document();

    // Try to load the photo as bytes for embedding
    Uint8List? photoBytes;
    if (cred.idPhotoUrl.isNotEmpty) {
      try {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(cred.idPhotoUrl));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
          photoBytes = Uint8List.fromList(bytes);
        }
        httpClient.close();
      } catch (_) {}
    }

    final roleColor = _parseHexColor(cred.roleColor);
    final pdfRoleColor = PdfColor.fromInt(roleColor.toARGB32());
    final goldColor = const PdfColor.fromInt(0xFFD4AF37);

    final eventDates = _formatEventDates(cred);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: pdfRoleColor,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(_programmeName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 3,
                      )),
                    pw.SizedBox(height: 6),
                    pw.Text('Burundi AU Chairmanship 2025-2026',
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),
              // Gold accent
              pw.Container(height: 3, color: goldColor),
              pw.SizedBox(height: 24),

              // Photo
              if (photoBytes != null)
                pw.ClipOval(
                  child: pw.Image(pw.MemoryImage(photoBytes), width: 100, height: 100, fit: pw.BoxFit.cover),
                ),
              pw.SizedBox(height: 16),

              // Name
              pw.Text('${cred.firstName} ${cred.lastName}',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),

              // Info table
              _pdfInfoRow('Organization', cred.organization),
              _pdfInfoRow('Role', cred.role),
              _pdfInfoRow('Position', cred.position),
              if (cred.nationalityDisplay.isNotEmpty)
                _pdfInfoRow('Nationality', '${cred.nationalityFlag} ${cred.nationalityDisplay}'),
              if (eventDates.isNotEmpty)
                _pdfInfoRow('Event Date', eventDates),

              // Extra fields from admin
              ...cred.extraFields.map((f) => _pdfInfoRow(f['label']!, f['value']!)),

              pw.SizedBox(height: 20),

              // Participant code
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdfRoleColor, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(cred.participantCode,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 4,
                    color: pdfRoleColor,
                    font: pw.Font.courier(),
                  )),
              ),

              pw.SizedBox(height: 20),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Text('Burundi Be 4 Africa 2026',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    if (value.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
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
        return '${start.day} \u2013 ${end.day} ${months[start.month]} ${start.year}';
      }
      return '${start.day} ${months[start.month]} \u2013 ${end.day} ${months[end.month]} ${end.year}';
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

          // The ID Card
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
                // Header with gradient + logos
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
                      // Multiple logos row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildHeaderLogo('assets/images/youth_dialogue/dialogue_logo_en.png', Icons.groups),
                          const SizedBox(width: 12),
                          _buildHeaderLogo('assets/images/youth_dialogue/b4_africa_logo.png', Icons.public),
                          // Extra logos from admin
                          ...cred.extraLogos.map((url) => Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Container(
                              width: 56,
                              height: 56,
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
                              padding: const EdgeInsets.all(6),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => Icon(Icons.image, color: AppColors.burundiGreen, size: 24),
                              ),
                            ),
                          )),
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
                        child: Text(
                          _programmeName.toUpperCase(),
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

                // Gold accent line
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.auGold, Color(0xFFFFD54F), AppColors.auGold],
                    ),
                  ),
                ),

                // Photo + Name
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

                // Info fields: Organization + Role + Event Date + extra fields
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
                        if (cred.organization.isNotEmpty)
                          _detailRow(Icons.business_rounded, 'Organization', cred.organization, isDark, accentColor: roleColor),
                        if (cred.organization.isNotEmpty)
                          Divider(height: 20, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                        _detailRow(Icons.badge_rounded, 'Role', cred.role, isDark, accentColor: roleColor),
                        if (cred.position.isNotEmpty) ...[
                          Divider(height: 20, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          _detailRow(Icons.work_rounded, 'Position', cred.position, isDark, accentColor: roleColor),
                        ],
                        if (cred.nationalityDisplay.isNotEmpty) ...[
                          Divider(height: 20, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          _detailRow(Icons.flag_rounded, 'Nationality',
                            '${cred.nationalityFlag} ${cred.nationalityDisplay}', isDark, accentColor: roleColor),
                        ],
                        if (eventDates.isNotEmpty) ...[
                          Divider(height: 20, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                          _detailRow(Icons.calendar_today_rounded, 'Event Date', eventDates, isDark, accentColor: roleColor),
                        ],
                        // Extra fields from admin
                        ...cred.extraFields.map((f) {
                          return Column(
                            children: [
                              Divider(height: 20, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                              _detailRow(Icons.info_outline_rounded, f['label']!, f['value']!, isDark, accentColor: roleColor),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // QR Code section
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

                // Participant code badge
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

                // Footer with multiple logos
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
                            'assets/images/youth_dialogue/dialogue_logo_en.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 6),
                          Image.asset(
                            'assets/images/youth_dialogue/b4_africa_logo.png',
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

          // Download PDF button (admin-controlled)
          if (cred.allowPdfDownload)
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
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_rounded, size: 18, color: isDark ? Colors.white30 : Colors.black26),
                  const SizedBox(width: 8),
                  Text(
                    'PDF download is currently unavailable',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),

          // Protected content badge
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security, size: 14, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(width: 6),
              Text(
                'Protected content',
                style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderLogo(String assetPath, IconData fallbackIcon) {
    return Container(
      width: 56,
      height: 56,
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
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: AppColors.burundiGreen, size: 28),
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
