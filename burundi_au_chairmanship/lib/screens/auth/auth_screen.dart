import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

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

  bool _obscureSignInPassword = true;
  bool _obscureSignUpPassword = true;
  bool _obscureConfirmPassword = true;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: Language toggle + Skip
            _buildTopBar(l10n, isDark),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Logo
                    _buildLogo(),

                    const SizedBox(height: 16),

                    // App title
                    Text(
                      'BURUNDI',
                      style: GoogleFonts.oswald(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.burundiGreen,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AU CHAIRMANSHIP 2026',
                      style: GoogleFonts.oswald(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Tab switch
                    _buildTabSwitch(l10n, isDark),

                    const SizedBox(height: 24),

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
            ),
          ],
        ),
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
              style: GoogleFonts.oswald(
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
      onTap: () => provider.setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.burundiGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: GoogleFonts.oswald(
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

  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.2), width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/Burundi Embassy in Addis Ababa.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.shield_rounded,
            size: 40,
            color: AppColors.burundiGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitch(AppLocalizations l10n, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          color: AppColors.burundiGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        labelStyle: GoogleFonts.oswald(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        unselectedLabelStyle: GoogleFonts.oswald(
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
          // Welcome text
          Text(
            l10n.welcomeBack,
            style: GoogleFonts.oswald(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.signInContinue,
            style: GoogleFonts.oswald(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Email
          _buildTextField(
            controller: _signInEmailController,
            hint: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Password
          _buildTextField(
            controller: _signInPasswordController,
            hint: l10n.password,
            icon: Icons.lock_outlined,
            obscureText: _obscureSignInPassword,
            isDark: isDark,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignInPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
            ),
          ),
          const SizedBox(height: 8),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                l10n.forgotPassword,
                style: GoogleFonts.oswald(
                  fontSize: 13,
                  color: AppColors.burundiGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sign In button
          _buildPrimaryButton(
            label: l10n.signIn,
            onPressed: () => _signIn(context),
            isLoading: context.watch<AuthProvider>().isLoading,
            color: AppColors.burundiGreen,
          ),
          const SizedBox(height: 16),

          // Continue as Guest button
          OutlinedButton(
            onPressed: () => _skipAuth(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burundiGreen,
              side: BorderSide(color: AppColors.burundiGreen.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.skipForNow,
                  style: GoogleFonts.oswald(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
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
          Text(
            l10n.createAccount,
            style: GoogleFonts.oswald(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Join the Burundi AU community',
            style: GoogleFonts.oswald(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Name
          _buildTextField(
            controller: _signUpNameController,
            hint: l10n.fullName,
            icon: Icons.person_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Email
          _buildTextField(
            controller: _signUpEmailController,
            hint: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Password
          _buildTextField(
            controller: _signUpPasswordController,
            hint: l10n.password,
            icon: Icons.lock_outlined,
            obscureText: _obscureSignUpPassword,
            isDark: isDark,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignUpPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
            ),
          ),
          const SizedBox(height: 14),

          // Confirm Password
          _buildTextField(
            controller: _signUpConfirmPasswordController,
            hint: l10n.confirmPassword,
            icon: Icons.lock_outlined,
            obscureText: _obscureConfirmPassword,
            isDark: isDark,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          const SizedBox(height: 24),

          // Sign Up button
          _buildPrimaryButton(
            label: l10n.signUp,
            onPressed: () => _signUp(context),
            isLoading: context.watch<AuthProvider>().isLoading,
            color: AppColors.burundiRed,
          ),
          const SizedBox(height: 16),

          // Continue as Guest button
          OutlinedButton(
            onPressed: () => _skipAuth(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burundiRed,
              side: BorderSide(color: AppColors.burundiRed.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.skipForNow,
                  style: GoogleFonts.oswald(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.oswald(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.oswald(
          color: isDark ? AppColors.darkTextSecondary : Colors.grey[400],
          fontSize: 15,
        ),
        prefixIcon: Icon(icon, size: 20, color: isDark ? AppColors.darkTextSecondary : Colors.grey[500]),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.burundiGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    required bool isLoading,
    required Color color,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
                style: GoogleFonts.oswald(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }


  Future<void> _signIn(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      _signInEmailController.text,
      _signInPasswordController.text,
    );
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _signUp(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      _signUpNameController.text,
      _signUpEmailController.text,
      _signUpPasswordController.text,
    );
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _skipAuth(BuildContext context) {
    context.read<AuthProvider>().skipAuth();
    Navigator.of(context).pushReplacementNamed('/home');
  }
}
