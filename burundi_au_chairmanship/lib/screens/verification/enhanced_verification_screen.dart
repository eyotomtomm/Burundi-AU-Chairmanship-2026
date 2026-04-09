import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/confetti_overlay.dart';

class EnhancedVerificationScreen extends StatefulWidget {
  const EnhancedVerificationScreen({super.key});

  @override
  State<EnhancedVerificationScreen> createState() => _EnhancedVerificationScreenState();
}

class _EnhancedVerificationScreenState extends State<EnhancedVerificationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers
  final _emailController = TextEditingController();
  final _emailOtpController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _reasoningController = TextEditingController();

  // Social media entries (list of maps with platform and username/URL controllers)
  final List<Map<String, dynamic>> _socialMediaEntries = [];

  // State
  bool _emailVerified = false;
  Timer? _emailTimer;
  int _emailCountdown = 0;

  // Country codes with flags
  @override
  void dispose() {
    _emailController.dispose();
    _emailOtpController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _reasoningController.dispose();
    // Dispose social media controllers
    for (var entry in _socialMediaEntries) {
      (entry['controller'] as TextEditingController).dispose();
    }
    _emailTimer?.cancel();
    super.dispose();
  }

  void _startEmailCountdown() {
    _emailCountdown = 60;
    _emailTimer?.cancel();
    _emailTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emailCountdown > 0) {
        setState(() => _emailCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  static const _blockedDomains = {
    'gmail.com', 'googlemail.com',
    'yahoo.com', 'yahoo.co.uk', 'yahoo.fr', 'yahoo.de', 'yahoo.ca', 'yahoo.in',
    'outlook.com', 'hotmail.com', 'live.com', 'msn.com',
    'aol.com',
    'icloud.com', 'me.com', 'mac.com',
    'protonmail.com', 'proton.me',
    'mail.com',
    'zoho.com',
    'yandex.com', 'yandex.ru',
    'gmx.com', 'gmx.de',
    'mail.ru',
    'qq.com',
    '163.com',
    '126.com',
  };

  bool _isWorkEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return false;
    return !_blockedDomains.contains(parts[1].toLowerCase());
  }

  Future<void> _sendEmailOtp() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    if (!_isWorkEmail(_emailController.text.trim())) {
      _showError('Please use a work/organizational email. Personal emails (Gmail, Yahoo, Outlook, etc.) are not accepted for verification.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService().post('otp/send-email/', {
        'email': _emailController.text,
      }, auth: true);

      if (mounted) {
        _showSuccess('OTP sent to your email!');
        _startEmailCountdown();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to send OTP: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyEmailOtp() async {
    if (_emailOtpController.text.isEmpty) {
      _showError('Please enter the OTP code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService().post('otp/verify-email/', {
        'email': _emailController.text,
        'otp_code': _emailOtpController.text,
      }, auth: true);

      if (mounted) {
        setState(() => _emailVerified = true);
        _showSuccess('Email verified successfully!');

        // Move to next step after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _currentStep++);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Invalid OTP code');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }




  Future<void> _submitVerificationRequest() async {
    // Validate all fields
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      _showError('Please enter your first and last name');
      return;
    }

    if (_reasoningController.text.isEmpty) {
      _showError('Please explain why you deserve the verification badge');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final body = <String, dynamic>{
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'full_name': '${_firstNameController.text} ${_lastNameController.text}'.trim(),
        'email': _emailController.text,
        'position_role': 'User',
        'reasoning_message': _reasoningController.text,
      };

      // Add social media profiles (only non-empty)
      final socialMediaProfiles = _socialMediaEntries
          .where((entry) => (entry['controller'] as TextEditingController).text.trim().isNotEmpty)
          .map((entry) => {
                'platform': entry['platform'],
                'username_or_url': (entry['controller'] as TextEditingController).text.trim(),
              })
          .toList();

      if (socialMediaProfiles.isNotEmpty) {
        body['social_media_profiles'] = socialMediaProfiles;
      }

      await ApiService().post('verification/request/', body, auth: true);

      if (mounted) {
        // Trigger confetti celebration
        ConfettiOverlay.show(context);

        _showSuccess('Verification request submitted successfully!');

        // Navigate back after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to submit request: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Verification'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ),

          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () {
                          setState(() => _currentStep--);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.burundiGreen),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleNext,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.burundiGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_getNextButtonText()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? AppColors.burundiGreen
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 3) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildEmailVerificationStep();
      case 1:
        return _buildPersonalInfoStep();
      case 2:
        return _buildSocialMediaStep();
      case 3:
        return _buildReasoningStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildEmailVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.email,
          title: 'Verify Your Work Email',
          subtitle: 'Use your professional/organizational email. Personal emails (Gmail, Yahoo, etc.) are not accepted.',
        ),
        const SizedBox(height: 32),

        // Email Input
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Work Email Address',
            hintText: 'name@organization.org',
            prefixIcon: const Icon(Icons.email_outlined),
            suffixIcon: _emailVerified
                ? const Icon(Icons.check_circle, color: AppColors.success)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey[100],
          ),
          enabled: !_emailVerified,
        ),
        const SizedBox(height: 16),

        // Send OTP Button
        if (!_emailVerified)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _emailCountdown > 0 ? null : _sendEmailOtp,
              icon: const Icon(Icons.send),
              label: Text(
                _emailCountdown > 0
                    ? 'Resend in $_emailCountdown seconds'
                    : 'Send Verification Code',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.burundiGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),

        if (_emailCountdown > 0) ...[
          const SizedBox(height: 24),
          AutofillGroup(
            child: TextField(
              controller: _emailOtpController,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Enter 6-Digit Code',
                hintText: '123456',
                prefixIcon: const Icon(Icons.pin),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey[100],
                counterText: '',
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _verifyEmailOtp,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Verify Code'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.person,
          title: 'Personal Information',
          subtitle: 'Enter your name for identity verification',
        ),
        const SizedBox(height: 32),

        // First Name
        TextField(
          controller: _firstNameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'First Name',
            hintText: 'John',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey[100],
          ),
        ),
        const SizedBox(height: 16),

        // Last Name
        TextField(
          controller: _lastNameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Last Name',
            hintText: 'Doe',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey[100],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialMediaStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.share,
          title: 'Social Media',
          subtitle: 'Select your platforms and add your username or profile link',
        ),
        const SizedBox(height: 24),

        // Info card
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add the social media platforms you have. You can enter just your username or the full profile URL.',
                  style: TextStyle(fontSize: 13, color: AppColors.info, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        // List of added social media entries
        if (_socialMediaEntries.isNotEmpty) ...[
          ..._socialMediaEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSocialMediaEntry(index, data, isDark),
            );
          }),
          const SizedBox(height: 8),
        ],

        // Add social media button
        OutlinedButton.icon(
          onPressed: _addSocialMediaEntry,
          icon: const Icon(Icons.add, size: 20),
          label: Text(_socialMediaEntries.isEmpty ? 'Add Social Media' : 'Add Another'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            side: BorderSide(color: AppColors.burundiGreen),
            foregroundColor: AppColors.burundiGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialMediaEntry(int index, Map<String, dynamic> data, bool isDark) {
    final platforms = [
      {'value': 'twitter', 'label': 'X (Twitter)', 'icon': Icons.close},
      {'value': 'facebook', 'label': 'Facebook', 'icon': Icons.facebook},
      {'value': 'linkedin', 'label': 'LinkedIn', 'icon': Icons.work_outline},
      {'value': 'instagram', 'label': 'Instagram', 'icon': Icons.camera_alt_outlined},
      {'value': 'tiktok', 'label': 'TikTok', 'icon': Icons.music_note_outlined},
      {'value': 'youtube', 'label': 'YouTube', 'icon': Icons.play_circle_outline},
      {'value': 'telegram', 'label': 'Telegram', 'icon': Icons.send},
      {'value': 'whatsapp', 'label': 'WhatsApp', 'icon': Icons.phone},
      {'value': 'threads', 'label': 'Threads', 'icon': Icons.alternate_email},
      {'value': 'other', 'label': 'Other', 'icon': Icons.link},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: data['platform'],
                  decoration: InputDecoration(
                    labelText: 'Platform',
                    prefixIcon: Icon(
                      platforms.firstWhere((p) => p['value'] == data['platform'])['icon'] as IconData,
                      size: 20,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: platforms.map((platform) {
                    return DropdownMenuItem<String>(
                      value: platform['value'] as String,
                      child: Text(platform['label'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        data['platform'] = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _removeSocialMediaEntry(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: data['controller'] as TextEditingController,
            decoration: InputDecoration(
              labelText: 'Username or URL',
              hintText: '@username or https://...',
              prefixIcon: const Icon(Icons.alternate_email, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _addSocialMediaEntry() {
    setState(() {
      _socialMediaEntries.add({
        'platform': 'twitter',
        'controller': TextEditingController(),
      });
    });
  }

  void _removeSocialMediaEntry(int index) {
    setState(() {
      final entry = _socialMediaEntries[index];
      (entry['controller'] as TextEditingController).dispose();
      _socialMediaEntries.removeAt(index);
    });
  }

  Widget _buildReasoningStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.message,
          title: 'Tell Us Why',
          subtitle: 'Explain why you deserve the verification badge',
        ),
        const SizedBox(height: 32),

        TextField(
          controller: _reasoningController,
          maxLines: 8,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: 'Your Message',
            hintText: 'I am a government official working on...',
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey[100],
          ),
        ),
        const SizedBox(height: 16),

        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Process',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Our team will review your request and verify your credentials. This usually takes 2-3 business days.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.info,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.burundiGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 48,
            color: AppColors.burundiGreen,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white60
                : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return _emailVerified ? 'Continue' : 'Verify Email First';
      case 1:
        return 'Continue';
      case 2:
        return 'Continue';
      case 3:
        return 'Submit Request';
      default:
        return 'Next';
    }
  }

  void _handleNext() {
    switch (_currentStep) {
      case 0:
        if (!_emailVerified) {
          _showError('Please verify your email first');
          return;
        }
        setState(() => _currentStep++);
        break;
      case 1:
        if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
          _showError('Please enter your first and last name');
          return;
        }
        setState(() => _currentStep++);
        break;
      case 2:
        // Social media step - optional, always allow continue
        setState(() => _currentStep++);
        break;
      case 3:
        _submitVerificationRequest();
        break;
    }
  }
}
