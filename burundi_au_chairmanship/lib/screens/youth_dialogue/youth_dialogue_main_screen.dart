import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStatus();
    ApiService().youthDialogueLogActivity('screen_visit', 'youth_dialogue_main');
  }

  Future<void> _loadStatus() async {
    try {
      final data = await ApiService().youthDialogueStatus();
      if (!mounted) return;
      setState(() {
        _hasApplication = data['has_application'] == true;
        if (_hasApplication) {
          _application = YouthDialogueApplication.fromJson(data);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load status. Please try again.';
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
                  onRefresh: _loadStatus,
                  color: AppColors.burundiGreen,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: _hasApplication ? _buildStatusView(isDark) : _buildWelcome(isDark),
                  ),
                ),
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
              onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadStatus(); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.burundiGreen),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: AppColors.burundiGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.forum_rounded, size: 48, color: AppColors.burundiGreen),
        ),
        const SizedBox(height: 24),
        Text('Youth Dialogue Programme',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Join the African Union Youth Dialogue and contribute to shaping the continent\'s future. Apply now to participate in this prestigious programme.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5,
              color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () async {
              await Navigator.pushNamed(context, '/youth-dialogue-apply');
              _loadStatus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Apply Now', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 40),
      ],
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
                    _loadStatus();
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
              // Show doc list with statuses
              ...app.documents.map((doc) => _buildDocRow(doc, isDark)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/youth-dialogue-documents');
                    _loadStatus();
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
