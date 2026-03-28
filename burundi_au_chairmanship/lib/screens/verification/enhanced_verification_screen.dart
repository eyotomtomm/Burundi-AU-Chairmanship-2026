import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

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
  final _phoneController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  final _reasoningController = TextEditingController();

  // Social media controllers
  final _twitterController = TextEditingController();
  final _facebookController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _otherSocialController = TextEditingController();

  // State
  String _selectedCountryCode = '+257'; // Burundi default
  bool _emailVerified = false;
  bool _phoneVerified = false;
  Timer? _emailTimer;
  Timer? _phoneTimer;
  int _emailCountdown = 0;
  int _phoneCountdown = 0;

  // Country codes with flags
  final List<Map<String, String>> _countryCodes = [
    // Burundi first (host country)
    {'name': 'Burundi', 'code': '+257', 'flag': '🇧🇮'},
    // African Union member states
    {'name': 'Algeria', 'code': '+213', 'flag': '🇩🇿'},
    {'name': 'Angola', 'code': '+244', 'flag': '🇦🇴'},
    {'name': 'Benin', 'code': '+229', 'flag': '🇧🇯'},
    {'name': 'Botswana', 'code': '+267', 'flag': '🇧🇼'},
    {'name': 'Burkina Faso', 'code': '+226', 'flag': '🇧🇫'},
    {'name': 'Cabo Verde', 'code': '+238', 'flag': '🇨🇻'},
    {'name': 'Cameroon', 'code': '+237', 'flag': '🇨🇲'},
    {'name': 'Central African Republic', 'code': '+236', 'flag': '🇨🇫'},
    {'name': 'Chad', 'code': '+235', 'flag': '🇹🇩'},
    {'name': 'Comoros', 'code': '+269', 'flag': '🇰🇲'},
    {'name': 'Congo (Brazzaville)', 'code': '+242', 'flag': '🇨🇬'},
    {'name': 'Congo (DRC)', 'code': '+243', 'flag': '🇨🇩'},
    {'name': "Côte d'Ivoire", 'code': '+225', 'flag': '🇨🇮'},
    {'name': 'Djibouti', 'code': '+253', 'flag': '🇩🇯'},
    {'name': 'Egypt', 'code': '+20', 'flag': '🇪🇬'},
    {'name': 'Equatorial Guinea', 'code': '+240', 'flag': '🇬🇶'},
    {'name': 'Eritrea', 'code': '+291', 'flag': '🇪🇷'},
    {'name': 'Eswatini', 'code': '+268', 'flag': '🇸🇿'},
    {'name': 'Ethiopia', 'code': '+251', 'flag': '🇪🇹'},
    {'name': 'Gabon', 'code': '+241', 'flag': '🇬🇦'},
    {'name': 'Gambia', 'code': '+220', 'flag': '🇬🇲'},
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Guinea', 'code': '+224', 'flag': '🇬🇳'},
    {'name': 'Guinea-Bissau', 'code': '+245', 'flag': '🇬🇼'},
    {'name': 'Kenya', 'code': '+254', 'flag': '🇰🇪'},
    {'name': 'Lesotho', 'code': '+266', 'flag': '🇱🇸'},
    {'name': 'Liberia', 'code': '+231', 'flag': '🇱🇷'},
    {'name': 'Libya', 'code': '+218', 'flag': '🇱🇾'},
    {'name': 'Madagascar', 'code': '+261', 'flag': '🇲🇬'},
    {'name': 'Malawi', 'code': '+265', 'flag': '🇲🇼'},
    {'name': 'Mali', 'code': '+223', 'flag': '🇲🇱'},
    {'name': 'Mauritania', 'code': '+222', 'flag': '🇲🇷'},
    {'name': 'Mauritius', 'code': '+230', 'flag': '🇲🇺'},
    {'name': 'Morocco', 'code': '+212', 'flag': '🇲🇦'},
    {'name': 'Mozambique', 'code': '+258', 'flag': '🇲🇿'},
    {'name': 'Namibia', 'code': '+264', 'flag': '🇳🇦'},
    {'name': 'Niger', 'code': '+227', 'flag': '🇳🇪'},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'Rwanda', 'code': '+250', 'flag': '🇷🇼'},
    {'name': 'São Tomé and Príncipe', 'code': '+239', 'flag': '🇸🇹'},
    {'name': 'Senegal', 'code': '+221', 'flag': '🇸🇳'},
    {'name': 'Seychelles', 'code': '+248', 'flag': '🇸🇨'},
    {'name': 'Sierra Leone', 'code': '+232', 'flag': '🇸🇱'},
    {'name': 'Somalia', 'code': '+252', 'flag': '🇸🇴'},
    {'name': 'South Africa', 'code': '+27', 'flag': '🇿🇦'},
    {'name': 'South Sudan', 'code': '+211', 'flag': '🇸🇸'},
    {'name': 'Sudan', 'code': '+249', 'flag': '🇸🇩'},
    {'name': 'Tanzania', 'code': '+255', 'flag': '🇹🇿'},
    {'name': 'Togo', 'code': '+228', 'flag': '🇹🇬'},
    {'name': 'Tunisia', 'code': '+216', 'flag': '🇹🇳'},
    {'name': 'Uganda', 'code': '+256', 'flag': '🇺🇬'},
    {'name': 'Zambia', 'code': '+260', 'flag': '🇿🇲'},
    {'name': 'Zimbabwe', 'code': '+263', 'flag': '🇿🇼'},
    // Major international countries
    {'name': 'Afghanistan', 'code': '+93', 'flag': '🇦🇫'},
    {'name': 'Argentina', 'code': '+54', 'flag': '🇦🇷'},
    {'name': 'Australia', 'code': '+61', 'flag': '🇦🇺'},
    {'name': 'Austria', 'code': '+43', 'flag': '🇦🇹'},
    {'name': 'Bangladesh', 'code': '+880', 'flag': '🇧🇩'},
    {'name': 'Belgium', 'code': '+32', 'flag': '🇧🇪'},
    {'name': 'Brazil', 'code': '+55', 'flag': '🇧🇷'},
    {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦'},
    {'name': 'China', 'code': '+86', 'flag': '🇨🇳'},
    {'name': 'Colombia', 'code': '+57', 'flag': '🇨🇴'},
    {'name': 'Cuba', 'code': '+53', 'flag': '🇨🇺'},
    {'name': 'Denmark', 'code': '+45', 'flag': '🇩🇰'},
    {'name': 'Finland', 'code': '+358', 'flag': '🇫🇮'},
    {'name': 'France', 'code': '+33', 'flag': '🇫🇷'},
    {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪'},
    {'name': 'Greece', 'code': '+30', 'flag': '🇬🇷'},
    {'name': 'India', 'code': '+91', 'flag': '🇮🇳'},
    {'name': 'Indonesia', 'code': '+62', 'flag': '🇮🇩'},
    {'name': 'Iran', 'code': '+98', 'flag': '🇮🇷'},
    {'name': 'Iraq', 'code': '+964', 'flag': '🇮🇶'},
    {'name': 'Ireland', 'code': '+353', 'flag': '🇮🇪'},
    {'name': 'Israel', 'code': '+972', 'flag': '🇮🇱'},
    {'name': 'Italy', 'code': '+39', 'flag': '🇮🇹'},
    {'name': 'Jamaica', 'code': '+1876', 'flag': '🇯🇲'},
    {'name': 'Japan', 'code': '+81', 'flag': '🇯🇵'},
    {'name': 'Jordan', 'code': '+962', 'flag': '🇯🇴'},
    {'name': 'Kuwait', 'code': '+965', 'flag': '🇰🇼'},
    {'name': 'Lebanon', 'code': '+961', 'flag': '🇱🇧'},
    {'name': 'Malaysia', 'code': '+60', 'flag': '🇲🇾'},
    {'name': 'Mexico', 'code': '+52', 'flag': '🇲🇽'},
    {'name': 'Netherlands', 'code': '+31', 'flag': '🇳🇱'},
    {'name': 'New Zealand', 'code': '+64', 'flag': '🇳🇿'},
    {'name': 'Norway', 'code': '+47', 'flag': '🇳🇴'},
    {'name': 'Oman', 'code': '+968', 'flag': '🇴🇲'},
    {'name': 'Pakistan', 'code': '+92', 'flag': '🇵🇰'},
    {'name': 'Palestine', 'code': '+970', 'flag': '🇵🇸'},
    {'name': 'Peru', 'code': '+51', 'flag': '🇵🇪'},
    {'name': 'Philippines', 'code': '+63', 'flag': '🇵🇭'},
    {'name': 'Poland', 'code': '+48', 'flag': '🇵🇱'},
    {'name': 'Portugal', 'code': '+351', 'flag': '🇵🇹'},
    {'name': 'Qatar', 'code': '+974', 'flag': '🇶🇦'},
    {'name': 'Romania', 'code': '+40', 'flag': '🇷🇴'},
    {'name': 'Russia', 'code': '+7', 'flag': '🇷🇺'},
    {'name': 'Saudi Arabia', 'code': '+966', 'flag': '🇸🇦'},
    {'name': 'Singapore', 'code': '+65', 'flag': '🇸🇬'},
    {'name': 'South Korea', 'code': '+82', 'flag': '🇰🇷'},
    {'name': 'Spain', 'code': '+34', 'flag': '🇪🇸'},
    {'name': 'Sri Lanka', 'code': '+94', 'flag': '🇱🇰'},
    {'name': 'Sweden', 'code': '+46', 'flag': '🇸🇪'},
    {'name': 'Switzerland', 'code': '+41', 'flag': '🇨🇭'},
    {'name': 'Thailand', 'code': '+66', 'flag': '🇹🇭'},
    {'name': 'Turkey', 'code': '+90', 'flag': '🇹🇷'},
    {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪'},
    {'name': 'UK', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'Ukraine', 'code': '+380', 'flag': '🇺🇦'},
    {'name': 'USA', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'Venezuela', 'code': '+58', 'flag': '🇻🇪'},
    {'name': 'Vietnam', 'code': '+84', 'flag': '🇻🇳'},
    {'name': 'Yemen', 'code': '+967', 'flag': '🇾🇪'},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _emailOtpController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _phoneOtpController.dispose();
    _reasoningController.dispose();
    _twitterController.dispose();
    _facebookController.dispose();
    _linkedinController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();
    _otherSocialController.dispose();
    _emailTimer?.cancel();
    _phoneTimer?.cancel();
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

  void _startPhoneCountdown() {
    _phoneCountdown = 60;
    _phoneTimer?.cancel();
    _phoneTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_phoneCountdown > 0) {
        setState(() => _phoneCountdown--);
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

  Future<void> _sendPhoneOtp() async {
    if (_phoneController.text.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService().post('otp/send-phone/', {
        'country_code': _selectedCountryCode,
        'phone_number': _phoneController.text,
      }, auth: true);

      if (mounted) {
        _showSuccess('OTP sent to your phone!');
        _startPhoneCountdown();
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

  Future<void> _verifyPhoneOtp() async {
    if (_phoneOtpController.text.isEmpty) {
      _showError('Please enter the OTP code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService().post('otp/verify-phone/', {
        'country_code': _selectedCountryCode,
        'phone_number': _phoneController.text,
        'otp_code': _phoneOtpController.text,
      }, auth: true);

      if (mounted) {
        setState(() => _phoneVerified = true);
        _showSuccess('Phone verified successfully!');

        // Move to next step
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
        'country_code': _selectedCountryCode,
        'phone_number': _phoneController.text,
        'position_role': 'User',
        'reasoning_message': _reasoningController.text,
      };

      // Add social media URLs (only non-empty)
      if (_twitterController.text.isNotEmpty) body['twitter_url'] = _twitterController.text;
      if (_facebookController.text.isNotEmpty) body['facebook_url'] = _facebookController.text;
      if (_linkedinController.text.isNotEmpty) body['linkedin_url'] = _linkedinController.text;
      if (_instagramController.text.isNotEmpty) body['instagram_url'] = _instagramController.text;
      if (_tiktokController.text.isNotEmpty) body['tiktok_url'] = _tiktokController.text;
      if (_youtubeController.text.isNotEmpty) body['youtube_url'] = _youtubeController.text;
      if (_otherSocialController.text.isNotEmpty) body['other_social_url'] = _otherSocialController.text;

      await ApiService().post('verification/request/', body, auth: true);

      if (mounted) {
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
        children: List.generate(5, (index) {
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
                if (index < 4) const SizedBox(width: 8),
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
        return _buildPhoneVerificationStep();
      case 3:
        return _buildSocialMediaStep();
      case 4:
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

  Widget _buildPhoneVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.phone_android,
          title: 'Verify Your Phone',
          subtitle: 'We\'ll send an SMS code to your phone number',
        ),
        const SizedBox(height: 32),

        // Country Code + Phone Number Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country Code Selector
            InkWell(
              onTap: _phoneVerified ? null : _showCountryCodePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white24
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _countryCodes.firstWhere(
                        (c) => c['code'] == _selectedCountryCode,
                        orElse: () => _countryCodes[0],
                      )['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCountryCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : Colors.grey[600]),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Phone Number
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '123456789',
                  prefixIcon: const Icon(Icons.phone),
                  suffixIcon: _phoneVerified
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
                enabled: !_phoneVerified,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Send OTP Button
        if (!_phoneVerified)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _phoneCountdown > 0 ? null : _sendPhoneOtp,
              icon: const Icon(Icons.sms),
              label: Text(
                _phoneCountdown > 0
                    ? 'Resend in $_phoneCountdown seconds'
                    : 'Send SMS Code',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.burundiGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),

        if (_phoneCountdown > 0) ...[
          const SizedBox(height: 24),
          AutofillGroup(
            child: TextField(
              controller: _phoneOtpController,
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
              onPressed: _verifyPhoneOtp,
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

  Widget _buildSocialMediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.share,
          title: 'Social Media',
          subtitle: 'Link your social profiles to help verify your identity',
        ),
        const SizedBox(height: 24),

        // Info card
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 24),
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
                  'At least one social media profile is recommended. All fields are optional.',
                  style: TextStyle(fontSize: 13, color: AppColors.info, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        _buildSocialField(
          controller: _twitterController,
          label: 'X (Twitter)',
          hint: 'https://x.com/username',
          icon: Icons.close, // X icon
        ),
        const SizedBox(height: 14),

        _buildSocialField(
          controller: _facebookController,
          label: 'Facebook',
          hint: 'https://facebook.com/username',
          icon: Icons.facebook,
        ),
        const SizedBox(height: 14),

        _buildSocialField(
          controller: _linkedinController,
          label: 'LinkedIn',
          hint: 'https://linkedin.com/in/username',
          icon: Icons.work_outline,
        ),
        const SizedBox(height: 14),

        _buildSocialField(
          controller: _instagramController,
          label: 'Instagram',
          hint: 'https://instagram.com/username',
          icon: Icons.camera_alt_outlined,
        ),
        const SizedBox(height: 14),

        _buildSocialField(
          controller: _tiktokController,
          label: 'TikTok',
          hint: 'https://tiktok.com/@username',
          icon: Icons.music_note_outlined,
        ),
        const SizedBox(height: 14),

        _buildSocialField(
          controller: _youtubeController,
          label: 'YouTube',
          hint: 'https://youtube.com/@channel',
          icon: Icons.play_circle_outline,
        ),
        const SizedBox(height: 14),

        _buildSocialField(
          controller: _otherSocialController,
          label: 'Other',
          hint: 'https://...',
          icon: Icons.link,
        ),
      ],
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
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

  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Select Country',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _countryCodes.length,
                  itemBuilder: (context, index) {
                    final country = _countryCodes[index];
                    final isSelected = country['code'] == _selectedCountryCode;

                    return ListTile(
                      leading: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 32),
                      ),
                      title: Text(country['name']!),
                      trailing: Text(
                        country['code']!,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.burundiGreen : null,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppColors.burundiGreen.withValues(alpha: 0.1),
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = country['code']!;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return _emailVerified ? 'Continue' : 'Verify Email First';
      case 1:
        return 'Continue';
      case 2:
        return _phoneVerified ? 'Continue' : 'Verify Phone First';
      case 3:
        return 'Continue';
      case 4:
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
        if (!_phoneVerified) {
          _showError('Please verify your phone number first');
          return;
        }
        setState(() => _currentStep++);
        break;
      case 3:
        // Social media step - optional, always allow continue
        setState(() => _currentStep++);
        break;
      case 4:
        _submitVerificationRequest();
        break;
    }
  }
}
