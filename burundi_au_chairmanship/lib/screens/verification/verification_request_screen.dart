import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/verification_provider.dart';
import '../../services/api_service.dart' show ApiService, ApiException;
import '../../widgets/confetti_overlay.dart';

class VerificationRequestScreen extends StatefulWidget {
  const VerificationRequestScreen({super.key});

  @override
  State<VerificationRequestScreen> createState() => _VerificationRequestScreenState();
}

class _VerificationRequestScreenState extends State<VerificationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailOtpController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();

  String? _selectedTitle;
  String? _selectedNationality;
  String? _selectedGender;
  String? _selectedBadgeType;
  String _selectedPhoneCode = '+257';
  String _selectedPhoneCountry = 'BI';
  File? _supportingDocument;
  bool _isLoading = false;

  // Email OTP state
  bool _emailVerified = false;
  bool _emailOtpSent = false;
  bool _sendingEmailOtp = false;
  bool _verifyingEmailOtp = false;
  Timer? _emailTimer;
  final ValueNotifier<int> _emailCountdown = ValueNotifier<int>(0);

  // Phone OTP state

  // Social media state — which platforms are toggled on
  final Map<String, bool> _socialMediaActive = {};
  final Map<String, TextEditingController> _socialMediaControllers = {};

  final List<Map<String, String>> _titles = [
    {'value': 'mr', 'label': 'Mr.'},
    {'value': 'mrs', 'label': 'Mrs.'},
    {'value': 'ms', 'label': 'Ms.'},
    {'value': 'dr', 'label': 'Dr.'},
    {'value': 'prof', 'label': 'Prof.'},
    {'value': 'he', 'label': 'H.E. (His/Her Excellency)'},
    {'value': 'amb', 'label': 'Ambassador'},
    {'value': 'hon', 'label': 'Honorable'},
    {'value': 'other', 'label': 'Other'},
  ];

  final List<Map<String, String>> _nationalities = [
    {'code': 'BI', 'name': 'Burundi'},
    {'code': 'DZ', 'name': 'Algeria'},
    {'code': 'AO', 'name': 'Angola'},
    {'code': 'BJ', 'name': 'Benin'},
    {'code': 'BW', 'name': 'Botswana'},
    {'code': 'BF', 'name': 'Burkina Faso'},
    {'code': 'CV', 'name': 'Cabo Verde'},
    {'code': 'CM', 'name': 'Cameroon'},
    {'code': 'CF', 'name': 'Central African Republic'},
    {'code': 'TD', 'name': 'Chad'},
    {'code': 'KM', 'name': 'Comoros'},
    {'code': 'CG', 'name': 'Congo (Brazzaville)'},
    {'code': 'CD', 'name': 'Congo (DRC)'},
    {'code': 'CI', 'name': "Côte d'Ivoire"},
    {'code': 'DJ', 'name': 'Djibouti'},
    {'code': 'EG', 'name': 'Egypt'},
    {'code': 'GQ', 'name': 'Equatorial Guinea'},
    {'code': 'ER', 'name': 'Eritrea'},
    {'code': 'SZ', 'name': 'Eswatini'},
    {'code': 'ET', 'name': 'Ethiopia'},
    {'code': 'GA', 'name': 'Gabon'},
    {'code': 'GM', 'name': 'Gambia'},
    {'code': 'GH', 'name': 'Ghana'},
    {'code': 'GN', 'name': 'Guinea'},
    {'code': 'GW', 'name': 'Guinea-Bissau'},
    {'code': 'KE', 'name': 'Kenya'},
    {'code': 'LS', 'name': 'Lesotho'},
    {'code': 'LR', 'name': 'Liberia'},
    {'code': 'LY', 'name': 'Libya'},
    {'code': 'MG', 'name': 'Madagascar'},
    {'code': 'MW', 'name': 'Malawi'},
    {'code': 'ML', 'name': 'Mali'},
    {'code': 'MR', 'name': 'Mauritania'},
    {'code': 'MU', 'name': 'Mauritius'},
    {'code': 'MA', 'name': 'Morocco'},
    {'code': 'MZ', 'name': 'Mozambique'},
    {'code': 'NA', 'name': 'Namibia'},
    {'code': 'NE', 'name': 'Niger'},
    {'code': 'NG', 'name': 'Nigeria'},
    {'code': 'RW', 'name': 'Rwanda'},
    {'code': 'ST', 'name': 'São Tomé and Príncipe'},
    {'code': 'SN', 'name': 'Senegal'},
    {'code': 'SC', 'name': 'Seychelles'},
    {'code': 'SL', 'name': 'Sierra Leone'},
    {'code': 'SO', 'name': 'Somalia'},
    {'code': 'ZA', 'name': 'South Africa'},
    {'code': 'SS', 'name': 'South Sudan'},
    {'code': 'SD', 'name': 'Sudan'},
    {'code': 'TZ', 'name': 'Tanzania'},
    {'code': 'TG', 'name': 'Togo'},
    {'code': 'TN', 'name': 'Tunisia'},
    {'code': 'UG', 'name': 'Uganda'},
    {'code': 'ZM', 'name': 'Zambia'},
    {'code': 'ZW', 'name': 'Zimbabwe'},
    // International
    {'code': 'US', 'name': 'United States'},
    {'code': 'GB', 'name': 'United Kingdom'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'DE', 'name': 'Germany'},
    {'code': 'CN', 'name': 'China'},
    {'code': 'IN', 'name': 'India'},
    {'code': 'BR', 'name': 'Brazil'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'AU', 'name': 'Australia'},
    {'code': 'JP', 'name': 'Japan'},
    {'code': 'BE', 'name': 'Belgium'},
    {'code': 'IT', 'name': 'Italy'},
    {'code': 'ES', 'name': 'Spain'},
    {'code': 'NL', 'name': 'Netherlands'},
    {'code': 'SE', 'name': 'Sweden'},
    {'code': 'CH', 'name': 'Switzerland'},
    {'code': 'AE', 'name': 'UAE'},
    {'code': 'SA', 'name': 'Saudi Arabia'},
    {'code': 'TR', 'name': 'Turkey'},
    {'code': 'RU', 'name': 'Russia'},
    {'code': 'KR', 'name': 'South Korea'},
    {'code': 'OTHER', 'name': 'Other'},
  ];

  // Phone country codes with dial codes
  static const List<Map<String, String>> _phoneCountryCodes = [
    {'code': 'BI', 'dial': '+257'},
    {'code': 'DZ', 'dial': '+213'},
    {'code': 'AO', 'dial': '+244'},
    {'code': 'BJ', 'dial': '+229'},
    {'code': 'BW', 'dial': '+267'},
    {'code': 'BF', 'dial': '+226'},
    {'code': 'CV', 'dial': '+238'},
    {'code': 'CM', 'dial': '+237'},
    {'code': 'CF', 'dial': '+236'},
    {'code': 'TD', 'dial': '+235'},
    {'code': 'KM', 'dial': '+269'},
    {'code': 'CG', 'dial': '+242'},
    {'code': 'CD', 'dial': '+243'},
    {'code': 'CI', 'dial': '+225'},
    {'code': 'DJ', 'dial': '+253'},
    {'code': 'EG', 'dial': '+20'},
    {'code': 'GQ', 'dial': '+240'},
    {'code': 'ER', 'dial': '+291'},
    {'code': 'SZ', 'dial': '+268'},
    {'code': 'ET', 'dial': '+251'},
    {'code': 'GA', 'dial': '+241'},
    {'code': 'GM', 'dial': '+220'},
    {'code': 'GH', 'dial': '+233'},
    {'code': 'GN', 'dial': '+224'},
    {'code': 'GW', 'dial': '+245'},
    {'code': 'KE', 'dial': '+254'},
    {'code': 'LS', 'dial': '+266'},
    {'code': 'LR', 'dial': '+231'},
    {'code': 'LY', 'dial': '+218'},
    {'code': 'MG', 'dial': '+261'},
    {'code': 'MW', 'dial': '+265'},
    {'code': 'ML', 'dial': '+223'},
    {'code': 'MR', 'dial': '+222'},
    {'code': 'MU', 'dial': '+230'},
    {'code': 'MA', 'dial': '+212'},
    {'code': 'MZ', 'dial': '+258'},
    {'code': 'NA', 'dial': '+264'},
    {'code': 'NE', 'dial': '+227'},
    {'code': 'NG', 'dial': '+234'},
    {'code': 'RW', 'dial': '+250'},
    {'code': 'ST', 'dial': '+239'},
    {'code': 'SN', 'dial': '+221'},
    {'code': 'SC', 'dial': '+248'},
    {'code': 'SL', 'dial': '+232'},
    {'code': 'SO', 'dial': '+252'},
    {'code': 'ZA', 'dial': '+27'},
    {'code': 'SS', 'dial': '+211'},
    {'code': 'SD', 'dial': '+249'},
    {'code': 'TZ', 'dial': '+255'},
    {'code': 'TG', 'dial': '+228'},
    {'code': 'TN', 'dial': '+216'},
    {'code': 'UG', 'dial': '+256'},
    {'code': 'ZM', 'dial': '+260'},
    {'code': 'ZW', 'dial': '+263'},
    {'code': 'US', 'dial': '+1'},
    {'code': 'GB', 'dial': '+44'},
    {'code': 'FR', 'dial': '+33'},
    {'code': 'DE', 'dial': '+49'},
    {'code': 'CN', 'dial': '+86'},
    {'code': 'IN', 'dial': '+91'},
    {'code': 'BR', 'dial': '+55'},
    {'code': 'CA', 'dial': '+1'},
    {'code': 'AU', 'dial': '+61'},
    {'code': 'JP', 'dial': '+81'},
    {'code': 'BE', 'dial': '+32'},
    {'code': 'IT', 'dial': '+39'},
    {'code': 'ES', 'dial': '+34'},
    {'code': 'NL', 'dial': '+31'},
    {'code': 'SE', 'dial': '+46'},
    {'code': 'CH', 'dial': '+41'},
    {'code': 'AE', 'dial': '+971'},
    {'code': 'SA', 'dial': '+966'},
    {'code': 'TR', 'dial': '+90'},
    {'code': 'RU', 'dial': '+7'},
    {'code': 'KR', 'dial': '+82'},
  ];

  /// Convert a 2-letter country code to its flag emoji.
  static String _countryCodeToEmoji(String code) {
    if (code == 'OTHER' || code.length != 2) return '';
    final int first = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  // Social media platforms with icons
  static const List<Map<String, dynamic>> _socialPlatforms = [
    {'key': 'twitter', 'label': 'X', 'icon': Icons.close, 'hint': '@username or https://x.com/...'},
    {'key': 'facebook', 'label': 'Facebook', 'icon': Icons.facebook, 'hint': 'https://facebook.com/...'},
    {'key': 'linkedin', 'label': 'LinkedIn', 'icon': Icons.work_outline, 'hint': 'https://linkedin.com/in/...'},
    {'key': 'instagram', 'label': 'Instagram', 'icon': Icons.camera_alt_outlined, 'hint': '@username or https://instagram.com/...'},
    {'key': 'tiktok', 'label': 'TikTok', 'icon': Icons.music_note_outlined, 'hint': '@username or https://tiktok.com/@...'},
    {'key': 'youtube', 'label': 'YouTube', 'icon': Icons.play_circle_outline, 'hint': 'https://youtube.com/@...'},
    {'key': 'telegram', 'label': 'Telegram', 'icon': Icons.send, 'hint': '@username or https://t.me/...'},
    {'key': 'whatsapp', 'label': 'WhatsApp', 'icon': Icons.phone, 'hint': 'Phone number or link'},
    {'key': 'threads', 'label': 'Threads', 'icon': Icons.alternate_email, 'hint': '@username'},
    {'key': 'other', 'label': 'Other', 'icon': Icons.link, 'hint': 'URL or username'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize social media controllers
    for (final platform in _socialPlatforms) {
      final key = platform['key'] as String;
      _socialMediaActive[key] = false;
      _socialMediaControllers[key] = TextEditingController();
    }
    // Pre-fill from profile data
    final auth = context.read<AuthProvider>();
    if (auth.userName != null && auth.userName!.isNotEmpty) {
      _fullNameController.text = auth.userName!;
    }
    if (auth.phoneNumber != null && auth.phoneNumber!.isNotEmpty) {
      _phoneController.text = auth.phoneNumber!;
    }
    if (auth.gender != null && auth.gender!.isNotEmpty) {
      _selectedGender = auth.gender;
    }
    if (auth.nationality != null && auth.nationality!.isNotEmpty) {
      // Match against the nationality codes in the list
      final code = auth.nationality!;
      if (_nationalities.any((n) => n['code'] == code)) {
        _selectedNationality = code;
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _emailOtpController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _emailTimer?.cancel();
    _emailCountdown.dispose();
    for (final c in _socialMediaControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _startEmailCountdown() {
    _emailCountdown.value = 60;
    _emailTimer?.cancel();
    _emailTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emailCountdown.value > 0) {
        _emailCountdown.value--;
      } else {
        timer.cancel();
      }
    });
  }



  Future<void> _sendEmailOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    setState(() => _sendingEmailOtp = true);
    try {
      final api = ApiService();
      await api.post('otp/send-email/', {'email': email}, auth: true);
      if (mounted) {
        setState(() {
          _emailOtpSent = true;
          _sendingEmailOtp = false;
        });
        _startEmailCountdown();
        _showSuccess('Verification code sent to $email');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingEmailOtp = false);
        String errorMsg;
        if (e is ApiException) {
          errorMsg = e.message;
        } else {
          errorMsg = 'Failed to send verification code. Please check your connection and try again.';
        }
        _showError(errorMsg);
      }
    }
  }

  Future<void> _verifyEmailOtp() async {
    final code = _emailOtpController.text.trim();
    if (code.isEmpty || code.length < 6) {
      _showError('Please enter the 6-digit code');
      return;
    }

    setState(() => _verifyingEmailOtp = true);
    try {
      final api = ApiService();
      await api.post('otp/verify-email/', {
        'email': _emailController.text.trim(),
        'otp_code': code,
      }, auth: true);
      if (mounted) {
        setState(() {
          _emailVerified = true;
          _verifyingEmailOtp = false;
        });
        _showSuccess('Email verified!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifyingEmailOtp = false);
        String errorMsg;
        if (e is ApiException) {
          errorMsg = e.message;
        } else {
          errorMsg = 'Invalid code. Please try again.';
        }
        _showError(errorMsg);
      }
    }
  }



  void _showError(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.burundiRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required bool isDark,
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.burundiGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.burundiRed),
      ),
    );
  }

  Widget _buildPendingStatusScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Verification Status',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, size: 56, color: Colors.orange),
                ),
                const SizedBox(height: 28),
                Text(
                  'Application Under Review',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your verification request has been submitted and is currently being reviewed by our team. You will be notified once a decision is made.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Status: Pending',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.burundiGreen,
                      side: BorderSide(color: AppColors.burundiGreen.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final verificationProvider = context.watch<VerificationProvider>();
    final requestStatus = verificationProvider.requestStatus;

    // If there's a pending request, show status page instead of the form
    if (requestStatus == 'pending') {
      return _buildPendingStatusScreen(isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Verification',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 32),
                _buildBadgeTypeInfo(isDark),
                const SizedBox(height: 32),

                // Title
                _buildTitleField(isDark),
                const SizedBox(height: 20),

                // Full Name
                _buildFullNameField(isDark),
                const SizedBox(height: 20),

                // Nationality
                _buildNationalityField(isDark),
                const SizedBox(height: 20),

                // Gender
                _buildGenderField(isDark),
                const SizedBox(height: 20),

                // Email with OTP
                _buildEmailSection(isDark),
                const SizedBox(height: 20),

                // Phone with OTP
                _buildPhoneSection(isDark),
                const SizedBox(height: 20),

                // Position/Role
                _buildPositionField(isDark),
                const SizedBox(height: 32),

                // Social Media
                _buildSocialMediaSection(isDark),
                const SizedBox(height: 32),

                // Supporting Document (optional)
                _buildDocumentUpload(isDark),
                const SizedBox(height: 32),

                // Notice
                _buildNotice(isDark),
                const SizedBox(height: 32),

                // Submit
                _buildSubmitButton(isDark),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.auGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.workspace_premium_rounded, size: 48, color: AppColors.auGold),
        ),
        const SizedBox(height: 20),
        Text(
          'Get Verified',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.darkBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Apply for a verified badge to stand out as an official representative or notable figure.',
          style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.white60 : Colors.black54),
        ),
      ],
    );
  }

  Widget _buildBadgeTypeInfo(bool isDark) {
    final badgeTypes = [
      {
        'value': 'GOLD',
        'label': 'Gold Badge',
        'description': 'VIPs, Government Officials, Ambassadors',
        'color': const Color(0xFFFFD700),
      },
      {
        'value': 'BLUE',
        'label': 'Blue Badge',
        'description': 'Verified professionals and notable individuals',
        'color': const Color(0xFF1DA1F2),
      },
      {
        'value': 'GREEN',
        'label': 'Green Badge',
        'description': 'Verified community members and contributors',
        'color': const Color(0xFF409843),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Badge Type *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Text(
          'Choose the badge type that best represents your role',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
        ),
        const SizedBox(height: 12),
        ...badgeTypes.map((badge) {
          final isSelected = _selectedBadgeType == badge['value'];
          final badgeColor = badge['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedBadgeType = badge['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? badgeColor.withValues(alpha: 0.1)
                      : (isDark ? AppColors.darkSurface : AppColors.lightBackground),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? badgeColor : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.verified, color: badgeColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge['label'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? badgeColor : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            badge['description'] as String,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? badgeColor : (isDark ? Colors.white30 : Colors.grey[400]!),
                          width: 2,
                        ),
                        color: isSelected ? badgeColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Text(
          'Our team will review your application and may assign a different badge based on your profile.',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildTitleField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Title *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTitle,
          decoration: _inputDecoration(isDark: isDark, hint: 'Select your title', prefixIcon: const Icon(Icons.person_outline)),
          items: _titles.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!))).toList(),
          onChanged: (v) => setState(() => _selectedTitle = v),
          validator: (v) => (v == null || v.isEmpty) ? 'Please select your title' : null,
        ),
      ],
    );
  }

  Widget _buildFullNameField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Full Legal Name *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fullNameController,
          decoration: _inputDecoration(isDark: isDark, hint: 'Enter your full legal name', prefixIcon: const Icon(Icons.badge_outlined)),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter your full name';
            if (v.trim().length < 3) return 'Name must be at least 3 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNationalityField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nationality *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedNationality,
          decoration: _inputDecoration(isDark: isDark, hint: 'Select your nationality', prefixIcon: const Icon(Icons.public)),
          isExpanded: true,
          items: _nationalities.map((n) {
            final flag = _countryCodeToEmoji(n['code']!);
            return DropdownMenuItem(
              value: n['code'],
              child: Text('$flag  ${n['name']}', style: const TextStyle(fontSize: 15)),
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _selectedNationality = v;
              // Auto-sync phone country code when nationality changes
              if (v != null && v != 'OTHER') {
                final match = _phoneCountryCodes.where((c) => c['code'] == v);
                if (match.isNotEmpty) {
                  _selectedPhoneCountry = match.first['code']!;
                  _selectedPhoneCode = match.first['dial']!;
                }
              }
            });
          },
          validator: (v) => (v == null || v.isEmpty) ? 'Please select your nationality' : null,
        ),
      ],
    );
  }

  Widget _buildGenderField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: _inputDecoration(isDark: isDark, hint: 'Select your gender', prefixIcon: const Icon(Icons.person_outline)),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
          ],
          onChanged: (v) => setState(() => _selectedGender = v),
          validator: (v) => (v == null || v.isEmpty) ? 'Please select your gender' : null,
        ),
      ],
    );
  }

  Widget _buildDocumentUpload(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Supporting Document (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Text(
          'Upload a photo of your ID, business card, or other supporting document',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
        ),
        const SizedBox(height: 12),
        if (_supportingDocument != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _supportingDocument!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _supportingDocument = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ] else
          InkWell(
            onTap: _pickDocument,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 32, color: isDark ? Colors.white38 : Colors.grey[500]),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to upload image',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _supportingDocument = File(picked.path));
    }
  }

  // ── Email with inline OTP ──────────────────────────────────

  Widget _buildEmailSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Work/Professional Email *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Text(
          'Use your professional or organizational email (not personal Gmail/Yahoo)',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
        ),
        const SizedBox(height: 8),

        // Email input + Get Code button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_emailVerified,
                decoration: _inputDecoration(
                  isDark: isDark,
                  hint: 'your@email.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: _emailVerified
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : null,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter your email';
                  final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                  if (!emailRegex.hasMatch(v)) return 'Please enter a valid email';
                  return null;
                },
              ),
            ),
            if (!_emailVerified) ...[
              const SizedBox(width: 10),
              ValueListenableBuilder<int>(
                valueListenable: _emailCountdown,
                builder: (context, countdown, _) {
                  return SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_sendingEmailOtp || countdown > 0) ? null : _sendEmailOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burundiGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _sendingEmailOtp
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              countdown > 0 ? '${countdown}s' : 'Get Code',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),

        // OTP input after code sent
        if (_emailOtpSent && !_emailVerified) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration(
                    isDark: isDark,
                    hint: 'Enter 6-digit code',
                    prefixIcon: const Icon(Icons.pin, size: 20),
                  ).copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _verifyingEmailOtp ? null : _verifyEmailOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _verifyingEmailOtp
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],

        // Verified badge
        if (_emailVerified)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Text('Email verified', style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code selector with flag
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPhoneCountry,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  items: _phoneCountryCodes.map((c) {
                    final flag = _countryCodeToEmoji(c['code']!);
                    return DropdownMenuItem(
                      value: c['code'],
                      child: Text(
                        '$flag ${c['dial']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      final match = _phoneCountryCodes.firstWhere((c) => c['code'] == v);
                      setState(() {
                        _selectedPhoneCountry = v;
                        _selectedPhoneCode = match['dial']!;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Phone number input
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration(
                  isDark: isDark,
                  hint: 'Phone number (optional)',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildPositionField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current Position/Role *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _positionController,
          decoration: _inputDecoration(isDark: isDark, hint: 'e.g., Ambassador, Director, Minister', prefixIcon: const Icon(Icons.work_outline)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your current position' : null,
        ),
      ],
    );
  }

  // ── Social Media Section ──────────────────────────────────

  Widget _buildSocialMediaSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Social Media (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text('Tap a platform to add your profile', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
        const SizedBox(height: 16),

        // Platform toggle buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _socialPlatforms.map((platform) {
            final key = platform['key'] as String;
            final isActive = _socialMediaActive[key] ?? false;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _socialMediaActive[key] = !isActive;
                  if (!_socialMediaActive[key]!) {
                    _socialMediaControllers[key]!.clear();
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.burundiGreen.withValues(alpha: 0.15)
                      : (isDark ? AppColors.darkSurface : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppColors.burundiGreen : (isDark ? AppColors.darkDivider : Colors.grey[300]!),
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      platform['icon'] as IconData,
                      size: 16,
                      color: isActive ? AppColors.burundiGreen : (isDark ? Colors.white54 : Colors.grey[600]),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      platform['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? AppColors.burundiGreen : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Input fields for active platforms
        ..._socialPlatforms.where((p) => _socialMediaActive[p['key'] as String] == true).map((platform) {
          final key = platform['key'] as String;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              controller: _socialMediaControllers[key],
              decoration: _inputDecoration(
                isDark: isDark,
                hint: platform['hint'] as String,
                prefixIcon: Icon(platform['icon'] as IconData, size: 20),
              ).copyWith(
                labelText: platform['label'] as String,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.auGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.auGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.auGold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Review typically takes up to 24 hours. You\'ll be notified once your request is reviewed.',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    final canSubmit = _emailVerified && _selectedBadgeType != null;

    return Column(
      children: [
        if (!_emailVerified)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.auGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please verify your email to submit',
                    style: TextStyle(fontSize: 13, color: AppColors.auGold, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        if (_selectedBadgeType == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.auGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please select a badge type',
                    style: TextStyle(fontSize: 13, color: AppColors.auGold, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (canSubmit && !_isLoading) ? _submitRequest : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      SizedBox(width: 8),
                      Icon(Icons.send_rounded, size: 20),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_emailVerified) return;
    if (_selectedBadgeType == null) {
      _showError('Please select a badge type');
      return;
    }
    HapticFeedback.lightImpact();

    setState(() => _isLoading = true);

    try {
      final api = ApiService();

      // Collect active social media
      String? twitterUrl, linkedinUrl, facebookUrl, instagramUrl, tiktokUrl, youtubeUrl, otherSocialUrl;
      for (final platform in _socialPlatforms) {
        final key = platform['key'] as String;
        if (_socialMediaActive[key] == true) {
          final value = _socialMediaControllers[key]!.text.trim();
          if (value.isNotEmpty) {
            switch (key) {
              case 'twitter': twitterUrl = value; break;
              case 'linkedin': linkedinUrl = value; break;
              case 'facebook': facebookUrl = value; break;
              case 'instagram': instagramUrl = value; break;
              case 'tiktok': tiktokUrl = value; break;
              case 'youtube': youtubeUrl = value; break;
              default: otherSocialUrl = value; break;
            }
          }
        }
      }

      // Prepend country code to phone number if provided
      final rawPhone = _phoneController.text.trim();
      final fullPhone = rawPhone.isNotEmpty ? '$_selectedPhoneCode$rawPhone' : '';

      await api.submitVerificationRequest(
        title: _selectedTitle!,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: fullPhone,
        positionRole: _positionController.text.trim(),
        countryCode: _selectedNationality,
        gender: _selectedGender,
        badgeType: _selectedBadgeType,
        twitterUrl: twitterUrl,
        linkedinUrl: linkedinUrl,
        facebookUrl: facebookUrl,
        instagramUrl: instagramUrl,
        tiktokUrl: tiktokUrl,
        youtubeUrl: youtubeUrl,
        otherSocialUrl: otherSocialUrl,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        // Trigger confetti celebration
        ConfettiOverlay.show(context);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle_outline, color: AppColors.burundiGreen, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Request Submitted!')),
              ],
            ),
            content: const Text(
              'Your verification request has been submitted successfully! '
              'Our team will review it within 24 hours and you\'ll be notified of the decision.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.burundiRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
