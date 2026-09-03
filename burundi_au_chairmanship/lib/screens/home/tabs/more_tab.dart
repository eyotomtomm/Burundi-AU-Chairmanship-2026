import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/name_format.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../../config/app_colors.dart';
import '../../../config/app_ds.dart';
import '../../../widgets/ds/ds_widgets.dart';
import '../../../config/app_constants.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/data_saver_service.dart';
import '../../../widgets/verified_badge.dart';
import '../../security/login_history_screen.dart';
import '../../security/active_sessions_screen.dart';
import '../../security/change_password_screen.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../../services/share_service.dart';

class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> with WidgetsBindingObserver {
  final GlobalKey _shareMenuKey = GlobalKey();

  // Feature toggles (loaded from SharedPreferences, set by admin via API)
  bool _newsletterEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeatureFlags();
    // Also fetch flags directly from API to ensure fresh values
    _fetchFeatureFlagsFromApi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFeatureFlags();
    }
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _newsletterEnabled = prefs.getBool('feature_newsletter_enabled') ?? true;
        });
      }
    } catch (_) {}
  }

  /// Opens the store listing URL from backend settings, with hardcoded fallback.
  Future<void> _openStoreListing() async {
    try {
      final settings = await ApiService().getSettings();
      String url;
      if (Platform.isIOS) {
        url = (settings?.appStoreUrl.isNotEmpty == true)
            ? settings!.appStoreUrl
            : 'https://apps.apple.com/app/id6740047505';
      } else {
        url = (settings?.playStoreUrl.isNotEmpty == true)
            ? settings!.playStoreUrl
            : 'https://play.google.com/store/apps/details?id=com.b4africa.app';
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Hardcoded fallback if API fails
      final fallbackUrl = Platform.isIOS
          ? 'https://apps.apple.com/app/id6740047505'
          : 'https://play.google.com/store/apps/details?id=com.b4africa.app';
      final uri = Uri.parse(fallbackUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _fetchFeatureFlagsFromApi() async {
    try {
      final settings = await ApiService().getSettings();
      if (settings != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('feature_newsletter_enabled', settings.newsletterEnabled);
        setState(() {
          _newsletterEnabled = settings.newsletterEnabled;
        });
      }
    } catch (_) {}
  }

  /// Build display name: "Title FirstName" for verified users, plain name otherwise.
  /// Uses the real name from verification instead of the signup name (which may
  /// be random for Google/Apple sign-in).
  String _buildDisplayName(AuthProvider auth) {
    final title = auth.verificationTitle;
    // Prefer real name from verification over signup name
    final realName = auth.verificationName;
    final name = (realName != null && realName.isNotEmpty) ? realName : (auth.userName ?? 'User');

    if (title != null && title.isNotEmpty) {
      // Title + family name — the protocol form, and short enough for the row.
      return NameFormat.greetingName(name, title: title);
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await _fetchFeatureFlagsFromApi();
          if (mounted) setState(() {});
        },
        color: Ds.green,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Green profile header
            SliverToBoxAdapter(
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) =>
                    _buildProfileHeader(context, authProvider, l10n),
              ),
            ),

            // ── Community ───────────────────────────────────
            const SliverToBoxAdapter(child: DsGroupLabel('Community')),
            SliverToBoxAdapter(
              child: DsTileGroup(
                children: [
                  DsTile(
                    icon: Icons.flag_rounded,
                    title: l10n.translate('priority_agenda'),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, '/arise-initiative');
                    },
                  ),
                ],
              ),
            ),

            // ── Preferences ─────────────────────────────────
            const SliverToBoxAdapter(child: DsGroupLabel('Preferences')),
            SliverToBoxAdapter(
              child: DsTileGroup(
                children: [
                  Consumer<LanguageProvider>(
                    builder: (context, langProvider, _) => DsTile(
                      icon: Icons.translate_rounded,
                      title: l10n.translate('language'),
                      value: langProvider.isEnglish ? 'English' : 'Français',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        langProvider.toggleLanguage();
                      },
                    ),
                  ),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) => DsTile(
                      icon: themeProvider.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      title: l10n.translate('theme'),
                      value: themeProvider.isDarkMode
                          ? l10n.translate('dark')
                          : l10n.translate('light'),
                      trailing: DsSwitch(
                        value: themeProvider.isDarkMode,
                        onChanged: (_) {
                          HapticFeedback.lightImpact();
                          themeProvider.toggleTheme();
                        },
                      ),
                    ),
                  ),
                  DsTile(
                    icon: Icons.data_saver_on_rounded,
                    title: l10n.dataSaver,
                    subtitle: l10n.dataSaverDesc,
                    trailing: DsSwitch(
                      value: DataSaverService().enabled,
                      onChanged: (val) async {
                        await DataSaverService().setEnabled(val);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),

            Consumer2<AuthProvider, VerificationProvider>(
              builder: (context, authProvider, verificationProvider, _) {
                final isLoggedIn = authProvider.isAuthenticated;
                // A pending or rejected request means the user is NOT yet verified,
                // even if authProvider.isVerified is stale-cached as true.
                final hasPendingRequest =
                    verificationProvider.requestStatus == 'pending' ||
                        verificationProvider.requestStatus == 'rejected';
                final isVerified = !hasPendingRequest &&
                    (authProvider.isVerified ||
                        verificationProvider.isProfileVerified);
                final showVerificationItem = isLoggedIn && !isVerified;

                return SliverList.list(
                  children: [
                    // ── Verification ────────────────────────────
                    if (showVerificationItem) ...[
                      const DsGroupLabel('Verification'),
                      DsTileGroup(children: [
                        _buildVerificationMenuItem(
                          context: context,
                          verificationStatus: verificationProvider.requestStatus,
                          l10n: l10n,
                        ),
                      ]),
                    ],

                    // ── Account ─────────────────────────────────
                    if (isLoggedIn) ...[
                      const DsGroupLabel('Account'),
                      DsTileGroup(
                        children: [
                          DsTile(
                            icon: Icons.manage_accounts_rounded,
                            iconTint: Ds.redTintOf(context),
                            iconColor: Ds.red,
                            title: 'Manage Account',
                            subtitle: 'Deactivate or delete your account',
                            onTap: () => _showAccountManageSheet(
                                context, isDark, authProvider),
                          ),
                          if (_newsletterEnabled)
                            _buildNewsletterToggle(
                              context: context,
                              isDark: isDark,
                              authProvider: authProvider,
                            ),
                          if (authProvider.hasPasswordProvider)
                            DsTile(
                              icon: Icons.lock_rounded,
                              iconTint: Ds.tint(context),
                              iconColor: Ds.green,
                              title: l10n.translate('change_password'),
                              onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (_) =>
                                          const ChangePasswordScreen())),
                            ),
                          DsTile(
                            icon: Icons.history_rounded,
                            title: l10n.translate('login_history'),
                            onTap: () => Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (_) => const LoginHistoryScreen())),
                          ),
                          DsTile(
                            icon: Icons.devices_rounded,
                            title: l10n.translate('active_sessions'),
                            onTap: () => Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (_) =>
                                        const ActiveSessionsScreen())),
                          ),
                        ],
                      ),
                    ],

                    // ── Support ─────────────────────────────────
                    const DsGroupLabel('Support'),
                    DsTileGroup(
                      children: [
                        DsTile(
                          icon: Icons.headset_mic_rounded,
                          iconTint: Ds.tint(context),
                          iconColor: Ds.green,
                          title: l10n.translate('contact_support'),
                          subtitle: 'Get help and support',
                          onTap: () {
                            if (!authProvider.isAuthenticated) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Localizations.localeOf(context)
                                                .languageCode ==
                                            'fr'
                                        ? 'Veuillez vous connecter pour contacter le support'
                                        : 'Please sign in to contact support',
                                  ),
                                  backgroundColor: AppColors.burundiGreen,
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: Localizations.localeOf(context)
                                                .languageCode ==
                                            'fr'
                                        ? 'Connexion'
                                        : 'Sign In',
                                    textColor: Colors.white,
                                    onPressed: () =>
                                        Navigator.pushNamed(context, '/auth'),
                                  ),
                                ),
                              );
                              return;
                            }
                            _showSupportOptions(context, isDark);
                          },
                        ),
                        DsTile(
                          icon: Icons.help_outline_rounded,
                          title: l10n.appGuide,
                          subtitle: l10n.appGuideSubtitle,
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) =>
                                  const OnboardingScreen(isReplay: true),
                            ),
                          ),
                        ),
                        DsTile(
                          icon: Icons.info_outline_rounded,
                          title: l10n.translate('about'),
                          subtitle:
                              '${AppConstants.appName} v${AppConstants.appVersion}',
                          onTap: () => _showAboutDialog(context, l10n),
                        ),
                      ],
                    ),

                    // ── Share the app ───────────────────────────
                    const DsGroupLabel('Spread the word'),
                    DsTileGroup(
                      children: [
                        DsTile(
                          key: _shareMenuKey,
                          icon: Icons.share_rounded,
                          iconTint: Ds.tint(context),
                          iconColor: Ds.green,
                          title: l10n.translate('share_app'),
                          onTap: () => ShareService.app(
                              _shareMenuKey.currentContext ?? context),
                        ),
                        DsTile(
                          icon: Icons.star_rounded,
                          iconTint: Ds.goldTintOf(context),
                          iconColor: Ds.goldInk,
                          title: l10n.translate('rate_app'),
                          onTap: () => _handleRateApp(context),
                        ),
                      ],
                    ),

                    // ── Legal ───────────────────────────────────
                    const DsGroupLabel('Legal'),
                    DsTileGroup(
                      children: [
                        DsTile(
                          icon: Icons.privacy_tip_outlined,
                          title: l10n.translate('privacy_policy'),
                          onTap: () => launchUrl(
                            Uri.parse(
                                '${Environment.siteBaseUrl}/privacy-policy/'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        DsTile(
                          icon: Icons.description_outlined,
                          title: l10n.translate('terms_of_service'),
                          onTap: () => launchUrl(
                            Uri.parse(
                                '${Environment.siteBaseUrl}/terms-of-service/'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),

                    // ── Sign out ────────────────────────────────
                    if (isLoggedIn)
                      DsTileGroup(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          DsTile(
                            icon: Icons.logout_rounded,
                            iconTint: Ds.redTintOf(context),
                            iconColor: Ds.red,
                            title: 'Sign Out',
                            titleColor: Ds.red,
                            onTap: () =>
                                _showSignOutConfirmation(context, authProvider),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),


          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Summit theme banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: Ds.green,
                  borderRadius: BorderRadius.circular(Ds.rCard),
                  boxShadow: Ds.shadowLg(context),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(Ds.rIcon),
                      ),
                      child: const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppConstants.summitTheme,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Clean footer
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 32, bottom: Ds.navSpace(context)),
              child: Column(
                children: [
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v${AppConstants.appVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showAccountManageSheet(BuildContext context, bool isDark, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Manage Your Account',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Deactivate option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pause_circle_outline, color: Colors.orange, size: 28),
                ),
                title: const Text('Take a Break', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: const Text('Deactivate temporarily. Log back in anytime to reactivate.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeactivate(context, isDark, authProvider);
                },
              ),
              const SizedBox(height: 8),

              // Delete option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 28),
                ),
                title: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.red)),
                subtitle: const Text('Permanently delete your account and all data after 30 days.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, isDark, authProvider);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, bool isDark, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Take a Break?'),
        content: const Text(
          'Your account will be deactivated and hidden from others.\n\n'
          'You can reactivate it anytime by simply logging back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
              final success = await authProvider.deactivateAccount();
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account deactivated. Log in anytime to come back!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(authProvider.errorMessage ?? 'Failed to deactivate'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, bool isDark, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Your account will be scheduled for permanent deletion.\n\n'
          'You have 30 days to change your mind by logging back in.\n'
          'After 30 days, all your data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
              final success = await authProvider.deleteAccount();
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account scheduled for deletion. You have 30 days to cancel by logging in.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(authProvider.errorMessage ?? 'Failed to delete account'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  bool _hasPendingOrRejectedRequest(BuildContext context) {
    final status = Provider.of<VerificationProvider>(context, listen: false).requestStatus;
    return status == 'pending' || status == 'rejected';
  }

  Widget _buildVerificationMenuItem({
    required BuildContext context,
    required String? verificationStatus,
    required AppLocalizations l10n,
  }) {
    final pending = verificationStatus == 'pending';
    if (pending || verificationStatus == 'rejected') {
      return DsTile(
        icon: Icons.hourglass_top_rounded,
        iconTint: Ds.goldTintOf(context),
        iconColor: Ds.goldInk,
        title: pending ? 'Verification Pending' : 'Verification In Review',
        subtitle:
            pending ? 'Your request is being processed' : 'Still being processed',
        chevron: false,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(pending
                  ? 'Your verification request is being processed. Please wait.'
                  : 'Your verification request is still being processed. Please wait.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    }
    // No request exists — show Get Verified
    return DsTile(
      icon: Icons.verified_rounded,
      iconTint: Ds.tint(context),
      iconColor: Ds.green,
      title: l10n.translate('get_verified'),
      subtitle: l10n.translate('get_verified_desc'),
      onTap: () => Navigator.pushNamed(context, '/verification-request'),
    );
  }

  void _showSignOutConfirmation(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => _AboutPage(l10n: l10n)),
    );
  }

  void _showSupportOptions(BuildContext context, bool isDark) async {
    // Fetch live agent status from backend
    bool liveAgentOnline = false;
    try {
      final settings = await ApiService().getSettings();
      if (settings != null) {
        liveAgentOnline = settings.liveAgentOnline;
      }
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'How would you like to reach us?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Email Support — always available
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.email_rounded, color: AppColors.burundiGreen, size: 28),
                ),
                title: const Text('Support Ticket', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: const Text('Create a ticket, we respond within 24 hours'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/support-tickets');
                },
              ),
              const SizedBox(height: 8),

              // Live Agent — only active when admin toggled ON
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: liveAgentOnline
                        ? AppColors.burundiGreen.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: liveAgentOnline ? AppColors.burundiGreen : Colors.grey,
                    size: 28,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      'Live Agent',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: liveAgentOnline
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: liveAgentOnline ? Colors.green : Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        liveAgentOnline ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  liveAgentOnline ? 'Quick response via support chat' : 'No agents available right now',
                  style: TextStyle(color: liveAgentOnline ? null : Colors.grey),
                ),
                trailing: liveAgentOnline ? const Icon(Icons.chevron_right) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                enabled: liveAgentOnline,
                onTap: liveAgentOnline
                    ? () async {
                        Navigator.pop(ctx);
                        // Create a live chat ticket and open it
                        try {
                          final api = ApiService();
                          final result = await api.createTicket(
                            'Live Chat Support',
                            'Started a live chat session.',
                          );
                          if (context.mounted) {
                            Navigator.pushNamed(
                              context,
                              '/ticket-conversation',
                              arguments: result['id'],
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to start live chat: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsletterToggle({
    required BuildContext context,
    required bool isDark,
    required AuthProvider authProvider,
  }) {
    final isSubscribed = authProvider.receivesNewsletter;
    return DsTile(
      icon: Icons.newspaper_rounded,
      iconTint: Ds.tint(context),
      iconColor: Ds.green,
      title: 'Monthly Newsletter',
      subtitle: isSubscribed
          ? 'Subscribed'
          : 'Subscribe to receive our monthly digest',
      trailing: isSubscribed
          ? const Icon(Icons.check_circle_rounded, color: Ds.green, size: 22)
          : null,
      onTap: isSubscribed
          ? () => _showUnsubscribeDialog(context, isDark, authProvider)
          : () =>
              _showNewsletterSubscriptionDialog(context, isDark, authProvider),
    );
  }

  void _showUnsubscribeDialog(BuildContext context, bool isDark, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unsubscribe from newsletter?'),
        content: const Text('You will no longer receive our monthly newsletter.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await authProvider.toggleNewsletter(false);
                if (context.mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Unsubscribed from newsletter'),
                      backgroundColor: AppColors.burundiGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to unsubscribe: $e'),
                      backgroundColor: AppColors.burundiRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
  }

  void _showNewsletterSubscriptionDialog(BuildContext context, bool isDark, AuthProvider authProvider) {
    final nameController = TextEditingController(text: authProvider.userName ?? '');
    final emailController = TextEditingController(text: authProvider.userEmail ?? '');
    final phoneController = TextEditingController(text: authProvider.phoneNumber ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.newspaper_rounded, color: AppColors.burundiGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Monthly Newsletter',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.burundiGreen,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Subscribe to receive our monthly newsletter with the latest updates and news.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : AppColors.burundiGreen.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (optional)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => isSubmitting = true);
                try {
                  await ApiService().subscribeNewsletter(
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                  );
                  await authProvider.toggleNewsletter(true);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Subscribed to Monthly Newsletter!'),
                        backgroundColor: AppColors.burundiGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to subscribe: $e'),
                        backgroundColor: AppColors.burundiRed,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Subscribe', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Green header with the member's avatar, name and role — the comp's
  /// "More / Profile" top block.
  Widget _buildProfileHeader(
      BuildContext context, AuthProvider authProvider, AppLocalizations l10n) {
    final isLoggedIn = authProvider.isAuthenticated;
    final name = isLoggedIn ? _buildDisplayName(authProvider) : 'Guest User';
    final photo = authProvider.profilePictureUrl;
    final role = authProvider.verificationRole;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, isLoggedIn ? '/profile' : '/auth'),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.paddingOf(context).top + 20, 20, 22),
        decoration: const BoxDecoration(
          color: Ds.green,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
        ),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 58,
                height: 58,
                child: isLoggedIn && photo != null && photo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: Environment.fixMediaUrl(photo),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _avatarInitials(name, isLoggedIn),
                        errorWidget: (_, _, _) => _avatarInitials(name, isLoggedIn),
                      )
                    : _avatarInitials(name, isLoggedIn),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                      if (isLoggedIn &&
                          authProvider.isVerified &&
                          !_hasPendingOrRejectedRequest(context)) ...[
                        const SizedBox(width: 6),
                        VerifiedBadge(
                            badgeType: authProvider.badgeType ??
                                Provider.of<VerificationProvider>(context, listen: false)
                                    .badgeType,
                            size: 17),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLoggedIn
                        ? (role != null && role.isNotEmpty
                            ? role
                            : (authProvider.userEmail ?? ''))
                        : l10n.translate('tap_to_sign_in'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded, size: 20, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _avatarInitials(String name, bool isLoggedIn) => Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: isLoggedIn && name.isNotEmpty
            ? Text(name[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: Ds.green))
            : const Icon(Icons.person_rounded, size: 28, color: Ds.green),
      );

  Future<void> _handleRateApp(BuildContext context) async {
    void toast(String msg) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.burundiGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    const unavailable =
        'Rating will be available once the app is on the App Store';
    try {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        toast('Thank you for your support!');
        return;
      }
    } catch (_) {
      // Fall through to the store listing below.
    }
    await _openStoreListing();
    toast(unavailable);
  }
}

/// Full-screen About page with parallax hero and rich content.
class _AboutPage extends StatefulWidget {
  final AppLocalizations l10n;
  const _AboutPage({required this.l10n});

  @override
  State<_AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<_AboutPage> {
  String _description = 'Official application for the Be 4 Africa 2026.';
  String _summitTheme = AppConstants.summitTheme;
  String _developerName = 'Eyosias Tamene';
  String _developerUrl = 'https://eyosias.dev';
  String _developerRole = 'Lead Developer';
  String _ownershipText = 'Property of Burundi Embassy in Addis Ababa';
  String _missionTitle = 'Our Mission';
  String _featuresTitle = 'Key Features';
  String _contactWebsite = 'burundi4africa.com';
  String _contactWebsiteUrl = 'https://burundi4africa.com';
  String _contactEmail = 'info@burundi4africa.com';
  List<Map<String, dynamic>>? _aboutFeatures;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAboutFeatures();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiService().getSettings();
      if (settings != null && mounted) {
        final langCode = widget.l10n.locale.languageCode;
        setState(() {
          if (settings.getDescription(langCode).isNotEmpty) {
            _description = settings.getDescription(langCode);
          }
          if (settings.getTheme(langCode).isNotEmpty) {
            _summitTheme = settings.getTheme(langCode);
          }
          if (settings.developerName.isNotEmpty) {
            _developerName = settings.developerName;
          }
          if (settings.developerUrl.isNotEmpty) {
            _developerUrl = settings.developerUrl;
          }
          if (settings.developerRole.isNotEmpty) {
            _developerRole = settings.developerRole;
          }
          if (settings.appOwnershipText.isNotEmpty) {
            _ownershipText = settings.appOwnershipText;
          }
          _missionTitle = settings.getMissionTitle(langCode);
          _featuresTitle = settings.getFeaturesTitle(langCode);
          if (settings.contactWebsite.isNotEmpty) {
            _contactWebsite = settings.contactWebsite;
          }
          if (settings.contactWebsiteUrl.isNotEmpty) {
            _contactWebsiteUrl = settings.contactWebsiteUrl;
          }
          if (settings.contactEmail.isNotEmpty) {
            _contactEmail = settings.contactEmail;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAboutFeatures() async {
    try {
      final features = await ApiService().getAboutFeatures();
      if (mounted && features.isNotEmpty) {
        setState(() {
          _aboutFeatures = features;
        });
      }
    } catch (_) {}
  }

  static IconData _mapIconName(String iconName) {
    const iconMap = <String, IconData>{
      'article': Icons.article_rounded,
      'event': Icons.event_rounded,
      'auto_stories': Icons.auto_stories_rounded,
      'translate': Icons.translate_rounded,
      'wb_sunny': Icons.wb_sunny_rounded,
      'account_balance': Icons.account_balance_rounded,
      'public': Icons.public_rounded,
      'group': Icons.group_rounded,
      'school': Icons.school_rounded,
      'gavel': Icons.gavel_rounded,
    };
    return iconMap[iconName] ?? Icons.star_rounded;
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1EB53A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Parallax hero header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.burundiGreen,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.l10n.translate('about'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Burundi flag gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.burundiGreen,
                          Color(0xFF2D6E31),
                          AppColors.burundiRed,
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // Dark overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                  // App logo / icon
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.stars, color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'v${AppConstants.appVersion}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App name and version
                  Center(
                    child: Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'HeatherGreen',
                        color: isDark ? Colors.white : AppColors.burundiGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Summit theme
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.auGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.auGold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _summitTheme,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          color: isDark ? AppColors.auGold : const Color(0xFF8B7D3C),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mission statement card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag_rounded, size: 20, color: AppColors.burundiGreen),
                            const SizedBox(width: 8),
                            Text(
                              _missionTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.burundiGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _description,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: isDark ? Colors.white70 : AppColors.burundiGreen.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Key features grid
                  Text(
                    _featuresTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.burundiGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFeaturesGrid(isDark),
                  const SizedBox(height: 24),

                  // Developer credit
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.burundiGreen.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : AppColors.burundiGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.l10n.translate('designed_by'),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : AppColors.burundiGreen.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse(_developerUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Text(
                            _developerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.burundiGreen,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _developerRole,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : AppColors.burundiGreen.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ownership / property line
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.burundiGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _ownershipText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : AppColors.burundiGreen.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Website link
                  _buildLinkTile(
                    icon: Icons.language_rounded,
                    title: _contactWebsite,
                    url: _contactWebsiteUrl,
                    color: AppColors.burundiGreen,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildLinkTile(
                    icon: Icons.mail_outline_rounded,
                    title: _contactEmail,
                    url: 'mailto:$_contactEmail',
                    color: AppColors.auGold,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),

                  // AU branding footer
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.auGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.public, size: 28, color: AppColors.auGold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'B4Africa',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : AppColors.burundiGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'v${AppConstants.appVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white30 : AppColors.burundiGreen.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(bool isDark) {
    final langCode = widget.l10n.locale.languageCode;

    // Use API features if available, otherwise fall back to defaults
    final List<Map<String, dynamic>> features;
    if (_aboutFeatures != null && _aboutFeatures!.isNotEmpty) {
      features = _aboutFeatures!.map((f) {
        final title = (langCode == 'fr' && (f['title_fr'] as String? ?? '').isNotEmpty)
            ? f['title_fr'] as String
            : f['title'] as String? ?? '';
        return {
          'icon': _mapIconName(f['icon_name'] as String? ?? 'star'),
          'title': title,
          'color': _parseColor(f['color'] as String? ?? '#1EB53A'),
        };
      }).toList();
    } else {
      features = [
        {'icon': Icons.article_rounded, 'title': 'News', 'color': AppColors.burundiGreen},
        {'icon': Icons.event_rounded, 'title': 'Events Calendar', 'color': AppColors.burundiRed},
        {'icon': Icons.auto_stories_rounded, 'title': 'Magazine', 'color': AppColors.auGold},
        {'icon': Icons.translate_rounded, 'title': 'Translation', 'color': AppColors.burundiGreen},
        {'icon': Icons.wb_sunny_rounded, 'title': 'Weather', 'color': AppColors.auGold},
        {'icon': Icons.account_balance_rounded, 'title': 'Diplomacy', 'color': AppColors.burundiRed},
      ];
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final f = features[index];
        final color = f['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(f['icon'] as IconData, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                f['title'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.burundiGreen.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required String url,
    required Color color,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: isDark ? Colors.white30 : Colors.black26),
          ],
        ),
      ),
    );
  }
}
