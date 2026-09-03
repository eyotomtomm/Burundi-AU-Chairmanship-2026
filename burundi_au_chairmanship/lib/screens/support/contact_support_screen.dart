import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/input_sanitizer.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Auto-fill email from user profile and pre-fill subject from route argument
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.userEmail != null) {
        _emailController.text = authProvider.userEmail!;
      }
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _subjectController.text = args;
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitSupport() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    setState(() => _isSubmitting = true);

    try {
      final api = ApiService();

      // Create a real support ticket (sanitize before sending)
      await api.createTicket(
        InputSanitizer.sanitizeSubject(_subjectController.text),
        InputSanitizer.sanitizeMessage(_messageController.text),
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true); // Return true to signal ticket created
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support ticket submitted! We\'ll respond via email.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: const Text('Contact support')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            DsCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  DsIconSquare(Icons.support_agent_rounded,
                      tint: Ds.tint(context),
                      color: Ds.green,
                      size: 44,
                      radius: Ds.rTile),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('How can we help?',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Ds.ink(context))),
                        const SizedBox(height: 3),
                        Text('We typically respond within 24 hours',
                            style: Ds.cardBody(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _field(
              controller: _emailController,
              label: 'EMAIL',
              hint: 'your.email@example.com',
              icon: Icons.mail_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: InputSanitizer.validateEmail,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _subjectController,
              label: 'SUBJECT',
              hint: 'Brief description of your issue',
              icon: Icons.subject_rounded,
              maxLength: InputSanitizer.maxSubjectLength,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a subject';
                }
                if (value.trim().length < 3) {
                  return 'Subject must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            _field(
              controller: _messageController,
              label: 'MESSAGE',
              hint: 'Describe your issue or question in detail…',
              icon: Icons.chat_rounded,
              maxLines: 6,
              maxLength: InputSanitizer.maxMessageLength,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your message';
                }
                if (value.trim().length < 10) {
                  return 'Please provide more details (at least 10 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            if (_isSubmitting)
              const Center(
                  child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green)))
            else
              DsPrimaryButton('Submit request',
                  radius: 14, onTap: _submitSupport),
          ],
        ),
      ),
    );
  }

  /// White card field with the comp's small-caps label and green leading icon.
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return DsCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(icon, size: 20, color: Ds.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              maxLength: maxLength,
              validator: validator,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Ds.ink(context)),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Ds.muted(context)),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Ds.muted(context)),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
