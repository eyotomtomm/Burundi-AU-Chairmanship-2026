import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/password_strength_meter.dart';
import '../../utils/input_sanitizer.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();

  // Honeypot field controller — invisible to users, bots auto-fill it.
  // If this field has a value on submit, the backend silently rejects the registration.
  final _honeypotController = TextEditingController();

  bool _obscureSignInPassword = true;
  bool _obscureSignUpPassword = true;
  bool _obscureConfirmPassword = true;
  String _signUpPassword = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    _honeypotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          // Top bar: Language toggle + Skip
          SafeArea(bottom: false, child: _buildTopBar(l10n, isDark)),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildWelcomeHeader(l10n),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      children: [
                    const SizedBox(height: 20),

                    // Tab switch
                    _buildTabSwitch(l10n, isDark),

                    const SizedBox(height: 16),

                    // Tab content
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        return IndexedStack(
                          index: _tabController.index,
                          sizing: StackFit.loose,
                          children: [
                            _buildSignInForm(l10n, theme, isDark),
                            _buildSignUpForm(l10n, theme, isDark),
                          ],
                        );
                      },
                    ),
                        const SizedBox(height: 24),
                      ],
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

  /// Green welcome header from the comp: B4 mark, greeting, subtitle.
  Widget _buildWelcomeHeader(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.paddingOf(context).top + 12, 24, 30),
      decoration: const BoxDecoration(
        color: Ds.green,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Ds.rSheet),
            ),
            alignment: Alignment.center,
            child: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'B'),
                  TextSpan(text: '4', style: TextStyle(color: Ds.gold)),
                ],
              ),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Ds.green),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.signIn,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to continue',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Language toggle
          Consumer<LanguageProvider>(
            builder: (context, langProvider, _) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLangChip('EN', 'en', langProvider, isDark),
                    _buildLangChip('FR', 'fr', langProvider, isDark),
                  ],
                ),
              );
            },
          ),

          // Skip button
          TextButton.icon(
            onPressed: () => _skipAuth(context),
            icon: Text(
              l10n.skipForNow,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.burundiGreen,
              ),
            ),
            label: const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppColors.burundiGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(String label, String code, LanguageProvider provider, bool isDark) {
    final isSelected = provider.languageCode == code;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        provider.setLanguage(code);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.burundiGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitch(AppLocalizations l10n, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rTile),
        boxShadow: Ds.shadow(context),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) {
          HapticFeedback.selectionClick();
          setState(() {});
        },
        indicator: BoxDecoration(
          color: Ds.green,
          borderRadius: BorderRadius.circular(Ds.rTile),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: l10n.signIn),
          Tab(text: l10n.signUp),
        ],
      ),
    );
  }

  Widget _buildSignInForm(AppLocalizations l10n, ThemeData theme, bool isDark) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email
          _buildTextField(
            controller: _signInEmailController,
            hint: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
            validator: InputSanitizer.validateEmail,
          ),
          const SizedBox(height: 12),

          // Password
          _buildTextField(
            controller: _signInPasswordController,
            hint: l10n.password,
            icon: Icons.lock_outlined,
            obscureText: _obscureSignInPassword,
            isDark: isDark,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
            suffixIcon: IconButton(
              tooltip: _obscureSignInPassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscureSignInPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
            ),
          ),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showForgotPasswordDialog(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.forgotPassword,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.burundiGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sign In button
          _buildPrimaryButton(
            label: l10n.signIn,
            onPressed: () => _signIn(context),
            isLoading: context.watch<AuthProvider>().isLoading,
            color: AppColors.burundiGreen,
          ),
          const SizedBox(height: 16),

          // OR divider
          _buildOrDivider(isDark),
          const SizedBox(height: 16),

          // Social Sign-In buttons (side by side)
          _buildSocialButtons(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(AppLocalizations l10n, ThemeData theme, bool isDark) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name
          _buildTextField(
            controller: _signUpNameController,
            hint: l10n.fullName,
            icon: Icons.person_outlined,
            isDark: isDark,
            validator: InputSanitizer.validateName,
          ),
          const SizedBox(height: 10),

          // Email
          _buildTextField(
            controller: _signUpEmailController,
            hint: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
            validator: InputSanitizer.validateEmail,
          ),
          const SizedBox(height: 10),

          // Password
          _buildTextField(
            controller: _signUpPasswordController,
            hint: l10n.password,
            icon: Icons.lock_outlined,
            obscureText: _obscureSignUpPassword,
            isDark: isDark,
            onChanged: (value) => setState(() => _signUpPassword = value),
            suffixIcon: IconButton(
              tooltip: _obscureSignUpPassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscureSignUpPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
            ),
            validator: InputSanitizer.validatePassword,
          ),
          PasswordStrengthMeter(password: _signUpPassword),
          const SizedBox(height: 10),

          // Confirm Password
          _buildTextField(
            controller: _signUpConfirmPasswordController,
            hint: l10n.confirmPassword,
            icon: Icons.lock_outlined,
            obscureText: _obscureConfirmPassword,
            isDark: isDark,
            suffixIcon: IconButton(
              tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Confirm password';
              if (value != _signUpPasswordController.text) return 'Passwords don\'t match';
              return null;
            },
          ),

          // Honeypot field — invisible to real users, bots auto-fill it.
          ExcludeSemantics(
            child: SizedBox(
              height: 0,
              child: Opacity(
                opacity: 0,
                child: TextFormField(
                  controller: _honeypotController,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Leave this field empty',
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sign Up button
          _buildPrimaryButton(
            label: l10n.signUp,
            onPressed: () => _signUp(context),
            isLoading: context.watch<AuthProvider>().isLoading,
            color: AppColors.burundiRed,
          ),
          const SizedBox(height: 16),

          // OR divider
          _buildOrDivider(isDark),
          const SizedBox(height: 16),

          // Social Sign-In buttons (side by side)
          _buildSocialButtons(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        boxShadow: Ds.shadow(context),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: Ds.ink(context)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w400, color: Ds.muted(context)),
          prefixIcon: Icon(icon, size: 20, color: Ds.green),
          suffixIcon: suffixIcon,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    required Color color,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildOrDivider(bool isDark) {
    return Row(
      children: [
        Expanded(child: Divider(color: Ds.outline(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with',
              style: TextStyle(fontSize: 12, color: Ds.muted(context))),
        ),
        Expanded(child: Divider(color: Ds.outline(context))),
      ],
    );
  }

  Widget _buildSocialButtons(ThemeData theme, bool isDark) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            label: 'Google',
            iconPath: 'assets/icons/google_logo.png',
            onPressed: () => _signInWithGoogle(context),
            backgroundColor: theme.colorScheme.surface,
            textColor: theme.colorScheme.onSurface,
            borderColor: theme.dividerColor,
            isLoading: isLoading,
          ),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildSocialButton(
              label: 'Apple',
              icon: Icons.apple,
              onPressed: () => _signInWithApple(context),
              backgroundColor: isDark ? Colors.white : Colors.black,
              textColor: isDark ? Colors.black : Colors.white,
              borderColor: isDark ? Colors.white : Colors.black,
              isLoading: isLoading,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    String? iconPath,
    IconData? icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    required bool isLoading,
  }) {
    return Semantics(
      button: true,
      label: 'Sign in with $label',
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Ds.rCard),
          boxShadow: Ds.shadow(context),
        ),
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Ds.rCard),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconPath != null)
                ExcludeSemantics(
                  child: Image.asset(iconPath, width: 20, height: 20, errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported, size: 20);
                  }),
                )
              else if (icon != null)
                Icon(icon, size: 20, semanticLabel: '$label icon'),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    HapticFeedback.lightImpact();
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();
    if (success && context.mounted) {
      if (authProvider.requiresEmailVerification) {
        Navigator.of(context).pushReplacementNamed('/email-verification');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else if (context.mounted && authProvider.errorMessage != null) {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar(context, authProvider.errorMessage!);
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    HapticFeedback.lightImpact();
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithApple();
    if (success && context.mounted) {
      if (authProvider.requiresEmailVerification) {
        Navigator.of(context).pushReplacementNamed('/email-verification');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else if (context.mounted && authProvider.errorMessage != null) {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar(context, authProvider.errorMessage!);
    }
  }

  Future<void> _signIn(BuildContext context) async {
    if (!(_signInFormKey.currentState?.validate() ?? false)) return;
    HapticFeedback.lightImpact();
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      _signInEmailController.text,
      _signInPasswordController.text,
    );
    if (success && context.mounted) {
      // Check if email verification is required
      if (authProvider.requiresEmailVerification) {
        Navigator.of(context).pushReplacementNamed('/email-verification');
        return;
      }

      // Check if profile is incomplete (name, gender, nationality are required)
      final isProfileIncomplete = (authProvider.userName?.isEmpty ?? true) ||
          (authProvider.gender?.isEmpty ?? true) ||
          (authProvider.nationality?.isEmpty ?? true);

      if (isProfileIncomplete) {
        // Show complete profile dialog
        _showCompleteProfileDialog(context);
      } else {
        // Navigate to home
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else if (context.mounted && authProvider.errorMessage != null) {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar(context, authProvider.errorMessage!);
    }
  }

  Future<void> _signUp(BuildContext context) async {
    // Validate form before proceeding
    if (!_signUpFormKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      InputSanitizer.sanitizeName(_signUpNameController.text),
      _signUpEmailController.text.trim(),
      _signUpPasswordController.text,
      honeypot: _honeypotController.text,
    );
    if (success && context.mounted) {
      // After sign-up: require email verification
      if (authProvider.requiresEmailVerification) {
        Navigator.of(context).pushReplacementNamed('/email-verification');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else if (context.mounted && authProvider.errorMessage != null) {
      HapticFeedback.heavyImpact();
      // Check if the error is about an existing account
      if (authProvider.errorMessage!.contains('already registered')) {
        _showAccountExistsDialog(context, _signUpEmailController.text);
      } else {
        _showErrorSnackBar(context, authProvider.errorMessage!);
      }
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.burundiRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAccountExistsDialog(BuildContext context, String email) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.patternOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_circle_outlined, color: AppColors.patternOrange, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Account Exists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'An account with $email is already registered. Please sign in instead.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.patternOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              // Pre-fill the sign-in email and switch to Sign In tab
              _signInEmailController.text = email;
              _tabController.animateTo(0);
            },
            child: const Text('Go to Sign In'),
          ),
        ],
      ),
    );
  }

  void _showCompleteProfileDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.burundiGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person_outline, color: AppColors.burundiGreen, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Complete Your Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.darkBackground,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help us personalize your experience by completing your profile information.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.auGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.auGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.auGold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This will only take a minute',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: Text(
              'Skip for Now',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/profile-completion');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Complete Profile', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _skipAuth(BuildContext context) {
    context.read<AuthProvider>().skipAuth();

    // If this auth screen was pushed on top of an existing screen (e.g. from
    // a login gate), just pop back. Otherwise replace with home.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.person_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Continuing as guest'),
          ],
        ),
        backgroundColor: AppColors.burundiGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your email address'),
                    backgroundColor: AppColors.burundiRed,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);

              final authProvider = context.read<AuthProvider>();
              final success = await authProvider.sendPasswordResetEmail(email);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Password reset link sent to $email'
                          : 'Failed to send reset link. Please try again.',
                    ),
                    backgroundColor: success ? AppColors.burundiGreen : AppColors.burundiRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}
