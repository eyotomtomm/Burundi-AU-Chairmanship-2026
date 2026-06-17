import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  // Loaded from backend — falls back to defaults if API returns empty
  List<Map<String, dynamic>> _requiredDocs = [];

  static const _defaultDocs = [
    {'type': 'passport', 'label': 'Passport Copy', 'label_fr': 'Copie du Passeport'},
    {'type': 'national_id', 'label': 'National ID', 'label_fr': "Carte d'Identité"},
    {'type': 'photo', 'label': 'Passport Photo', 'label_fr': "Photo d'Identité"},
    {'type': 'cv', 'label': 'CV / Resume', 'label_fr': 'CV / Résumé'},
  ];

  static const _iconMap = {
    'passport': Icons.article_outlined,
    'national_id': Icons.badge_outlined,
    'photo': Icons.photo_camera_outlined,
    'cv': Icons.description_outlined,
    'recommendation': Icons.recommend_outlined,
  };

  /// Returns true if this doc type requires a live camera capture (no gallery/files).
  bool _isCameraOnly(Map<String, dynamic> doc) {
    // Explicit backend flag
    if (doc['camera_only'] == true) return true;
    // Default: 'photo' key always requires live capture
    final key = _docKey(doc);
    return key == 'photo' || key.contains('photo');
  }

  String _isFr() {
    try {
      final locale = Localizations.localeOf(context);
      return locale.languageCode == 'fr' ? 'fr' : 'en';
    } catch (_) {
      return 'en';
    }
  }

  String _docLabel(Map<String, dynamic> doc) {
    if (_isFr() == 'fr') {
      final fr = doc['label_fr'] as String? ?? '';
      if (fr.isNotEmpty) return fr;
    }
    return doc['label'] as String? ?? doc['key'] as String? ?? '';
  }

  IconData _docIcon(Map<String, dynamic> doc) {
    final key = doc['type'] as String? ?? doc['key'] as String? ?? '';
    return _iconMap[key] ?? Icons.insert_drive_file_outlined;
  }

  String _docKey(Map<String, dynamic> doc) {
    return doc['type'] as String? ?? doc['key'] as String? ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    ApiService().youthDialogueLogActivity('screen_visit', 'youth_dialogue_documents');
  }

  Future<void> _loadData() async {
    // Load settings (for required docs) and application status in parallel
    try {
      final results = await Future.wait([
        ApiService().youthDialogueSettings(),
        ApiService().youthDialogueStatus(),
      ]);
      if (!mounted) return;
      final settings = results[0];
      final status = results[1];

      // Parse required_documents from backend
      final configuredDocs = settings['required_documents'];
      if (configuredDocs is List && configuredDocs.isNotEmpty) {
        _requiredDocs = configuredDocs.map<Map<String, dynamic>>((d) {
          final item = d as Map<String, dynamic>;
          return {
            'type': item['key'] ?? '',
            'label': item['label'] ?? '',
            'label_fr': item['label_fr'] ?? '',
            'camera_only': item['camera_only'] ?? false,
          };
        }).toList();
      } else {
        _requiredDocs = List<Map<String, dynamic>>.from(_defaultDocs);
      }

      setState(() {
        if (status['has_application'] == true) {
          _application = YouthDialogueApplication.fromJson(status);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _requiredDocs = List<Map<String, dynamic>>.from(_defaultDocs);
      setState(() {
        _error = 'Failed to load. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatus() async {
    try {
      final data = await ApiService().youthDialogueStatus();
      if (!mounted) return;
      setState(() {
        if (data['has_application'] == true) {
          _application = YouthDialogueApplication.fromJson(data);
        }
      });
    } catch (_) {}
  }

  static const _maxFileSize = 5 * 1024 * 1024; // 5MB

  /// Main entry point for uploading a document.
  /// If the doc is camera_only (e.g. photo), opens camera directly with preview.
  /// Otherwise shows the source picker bottom sheet.
  void _initiateUpload(String docType, Map<String, dynamic> docConfig, {int? replacesId}) {
    if (_isCameraOnly(docConfig)) {
      _capturePhoto(docType, replacesId: replacesId);
    } else {
      _showSourcePicker(docType, replacesId: replacesId);
    }
  }

  /// Live camera capture with preview — for photo documents only.
  /// Loops: camera → preview → retake or accept. Cancel at camera exits.
  Future<void> _capturePhoto(String docType, {int? replacesId}) async {
    final picker = ImagePicker();

    while (mounted) {
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        imageQuality: 90,
      );
      // User cancelled the camera → exit
      if (picked == null || !mounted) return;

      final file = File(picked.path);
      // Show preview for review
      final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _PhotoPreviewScreen(imageFile: file),
        ),
      );

      if (accepted == true && mounted) {
        _uploadFile(file, docType, replacesId: replacesId);
        return;
      }
      // accepted == false → user tapped "Retake" → loop back to camera
      // accepted == null → user pressed back → exit
      if (accepted == null) return;
    }
  }

  void _showSourcePicker(String docType, {int? replacesId}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = _isFr() == 'fr';
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFr ? 'Télécharger le document' : 'Upload Document',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF, JPG, PNG  •  Max 5MB',
                style: TextStyle(fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black45),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: isFr ? 'Caméra' : 'Camera',
                      color: Colors.blue,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickFromCamera(docType, replacesId: replacesId);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: isFr ? 'Galerie' : 'Gallery',
                      color: AppColors.burundiGreen,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickFromGallery(docType, replacesId: replacesId);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.folder_rounded,
                      label: isFr ? 'Fichiers' : 'Files',
                      color: AppColors.auGold,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickFromFiles(docType, replacesId: replacesId);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera(String docType, {int? replacesId}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 2048);
    if (picked == null) return;
    _uploadFile(File(picked.path), docType, replacesId: replacesId);
  }

  Future<void> _pickFromGallery(String docType, {int? replacesId}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (picked == null) return;
    _uploadFile(File(picked.path), docType, replacesId: replacesId);
  }

  Future<void> _pickFromFiles(String docType, {int? replacesId}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    _uploadFile(File(result.files.first.path!), docType, replacesId: replacesId);
  }

  Future<void> _uploadFile(File file, String docType, {int? replacesId}) async {
    // Validate file size (5MB max)
    final fileSize = await file.length();
    if (fileSize > _maxFileSize) {
      if (!mounted) return;
      final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File too large (${sizeMB}MB). Maximum is 5MB.'),
          backgroundColor: AppColors.burundiRed,
        ),
      );
      return;
    }

    setState(() => _uploading[docType] = true);

    try {
      await ApiService().youthDialogueUploadDocument(
        file,
        docType,
        replacesId: replacesId,
      );
      await _loadStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully.'), backgroundColor: AppColors.burundiGreen),
      );
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

  bool _showStatusPage = false;

  Future<void> _submitDocuments() async {
    setState(() => _isSubmitting = true);
    try {
      await ApiService().youthDialogueSubmitDocuments();
      if (!mounted) return;
      setState(() {
        _showStatusPage = true;
        _isSubmitting = false;
      });
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
      if (mounted && _isSubmitting) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStatusPage(bool isDark) {
    final docs = _application?.documents ?? [];
    final docsByType = <String, YouthDialogueDocument>{};
    for (final doc in docs) {
      if (!docsByType.containsKey(doc.documentType) || doc.id > docsByType[doc.documentType]!.id) {
        docsByType[doc.documentType] = doc;
      }
    }
    final uploadedCount = _requiredDocs.where((r) => docsByType.containsKey(_docKey(r))).length;

    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(_isFr() == 'fr' ? 'Documents soumis' : 'Documents Submitted'),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Success icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.burundiGreen),
                ),
                const SizedBox(height: 24),
                Text(
                  'Documents Submitted',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your documents have been submitted for verification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 32),

                // Documents summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 20,
                            color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 8),
                          Text('Documents Uploaded',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.burundiGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$uploadedCount / ${_requiredDocs.length}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.burundiGreen)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._requiredDocs.map((req) {
                        final type = _docKey(req);
                        final label = _docLabel(req);
                        final doc = docsByType[type];
                        final uploaded = doc != null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Icon(
                                uploaded ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                size: 18,
                                color: uploaded ? AppColors.burundiGreen : Colors.grey,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(label, style: TextStyle(fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87)),
                              ),
                              if (uploaded && doc.originalFilename.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    doc.originalFilename,
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.black26),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // What happens next card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 20, color: Colors.blue[400]),
                          const SizedBox(width: 8),
                          Text('What Happens Next',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildStatusStep('1', 'Our team will review your documents', AppColors.burundiGreen, isDark, done: true),
                      _buildStatusStep('2', 'You\'ll receive a notification once verified', AppColors.auGold, isDark),
                      _buildStatusStep('3', 'If any document is rejected, you can re-upload', Colors.blue, isDark),
                      _buildStatusStep('4', 'Once approved, your credential will be issued', AppColors.burundiGreen, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Email note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.auGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.auGold.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 18, color: AppColors.auGold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You will also receive an email confirmation with your verification status.',
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Done button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burundiGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildStatusStep(String number, String text, Color color, bool isDark, {bool done = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: done ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: done
                  ? Icon(Icons.check, size: 14, color: color)
                  : Text(number, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: TextStyle(fontSize: 13.5,
                color: isDark ? Colors.white60 : Colors.black54)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_showStatusPage) {
      return _buildStatusPage(isDark);
    }

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
            onPressed: () { setState(() { _isLoading = true; _error = null; }); _loadData(); },
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
    // Map existing docs by type (keep latest)
    final docsByType = <String, YouthDialogueDocument>{};
    for (final doc in docs) {
      if (!docsByType.containsKey(doc.documentType) || doc.id > docsByType[doc.documentType]!.id) {
        docsByType[doc.documentType] = doc;
      }
    }

    final hasRejectedDocs = docsByType.values.any((d) => d.status == 'rejected');
    final isWaitingState = _application!.status == 'documents_submitted' ||
        _application!.status == 'documents_under_review';
    final isResubmit = _application!.status == 'documents_rejected';

    return Column(
      children: [
        // Waiting state banner
        if (isWaitingState)
          _buildWaitingBanner(isDark),

        // Rejection summary banner
        if (hasRejectedDocs && !isWaitingState)
          _buildRejectionSummaryBanner(isDark, docsByType),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadStatus,
            color: AppColors.burundiGreen,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Required Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text(
                  isWaitingState
                      ? 'Your documents are being reviewed. You will be notified when verification is complete.'
                      : isResubmit
                          ? 'Some documents were rejected. Please re-upload the affected documents and submit again.'
                          : 'Upload the following documents to proceed with your application.',
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                if (!isWaitingState) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16,
                          color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Accepted formats: PDF, JPG, PNG  •  Max 5MB per file',
                            style: TextStyle(fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                ..._requiredDocs.map((req) {
                  final type = _docKey(req);
                  final label = _docLabel(req);
                  final icon = _docIcon(req);
                  final existingDoc = docsByType[type];
                  final isUploading = _uploading[type] == true;

                  return _buildDocSlot(isDark, type, label, icon, existingDoc, isUploading, req);
                }),
              ],
            ),
          ),
        ),

        // Submit button (hide when waiting for review)
        if (!isWaitingState)
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
                      : Text(isResubmit ? 'Re-submit Documents' : 'Submit All Documents',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaitingBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.blue.withValues(alpha: 0.1),
      child: Row(
        children: [
          const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your documents are under review',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: isDark ? Colors.blue[200] : Colors.blue[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionSummaryBanner(bool isDark, Map<String, YouthDialogueDocument> docsByType) {
    final rejectedNames = docsByType.entries
        .where((e) => e.value.status == 'rejected')
        .map((e) {
          // Find label from _requiredDocs config
          final match = _requiredDocs.where((r) => _docKey(r) == e.key);
          if (match.isNotEmpty) return _docLabel(match.first);
          return e.key;
        })
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppColors.burundiRed.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.burundiRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Re-upload required: ${rejectedNames.join(", ")}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: isDark ? Colors.red[200] : AppColors.burundiRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocSlot(bool isDark, String type, String label, IconData icon,
      YouthDialogueDocument? doc, bool isUploading, Map<String, dynamic> docConfig) {
    final hasDoc = doc != null;
    final isRejected = hasDoc && doc.status == 'rejected';
    final isApproved = hasDoc && doc.status == 'approved';
    final isPending = hasDoc && doc.status == 'pending';

    final cameraOnly = _isCameraOnly(docConfig);

    Color statusColor = Colors.grey;
    String statusText = cameraOnly ? 'Live photo required' : 'Not uploaded';
    IconData statusIcon = cameraOnly ? Icons.camera_alt_outlined : Icons.radio_button_unchecked;
    if (hasDoc) {
      switch (doc.status) {
        case 'pending':
          statusColor = AppColors.auGold;
          statusText = 'Under review';
          statusIcon = Icons.hourglass_top_rounded;
          break;
        case 'approved':
          statusColor = AppColors.burundiGreen;
          statusText = 'Approved';
          statusIcon = Icons.check_circle_rounded;
          break;
        case 'rejected':
          statusColor = AppColors.burundiRed;
          statusText = 'Rejected — Re-upload';
          statusIcon = Icons.cancel_rounded;
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isRejected
            ? Border.all(color: AppColors.burundiRed.withValues(alpha: 0.4), width: 1.5)
            : isApproved
                ? Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.3))
                : null,
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isUploading)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              else if (isApproved)
                // Approved docs are locked — show lock icon
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: AppColors.burundiGreen),
                      SizedBox(width: 4),
                      Text('Locked', style: TextStyle(fontSize: 11, color: AppColors.burundiGreen, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else if (isPending)
                // Pending docs — allow replacing in case of wrong upload
                GestureDetector(
                  onTap: () => _initiateUpload(type, docConfig, replacesId: doc.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.auGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.auGold),
                        SizedBox(width: 4),
                        Text('Replace', style: TextStyle(fontSize: 11, color: AppColors.auGold, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _initiateUpload(type, docConfig, replacesId: isRejected ? doc.id : null),
                  icon: cameraOnly && !hasDoc
                      ? Icon(Icons.camera_alt_rounded, size: 16,
                          color: isRejected ? AppColors.burundiRed : AppColors.burundiGreen)
                      : const SizedBox.shrink(),
                  label: Text(
                    hasDoc
                        ? (isRejected ? 'Re-upload' : 'Replace')
                        : (cameraOnly ? 'Take Photo' : 'Upload'),
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
            Row(
              children: [
                Icon(
                  doc.originalFilename.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_outlined,
                  size: 14,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(doc.originalFilename,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                    overflow: TextOverflow.ellipsis),
                ),
                if (doc.fileSize > 0)
                  Text(
                    doc.fileSize >= 1024 * 1024
                        ? '${(doc.fileSize / (1024 * 1024)).toStringAsFixed(1)}MB'
                        : '${(doc.fileSize / 1024).toStringAsFixed(0)}KB',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26),
                  ),
              ],
            ),
          ],
          if (isRejected && doc.rejectionReason != null && doc.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.burundiRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.burundiRed.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rejection reason:', style: TextStyle(fontSize: 11, color: AppColors.burundiRed, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(doc.rejectionReason!, style: const TextStyle(fontSize: 12, color: AppColors.burundiRed)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _initiateUpload(type, docConfig, replacesId: doc.id),
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Re-upload This Document'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.burundiRed,
                  side: const BorderSide(color: AppColors.burundiRed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Photo preview screen — shown after live camera capture so user
// can review and retake before uploading.
// ═══════════════════════════════════════════════════════════════════
class _PhotoPreviewScreen extends StatelessWidget {
  final File imageFile;

  const _PhotoPreviewScreen({required this.imageFile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isFr ? 'Vérifier la photo' : 'Review Photo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // balance
                ],
              ),
            ),

            // Photo preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // Hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isFr
                            ? 'Assurez-vous que votre visage est clairement visible et bien éclairé.'
                            : 'Make sure your face is clearly visible and well-lit.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  // Retake
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: Text(isFr ? 'Reprendre' : 'Retake'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Use this photo
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                        label: Text(
                          isFr ? 'Utiliser cette photo' : 'Use This Photo',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.burundiGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
