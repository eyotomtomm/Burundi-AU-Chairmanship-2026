import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/verification_provider.dart';
import '../../services/api_service.dart' show ApiService, ApiException;
import '../../utils/input_sanitizer.dart';
import '../../widgets/confetti_overlay.dart';
import '../../l10n/app_localizations.dart';

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

  // 'label' is an l10n key.
  static const List<Map<String, String>> _titles = [
    {'value': 'mr', 'label': 'vr_title_mr'},
    {'value': 'mrs', 'label': 'vr_title_mrs'},
    {'value': 'ms', 'label': 'vr_title_ms'},
    {'value': 'dr', 'label': 'vr_title_dr'},
    {'value': 'prof', 'label': 'vr_title_prof'},
    {'value': 'he', 'label': 'vr_title_he'},
    {'value': 'amb', 'label': 'vr_title_amb'},
    {'value': 'hon', 'label': 'vr_title_hon'},
    {'value': 'other', 'label': 'vr_other'},
  ];

  // Social media platforms with icons. Labels/hints that are l10n keys get
  // translated; brand names and URL patterns pass through translate() unchanged.
  static const List<Map<String, dynamic>> _socialPlatforms = [
    {'key': 'twitter', 'label': 'X', 'icon': Icons.close, 'hint': '@username or https://x.com/...'},
    {'key': 'facebook', 'label': 'Facebook', 'icon': Icons.facebook, 'hint': 'https://facebook.com/...'},
    {'key': 'linkedin', 'label': 'LinkedIn', 'icon': Icons.work_outline, 'hint': 'https://linkedin.com/in/...'},
    {'key': 'instagram', 'label': 'Instagram', 'icon': Icons.camera_alt_outlined, 'hint': '@username or https://instagram.com/...'},
    {'key': 'tiktok', 'label': 'TikTok', 'icon': Icons.music_note_outlined, 'hint': '@username or https://tiktok.com/@...'},
    {'key': 'youtube', 'label': 'YouTube', 'icon': Icons.play_circle_outline, 'hint': 'https://youtube.com/@...'},
    {'key': 'telegram', 'label': 'Telegram', 'icon': Icons.send, 'hint': '@username or https://t.me/...'},
    {'key': 'whatsapp', 'label': 'WhatsApp', 'icon': Icons.phone, 'hint': 'vr_hint_phone_or_link'},
    {'key': 'threads', 'label': 'Threads', 'icon': Icons.alternate_email, 'hint': '@username'},
    {'key': 'other', 'label': 'vr_other', 'icon': Icons.link, 'hint': 'vr_hint_url_or_username'},
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
      if (AppConstants.nationalityChoices.containsKey(code)) {
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
    final l10n = AppLocalizations.of(context);
    if (email.isEmpty) {
      _showError(l10n.translate('auth_enter_email'));
      return;
    }
    final emailError = InputSanitizer.validateEmail(email);
    if (emailError != null) {
      _showError(emailError);
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
        _showSuccess('${l10n.translate('vr_code_sent_to')} $email');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingEmailOtp = false);
        String errorMsg;
        if (e is ApiException) {
          errorMsg = e.message;
        } else {
          errorMsg = l10n.translate('vr_send_code_failed');
        }
        _showError(errorMsg);
      }
    }
  }

  Future<void> _verifyEmailOtp() async {
    final code = _emailOtpController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (code.isEmpty || code.length < 6) {
      _showError(l10n.translate('auth_enter_6_digit_code'));
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
        _showSuccess(l10n.translate('vr_email_verified_snack'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifyingEmailOtp = false);
        String errorMsg;
        if (e is ApiException) {
          errorMsg = e.message;
        } else {
          errorMsg = l10n.translate('auth_invalid_code');
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: Text(l10n.translate('vr_verification'))),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          // Status summary
          DsCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: Ds.goldTintOf(context), shape: BoxShape.circle),
                  child: const Icon(Icons.shield_outlined,
                      size: 32, color: Ds.goldDeep),
                ),
                const SizedBox(height: 12),
                Text(l10n.translate('vr_in_review'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Ds.ink(context))),
                const SizedBox(height: 6),
                Text(
                  l10n.translate('vr_pending_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, height: 1.5, color: Ds.body(context)),
                ),
                const SizedBox(height: 12),
                DsPill(l10n.translate('vr_pending'), tone: DsTone.gold),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Progress timeline
          DsCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate('vr_progress'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Ds.ink(context))),
                const SizedBox(height: 14),
                _timelineStep(
                  done: true,
                  title: l10n.translate('vr_step_docs'),
                  subtitle: l10n.translate('vr_step_docs_sub'),
                ),
                _timelineStep(
                  active: true,
                  title: l10n.translate('vr_step_review'),
                  subtitle: l10n.translate('vr_step_review_sub'),
                ),
                _timelineStep(
                  title: l10n.translate('vr_step_badge'),
                  subtitle: l10n.translate('vr_step_badge_sub'),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DsOutlineButton(l10n.translate('vr_go_back'),
                expand: true, onTap: () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }

  /// One node of the review timeline: filled, active, or upcoming.
  Widget _timelineStep({
    bool done = false,
    bool active = false,
    bool isLast = false,
    required String title,
    required String subtitle,
  }) {
    final Widget marker;
    if (done) {
      marker = Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(color: Ds.green, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 15, color: Colors.white),
      );
    } else if (active) {
      marker = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Ds.goldTintOf(context),
          shape: BoxShape.circle,
          border: Border.all(color: Ds.goldDeep, width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Ds.goldDeep, shape: BoxShape.circle),
          ),
        ),
      );
    } else {
      marker = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Ds.outline(context), width: 2),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              marker,
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: done ? Ds.green : Ds.outline(context),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: done || active ? Ds.ink(context) : Ds.muted(context))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Ds.meta(context)),
                ],
              ),
            ),
          ),
        ],
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

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(l10n.translate('vr_verification')),
        leading: IconButton(
          tooltip: l10n.translate('close'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
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
    final l10n = AppLocalizations.of(context);
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
          l10n.translate('get_verified'),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.darkBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.translate('vr_intro'),
          style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.white60 : Colors.black54),
        ),
      ],
    );
  }

  Widget _buildBadgeTypeInfo(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final badgeTypes = [
      {
        'value': 'GOLD',
        'label': l10n.translate('vr_gold_badge'),
        'description': l10n.translate('vr_gold_desc'),
        'color': const Color(0xFFFFD700),
      },
      {
        'value': 'BLUE',
        'label': l10n.translate('vr_blue_badge'),
        'description': l10n.translate('vr_blue_desc'),
        'color': const Color(0xFF1DA1F2),
      },
      {
        'value': 'GREEN',
        'label': l10n.translate('vr_green_badge'),
        'description': l10n.translate('vr_green_desc'),
        'color': const Color(0xFF409843),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_select_badge_type'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Text(
          l10n.translate('vr_select_badge_hint'),
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
          l10n.translate('vr_badge_notice'),
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildTitleField(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_title_label'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedTitle,
          decoration: _inputDecoration(isDark: isDark, hint: l10n.translate('vr_select_title'), prefixIcon: const Icon(Icons.person_outline)),
          items: _titles.map((t) => DropdownMenuItem(value: t['value'], child: Text(l10n.translate(t['label']!)))).toList(),
          onChanged: (v) => setState(() => _selectedTitle = v),
          validator: (v) => (v == null || v.isEmpty) ? l10n.translate('vr_title_required') : null,
        ),
      ],
    );
  }

  Widget _buildFullNameField(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_full_legal_name'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fullNameController,
          decoration: _inputDecoration(isDark: isDark, hint: l10n.translate('vr_enter_full_legal_name'), prefixIcon: const Icon(Icons.badge_outlined)),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return l10n.translate('vr_full_name_required');
            if (v.trim().length < 3) return l10n.translate('vr_name_min');
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNationalityField(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_nationality_label'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedNationality,
          decoration: _inputDecoration(isDark: isDark, hint: l10n.translate('pc_select_nationality'), prefixIcon: const Icon(Icons.public)),
          isExpanded: true,
          items: AppConstants.nationalityChoices.entries.map((n) {
            final flag = AppConstants.countryFlag(n.key);
            return DropdownMenuItem(
              value: n.key,
              child: Text('$flag  ${n.value}', style: const TextStyle(fontSize: 15)),
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _selectedNationality = v;
              // Auto-sync phone country code when nationality changes
              final dial = v == null ? null : AppConstants.countryDialCodes[v];
              if (dial != null) {
                _selectedPhoneCountry = v!;
                _selectedPhoneCode = dial;
              }
            });
          },
          validator: (v) => (v == null || v.isEmpty) ? l10n.translate('pc_nationality_required') : null,
        ),
      ],
    );
  }

  Widget _buildGenderField(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_gender_label'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          decoration: _inputDecoration(isDark: isDark, hint: l10n.translate('vr_select_gender'), prefixIcon: const Icon(Icons.person_outline)),
          items: [
            DropdownMenuItem(value: 'male', child: Text(l10n.translate('pc_male'))),
            DropdownMenuItem(value: 'female', child: Text(l10n.translate('pc_female'))),
          ],
          onChanged: (v) => setState(() => _selectedGender = v),
          validator: (v) => (v == null || v.isEmpty) ? l10n.translate('pc_gender_required') : null,
        ),
      ],
    );
  }

  Widget _buildDocumentUpload(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_supporting_doc'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Text(
          l10n.translate('vr_supporting_doc_hint'),
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
                child: Semantics(
                  button: true,
                  label: l10n.translate('remove'),
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
                    l10n.translate('vr_tap_upload'),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_work_email'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Text(
          l10n.translate('vr_work_email_hint'),
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
                validator: InputSanitizer.validateEmail,
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
                              countdown > 0 ? '${countdown}s' : l10n.translate('vr_get_code'),
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
                    hint: l10n.translate('vr_enter_code'),
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
                      : Text(l10n.translate('auth_verify'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                Text(l10n.translate('vr_email_verified'), style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneSection(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('pc_phone_number'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
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
                  items: AppConstants.countryDialCodes.entries.map((c) {
                    final flag = AppConstants.countryFlag(c.key);
                    return DropdownMenuItem(
                      value: c.key,
                      child: Text(
                        '$flag ${c.value}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedPhoneCountry = v;
                        _selectedPhoneCode = AppConstants.countryDialCodes[v]!;
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
                  hint: l10n.translate('pc_phone_optional'),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_position'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _positionController,
          decoration: _inputDecoration(isDark: isDark, hint: l10n.translate('vr_position_hint'), prefixIcon: const Icon(Icons.work_outline)),
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.translate('vr_position_required') : null,
        ),
      ],
    );
  }

  // ── Social Media Section ──────────────────────────────────

  Widget _buildSocialMediaSection(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_social_media'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text(l10n.translate('vr_social_hint'), style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
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
                      l10n.translate(platform['label'] as String),
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
                hint: l10n.translate(platform['hint'] as String),
                prefixIcon: Icon(platform['icon'] as IconData, size: 20),
              ).copyWith(
                labelText: l10n.translate(platform['label'] as String),
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
              AppLocalizations.of(context).translate('vr_review_notice'),
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    final l10n = AppLocalizations.of(context);
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
                    l10n.translate('vr_verify_email_to_submit'),
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
                    l10n.translate('vr_select_badge_required'),
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.translate('vr_submit_request'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(width: 8),
                      const Icon(Icons.send_rounded, size: 20),
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
    final l10n = AppLocalizations.of(context);
    if (_selectedBadgeType == null) {
      _showError(l10n.translate('vr_select_badge_required'));
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

      final fields = <String, String>{
        'title': _selectedTitle!,
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': fullPhone,
        'position_role': _positionController.text.trim(),
      };
      void put(String key, String? value) {
        if (value != null && value.isNotEmpty) fields[key] = value;
      }
      put('country_code', _selectedNationality);
      put('gender', _selectedGender);
      put('badge_type', _selectedBadgeType);
      put('twitter_url', twitterUrl);
      put('linkedin_url', linkedinUrl);
      put('facebook_url', facebookUrl);
      put('instagram_url', instagramUrl);
      put('tiktok_url', tiktokUrl);
      put('youtube_url', youtubeUrl);
      put('other_social_url', otherSocialUrl);

      final doc = _supportingDocument;
      if (doc != null) {
        await api.submitVerificationRequestWithDocument(fields, doc);
      } else {
        await api.post('verification/request/', fields, auth: true);
      }

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
                Expanded(child: Text(l10n.translate('vr_request_submitted'))),
              ],
            ),
            content: Text(l10n.translate('vr_request_submitted_body')),
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
                child: Text(l10n.translate('ok')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : l10n.translate('generic_error')),
            backgroundColor: AppColors.burundiRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
