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
  final _mainScrollController = ScrollController();

  String? _selectedTitle;
  String? _selectedNationality;
  String? _selectedGender;
  String? _selectedBadgeType;
  String _selectedPhoneCode = '+257';
  String _selectedPhoneCountry = 'BI';
  File? _supportingDocument;
  bool _isLoading = false;

  // Stepped-flow state. Steps: 0 badge, 1 who you are, 2 contact, 3 proof, 4 review.
  static const int _totalSteps = 5;
  int _step = 0;
  bool _badgeTypeError = false;
  bool _emailNotVerifiedError = false;

  // Scroll-to / focus-on-error support. Every validated field gets a
  // GlobalKey (to scroll it into view) and, for text inputs, a FocusNode
  // (so the keyboard opens right where the error is).
  static const List<String> _fieldIds = [
    'badge', 'title', 'fullName', 'nationality', 'gender', 'email', 'position',
  ];
  final Map<String, GlobalKey> _fieldKeys = {
    for (final id in _fieldIds) id: GlobalKey(debugLabel: id),
  };
  final Map<String, FocusNode> _focusNodes = {
    for (final id in _fieldIds) id: FocusNode(debugLabel: id),
  };

  // Email OTP state
  bool _emailVerified = false;
  bool _emailOtpSent = false;
  bool _sendingEmailOtp = false;
  bool _verifyingEmailOtp = false;
  Timer? _emailTimer;
  final ValueNotifier<int> _emailCountdown = ValueNotifier<int>(0);

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
    _mainScrollController.dispose();
    _emailTimer?.cancel();
    _emailCountdown.dispose();
    for (final c in _socialMediaControllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
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
          _emailNotVerifiedError = false;
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

  // ── Step navigation ──────────────────────────────────

  bool _fieldValid(String id) {
    switch (id) {
      case 'badge':
        return _selectedBadgeType != null;
      case 'title':
        return _selectedTitle != null;
      case 'fullName':
        final v = _fullNameController.text.trim();
        return v.isNotEmpty && v.length >= 3;
      case 'nationality':
        return _selectedNationality != null;
      case 'gender':
        return _selectedGender != null;
      case 'email':
        return InputSanitizer.validateEmail(_emailController.text) == null;
      case 'position':
        return _positionController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _scrollToField(String id) {
    final ctx = _fieldKeys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  void _focusFirstInvalid(List<String> order) {
    for (final id in order) {
      if (!_fieldValid(id)) {
        final focus = _focusNodes[id];
        if (focus != null) FocusScope.of(context).requestFocus(focus);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToField(id));
        return;
      }
    }
  }

  void _scrollStepToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mainScrollController.hasClients) _mainScrollController.jumpTo(0);
    });
  }

  void _goNext() {
    switch (_step) {
      case 0:
        if (_selectedBadgeType == null) {
          setState(() => _badgeTypeError = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToField('badge'));
          return;
        }
      case 1:
        if (!_formKey.currentState!.validate()) {
          _focusFirstInvalid(['title', 'fullName', 'nationality', 'gender']);
          return;
        }
      case 2:
        if (!_formKey.currentState!.validate()) {
          _focusFirstInvalid(['email']);
          return;
        }
        if (!_emailVerified) {
          setState(() => _emailNotVerifiedError = true);
          _focusFirstInvalid(['email']);
          return;
        }
      case 3:
        if (!_formKey.currentState!.validate()) {
          _focusFirstInvalid(['position']);
          return;
        }
    }
    HapticFeedback.selectionClick();
    setState(() {
      _badgeTypeError = false;
      _step++;
    });
    _scrollStepToTop();
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
    _scrollStepToTop();
  }

  void _jumpTo(int step) {
    setState(() => _step = step);
    _scrollStepToTop();
  }

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final sizeBytes = await file.length();
    if (sizeBytes > 10 * 1024 * 1024) {
      if (mounted) _showError(AppLocalizations.of(context).translate('vr_doc_too_large'));
      return;
    }
    if (mounted) setState(() => _supportingDocument = file);
  }

  // ── Pending status screen (unchanged behaviour) ──────────────────────

  Widget _buildPendingStatusScreen() {
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

  // ── Build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final verificationProvider = context.watch<VerificationProvider>();
    final requestStatus = verificationProvider.requestStatus;

    // If there's a pending request, show status page instead of the form
    if (requestStatus == 'pending') {
      return _buildPendingStatusScreen();
    }

    final l10n = AppLocalizations.of(context);
    final isLastStep = _step == _totalSteps - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Ds.bg(context),
        appBar: AppBar(
          title: Text(l10n.translate('vr_verification')),
          leading: IconButton(
            tooltip: l10n.translate(_step == 0 ? 'close' : 'vr_back'),
            icon: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: _goBack,
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildProgress(l10n),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _mainScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: _buildStepBody(l10n),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: DsBottomBar(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: DsOutlineButton(l10n.translate('vr_back'), expand: true, onTap: _goBack),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: !isLastStep
                  ? DsPrimaryButton(l10n.translate('next'), radius: 14, onTap: _goNext)
                  : (_isLoading
                      ? const Center(
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green),
                          ),
                        )
                      : DsPrimaryButton(
                          l10n.translate('vr_submit_request'),
                          icon: Icons.send_rounded,
                          radius: 14,
                          onTap: _submitRequest,
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(AppLocalizations l10n) {
    final stepTitles = [
      l10n.translate('vr_step_badge_type'),
      l10n.translate('vr_step_who_you_are'),
      l10n.translate('vr_step_contact'),
      l10n.translate('vr_step_proof'),
      l10n.translate('vr_step_review_submit'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < stepTitles.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step ? Ds.green : Ds.hairline(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.translate('vr_step_prefix')} ${_step + 1} '
            '${l10n.translate('vr_step_of')} ${stepTitles.length} '
            '· ${stepTitles[_step]}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Ds.body(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return _buildBadgeStep(l10n);
      case 1:
        return _buildIdentityStep(l10n);
      case 2:
        return _buildContactStep(l10n);
      case 3:
        return _buildProofStep(l10n);
      default:
        return _buildReviewStep(l10n);
    }
  }

  // ── Step 1: badge type ──────────────────────────────────

  Widget _buildIntroHeader(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Ds.goldTintOf(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.workspace_premium_rounded, size: 48, color: Ds.gold),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.translate('get_verified'),
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Ds.ink(context)),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.translate('vr_intro'),
          style: TextStyle(fontSize: 14, height: 1.5, color: Ds.body(context)),
        ),
      ],
    );
  }

  Widget _buildBadgeStep(AppLocalizations l10n) {
    final badgeTypes = [
      {
        'value': 'GOLD',
        'label': l10n.translate('vr_gold_badge'),
        'description': l10n.translate('vr_gold_desc'),
        'color': Ds.gold,
      },
      {
        'value': 'BLUE',
        'label': l10n.translate('vr_blue_badge'),
        'description': l10n.translate('vr_blue_desc'),
        'color': Ds.blue,
      },
      {
        'value': 'GREEN',
        'label': l10n.translate('vr_green_badge'),
        'description': l10n.translate('vr_green_desc'),
        'color': Ds.green,
      },
    ];

    return Column(
      key: _fieldKeys['badge'],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntroHeader(l10n),
        const SizedBox(height: 28),
        Text(l10n.translate('vr_select_badge_type'), style: Ds.sectionTitle(context)),
        const SizedBox(height: 4),
        Text(l10n.translate('vr_select_badge_hint'), style: Ds.cardBody(context)),
        const SizedBox(height: 12),
        ...badgeTypes.map((badge) => _badgeCard(badge)),
        if (_badgeTypeError) ...[
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: Ds.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.translate('vr_select_badge_required'),
                  style: TextStyle(fontSize: 12, color: Ds.red, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        DsNoteBanner(
          icon: Icons.info_outline,
          title: l10n.translate('vr_badge_notice'),
          subtitle: l10n.translate('vr_badge_proof_note'),
          margin: const EdgeInsets.only(top: 4),
        ),
      ],
    );
  }

  Widget _badgeCard(Map<String, dynamic> badge) {
    final isSelected = _selectedBadgeType == badge['value'];
    final badgeColor = badge['color'] as Color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            _selectedBadgeType = badge['value'] as String;
            _badgeTypeError = false;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? badgeColor.withValues(alpha: 0.1) : Ds.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? badgeColor : Ds.outline(context),
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
                          color: isSelected ? badgeColor : Ds.ink(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(badge['description'] as String, style: Ds.cardBody(context)),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? badgeColor : Ds.outline(context),
                      width: 2,
                    ),
                    color: isSelected ? badgeColor : Colors.transparent,
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 2: who you are ──────────────────────────────────

  Widget _buildIdentityStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_step_who_you_are'), style: Ds.sectionTitle(context)),
        const SizedBox(height: 4),
        Text(l10n.translate('vr_why_identity_note'), style: Ds.cardBody(context)),
        const SizedBox(height: 16),
        _dropdownField<String>(
          id: 'title',
          label: l10n.translate('vr_title_label').toUpperCase(),
          hint: l10n.translate('vr_select_title'),
          icon: Icons.person_outline,
          value: _selectedTitle,
          items: _titles
              .map((t) => DropdownMenuItem(value: t['value'], child: Text(l10n.translate(t['label']!))))
              .toList(),
          onChanged: (v) => setState(() => _selectedTitle = v),
          validator: (v) => (v == null || v.isEmpty) ? l10n.translate('vr_title_required') : null,
        ),
        const SizedBox(height: 10),
        _textField(
          id: 'fullName',
          controller: _fullNameController,
          label: l10n.translate('vr_full_legal_name').toUpperCase(),
          hint: l10n.translate('vr_enter_full_legal_name'),
          icon: Icons.badge_outlined,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return l10n.translate('vr_full_name_required');
            if (v.trim().length < 3) return l10n.translate('vr_name_min');
            return null;
          },
        ),
        const SizedBox(height: 10),
        _dropdownField<String>(
          id: 'nationality',
          label: l10n.translate('vr_nationality_label').toUpperCase(),
          hint: l10n.translate('pc_select_nationality'),
          icon: Icons.public,
          value: _selectedNationality,
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
        const SizedBox(height: 10),
        _dropdownField<String>(
          id: 'gender',
          label: l10n.translate('vr_gender_label').toUpperCase(),
          hint: l10n.translate('vr_select_gender'),
          icon: Icons.person_outline,
          value: _selectedGender,
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

  // ── Step 3: how to reach you ──────────────────────────────────

  Widget _buildContactStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_step_contact'), style: Ds.sectionTitle(context)),
        const SizedBox(height: 4),
        Text(l10n.translate('vr_why_contact_note'), style: Ds.cardBody(context)),
        const SizedBox(height: 16),
        _buildEmailSection(l10n),
        const SizedBox(height: 14),
        _buildPhoneSection(l10n),
      ],
    );
  }

  Widget _buildEmailSection(AppLocalizations l10n) {
    return Column(
      key: _fieldKeys['email'],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('vr_work_email').toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: Ds.muted(context)),
        ),
        const SizedBox(height: 4),
        Text(l10n.translate('vr_work_email_hint'), style: Ds.cardBody(context)),
        const SizedBox(height: 8),

        // Email input + Get Code button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DsCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, size: 20, color: Ds.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        focusNode: _focusNodes['email'],
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_emailVerified,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Ds.ink(context)),
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          hintStyle: TextStyle(fontSize: 15, color: Ds.muted(context)),
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          suffixIcon: _emailVerified
                              ? Icon(Icons.check_circle, color: AppColors.success)
                              : null,
                        ),
                        validator: InputSanitizer.validateEmail,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_emailVerified) ...[
              const SizedBox(width: 10),
              ValueListenableBuilder<int>(
                valueListenable: _emailCountdown,
                builder: (context, countdown, _) {
                  return SizedBox(
                    height: 52,
                    child: DsPrimaryButton(
                      countdown > 0 ? '${countdown}s' : l10n.translate('vr_get_code'),
                      expand: false,
                      radius: 12,
                      onTap: (_sendingEmailOtp || countdown > 0) ? null : _sendEmailOtp,
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
                child: DsCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.pin, size: 20, color: Ds.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _emailOtpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Ds.ink(context)),
                          decoration: InputDecoration(
                            hintText: l10n.translate('vr_enter_code'),
                            hintStyle: TextStyle(fontSize: 15, color: Ds.muted(context)),
                            counterText: '',
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _verifyingEmailOtp
                  ? const SizedBox(
                      height: 52,
                      width: 52,
                      child: Center(
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 52,
                      child: DsPrimaryButton(
                        l10n.translate('auth_verify'),
                        expand: false,
                        radius: 12,
                        onTap: _verifyEmailOtp,
                      ),
                    ),
            ],
          ),
        ],

        // Verified badge
        if (_emailVerified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Text(
                  l10n.translate('vr_email_verified'),
                  style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        // Gate: must verify before moving on
        if (_emailNotVerifiedError && !_emailVerified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Ds.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.translate('vr_verify_email_to_continue'),
                    style: TextStyle(fontSize: 12, color: Ds.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('pc_phone_number').toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: Ds.muted(context)),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code selector with flag
            DsCard(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: 52,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPhoneCountry,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    items: AppConstants.countryDialCodes.entries.map((c) {
                      final flag = AppConstants.countryFlag(c.key);
                      return DropdownMenuItem(
                        value: c.key,
                        child: Text('$flag ${c.value}', style: const TextStyle(fontSize: 14)),
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
            ),
            const SizedBox(width: 10),
            // Phone number input
            Expanded(
              child: DsCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 20, color: Ds.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Ds.ink(context)),
                        decoration: InputDecoration(
                          hintText: l10n.translate('pc_phone_optional'),
                          hintStyle: TextStyle(fontSize: 15, color: Ds.muted(context)),
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 4: proof ──────────────────────────────────

  Widget _buildProofStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_step_proof'), style: Ds.sectionTitle(context)),
        const SizedBox(height: 12),
        _textField(
          id: 'position',
          controller: _positionController,
          label: l10n.translate('vr_position').toUpperCase(),
          hint: l10n.translate('vr_position_hint'),
          icon: Icons.work_outline,
          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.translate('vr_position_required') : null,
        ),
        const SizedBox(height: 20),
        _buildDocumentUpload(l10n),
        const SizedBox(height: 24),
        _buildSocialMediaSection(l10n),
      ],
    );
  }

  Widget _buildDocumentUpload(AppLocalizations l10n) {
    final doc = _supportingDocument;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_supporting_doc'), style: Ds.sectionTitle(context).copyWith(fontSize: 14)),
        const SizedBox(height: 4),
        Text(l10n.translate('vr_supporting_doc_hint'), style: Ds.cardBody(context)),
        const SizedBox(height: 2),
        Text(l10n.translate('vr_doc_formats'), style: Ds.meta(context)),
        const SizedBox(height: 12),
        if (doc != null)
          DsCard(
            clip: true,
            child: Column(
              children: [
                Image.file(doc, height: 160, width: double.infinity, fit: BoxFit.cover),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_outlined, size: 18, color: Ds.body(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          doc.path.split('/').last,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Ds.body(context), fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.translate('vr_replace'),
                        icon: Icon(Icons.refresh_rounded, size: 20, color: Ds.green),
                        onPressed: _pickDocument,
                      ),
                      IconButton(
                        tooltip: l10n.translate('remove'),
                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: Ds.red),
                        onPressed: () => setState(() => _supportingDocument = null),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: _pickDocument,
            borderRadius: BorderRadius.circular(Ds.rCard),
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Ds.surface(context),
                borderRadius: BorderRadius.circular(Ds.rCard),
                border: Border.all(color: Ds.outline(context)),
                boxShadow: Ds.shadow(context),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 30, color: Ds.muted(context)),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('vr_tap_upload'),
                    style: TextStyle(fontSize: 13, color: Ds.body(context), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSocialMediaSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_social_media'), style: Ds.sectionTitle(context)),
        const SizedBox(height: 6),
        Text(l10n.translate('vr_social_hint'), style: Ds.cardBody(context)),
        const SizedBox(height: 14),

        // Platform toggle chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _socialPlatforms.map((platform) {
            final key = platform['key'] as String;
            final isActive = _socialMediaActive[key] ?? false;
            final label = l10n.translate(platform['label'] as String);

            return Semantics(
              button: true,
              selected: isActive,
              label: label,
              child: GestureDetector(
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
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? Ds.tint(context) : Ds.subtle(context),
                    borderRadius: BorderRadius.circular(Ds.rPill),
                    border: Border.all(
                      color: isActive ? Ds.green : Ds.outline(context),
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        platform['icon'] as IconData,
                        size: 16,
                        color: isActive ? Ds.greenDeep : Ds.body(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? Ds.greenDeep : Ds.ink(context),
                        ),
                      ),
                    ],
                  ),
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
            child: _textField(
              id: 'social_$key',
              controller: _socialMediaControllers[key]!,
              label: l10n.translate(platform['label'] as String).toUpperCase(),
              hint: l10n.translate(platform['hint'] as String),
              icon: platform['icon'] as IconData,
            ),
          );
        }),
      ],
    );
  }

  // ── Step 5: review & submit ──────────────────────────────────

  String _badgeTypeLabel(AppLocalizations l10n) {
    switch (_selectedBadgeType) {
      case 'GOLD':
        return l10n.translate('vr_gold_badge');
      case 'BLUE':
        return l10n.translate('vr_blue_badge');
      case 'GREEN':
        return l10n.translate('vr_green_badge');
      default:
        return l10n.translate('vr_not_provided');
    }
  }

  Color _badgeTypeColor() {
    switch (_selectedBadgeType) {
      case 'GOLD':
        return Ds.gold;
      case 'BLUE':
        return Ds.blue;
      case 'GREEN':
        return Ds.green;
      default:
        return Ds.chevron;
    }
  }

  String _titleDisplay(AppLocalizations l10n) {
    for (final t in _titles) {
      if (t['value'] == _selectedTitle) return l10n.translate(t['label']!);
    }
    return l10n.translate('vr_not_provided');
  }

  String _genderDisplay(AppLocalizations l10n) {
    if (_selectedGender == 'male') return l10n.translate('pc_male');
    if (_selectedGender == 'female') return l10n.translate('pc_female');
    return l10n.translate('vr_not_provided');
  }

  String _nationalityDisplay(AppLocalizations l10n) {
    final code = _selectedNationality;
    if (code == null) return l10n.translate('vr_not_provided');
    return AppConstants.nationalityChoices[code] ?? l10n.translate('vr_not_provided');
  }

  Widget _buildReviewStep(AppLocalizations l10n) {
    final fullName = _fullNameController.text.trim();
    final position = _positionController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final activeSocials = _socialPlatforms.where((p) {
      final key = p['key'] as String;
      return (_socialMediaActive[key] ?? false) && _socialMediaControllers[key]!.text.trim().isNotEmpty;
    }).map((p) => l10n.translate(p['label'] as String)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.translate('vr_step_review_submit'), style: Ds.sectionTitle(context)),
        const SizedBox(height: 16),
        _reviewSection(
          l10n.translate('vr_step_badge_type'),
          onEdit: () => _jumpTo(0),
          tiles: [
            DsTile(
              title: _badgeTypeLabel(l10n),
              icon: Icons.verified,
              iconColor: _badgeTypeColor(),
              iconTint: _badgeTypeColor().withValues(alpha: 0.15),
              chevron: false,
            ),
          ],
        ),
        _reviewSection(
          l10n.translate('vr_step_who_you_are'),
          onEdit: () => _jumpTo(1),
          tiles: [
            DsTile(
              title: fullName.isEmpty ? l10n.translate('vr_not_provided') : fullName,
              subtitle: l10n.translate('vr_full_legal_name'),
              chevron: false,
            ),
            DsTile(title: _titleDisplay(l10n), subtitle: l10n.translate('vr_title_label'), chevron: false),
            DsTile(
              title: _nationalityDisplay(l10n),
              subtitle: l10n.translate('vr_nationality_label'),
              chevron: false,
            ),
            DsTile(title: _genderDisplay(l10n), subtitle: l10n.translate('vr_gender_label'), chevron: false),
          ],
        ),
        _reviewSection(
          l10n.translate('vr_step_contact'),
          onEdit: () => _jumpTo(2),
          tiles: [
            DsTile(
              title: email.isEmpty ? l10n.translate('vr_not_provided') : email,
              subtitle: l10n.translate('vr_work_email'),
              chevron: false,
              trailing: _emailVerified ? Icon(Icons.check_circle, size: 18, color: AppColors.success) : null,
            ),
            DsTile(
              title: phone.isEmpty ? l10n.translate('vr_not_provided') : '$_selectedPhoneCode $phone',
              subtitle: l10n.translate('pc_phone_number'),
              chevron: false,
            ),
          ],
        ),
        _reviewSection(
          l10n.translate('vr_step_proof'),
          onEdit: () => _jumpTo(3),
          tiles: [
            DsTile(
              title: position.isEmpty ? l10n.translate('vr_not_provided') : position,
              subtitle: l10n.translate('vr_position'),
              chevron: false,
            ),
            DsTile(
              title: _supportingDocument != null
                  ? _supportingDocument!.path.split('/').last
                  : l10n.translate('vr_not_provided'),
              subtitle: l10n.translate('vr_supporting_doc'),
              chevron: false,
            ),
            DsTile(
              title: activeSocials.isEmpty ? l10n.translate('vr_not_provided') : activeSocials.join(', '),
              subtitle: l10n.translate('vr_social_media'),
              chevron: false,
            ),
          ],
        ),
        DsNoteBanner(
          icon: Icons.lock_outline_rounded,
          title: l10n.translate('vr_review_notice'),
          margin: const EdgeInsets.only(top: 4, bottom: 4),
        ),
      ],
    );
  }

  Widget _reviewSection(String title, {required VoidCallback onEdit, required List<Widget> tiles}) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(title.toUpperCase(), style: Ds.groupLabel(context)),
                ),
                Semantics(
                  button: true,
                  label: l10n.translate('edit'),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEdit,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 14, color: Ds.green),
                          const SizedBox(width: 4),
                          Text(
                            l10n.translate('edit'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Ds.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          DsTileGroup(margin: EdgeInsets.zero, children: tiles),
        ],
      ),
    );
  }

  // ── Field helpers ──────────────────────────────────

  /// White card field with a leading icon and floating small-caps label,
  /// matching the rest of the redesigned app (see contact_support_screen).
  Widget _textField({
    required String id,
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      key: _fieldKeys[id],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Padding(padding: const EdgeInsets.only(top: 14), child: Icon(icon, size: 20, color: Ds.green)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextFormField(
                  controller: controller,
                  focusNode: _focusNodes[id],
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  maxLength: maxLength,
                  validator: validator,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Ds.ink(context)),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint,
                    labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Ds.muted(context)),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintStyle: TextStyle(fontSize: 15, color: Ds.muted(context)),
                    filled: false,
                    isDense: true,
                    counterText: maxLength != null ? '' : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Dropdown counterpart to [_textField], same shell and label treatment.
  Widget _dropdownField<T>({
    required String id,
    required String label,
    required String hint,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
    bool isExpanded = false,
  }) {
    return Column(
      key: _fieldKeys[id],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 16), child: Icon(icon, size: 20, color: Ds.green)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<T>(
                  initialValue: value,
                  focusNode: _focusNodes[id],
                  isExpanded: isExpanded,
                  items: items,
                  onChanged: onChanged,
                  validator: validator,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Ds.ink(context)),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint,
                    labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Ds.muted(context)),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintStyle: TextStyle(fontSize: 15, color: Ds.muted(context)),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Submit (payload unchanged) ──────────────────────────────────

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
