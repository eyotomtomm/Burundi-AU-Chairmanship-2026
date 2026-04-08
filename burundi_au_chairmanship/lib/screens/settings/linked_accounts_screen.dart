import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../l10n/app_localizations.dart';

/// Screen that displays all auth providers linked to the user's account
/// and allows linking/unlinking Google, Apple, and email/password providers.
class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  final ApiService _api = ApiService();
  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();

  List<Map<String, dynamic>> _linkedAccounts = [];
  bool _isLoading = true;
  bool _isLinking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLinkedAccounts();
  }

  Future<void> _loadLinkedAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final accounts = await _api.getLinkedAccounts();
      if (mounted) {
        setState(() {
          _linkedAccounts = accounts;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load linked accounts';
          _isLoading = false;
        });
      }
    }
  }

  bool _isProviderLinked(String provider) {
    return _linkedAccounts.any((a) => a['provider'] == provider);
  }

  int get _totalLinked => _linkedAccounts.length;

  Future<void> _linkGoogleAccount() async {
    if (_isLinking) return;
    setState(() => _isLinking = true);

    try {
      // Trigger Google sign-in to get credentials
      final credential = await _firebaseAuth.signInWithGoogle();
      final user = credential.user;

      if (user == null) {
        throw Exception('Google sign-in returned no user');
      }

      await _api.linkAccount(
        provider: 'google',
        providerUid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google account linked successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadLinkedAccounts();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final msg = _firebaseAuth.getErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link Google account: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _linkAppleAccount() async {
    if (_isLinking) return;
    setState(() => _isLinking = true);

    try {
      final credential = await _firebaseAuth.signInWithApple();
      final user = credential.user;

      if (user == null) {
        throw Exception('Apple sign-in returned no user');
      }

      await _api.linkAccount(
        provider: 'apple',
        providerUid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apple account linked successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadLinkedAccounts();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final msg = _firebaseAuth.getErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link Apple account: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _linkEmailPassword() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Link Email/Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Set an email and password to use as an additional sign-in method.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Link'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _isLinking = true);

    try {
      // Create email/password credential in Firebase
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await firebaseUser.linkWithCredential(credential);
      }

      await _api.linkAccount(
        provider: 'email',
        providerUid: email,
        email: email,
        displayName: '',
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email/password linked successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadLinkedAccounts();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final msg = _firebaseAuth.getErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link email: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _unlinkAccount(Map<String, dynamic> account) async {
    final provider = account['provider'] as String;
    final providerDisplay = account['provider_display'] as String? ?? provider;

    if (_totalLinked <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot unlink your only sign-in method. Link another provider first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            const SizedBox(width: 8),
            Text('Unlink $providerDisplay?'),
          ],
        ),
        content: Text(
          'You will no longer be able to sign in with your $providerDisplay account.\n\n'
          'Make sure you have another sign-in method available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLinking = true);
    try {
      await _api.unlinkAccount(
        provider,
        providerUid: account['provider_uid'] as String?,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$providerDisplay account unlinked'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadLinkedAccounts();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unlink: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  IconData _getProviderIcon(String provider) {
    switch (provider) {
      case 'google':
        return Icons.g_mobiledata_rounded;
      case 'apple':
        return Icons.apple_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'firebase':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  Color _getProviderColor(String provider) {
    switch (provider) {
      case 'google':
        return const Color(0xFF4285F4);
      case 'apple':
        return Colors.black87;
      case 'email':
        return AppColors.burundiGreen;
      case 'firebase':
        return const Color(0xFFFFA000);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked Accounts'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.burundiGreen))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadLinkedAccounts,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.burundiGreen),
                        child: Text(l10n.translate('retry')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLinkedAccounts,
                  color: AppColors.burundiGreen,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Header info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.burundiGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.burundiGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.burundiGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.link_rounded,
                                color: AppColors.burundiGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Manage Sign-In Methods',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Link multiple providers to sign in with any of them. '
                                    'You must keep at least one.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Currently linked accounts
                      if (_linkedAccounts.isNotEmpty) ...[
                        Text(
                          'LINKED ACCOUNTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < _linkedAccounts.length; i++) ...[
                                if (i > 0)
                                  const Divider(height: 1, indent: 16, endIndent: 16),
                                _buildLinkedAccountTile(_linkedAccounts[i]),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Available providers to link
                      Text(
                        'LINK NEW PROVIDER',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Google
                            _buildLinkProviderTile(
                              provider: 'google',
                              label: 'Link Google Account',
                              icon: Icons.g_mobiledata_rounded,
                              color: const Color(0xFF4285F4),
                              isLinked: _isProviderLinked('google'),
                              onTap: _linkGoogleAccount,
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            // Apple (only show on iOS/macOS)
                            if (Platform.isIOS || Platform.isMacOS)
                              ...[
                                _buildLinkProviderTile(
                                  provider: 'apple',
                                  label: 'Link Apple Account',
                                  icon: Icons.apple_rounded,
                                  color: isDark ? Colors.white : Colors.black87,
                                  isLinked: _isProviderLinked('apple'),
                                  onTap: _linkAppleAccount,
                                ),
                                const Divider(height: 1, indent: 16, endIndent: 16),
                              ],
                            // Email/Password
                            _buildLinkProviderTile(
                              provider: 'email',
                              label: 'Link Email/Password',
                              icon: Icons.email_rounded,
                              color: AppColors.burundiGreen,
                              isLinked: _isProviderLinked('email'),
                              onTap: _linkEmailPassword,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLinkedAccountTile(Map<String, dynamic> account) {
    final provider = account['provider'] as String? ?? 'unknown';
    final providerDisplay = account['provider_display'] as String? ?? provider;
    final email = account['email'] as String? ?? '';
    final displayName = account['display_name'] as String? ?? '';
    final linkedAt = account['linked_at'] as String? ?? '';
    final isPrimary = account['is_primary'] as bool? ?? false;
    final canUnlink = _totalLinked > 1;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _getProviderColor(provider).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _getProviderIcon(provider),
          color: _getProviderColor(provider),
          size: 24,
        ),
      ),
      title: Row(
        children: [
          Text(
            providerDisplay,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          if (isPrimary) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.burundiGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PRIMARY',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (email.isNotEmpty)
            Text(email, style: const TextStyle(fontSize: 13)),
          if (displayName.isNotEmpty && displayName != email)
            Text(displayName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (linkedAt.isNotEmpty)
            Text(
              'Linked ${_formatDate(linkedAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
      trailing: canUnlink
          ? IconButton(
              icon: const Icon(Icons.link_off_rounded, color: AppColors.error, size: 20),
              tooltip: 'Unlink',
              onPressed: _isLinking ? null : () => _unlinkAccount(account),
            )
          : Tooltip(
              message: 'Cannot unlink your only sign-in method',
              child: Icon(
                Icons.lock_outline,
                color: Colors.grey.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
    );
  }

  Widget _buildLinkProviderTile({
    required String provider,
    required String label,
    required IconData icon,
    required Color color,
    required bool isLinked,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isLinked ? Colors.grey : null,
        ),
      ),
      subtitle: isLinked
          ? const Text('Already linked', style: TextStyle(fontSize: 12, color: Colors.grey))
          : null,
      trailing: isLinked
          ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
          : _isLinking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.burundiGreen,
                  ),
                )
              : const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.burundiGreen,
                  size: 22,
                ),
      onTap: isLinked || _isLinking ? null : onTap,
    );
  }
}
