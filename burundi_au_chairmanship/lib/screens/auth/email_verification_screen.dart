import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Email verification gate:
///   Sends OTP to user's registration email and verifies it before proceeding.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // ── State ─────────────────────────────────────────────────
  String? _errorMessage;

  // ── Email OTP ─────────────────────────────────────────────
  final _emailOtpController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _emailOtpSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Auto-send OTP as soon as the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendEmailOtp());
  }

  @override
  void dispose() {
    _emailOtpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────
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

  // ── Send Email OTP ────────────────────────────────────────
  Future<void> _sendEmailOtp() async {
    setState(() { _isSending = true; _errorMessage = null; });
    try {
      final authProvider = context.read<AuthProvider>();
      final success = authProvider.userId == null
          ? await authProvider.sendPendingSignupOtp()
          : await authProvider.sendSignupEmailOtp();
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
      final success = authProvider.userId == null
          ? await authProvider.verifyPendingSignupOtp(code)
          : await authProvider.verifySignupEmailOtp(code);
      if (mounted) {
        if (success) {
          Navigator.of(context).pushReplacementNamed('/home');
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

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = context.watch<AuthProvider>().userEmail ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 60),

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
              Text(_emailOtpSent ? 'A verification code has been sent to your email.' : 'We need to verify your email address to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 8),
              Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.burundiGreen)),
              const SizedBox(height: 32),

              if (_isSending && !_emailOtpSent) ...[
                const SizedBox(height: 8),
                const CircularProgressIndicator(color: AppColors.burundiGreen),
                const SizedBox(height: 16),
                Text('Sending verification code...', style: TextStyle(
                  fontSize: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                )),
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
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    final navigator = Navigator.of(context);
                    await authProvider.signOut();
                    if (mounted) {
                      navigator.pushNamedAndRemoveUntil('/auth', (route) => false);
                    }
                  },
                  child: Text(
                    'Use a different email',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
          ),
        ),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────
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
        hintText: '${String.fromCharCode(8226)} ${String.fromCharCode(8226)} ${String.fromCharCode(8226)} ${String.fromCharCode(8226)} ${String.fromCharCode(8226)} ${String.fromCharCode(8226)}',
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.5) : Colors.grey[400],
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12,
        ),
        counterText: '',
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.burundiGreen, width: 1.5)),
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
