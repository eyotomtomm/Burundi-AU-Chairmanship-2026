import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../models/youth_dialogue_model.dart';
import '../../services/api_service.dart';

class YouthDialogueDocumentsScreen extends StatefulWidget {
  const YouthDialogueDocumentsScreen({super.key});

  @override
  State<YouthDialogueDocumentsScreen> createState() => _YouthDialogueDocumentsScreenState();
}

class _YouthDialogueDocumentsScreenState extends State<YouthDialogueDocumentsScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  YouthDialogueApplication? _application;
  final Map<String, bool> _uploading = {};

  static const _requiredDocs = [
    {'type': 'passport', 'label': 'Passport Copy', 'icon': Icons.article_outlined},
    {'type': 'national_id', 'label': 'National ID', 'icon': Icons.badge_outlined},
    {'type': 'photo', 'label': 'Passport Photo', 'icon': Icons.photo_camera_outlined},
    {'type': 'cv', 'label': 'CV / Resume', 'icon': Icons.description_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
    ApiService().youthDialogueLogActivity('screen_visit', 'youth_dialogue_documents');
  }

  Future<void> _loadStatus() async {
    try {
      final data = await ApiService().youthDialogueStatus();
      if (!mounted) return;
      setState(() {
        if (data['has_application'] == true) {
          _application = YouthDialogueApplication.fromJson(data);
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

  Future<void> _pickAndUpload(String docType, {int? replacesId}) async {
    final picker = ImagePicker();

    // Use file picker for CV, image picker for others
    final XFile? picked;
    if (docType == 'cv') {
      // For CV, use gallery which allows any file on some platforms
      picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    } else {
      picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    }

    if (picked == null) return;

    setState(() => _uploading[docType] = true);

    try {
      await ApiService().youthDialogueUploadDocument(
        File(picked.path),
        docType,
        replacesId: replacesId,
      );
      await _loadStatus();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.'), backgroundColor: AppColors.burundiRed),
      );
    } finally {
      if (mounted) setState(() => _uploading[docType] = false);
    }
  }

  Future<void> _submitDocuments() async {
    setState(() => _isSubmitting = true);
    try {
      await ApiService().youthDialogueSubmitDocuments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documents submitted for review!'), backgroundColor: AppColors.burundiGreen),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.burundiRed),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission failed. Please try again.'), backgroundColor: AppColors.burundiRed),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Upload Documents'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen))
          : _error != null
              ? _buildError(isDark)
              : _buildContent(isDark),
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
            onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadStatus(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.burundiGreen),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_application == null) {
      return const Center(child: Text('No application found.'));
    }

    final docs = _application!.documents;
    // Map existing docs by type
    final docsByType = <String, YouthDialogueDocument>{};
    for (final doc in docs) {
      // Keep the latest doc per type
      if (!docsByType.containsKey(doc.documentType) || doc.id > docsByType[doc.documentType]!.id) {
        docsByType[doc.documentType] = doc;
      }
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Required Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text('Upload the following documents to proceed with your application.',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 20),

              ..._requiredDocs.map((req) {
                final type = req['type'] as String;
                final label = req['label'] as String;
                final icon = req['icon'] as IconData;
                final existingDoc = docsByType[type];
                final isUploading = _uploading[type] == true;

                return _buildDocSlot(isDark, type, label, icon, existingDoc, isUploading);
              }),
            ],
          ),
        ),

        // Submit button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDocuments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: AppColors.burundiGreen.withValues(alpha: 0.5),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit All Documents', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocSlot(bool isDark, String type, String label, IconData icon,
      YouthDialogueDocument? doc, bool isUploading) {
    final hasDoc = doc != null;
    final isRejected = hasDoc && doc.status == 'rejected';
    final isApproved = hasDoc && doc.status == 'approved';

    Color statusColor = Colors.grey;
    String statusText = 'Not uploaded';
    if (hasDoc) {
      switch (doc.status) {
        case 'pending':
          statusColor = AppColors.auGold;
          statusText = 'Pending review';
          break;
        case 'approved':
          statusColor = AppColors.burundiGreen;
          statusText = 'Approved';
          break;
        case 'rejected':
          statusColor = AppColors.burundiRed;
          statusText = 'Rejected';
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isRejected ? Border.all(color: AppColors.burundiRed.withValues(alpha: 0.3)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (hasDoc ? statusColor : Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: hasDoc ? statusColor : Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isUploading)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              else if (!isApproved)
                TextButton(
                  onPressed: () => _pickAndUpload(type, replacesId: isRejected ? doc.id : null),
                  child: Text(
                    hasDoc ? (isRejected ? 'Re-upload' : 'Replace') : 'Upload',
                    style: TextStyle(
                      color: isRejected ? AppColors.burundiRed : AppColors.burundiGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (hasDoc && doc.originalFilename.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(doc.originalFilename,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
              overflow: TextOverflow.ellipsis),
          ],
          if (isRejected && doc.rejectionReason != null && doc.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.burundiRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(doc.rejectionReason!, style: const TextStyle(fontSize: 12, color: AppColors.burundiRed)),
            ),
          ],
        ],
      ),
    );
  }
}
