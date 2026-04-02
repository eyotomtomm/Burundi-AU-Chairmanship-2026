import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

/// Two-step verification gate:
///   Step 1 – Email OTP  (mandatory)
///   Step 2 – Phone OTP via SMS or WhatsApp  (can be skipped, controlled by backend)
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // ── Shared state ──────────────────────────────────────────
  int _step = 1; // 1 = email, 2 = phone
  String? _errorMessage;

  // ── Backend toggles ───────────────────────────────────────
  bool _smsEnabled = false;
  bool _whatsappEnabled = false;

  // ── Step 1 – Email ────────────────────────────────────────
  final _emailOtpController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _emailOtpSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  // ── Step 2 – Phone ────────────────────────────────────────
  final _phoneController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  String _selectedCountryCode = '+257';
  String _selectedChannel = 'sms'; // 'sms' or 'whatsapp'
  bool _phoneSending = false;
  bool _phoneVerifying = false;
  bool _phoneOtpSent = false;
  int _phoneResendCountdown = 0;
  Timer? _phoneCountdownTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final api = ApiService();
      final settings = await api.getSettings();
      if (mounted && settings != null) {
        setState(() {
          _smsEnabled = settings.smsVerificationEnabled;
          _whatsappEnabled = settings.whatsappVerificationEnabled;
          // Default channel to whichever is enabled
          if (_smsEnabled) {
            _selectedChannel = 'sms';
          } else if (_whatsappEnabled) {
            _selectedChannel = 'whatsapp';
          }
        });
      }
    } catch (_) {
      // If settings fail to load, phone step will be skipped
      // If settings fail to load, phone step stays disabled (skipped)
    }
  }

  bool get _phoneStepEnabled => _smsEnabled || _whatsappEnabled;

  // Full country code list
  static const _countryCodes = [
    ('+257', '🇧🇮', 'Burundi'),
    ('+250', '🇷🇼', 'Rwanda'),
    ('+243', '🇨🇩', 'DR Congo'),
    ('+255', '🇹🇿', 'Tanzania'),
    ('+256', '🇺🇬', 'Uganda'),
    ('+254', '🇰🇪', 'Kenya'),
    ('+251', '🇪🇹', 'Ethiopia'),
    ('+252', '🇸🇴', 'Somalia'),
    ('+253', '🇩🇯', 'Djibouti'),
    ('+291', '🇪🇷', 'Eritrea'),
    ('+249', '🇸🇩', 'Sudan'),
    ('+211', '🇸🇸', 'South Sudan'),
    ('+27', '🇿🇦', 'South Africa'),
    ('+234', '🇳🇬', 'Nigeria'),
    ('+233', '🇬🇭', 'Ghana'),
    ('+225', '🇨🇮', 'Côte d\'Ivoire'),
    ('+221', '🇸🇳', 'Senegal'),
    ('+237', '🇨🇲', 'Cameroon'),
    ('+20', '🇪🇬', 'Egypt'),
    ('+212', '🇲🇦', 'Morocco'),
    ('+216', '🇹🇳', 'Tunisia'),
    ('+213', '🇩🇿', 'Algeria'),
    ('+218', '🇱🇾', 'Libya'),
    ('+231', '🇱🇷', 'Liberia'),
    ('+232', '🇸🇱', 'Sierra Leone'),
    ('+226', '🇧🇫', 'Burkina Faso'),
    ('+227', '🇳🇪', 'Niger'),
    ('+223', '🇲🇱', 'Mali'),
    ('+222', '🇲🇷', 'Mauritania'),
    ('+228', '🇹🇬', 'Togo'),
    ('+229', '🇧🇯', 'Benin'),
    ('+235', '🇹🇩', 'Chad'),
    ('+236', '🇨🇫', 'Central African Rep.'),
    ('+241', '🇬🇦', 'Gabon'),
    ('+242', '🇨🇬', 'Congo'),
    ('+240', '🇬🇶', 'Equatorial Guinea'),
    ('+244', '🇦🇴', 'Angola'),
    ('+258', '🇲🇿', 'Mozambique'),
    ('+260', '🇿🇲', 'Zambia'),
    ('+263', '🇿🇼', 'Zimbabwe'),
    ('+265', '🇲🇼', 'Malawi'),
    ('+261', '🇲🇬', 'Madagascar'),
    ('+230', '🇲🇺', 'Mauritius'),
    ('+267', '🇧🇼', 'Botswana'),
    ('+264', '🇳🇦', 'Namibia'),
    ('+266', '🇱🇸', 'Lesotho'),
    ('+268', '🇸🇿', 'Eswatini'),
    ('+248', '🇸🇨', 'Seychelles'),
    ('+269', '🇰🇲', 'Comoros'),
    ('+1', '🇺🇸', 'USA / Canada'),
    ('+44', '🇬🇧', 'United Kingdom'),
    ('+33', '🇫🇷', 'France'),
    ('+32', '🇧🇪', 'Belgium'),
    ('+49', '🇩🇪', 'Germany'),
    ('+31', '🇳🇱', 'Netherlands'),
    ('+39', '🇮🇹', 'Italy'),
    ('+34', '🇪🇸', 'Spain'),
    ('+351', '🇵🇹', 'Portugal'),
    ('+41', '🇨🇭', 'Switzerland'),
    ('+46', '🇸🇪', 'Sweden'),
    ('+47', '🇳🇴', 'Norway'),
    ('+45', '🇩🇰', 'Denmark'),
    ('+358', '🇫🇮', 'Finland'),
    ('+43', '🇦🇹', 'Austria'),
    ('+48', '🇵🇱', 'Poland'),
    ('+353', '🇮🇪', 'Ireland'),
    ('+30', '🇬🇷', 'Greece'),
    ('+40', '🇷🇴', 'Romania'),
    ('+380', '🇺🇦', 'Ukraine'),
    ('+7', '🇷🇺', 'Russia'),
    ('+90', '🇹🇷', 'Turkey'),
    ('+86', '🇨🇳', 'China'),
    ('+91', '🇮🇳', 'India'),
    ('+81', '🇯🇵', 'Japan'),
    ('+82', '🇰🇷', 'South Korea'),
    ('+65', '🇸🇬', 'Singapore'),
    ('+60', '🇲🇾', 'Malaysia'),
    ('+62', '🇮🇩', 'Indonesia'),
    ('+63', '🇵🇭', 'Philippines'),
    ('+66', '🇹🇭', 'Thailand'),
    ('+84', '🇻🇳', 'Vietnam'),
    ('+880', '🇧🇩', 'Bangladesh'),
    ('+92', '🇵🇰', 'Pakistan'),
    ('+94', '🇱🇰', 'Sri Lanka'),
    ('+971', '🇦🇪', 'UAE'),
    ('+966', '🇸🇦', 'Saudi Arabia'),
    ('+974', '🇶🇦', 'Qatar'),
    ('+968', '🇴🇲', 'Oman'),
    ('+965', '🇰🇼', 'Kuwait'),
    ('+973', '🇧🇭', 'Bahrain'),
    ('+962', '🇯🇴', 'Jordan'),
    ('+961', '🇱🇧', 'Lebanon'),
    ('+964', '🇮🇶', 'Iraq'),
    ('+972', '🇮🇱', 'Israel'),
    ('+55', '🇧🇷', 'Brazil'),
    ('+54', '🇦🇷', 'Argentina'),
    ('+52', '🇲🇽', 'Mexico'),
    ('+57', '🇨🇴', 'Colombia'),
    ('+56', '🇨🇱', 'Chile'),
    ('+51', '🇵🇪', 'Peru'),
    ('+61', '🇦🇺', 'Australia'),
    ('+64', '🇳🇿', 'New Zealand'),
    ('+509', '🇭🇹', 'Haiti'),
    ('+1876', '🇯🇲', 'Jamaica'),
    ('+1868', '🇹🇹', 'Trinidad & Tobago'),
  ];

  @override
  void dispose() {
    _emailOtpController.dispose();
    _phoneController.dispose();
    _phoneOtpController.dispose();
    _countdownTimer?.cancel();
    _phoneCountdownTimer?.cancel();
    super.dispose();
  }

  // ── Timers ────────────────────────────────────────────────
  void _startResendCountdown() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  void _startPhoneResendCountdown() {
    _phoneResendCountdown = 60;
    _phoneCountdownTimer?.cancel();
    _phoneCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _phoneResendCountdown--;
        if (_phoneResendCountdown <= 0) timer.cancel();
      });
    });
  }

  // ── Step 1: Email OTP ─────────────────────────────────────
  Future<void> _sendEmailOtp() async {
    setState(() { _isSending = true; _errorMessage = null; });
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.sendSignupEmailOtp();
      if (mounted) {
        setState(() { _isSending = false; _emailOtpSent = success; });
        if (success) {
          _startResendCountdown();
        } else {
          setState(() {
            _errorMessage = authProvider.errorMessage ?? 'Failed to send OTP';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSending = false; _errorMessage = 'Failed to send verification code. Try again.'; });
      }
    }
  }

  Future<void> _verifyEmailOtp() async {
    final code = _emailOtpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }
    setState(() { _isVerifying = true; _errorMessage = null; });
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.verifySignupEmailOtp(code);
      if (mounted) {
        if (success) {
          // Email verified → phone step if enabled, otherwise go home
          if (_phoneStepEnabled) {
            setState(() { _step = 2; _isVerifying = false; _errorMessage = null; });
          } else {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        } else {
          setState(() {
            _isVerifying = false;
            _errorMessage = authProvider.errorMessage ?? 'Invalid code. Try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isVerifying = false; _errorMessage = 'Verification failed. Try again.'; });
      }
    }
  }

  // ── Step 2: Phone OTP ─────────────────────────────────────
  Future<void> _sendPhoneOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 6) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }
    setState(() { _phoneSending = true; _errorMessage = null; });
    try {
      final api = ApiService();
      await api.sendPhoneOtp(_selectedCountryCode, phone, channel: _selectedChannel);
      if (mounted) {
        setState(() { _phoneSending = false; _phoneOtpSent = true; });
        _startPhoneResendCountdown();
      }
    } catch (e) {
      if (mounted) {
        // Even if we get an error, the OTP might have been sent
        // Show a friendlier message and allow user to proceed
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('500') || errorMsg.contains('failed to send')) {
          setState(() {
            _phoneSending = false;
            _phoneOtpSent = true; // Allow user to enter code anyway
            _errorMessage = 'Code may have been sent. Please check your messages and enter the code below.';
          });
          _startPhoneResendCountdown();
        } else {
          setState(() { _phoneSending = false; _errorMessage = 'Failed to send code. Please try again.'; });
        }
      }
    }
  }

  Future<void> _verifyPhoneOtp() async {
    final code = _phoneOtpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }
    final phone = _phoneController.text.trim();
    setState(() { _phoneVerifying = true; _errorMessage = null; });
    final navigator = Navigator.of(context);
    try {
      final api = ApiService();
      await api.verifyPhoneOtp(_selectedCountryCode, phone, code);
      navigator.pushReplacementNamed('/home');
    } catch (e) {
      if (mounted) {
        setState(() { _phoneVerifying = false; _errorMessage = '$e'; });
      }
    }
  }

  void _skipPhoneVerification() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _step == 1
              ? _buildEmailStep(isDark)
              : _buildPhoneStep(isDark),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  STEP 1 – Email OTP
  // ──────────────────────────────────────────────────────────
  Widget _buildEmailStep(bool isDark) {
    final email = context.watch<AuthProvider>().userEmail ?? '';
    return Column(
      children: [
        const SizedBox(height: 60),

        // Step indicator
        _buildStepIndicator(1, isDark),
        const SizedBox(height: 24),

        // Icon
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.burundiGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined, size: 40, color: AppColors.burundiGreen),
        ),
        const SizedBox(height: 24),

        Text('Verify Your Email', style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.lightText,
        )),
        const SizedBox(height: 12),
        Text('We need to verify your email address to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 8),
        Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.burundiGreen)),
        const SizedBox(height: 32),

        if (!_emailOtpSent) ...[
          _buildButton('Send Verification Code', _isSending, _sendEmailOtp, AppColors.burundiGreen),
        ] else ...[
          _buildOtpInput(_emailOtpController, isDark),
          const SizedBox(height: 20),
          _buildButton('Verify Email', _isVerifying, _verifyEmailOtp, AppColors.burundiGreen),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _resendCountdown > 0 ? null : _sendEmailOtp,
            child: Text(
              _resendCountdown > 0 ? 'Resend code in ${_resendCountdown}s' : 'Resend Code',
              style: TextStyle(
                color: _resendCountdown > 0 ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary) : AppColors.burundiGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        _buildErrorBox(),
        const Spacer(),
        _buildInfoBox('Email verification is required to access the app. Check your inbox and spam folder.', isDark),
        const SizedBox(height: 24),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  //  STEP 2 – Phone OTP (SMS or WhatsApp)
  // ──────────────────────────────────────────────────────────
  Widget _buildPhoneStep(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 40),

        // Step indicator
        _buildStepIndicator(2, isDark),
        const SizedBox(height: 24),

        // Icon
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.auGold.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone_android, size: 40, color: AppColors.auGold),
        ),
        const SizedBox(height: 20),

        Text('Verify Your Phone', style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.lightText,
        )),
        const SizedBox(height: 8),
        Text('Receive a code via SMS or WhatsApp',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 24),

        if (!_phoneOtpSent) ...[
          // Country code + phone input
          Row(
            children: [
              // Country code picker
              Expanded(
                flex: 4,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCountryCode,
                      isExpanded: true,
                      isDense: false,
                      menuMaxHeight: 400,
                      items: _countryCodes.map((c) {
                        return DropdownMenuItem(
                          value: c.$1,
                          child: Text('${c.$2} ${c.$1}', style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      selectedItemBuilder: (context) => _countryCodes.map((c) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${c.$2} ${c.$1}', style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (v) { if (v != null) setState(() => _selectedCountryCode = v); },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Phone number
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Phone number',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.auGold, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SMS / WhatsApp toggle
          _buildChannelToggle(isDark),
          const SizedBox(height: 20),

          // Send code
          _buildButton(
            _selectedChannel == 'whatsapp' ? 'Send Code via WhatsApp' : 'Send Code via SMS',
            _phoneSending, _sendPhoneOtp, AppColors.auGold,
          ),
        ] else ...[
          // Show where code was sent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.auGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedChannel == 'whatsapp' ? Icons.message : Icons.sms,
                  size: 16, color: AppColors.auGold,
                ),
                const SizedBox(width: 8),
                Text(
                  'Code sent to $_selectedCountryCode ${_phoneController.text.trim()} via ${_selectedChannel == 'whatsapp' ? 'WhatsApp' : 'SMS'}',
                  style: TextStyle(fontSize: 13, color: AppColors.auGold, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildOtpInput(_phoneOtpController, isDark),
          const SizedBox(height: 20),

          _buildButton('Verify Phone', _phoneVerifying, _verifyPhoneOtp, AppColors.auGold),
          const SizedBox(height: 12),

          TextButton(
            onPressed: _phoneResendCountdown > 0 ? null : _sendPhoneOtp,
            child: Text(
              _phoneResendCountdown > 0 ? 'Resend in ${_phoneResendCountdown}s' : 'Resend Code',
              style: TextStyle(
                color: _phoneResendCountdown > 0 ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary) : AppColors.auGold,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        _buildErrorBox(),
        const Spacer(),

        // Skip button
        TextButton(
          onPressed: _skipPhoneVerification,
          child: Text(
            'Skip for now',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _buildInfoBox('Phone verification adds extra security. You can also verify later from your profile.', isDark),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────
  Widget _buildStepIndicator(int currentStep, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(1, currentStep, 'Email'),
        Container(
          width: 40, height: 2,
          color: currentStep >= 2 ? AppColors.auGold : (isDark ? Colors.white24 : Colors.grey[300]),
        ),
        _stepDot(2, currentStep, 'Phone'),
      ],
    );
  }

  Widget _stepDot(int step, int currentStep, String label) {
    final isActive = step <= currentStep;
    final isCurrent = step == currentStep;
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (step == 1 ? AppColors.burundiGreen : AppColors.auGold)
                : Colors.grey[400],
            border: isCurrent
                ? Border.all(color: (step == 1 ? AppColors.burundiGreen : AppColors.auGold).withValues(alpha: 0.3), width: 3)
                : null,
          ),
          child: Center(
            child: step < currentStep
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
          color: isActive ? (step == 1 ? AppColors.burundiGreen : AppColors.auGold) : Colors.grey,
        )),
      ],
    );
  }

  Widget _buildOtpInput(TextEditingController controller, bool isDark) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12,
        color: isDark ? Colors.white : AppColors.lightText,
      ),
      decoration: InputDecoration(
        hintText: '• • • • • •',
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.5) : Colors.grey[400],
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12,
        ),
        counterText: '',
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _step == 1 ? AppColors.burundiGreen : AppColors.auGold, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildButton(String text, bool loading, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildChannelToggle(bool isDark) {
    // If only one channel is on, don't show the toggle
    if (_smsEnabled && !_whatsappEnabled) return const SizedBox.shrink();
    if (!_smsEnabled && _whatsappEnabled) return const SizedBox.shrink();

    return Row(
      children: [
        if (_smsEnabled)
          Expanded(child: _channelOption('sms', 'SMS', Icons.sms_outlined, isDark)),
        if (_smsEnabled && _whatsappEnabled)
          const SizedBox(width: 12),
        if (_whatsappEnabled)
          Expanded(child: _channelOption('whatsapp', 'WhatsApp', Icons.message_outlined, isDark)),
      ],
    );
  }

  Widget _channelOption(String channel, String label, IconData icon, bool isDark) {
    final isSelected = _selectedChannel == channel;
    final color = channel == 'whatsapp' ? const Color(0xFF25D366) : AppColors.auGold;
    return GestureDetector(
      onTap: () => setState(() => _selectedChannel = channel),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : (isDark ? AppColors.darkSurface : AppColors.lightBackground),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? color : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBox() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.burundiRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.burundiRed, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.burundiRed, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
        ],
      ),
    );
  }
}
