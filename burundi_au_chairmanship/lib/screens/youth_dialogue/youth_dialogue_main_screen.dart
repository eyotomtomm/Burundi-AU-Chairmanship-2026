import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../models/youth_dialogue_model.dart';
import '../../services/api_service.dart';

class YouthDialogueMainScreen extends StatefulWidget {
  const YouthDialogueMainScreen({super.key});

  @override
  State<YouthDialogueMainScreen> createState() => _YouthDialogueMainScreenState();
}

class _YouthDialogueMainScreenState extends State<YouthDialogueMainScreen> {
  bool _isLoading = true;
  String? _error;
  bool _hasApplication = false;
  YouthDialogueApplication? _application;
  Map<String, dynamic>? _settings;

  @override
  void initState() {
    super.initState();
    _loadData();
    ApiService().youthDialogueLogActivity('screen_visit', 'youth_dialogue_main');
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService().youthDialogueSettings(),
        ApiService().youthDialogueStatus().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _settings = results[0];
        final statusData = results[1];
        _hasApplication = statusData['has_application'] == true;
        if (_hasApplication) {
          _application = YouthDialogueApplication.fromJson(statusData);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _t(String enKey, String frKey, bool isFr) {
    if (_settings == null) return '';
    final val = isFr ? _settings![frKey] : null;
    if (val != null && val.toString().isNotEmpty) return val.toString();
    return _settings![enKey]?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Youth Dialogue'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen))
          : _error != null
              ? _buildError(isDark)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.burundiGreen,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildHeader(isDark, isFr),
                        const SizedBox(height: 24),
                        if (_hasApplication)
                          _buildStatusView(isDark)
                        else
                          _buildWelcome(isDark, isFr),
                        const SizedBox(height: 24),
                        _buildSupportSection(isDark, isFr),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(bool isDark, bool isFr) {
    final logoUrl = isDark
        ? (_settings?['logo_dark']?.toString() ?? '')
        : (_settings?['logo_light']?.toString() ?? '');
    // Fallback: if dark logo is empty, try light
    final effectiveUrl = logoUrl.isNotEmpty
        ? logoUrl
        : (_settings?['logo_light']?.toString() ?? '');

    if (effectiveUrl.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 8),
        Image.network(
          Environment.fixMediaUrl(effectiveUrl),
          height: 80,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        Text(
          _t('programme_title', 'programme_title_fr', isFr),
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _t('description', 'description_fr', isFr),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14, height: 1.5,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: isDark ? Colors.white38 : Colors.black26),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadData(); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.burundiGreen),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(bool isDark, bool isFr) {
    final isOpen = _settings?['is_registration_open'] ?? true;

    if (!isOpen) {
      final closedMsg = _t('registration_closed_message', 'registration_closed_message_fr', isFr);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.auGold.withValues(alpha: 0.1), shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock_rounded, size: 36, color: AppColors.auGold),
            ),
            const SizedBox(height: 16),
            Text(closedMsg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54)),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/youth-dialogue-apply');
          _loadData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.burundiGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(isFr ? 'Postuler Maintenant' : 'Apply Now',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSupportSection(bool isDark, bool isFr) {
    final supportNote = _t('support_note', 'support_note_fr', isFr);
    final email = _settings?['support_email']?.toString() ?? '';
    final phone = _settings?['support_phone']?.toString() ?? '';
    final chatUrl = _settings?['live_chat_url']?.toString() ?? '';

    if (email.isEmpty && phone.isEmpty && chatUrl.isEmpty && supportNote.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_rounded, size: 22,
                color: isDark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 8),
              Text(isFr ? 'Support' : 'Support',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          if (supportNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(supportNote,
              style: TextStyle(fontSize: 13, height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54)),
          ],
          const SizedBox(height: 16),
          if (email.isNotEmpty)
            _buildContactTile(
              isDark,
              icon: Icons.email_outlined,
              label: isFr ? 'Email' : 'Email',
              value: email,
              onTap: () => launchUrl(Uri.parse('mailto:$email')),
            ),
          if (phone.isNotEmpty)
            _buildContactTile(
              isDark,
              icon: Icons.phone_outlined,
              label: isFr ? 'Téléphone' : 'Phone',
              value: phone,
              onTap: () => launchUrl(Uri.parse('tel:$phone')),
            ),
          if (chatUrl.isNotEmpty)
            _buildContactTile(
              isDark,
              icon: Icons.chat_bubble_outline_rounded,
              label: isFr ? 'Chat en direct' : 'Live Chat',
              value: isFr ? 'Ouvrir le chat' : 'Open chat',
              onTap: () => launchUrl(Uri.parse(chatUrl), mode: LaunchMode.externalApplication),
            ),
        ],
      ),
    );
  }

  Widget _buildContactTile(bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.burundiGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38)),
                    Text(value, style: TextStyle(fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20,
                color: isDark ? Colors.white30 : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusView(bool isDark) {
    final app = _application!;

    switch (app.status) {
      case 'submitted':
      case 'under_review':
        return _buildProgressCard(isDark, app, 'Application Under Review',
          'Your application is being reviewed by our team. We will notify you once a decision has been made.',
          Icons.hourglass_top_rounded, AppColors.auGold);

      case 'rejected':
        return _buildRejectedCard(isDark, app);

      case 'accepted':
      case 'documents_pending':
        return _buildDocumentsNeeded(isDark, app);

      case 'documents_submitted':
      case 'documents_under_review':
        return _buildProgressCard(isDark, app, 'Documents Under Review',
          'Your documents are being reviewed. You will be notified once verification is complete.',
          Icons.description_rounded, Colors.blue);

      case 'documents_rejected':
        return _buildDocumentsRejected(isDark, app);

      case 'credential_issued':
        return _buildCredentialReady(isDark, app);

      default:
        return _buildProgressCard(isDark, app, app.status, 'Status: ${app.status}',
          Icons.info_outline, Colors.grey);
    }
  }

  Widget _buildProgressCard(bool isDark, YouthDialogueApplication app,
      String title, String message, IconData icon, Color color) {
    return Column(
      children: [
        _buildStatusHeader(isDark, app),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5,
                  color: isDark ? Colors.white60 : Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHeader(bool isDark, YouthDialogueApplication app) {
    final statusColors = {
      'submitted': Colors.grey, 'under_review': AppColors.auGold,
      'accepted': AppColors.burundiGreen, 'rejected': AppColors.burundiRed,
      'documents_pending': Colors.blue, 'documents_submitted': Colors.blue,
      'documents_under_review': AppColors.auGold, 'documents_rejected': AppColors.burundiRed,
      'credential_issued': Colors.purple,
    };
    final color = statusColors[app.status] ?? Colors.grey;
    final statusLabels = {
      'submitted': 'Submitted', 'under_review': 'Under Review',
      'accepted': 'Accepted', 'rejected': 'Rejected',
      'documents_pending': 'Documents Pending', 'documents_submitted': 'Documents Submitted',
      'documents_under_review': 'Documents Under Review', 'documents_rejected': 'Documents Rejected',
      'credential_issued': 'Credential Issued',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusLabels[app.status] ?? app.status,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(height: 2),
                Text('${app.firstName} ${app.lastName}',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(bool isDark, YouthDialogueApplication app) {
    return Column(
      children: [
        _buildStatusHeader(isDark, app),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.burundiRed.withValues(alpha: 0.1), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel_rounded, size: 36, color: AppColors.burundiRed),
              ),
              const SizedBox(height: 16),
              Text('Application Not Approved', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 12),
              if (app.rejectionReason != null && app.rejectionReason!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.burundiRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.burundiRed.withValues(alpha: 0.2)),
                  ),
                  child: Text(app.rejectionReason!,
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, height: 1.5)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsNeeded(bool isDark, YouthDialogueApplication app) {
    return Column(
      children: [
        _buildStatusHeader(isDark, app),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.upload_file_rounded, size: 36, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              Text('Upload Your Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text('Please upload the required documents to continue your application.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/youth-dialogue-documents');
                    _loadData();
                  },
                  icon: const Icon(Icons.upload_rounded, color: Colors.white),
                  label: const Text('Upload Documents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsRejected(bool isDark, YouthDialogueApplication app) {
    return Column(
      children: [
        _buildStatusHeader(isDark, app),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.burundiRed),
                  const SizedBox(width: 8),
                  Text('Documents Need Attention', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              if (app.documentsRejectionNotes != null && app.documentsRejectionNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.burundiRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(app.documentsRejectionNotes!,
                    style: const TextStyle(fontSize: 13, color: AppColors.burundiRed)),
                ),
              ],
              const SizedBox(height: 16),
              ...app.documents.map((doc) => _buildDocRow(doc, isDark)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/youth-dialogue-documents');
                    _loadData();
                  },
                  icon: const Icon(Icons.edit_document, color: Colors.white),
                  label: const Text('Fix Documents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burundiRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocRow(YouthDialogueDocument doc, bool isDark) {
    final typeLabels = {
      'passport': 'Passport Copy', 'national_id': 'National ID',
      'photo': 'Passport Photo', 'cv': 'CV / Resume',
      'recommendation': 'Recommendation', 'other': 'Other',
    };
    final statusColors = {
      'pending': AppColors.auGold, 'approved': AppColors.burundiGreen, 'rejected': AppColors.burundiRed,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: statusColors[doc.status] ?? Colors.grey, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeLabels[doc.documentType] ?? doc.documentType,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87)),
                if (doc.status == 'rejected' && doc.rejectionReason != null)
                  Text(doc.rejectionReason!, style: const TextStyle(fontSize: 12, color: AppColors.burundiRed)),
              ],
            ),
          ),
          Text(doc.status.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: statusColors[doc.status] ?? Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCredentialReady(bool isDark, YouthDialogueApplication app) {
    return Column(
      children: [
        _buildStatusHeader(isDark, app),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.deepPurple],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 16)],
                ),
                child: const Icon(Icons.badge_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text('Your ID Card is Ready!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              if (app.participantCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(app.participantCode!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                      fontFamily: 'monospace', color: Colors.purple, letterSpacing: 2)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/youth-dialogue-credential'),
                  icon: const Icon(Icons.credit_card_rounded, color: Colors.white),
                  label: const Text('View ID Card', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
