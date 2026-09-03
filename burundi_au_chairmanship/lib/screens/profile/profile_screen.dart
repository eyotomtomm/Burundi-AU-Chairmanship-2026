import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/verification_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/verified_badge.dart';
import '../../services/api_service.dart';
import '../../widgets/translate_button.dart';
import '../security/change_password_screen.dart';
import '../settings/linked_accounts_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double _completionPercent = 0.0;
  String _completionMessage = '';
  bool _completionLoaded = false;

  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_onAuthChanged);
    _loadProfileCompletion();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    // Re-fetch completion whenever profile data changes
    _loadProfileCompletion();
  }

  Future<void> _loadProfileCompletion() async {
    try {
      final api = ApiService();
      final data = await api.getProfileCompletion();
      if (mounted) {
        setState(() {
          _completionPercent = (data['percentage'] as num?)?.toDouble() ?? 0.0;
          final fields = data['fields'] as Map<String, dynamic>? ?? {};
          final missing = fields.entries.where((e) => e.value == false).map((e) => e.key).toList();
          _completionMessage = missing.isEmpty ? '' : 'Missing: ${missing.join(', ')}';
          _completionLoaded = true;
        });
      }
    } catch (_) {
      // Silently fail - completion is non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return CustomScrollView(
            slivers: [
              // Green profile header
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                      20, MediaQuery.paddingOf(context).top + 20, 20, 24),
                  decoration: const BoxDecoration(
                    color: Ds.green,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.pop(context),
                            child: const SizedBox(
                              width: 30,
                              height: 36,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Icon(Icons.arrow_back_rounded,
                                    size: 22, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Profile',
                                style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: Colors.white)),
                          ),
                          const TranslateButton(),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          // Tap the avatar to change the profile picture.
                          GestureDetector(
                            onTap: () =>
                                _showProfilePictureOptions(context, authProvider),
                            child: Stack(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle, color: Colors.white),
                                  child: ClipOval(
                                    child: authProvider.profilePictureUrl != null &&
                                            authProvider.profilePictureUrl!.isNotEmpty
                                        ? Semantics(
                                            label: 'Profile picture',
                                            child: CachedNetworkImage(
                                              imageUrl: authProvider.profilePictureUrl!,
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  _buildInitialsAvatar(authProvider),
                                              errorWidget: (context, url, error) =>
                                                  _buildInitialsAvatar(authProvider),
                                            ),
                                          )
                                        : _buildInitialsAvatar(authProvider),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Ds.green,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        size: 14,
                                        color: Colors.white,
                                        semanticLabel: 'Change profile picture'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        authProvider.userName ?? 'User',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white),
                                      ),
                                    ),
                                    if (authProvider.isVerified)
                                      Builder(builder: (ctx) {
                                        final vStatus =
                                            Provider.of<VerificationProvider>(ctx,
                                                    listen: false)
                                                .requestStatus;
                                        if (vStatus == 'pending' ||
                                            vStatus == 'rejected') {
                                          return const SizedBox.shrink();
                                        }
                                        return Row(children: [
                                          const SizedBox(width: 6),
                                          VerifiedBadge(
                                              badgeType: authProvider.badgeType,
                                              size: 18),
                                        ]);
                                      }),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  authProvider.verificationRole?.isNotEmpty == true
                                      ? authProvider.verificationRole!
                                      : (authProvider.userEmail ?? ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.85)),
                                ),
                                if (authProvider.isEmailVerified ||
                                    authProvider.isGovernmentOfficial) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (authProvider.isEmailVerified)
                                        _headerPill('VERIFIED'),
                                      if (authProvider.isGovernmentOfficial)
                                        _headerPill('OFFICIAL'),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Profile completion ───────────────────────────
              if (_completionLoaded && _completionPercent < 100)
                SliverToBoxAdapter(
                  child: DsCard(
                    featured: true,
                    margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: _completionPercent / 100.0,
                                strokeWidth: 5,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Ds.subtle(context),
                                valueColor:
                                    const AlwaysStoppedAnimation(Ds.green),
                              ),
                              Center(
                                child: Text('${_completionPercent.toInt()}%',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Ds.green)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.translate('complete_your_profile'),
                                  style: Ds.sectionTitle(context)),
                              if (_completionMessage.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(_completionMessage,
                                    style: Ds.cardBody(context)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Personal information ─────────────────────────
              SliverToBoxAdapter(
                child: DsGroupLabel(l10n.translate('personal_info')),
              ),
              SliverToBoxAdapter(
                child: DsTileGroup(
                  children: [
                    DsTile(
                      icon: Icons.person_outline,
                      iconTint: Ds.tint(context),
                      iconColor: Ds.green,
                      title: l10n.translate('full_name'),
                      subtitle: authProvider.userName ?? 'Not set',
                      onTap: () =>
                          _showEditNameDialog(context, authProvider, l10n),
                    ),
                    // Email is read-only: neutral square, no chevron.
                    DsTile(
                      icon: Icons.email_outlined,
                      title: l10n.translate('email'),
                      subtitle: authProvider.userEmail ?? 'Not set',
                      chevron: false,
                    ),
                    DsTile(
                      icon: Icons.phone_outlined,
                      iconTint: Ds.tint(context),
                      iconColor: Ds.green,
                      title: 'Phone Number',
                      subtitle: _getPhoneLabel(authProvider.phoneNumber),
                      onTap: () =>
                          _showEditPhoneDialog(context, authProvider, l10n),
                    ),
                    DsTile(
                      icon: Icons.wc_outlined,
                      iconTint: Ds.tint(context),
                      iconColor: Ds.green,
                      title: 'Gender',
                      subtitle: _getGenderLabel(authProvider.gender),
                      onTap: () =>
                          _showEditGenderDialog(context, authProvider, l10n),
                    ),
                    DsTile(
                      icon: Icons.flag_outlined,
                      iconTint: Ds.tint(context),
                      iconColor: Ds.green,
                      title: 'Nationality',
                      subtitle: _getNationalityLabel(authProvider.nationality),
                      onTap: () => _showEditNationalityDialog(
                          context, authProvider, l10n),
                    ),
                    DsTile(
                      icon: Icons.cake_outlined,
                      iconTint: Ds.tint(context),
                      iconColor: Ds.green,
                      title: 'Date of Birth',
                      subtitle: _formatDob(authProvider.dateOfBirth),
                      onTap: () =>
                          _showEditDobDialog(context, authProvider, l10n),
                    ),
                  ],
                ),
              ),

              // ── Account & privacy ────────────────────────────
              SliverToBoxAdapter(
                child: DsGroupLabel(l10n.translate('data_privacy')),
              ),
              SliverToBoxAdapter(
                child: DsTileGroup(
                  children: [
                    // Password rows only exist for email/password accounts.
                    if (authProvider.hasPasswordProvider)
                      DsTile(
                        icon: Icons.lock_outline,
                        iconTint: Ds.tint(context),
                        iconColor: Ds.green,
                        title: l10n.translate('change_password'),
                        subtitle: 'Update your account password',
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        ),
                      ),
                    DsTile(
                      icon: Icons.link_rounded,
                      iconTint: Ds.blueTint,
                      iconColor: Ds.blue,
                      title: 'Linked Accounts',
                      subtitle: 'Manage sign-in methods',
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const LinkedAccountsScreen(),
                        ),
                      ),
                    ),
                    DsTile(
                      icon: Icons.logout_rounded,
                      title: l10n.translate('sign_out'),
                      subtitle: 'End this session on this device',
                      onTap: () => _handleSignOut(context, authProvider),
                    ),
                  ],
                ),
              ),

              // ── Danger zone ──────────────────────────────────
              SliverToBoxAdapter(
                child: DsGroupLabel(l10n.translate('danger_zone')),
              ),
              SliverToBoxAdapter(
                child: DsTileGroup(
                  children: [
                    DsTile(
                      icon: Icons.pause_circle_outline,
                      iconTint: Ds.goldTintOf(context),
                      iconColor: Ds.goldInk,
                      title: 'Take a Break',
                      subtitle:
                          'Deactivate your account temporarily. Log in anytime to come back.',
                      onTap: () =>
                          _handleDeactivateAccount(context, authProvider, l10n),
                    ),
                    DsTile(
                      icon: Icons.delete_forever_outlined,
                      iconTint: Ds.redTintOf(context),
                      iconColor: Ds.red,
                      title: l10n.translate('delete_account'),
                      titleColor: Ds.red,
                      subtitle:
                          'Schedule permanent deletion. You have 30 days to change your mind.',
                      onTap: () =>
                          _handleDeleteAccount(context, authProvider, l10n),
                    ),
                  ],
                ),
              ),

              // Bottom safe area spacing
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditNameDialog(
      BuildContext context, AuthProvider authProvider, AppLocalizations l10n) {
    final controller = TextEditingController(text: authProvider.userName ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.translate('update_name')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.translate('full_name'),
              hintText: l10n.translate('enter_name'),
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.burundiGreen, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.translate('enter_name');
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(dialogContext);

              final success =
                  await authProvider.updateProfile(controller.text.trim());

              if (context.mounted) {
                if (success) {
                  HapticFeedback.mediumImpact();
                } else {
                  HapticFeedback.heavyImpact();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? l10n.translate('profile_updated')
                        : (authProvider.errorMessage ??
                            'Failed to update profile')),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: Text(l10n.translate('save')),
          ),
        ],
      ),
    );
  }

  void _handleSignOut(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).translate('sign_out')),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(dialogContext);
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/auth', (route) => false);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: Text(AppLocalizations.of(context).translate('sign_out')),
          ),
        ],
      ),
    );
  }

  /// Translucent status pill used inside the green header.
  static Widget _headerPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(Ds.rPill),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      );

  static Widget _buildInitialsAvatar(AuthProvider authProvider) {
    return Center(
      child: authProvider.userName != null && authProvider.userName!.isNotEmpty
          ? Text(
              authProvider.userName![0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            )
          : const Icon(Icons.person, size: 44, color: Colors.white),
    );
  }

  void _handleDeactivateAccount(
      BuildContext context, AuthProvider authProvider, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline,
                color: AppColors.warning, size: 28),
            SizedBox(width: 8),
            Text('Take a Break'),
          ],
        ),
        content: const Text(
          'Your account will be deactivated and hidden from other users. '
          'All your data will be preserved.\n\n'
          'Simply log in again anytime to reactivate your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) =>
                    const Center(child: CircularProgressIndicator()),
              );

              final success = await authProvider.deactivateAccount();

              if (context.mounted) {
                Navigator.pop(context);

                if (success) {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account deactivated. Log in anytime to come back!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/auth', (route) => false);
                } else {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(authProvider.errorMessage ??
                          'Failed to deactivate account'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Take a Break'),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount(
      BuildContext context, AuthProvider authProvider, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 28),
            const SizedBox(width: 8),
            Text(l10n.translate('delete_account')),
          ],
        ),
        content: const Text(
          'Your account will be scheduled for permanent deletion.\n\n'
          'You have 30 days to change your mind - just log in again to cancel.\n\n'
          'After 30 days, all your data will be permanently removed and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) =>
                    const Center(child: CircularProgressIndicator()),
              );

              final success = await authProvider.deleteAccount();

              if (context.mounted) {
                Navigator.pop(context); // Close loading

                if (success) {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account scheduled for deletion. Log in within 30 days to cancel.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/auth', (route) => false);
                } else {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(authProvider.errorMessage ??
                          'Failed to delete account'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.translate('delete_account')),
          ),
        ],
      ),
    );
  }

  String _getGenderLabel(String? gender) {
    if (gender == null || gender.isEmpty) return 'Not set';
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return 'Not set';
    }
  }

  String _getNationalityLabel(String? code) {
    if (code == null || code.isEmpty) return 'Not set';
    final name = AppConstants.nationalityChoices[code] ?? code;
    final flag = AppConstants.countryFlag(code);
    return '$flag  $name';
  }

  String _getPhoneLabel(String? phone) {
    if (phone == null || phone.isEmpty) return 'Not set';
    // Try to find the country flag from the dial code prefix
    for (final entry in AppConstants.countryDialCodes.entries) {
      if (phone.startsWith(entry.value)) {
        final flag = AppConstants.countryFlag(entry.key);
        return '$flag  $phone';
      }
    }
    return phone;
  }

  String _formatDob(String? dob) {
    if (dob == null || dob.isEmpty) return 'Not set';
    try {
      final date = DateTime.parse(dob);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dob;
    }
  }

  void _showEditPhoneDialog(
      BuildContext context, AuthProvider authProvider, AppLocalizations l10n) {
    // Parse existing phone number to separate dial code and number
    final existingPhone = authProvider.phoneNumber ?? '';
    String selectedCountryCode = 'BI'; // Default to Burundi

    // Try to detect country code from nationality or existing phone
    if (authProvider.nationality != null &&
        AppConstants.countryDialCodes.containsKey(authProvider.nationality)) {
      selectedCountryCode = authProvider.nationality!;
    }

    String phoneBody = existingPhone;
    // Strip known dial code prefix from existing phone
    for (final entry in AppConstants.countryDialCodes.entries) {
      if (existingPhone.startsWith(entry.value)) {
        selectedCountryCode = entry.key;
        phoneBody = existingPhone.substring(entry.value.length).trim();
        break;
      }
    }

    final controller = TextEditingController(text: phoneBody);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Phone Number'),
        content: Form(
          key: formKey,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country code picker
                  GestureDetector(
                    onTap: () {
                      _showCountryCodePicker(context, selectedCountryCode, (code) {
                        setState(() => selectedCountryCode = code);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppConstants.countryFlag(selectedCountryCode),
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppConstants.countryDialCodes[selectedCountryCode] ?? '+257',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Phone number field
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'XX XXX XXXX',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.patternOrange, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.patternOrange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final dialCode = AppConstants.countryDialCodes[selectedCountryCode] ?? '+257';
              final fullPhone = '$dialCode${controller.text.trim()}';
              Navigator.pop(dialogContext);
              final success = await authProvider.updateProfile(
                authProvider.userName ?? '',
                phoneNumber: fullPhone,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Phone number updated to $fullPhone'
                        : 'Failed to update phone number'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: Text(l10n.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showCountryCodePicker(BuildContext context, String currentCode, ValueChanged<String> onSelected) {
    String searchQuery = '';
    final entries = AppConstants.countryDialCodes.entries
        .where((e) => AppConstants.nationalityChoices.containsKey(e.key))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = entries.where((e) {
              final name = AppConstants.nationalityChoices[e.key]?.toLowerCase() ?? '';
              final code = e.value.toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || code.contains(query) || e.key.toLowerCase().contains(query);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.85,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search country...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (value) => setState(() => searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final countryName = AppConstants.nationalityChoices[entry.key] ?? entry.key;
                          final isSelected = entry.key == currentCode;
                          return ListTile(
                            leading: Text(
                              AppConstants.countryFlag(entry.key),
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(countryName),
                            trailing: Text(
                              entry.value,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isSelected ? AppColors.patternOrange : null,
                              ),
                            ),
                            selected: isSelected,
                            onTap: () {
                              onSelected(entry.key);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showEditGenderDialog(
      BuildContext context, AuthProvider authProvider, AppLocalizations l10n) {
    String selectedGender = (authProvider.gender == 'male' || authProvider.gender == 'female')
        ? authProvider.gender!
        : 'male';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Gender'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return RadioGroup<String>(
              groupValue: selectedGender,
              onChanged: (value) {
                setState(() => selectedGender = value!);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Male'),
                    value: 'male',
                    activeColor: AppColors.success,
                  ),
                  RadioListTile<String>(
                    title: const Text('Female'),
                    value: 'female',
                    activeColor: AppColors.success,
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await authProvider.updateProfile(
                authProvider.userName ?? '',
                gender: selectedGender,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Gender updated'
                        : 'Failed to update gender'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: Text(l10n.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showEditNationalityDialog(
      BuildContext context, AuthProvider authProvider, AppLocalizations l10n) {
    String? selectedCode = authProvider.nationality;
    final entries = AppConstants.nationalityChoices.entries.toList();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Nationality'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StatefulBuilder(
            builder: (context, setState) {
              final filtered = entries.where((e) {
                final query = searchQuery.toLowerCase();
                return query.isEmpty ||
                    e.value.toLowerCase().contains(query) ||
                    e.key.toLowerCase().contains(query);
              }).toList();

              return Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search country...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: RadioGroup<String>(
                      groupValue: selectedCode ?? '',
                      onChanged: (value) {
                        setState(() => selectedCode = value);
                      },
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          return RadioListTile<String>(
                            title: Text('${AppConstants.countryFlag(entry.key)} ${entry.value}'),
                            value: entry.key,
                            activeColor: AppColors.burundiGreen,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (selectedCode != null) {
                final success = await authProvider.updateProfile(
                  authProvider.userName ?? '',
                  nationality: selectedCode,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Nationality updated' : 'Failed to update'),
                      backgroundColor: success ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showEditDobDialog(
      BuildContext context, AuthProvider authProvider, AppLocalizations l10n) async {
    DateTime initialDate;
    try {
      initialDate = authProvider.dateOfBirth != null && authProvider.dateOfBirth!.isNotEmpty
          ? DateTime.parse(authProvider.dateOfBirth!)
          : DateTime(2000, 1, 1);
    } catch (_) {
      initialDate = DateTime(2000, 1, 1);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.auGold,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      final dobString = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      final success = await authProvider.updateProfile(
        authProvider.userName ?? '',
        dateOfBirth: dobString,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Date of birth updated' : 'Failed to update'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  static void _showProfilePictureOptions(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppColors.burundiGreen),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(context, authProvider, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.burundiGreen),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(context, authProvider, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: AppColors.error),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _pickAndUploadImage(
    BuildContext context,
    AuthProvider authProvider,
    ImageSource source,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: AppColors.burundiGreen,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.burundiGreen,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Upload to backend
      final imageFile = File(croppedFile.path);
      final success = await authProvider.uploadProfilePicture(imageFile);

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        if (success) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.heavyImpact();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Profile picture updated!'
                : (authProvider.errorMessage ?? 'Failed to upload image')),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if open
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
