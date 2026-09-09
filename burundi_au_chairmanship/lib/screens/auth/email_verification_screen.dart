import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

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
            _errorMessage = authProvider.errorMessage ??
                AppLocalizations.of(context).translate('auth_otp_send_failed');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSending = false; _errorMessage = AppLocalizations.of(context).translate('auth_otp_send_failed'); });
      }
    }
  }

  Future<void> _verifyEmailOtp() async {
    final code = _emailOtpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage =
          AppLocalizations.of(context).translate('auth_enter_6_digit_code'));
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
            _errorMessage = authProvider.errorMessage ??
                AppLocalizations.of(context).translate('auth_invalid_code');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isVerifying = false; _errorMessage = AppLocalizations.of(context).translate('auth_verification_failed'); });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().userEmail ?? '';
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Ds.bg(context),
        appBar: AppBar(
          title: Text(l10n.translate('auth_verify_email')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: l10n.translate('auth_back_to_sign_in'),
            onPressed: _backToSignIn,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: Ds.tint(context), shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_unread_rounded,
                    size: 34, color: Ds.green),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.translate('auth_check_inbox'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Ds.ink(context))),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: '${l10n.translate(_emailOtpSent ? 'auth_sent_code_to' : 'auth_need_verify_email')}\n'),
                  TextSpan(
                      text: email,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: Ds.body(context)),
            ),
            const SizedBox(height: 24),

            if (_isSending && !_emailOtpSent) ...[
              const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green)),
              const SizedBox(height: 16),
              Text(l10n.translate('auth_sending_code'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Ds.body(context))),
            ] else ...[
              _buildOtpBoxes(),
              const SizedBox(height: 24),
              if (_isVerifying)
                const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Ds.green))
              else
                DsPrimaryButton(l10n.translate('auth_verify'), radius: 14, onTap: _verifyEmailOtp),
              const SizedBox(height: 18),
              Center(
                child: GestureDetector(
                  onTap: _resendCountdown > 0 ? null : _sendEmailOtp,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.translate('auth_didnt_get_it')),
                        TextSpan(
                          text: _resendCountdown > 0
                              ? '${l10n.translate('auth_resend_in')} 0:${_resendCountdown.toString().padLeft(2, '0')}'
                              : l10n.translate('auth_resend_code'),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _resendCountdown > 0
                                  ? Ds.muted(context)
                                  : Ds.green),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 13, color: Ds.body(context)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onTap: _backToSignIn,
                  child: Text(l10n.translate('auth_use_different_email'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Ds.muted(context))),
                ),
              ),
            ],

            _buildErrorBox(),
            const SizedBox(height: 24),
            DsFootnote(l10n.translate('auth_email_verification_footnote'),
                center: true),
          ],
        ),
      ),
    );
  }

  Future<void> _backToSignIn() async {
    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    await authProvider.signOut();
    if (mounted) {
      navigator.pushNamedAndRemoveUntil('/auth', (route) => false);
    }
  }

  /// Six boxed digit cells with an invisible field capturing the input.
  Widget _buildOtpBoxes() {
    final code = _emailOtpController.text;
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < code.length;
            final isNext = i == code.length;
            return Container(
              width: 46,
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Ds.surface(context),
                borderRadius: BorderRadius.circular(Ds.rTile),
                border: Border.all(
                  color: isNext ? Ds.green : Ds.outline(context),
                  width: 2,
                ),
              ),
              child: Text(
                filled ? code[i] : '',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Ds.ink(context)),
              ),
            );
          }),
        ),
        // Transparent capture field sits on top of the boxes.
        Opacity(
          opacity: 0,
          alwaysIncludeSemantics: true,
          child: SizedBox(
            height: 54,
            child: TextField(
              controller: _emailOtpController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Ds.redTintOf(context),
          borderRadius: BorderRadius.circular(Ds.rIcon),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Ds.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Ds.red, fontSize: 13))),
          ],
        ),
      ),
    );
  }
}
