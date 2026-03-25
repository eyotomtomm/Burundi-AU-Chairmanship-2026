import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  bool _otpSent = false;
  String? _errorMessage;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.sendSignupEmailOtp();
      if (mounted) {
        setState(() {
          _isSending = false;
          _otpSent = success;
        });
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
        setState(() {
          _isSending = false;
          _errorMessage = 'Failed to send verification code. Try again.';
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit code';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.verifySignupEmailOtp(code);
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
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Verification failed. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final email = authProvider.userEmail ?? '';

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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 40,
                  color: AppColors.burundiGreen,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle with email
              Text(
                'We need to verify your email address to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.burundiGreen,
                ),
              ),
              const SizedBox(height: 32),

              // Send Code / OTP Entry
              if (!_otpSent) ...[
                // Send Code button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burundiGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Send Verification Code',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ] else ...[
                // OTP input
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 12,
                    color: isDark ? Colors.white : AppColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.3) : Colors.grey[300],
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 12,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.burundiGreen, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 20),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burundiGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resend code
                TextButton(
                  onPressed: _resendCountdown > 0 ? null : _sendOtp,
                  child: Text(
                    _resendCountdown > 0
                        ? 'Resend code in ${_resendCountdown}s'
                        : 'Resend Code',
                    style: TextStyle(
                      color: _resendCountdown > 0
                          ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                          : AppColors.burundiGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.burundiRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.burundiRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.burundiRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Email verification is required to access the app. Check your inbox and spam folder.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
