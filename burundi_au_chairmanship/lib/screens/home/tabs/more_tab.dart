import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/name_format.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../../widgets/app_network_image.dart';
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
import '../../about/about_screen.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../../services/share_service.dart';
import '../../settings/notification_preferences_screen.dart';
import '../../../widgets/african_pattern.dart';

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
          _newsletterEnabled =
              prefs.getBool('feature_newsletter_enabled') ?? true;
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
        await prefs.setBool(
          'feature_newsletter_enabled',
          settings.newsletterEnabled,
        );
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
    final name = (realName != null && realName.isNotEmpty)
        ? realName
        : (auth.userName ??
              AppLocalizations.of(context).translate('more_user'));

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
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Green profile header
            SliverToBoxAdapter(
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) =>
                    _buildProfileHeader(context, authProvider, l10n),
              ),
            ),

            // A pending badge is an action, not a settings row — it gets a
            // tinted callout above the grid rather than a line in a list.
            SliverToBoxAdapter(
              child: Consumer2<AuthProvider, VerificationProvider>(
                builder: (context, auth, verification, _) {
                  final pending =
                      verification.requestStatus == 'pending' ||
                      verification.requestStatus == 'rejected';
                  final verified =
                      !pending &&
                      (auth.isVerified || verification.isProfileVerified);
                  if (!auth.isAuthenticated || verified) {
                    return const SizedBox(height: 18);
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: _verificationCallout(
                      context,
                      verification.requestStatus,
                      l10n,
                    ),
                  );
                },
              ),
            ),

            // The four places people actually come here for, as targets big
            // enough to hit without reading a list.
            SliverToBoxAdapter(child: _quickActions(context, l10n)),

            // ── Preferences ─────────────────────────────────
            SliverToBoxAdapter(
              child: DsGroupLabel(l10n.translate('more_preferences')),
            ),
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
                    icon: Icons.notifications_none_rounded,
                    title: l10n.translate('st_push_notifications'),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const NotificationPreferencesScreen(),
                        ),
                      );
                    },
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

            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final isLoggedIn = authProvider.isAuthenticated;

                return SliverList.list(
                  children: [
                    // ── Account ─────────────────────────────────
                    // Sign-in security is part of the account, not a separate
                    // idea: one label, one card.
                    if (isLoggedIn) ...[
                      DsGroupLabel(l10n.translate('more_account')),
                      DsTileGroup(
                        children: [
                          DsTile(
                            icon: Icons.manage_accounts_rounded,
                            iconTint: Ds.redTintOf(context),
                            iconColor: Ds.red,
                            title: l10n.translate('more_manage_account'),
                            subtitle: l10n.translate('more_manage_account_sub'),
                            onTap: () => _showAccountManageSheet(
                              context,
                              isDark,
                              authProvider,
                            ),
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
                                  builder: (_) => const ChangePasswordScreen(),
                                ),
                              ),
                            ),
                          DsTile(
                            icon: Icons.history_rounded,
                            title: l10n.translate('login_history'),
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const LoginHistoryScreen(),
                              ),
                            ),
                          ),
                          DsTile(
                            icon: Icons.devices_rounded,
                            title: l10n.translate('active_sessions'),
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const ActiveSessionsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Support ─────────────────────────────────
                    DsGroupLabel(l10n.translate('more_support')),
                    DsTileGroup(
                      children: [
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
                          icon: Icons.star_rounded,
                          iconTint: Ds.goldTintOf(context),
                          iconColor: Ds.goldInk,
                          title: l10n.translate('rate_app'),
                          onTap: () => _handleRateApp(context),
                        ),
                      ],
                    ),

                    // ── About this app ──────────────────────────
                    DsGroupLabel(l10n.translate('more_about_app')),
                    DsTileGroup(
                      children: [
                        DsTile(
                          icon: Icons.privacy_tip_outlined,
                          title: l10n.translate('privacy_policy'),
                          onTap: () => launchUrl(
                            Uri.parse(
                              '${Environment.siteBaseUrl}/privacy-policy/',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        DsTile(
                          icon: Icons.description_outlined,
                          title: l10n.translate('terms_of_service'),
                          onTap: () => launchUrl(
                            Uri.parse(
                              '${Environment.siteBaseUrl}/terms-of-service/',
                            ),
                            mode: LaunchMode.externalApplication,
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

                    // ── Sign out ────────────────────────────────
                    if (isLoggedIn)
                      DsTileGroup(
                        margin: const EdgeInsets.fromLTRB(16, 26, 16, 16),
                        children: [
                          DsTile(
                            icon: Icons.logout_rounded,
                            iconTint: Ds.redTintOf(context),
                            iconColor: Ds.red,
                            title: l10n.translate('sign_out'),
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
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.3,
                        ),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.2,
                        ),
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

  void _showAccountManageSheet(
    BuildContext context,
    bool isDark,
    AuthProvider authProvider,
  ) {
    final l10n = AppLocalizations.of(context);
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
                l10n.translate('more_manage_your_account'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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
                  child: const Icon(
                    Icons.pause_circle_outline,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                title: Text(
                  l10n.translate('more_take_break'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(l10n.translate('more_take_break_sub')),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                ),
                title: Text(
                  l10n.translate('more_delete_forever'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(l10n.translate('more_delete_forever_sub')),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

  void _confirmDeactivate(
    BuildContext context,
    bool isDark,
    AuthProvider authProvider,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.translate('more_take_break_q')),
        content: Text(l10n.translate('more_take_break_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              final success = await authProvider.deactivateAccount();
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.translate('more_deactivated_toast')),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/auth',
                    (route) => false,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        authProvider.errorMessage ??
                            l10n.translate('more_deactivate_failed'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(l10n.translate('more_deactivate')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    bool isDark,
    AuthProvider authProvider,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(l10n.translate('more_delete_account_q')),
          ],
        ),
        content: Text(l10n.translate('more_delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              final success = await authProvider.deleteAccount();
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.translate('more_delete_scheduled_toast'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/auth',
                    (route) => false,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        authProvider.errorMessage ??
                            l10n.translate('more_delete_failed'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.translate('more_delete_forever')),
          ),
        ],
      ),
    );
  }

  bool _hasPendingOrRejectedRequest(BuildContext context) {
    final status = Provider.of<VerificationProvider>(
      context,
      listen: false,
    ).requestStatus;
    return status == 'pending' || status == 'rejected';
  }

  /// Waiting on a badge, or never asked for one — either way it is the one
  /// thing on this page the user can still act on, so it is a coloured card
  /// above the grid instead of a grey row buried in a list.
  Widget _verificationCallout(
    BuildContext context,
    String? status,
    AppLocalizations l10n,
  ) {
    final pending = status == 'pending';
    final waiting = pending || status == 'rejected';

    final fill = waiting ? Ds.goldTintOf(context) : Ds.tint(context);
    final ink = waiting ? Ds.goldInk : Ds.greenDeep;
    final icon = waiting ? Icons.hourglass_top_rounded : Icons.verified_rounded;
    final title = l10n.translate(
      waiting
          ? (pending ? 'more_verif_pending' : 'more_verif_in_review')
          : 'get_verified',
    );
    final subtitle = l10n.translate(
      waiting
          ? (pending ? 'more_verif_pending_sub' : 'more_verif_review_sub')
          : 'get_verified_desc',
    );

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(Ds.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(Ds.rCard),
        onTap: () {
          HapticFeedback.lightImpact();
          if (!waiting) {
            Navigator.pushNamed(context, '/verification-request');
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.translate(
                  pending ? 'more_verif_pending_msg' : 'more_verif_review_msg',
                ),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Icon(icon, size: 24, color: ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: ink.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (!waiting)
                Icon(Icons.chevron_right_rounded, size: 20, color: ink),
            ],
          ),
        ),
      ),
    );
  }

  /// Brand tint that survives both themes (Ds only ships green/gold/red).
  Color _softTint(BuildContext context, Color base) => base.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.12,
  );

  /// The four destinations people open this tab for, as one card of targets
  /// rather than four lines spread across three labelled sections.
  Widget _quickActions(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cells = <Widget>[
      _quickCell(
        context,
        Icons.bookmark_rounded,
        l10n.translate('bookmarks'),
        Ds.goldTintOf(context),
        Ds.goldInk,
        () => Navigator.pushNamed(context, '/bookmarks'),
      ),
      _quickCell(
        context,
        Icons.flag_rounded,
        l10n.translate('priority_agenda'),
        Ds.tint(context),
        Ds.greenDeep,
        () => Navigator.pushNamed(context, '/priority-agenda'),
      ),
      _quickCell(
        context,
        Icons.headset_mic_rounded,
        l10n.translate('contact_support'),
        _softTint(context, Ds.blue),
        Ds.blue,
        () {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (!auth.isAuthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.translate('more_sign_in_to_contact')),
                backgroundColor: AppColors.burundiGreen,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: l10n.translate('sign_in'),
                  textColor: Colors.white,
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                ),
              ),
            );
            return;
          }
          _showSupportOptions(context, isDark);
        },
      ),
      _quickCell(
        context,
        Icons.share_rounded,
        l10n.translate('share_app'),
        _softTint(context, Ds.red),
        Ds.redDeep,
        () => ShareService.app(_shareMenuKey.currentContext ?? context),
        key: _shareMenuKey,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Ds.surface(context),
        borderRadius: BorderRadius.circular(Ds.rCard),
        boxShadow: Ds.shadow(context),
      ),
      child: Row(children: [for (final cell in cells) Expanded(child: cell)]),
    );
  }

  Widget _quickCell(
    BuildContext context,
    IconData icon,
    String label,
    Color tint,
    Color color,
    VoidCallback onTap, {
    Key? key,
  }) {
    return InkWell(
      key: key,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(Ds.rTile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: Ds.body(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutConfirmation(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.translate('sign_out')),
        content: Text(l10n.translate('more_sign_out_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/auth',
                  (route) => false,
                );
              }
            },
            child: Text(l10n.translate('sign_out')),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  void _showSupportOptions(BuildContext context, bool isDark) async {
    final l10n = AppLocalizations.of(context);
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
                l10n.translate('more_reach_us'),
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
                  child: Icon(
                    Icons.email_rounded,
                    color: AppColors.burundiGreen,
                    size: 28,
                  ),
                ),
                title: Text(
                  l10n.translate('more_support_ticket'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(l10n.translate('more_support_ticket_sub')),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                    color: liveAgentOnline
                        ? AppColors.burundiGreen
                        : Colors.grey,
                    size: 28,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      l10n.translate('more_live_agent'),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: liveAgentOnline
                            ? Colors.green
                            : Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        l10n.translate(
                          liveAgentOnline ? 'more_online' : 'more_offline',
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  l10n.translate(
                    liveAgentOnline
                        ? 'more_live_agent_online_sub'
                        : 'more_live_agent_offline_sub',
                  ),
                  style: TextStyle(color: liveAgentOnline ? null : Colors.grey),
                ),
                trailing: liveAgentOnline
                    ? const Icon(Icons.chevron_right)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabled: liveAgentOnline,
                onTap: liveAgentOnline
                    ? () async {
                        Navigator.pop(ctx);
                        // Create a live chat ticket and open it
                        try {
                          final api = ApiService();
                          final result = await api.createTicket(
                            l10n.translate('more_live_chat_subject'),
                            l10n.translate('more_live_chat_body'),
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
                              SnackBar(
                                content: Text(
                                  e is ApiException
                                      ? e.message
                                      : l10n.translate('more_live_chat_failed'),
                                ),
                                backgroundColor: AppColors.error,
                              ),
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
    final l10n = AppLocalizations.of(context);
    final isSubscribed = authProvider.receivesNewsletter;
    return DsTile(
      icon: Icons.newspaper_rounded,
      iconTint: Ds.tint(context),
      iconColor: Ds.green,
      title: l10n.translate('more_newsletter'),
      subtitle: l10n.translate(
        isSubscribed ? 'more_subscribed' : 'more_subscribe_sub',
      ),
      trailing: isSubscribed
          ? const Icon(Icons.check_circle_rounded, color: Ds.green, size: 22)
          : null,
      onTap: isSubscribed
          ? () => _showUnsubscribeDialog(context, isDark, authProvider)
          : () => _showNewsletterSubscriptionDialog(
              context,
              isDark,
              authProvider,
            ),
    );
  }

  void _showUnsubscribeDialog(
    BuildContext context,
    bool isDark,
    AuthProvider authProvider,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.translate('more_unsubscribe_q')),
        content: Text(l10n.translate('more_unsubscribe_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
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
                      content: Text(l10n.translate('more_unsubscribed')),
                      backgroundColor: AppColors.burundiGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e is ApiException
                            ? e.message
                            : l10n.translate('more_unsubscribe_failed'),
                      ),
                      backgroundColor: AppColors.burundiRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.translate('more_unsubscribe')),
          ),
        ],
      ),
    );
  }

  void _showNewsletterSubscriptionDialog(
    BuildContext context,
    bool isDark,
    AuthProvider authProvider,
  ) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(
      text: authProvider.userName ?? '',
    );
    final emailController = TextEditingController(
      text: authProvider.userEmail ?? '',
    );
    final phoneController = TextEditingController(
      text: authProvider.phoneNumber ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                child: Icon(
                  Icons.newspaper_rounded,
                  color: AppColors.burundiGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.translate('more_newsletter'),
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
                    l10n.translate('more_newsletter_desc'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white60
                          : AppColors.burundiGreen.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n.translate('full_name'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.translate('more_name_required')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.translate('more_email_address'),
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return l10n.translate('more_email_required');
                      if (!v.contains('@') || !v.contains('.'))
                        return l10n.translate('more_valid_email');
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.translate('more_phone_optional'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: Text(
                l10n.translate('cancel'),
                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
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
                              content: Text(
                                l10n.translate('more_subscribed_toast'),
                              ),
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
                              content: Text(
                                e is ApiException
                                    ? e.message
                                    : l10n.translate('more_subscribe_failed'),
                              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.translate('more_subscribe'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Green header with the member's avatar, name and role — the comp's
  /// "More / Profile" top block.
  Widget _buildProfileHeader(
    BuildContext context,
    AuthProvider authProvider,
    AppLocalizations l10n,
  ) {
    final isLoggedIn = authProvider.isAuthenticated;
    final name = isLoggedIn
        ? _buildDisplayName(authProvider)
        : l10n.translate('more_guest_user');
    final photo = authProvider.profilePictureUrl;
    final role = authProvider.verificationRole;

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, isLoggedIn ? '/profile' : '/auth'),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Ds.rHeader),
        ),
        child: Container(
          width: double.infinity,
          color: Ds.green,
          // The flat green block read as a placeholder; the woven motif is
          // already the app's, at an opacity that stays behind the text.
          child: AfricanPatternBackground(
            patternColor: Colors.white,
            opacity: 0.07,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 18,
                16,
                24,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: isLoggedIn && photo != null && photo.isNotEmpty
                            ? AppNetworkImage(
                                imageUrl: Environment.fixMediaUrl(photo),
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    _avatarInitials(name, isLoggedIn),
                                errorWidget: (_, _, _) =>
                                    _avatarInitials(name, isLoggedIn),
                              )
                            : _avatarInitials(name, isLoggedIn),
                      ),
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
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isLoggedIn &&
                                authProvider.isVerified &&
                                !_hasPendingOrRejectedRequest(context)) ...[
                              const SizedBox(width: 6),
                              VerifiedBadge(
                                badgeType:
                                    authProvider.badgeType ??
                                    Provider.of<VerificationProvider>(
                                      context,
                                      listen: false,
                                    ).badgeType,
                                size: 17,
                              ),
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
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DsHeaderAction(
                    Icons.edit_rounded,
                    label: l10n.translate('edit_profile'),
                    onTap: () => Navigator.pushNamed(
                      context,
                      isLoggedIn ? '/profile' : '/auth',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarInitials(String name, bool isLoggedIn) => Container(
    color: Colors.white,
    alignment: Alignment.center,
    child: isLoggedIn && name.isNotEmpty
        ? Text(
            name[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Ds.green,
            ),
          )
        : const Icon(Icons.person_rounded, size: 28, color: Ds.green),
  );

  Future<void> _handleRateApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    void toast(String msg) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.burundiGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    final unavailable = l10n.translate('more_rating_unavailable');
    try {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        toast(l10n.translate('more_thanks_support'));
        return;
      }
    } catch (_) {
      // Fall through to the store listing below.
    }
    await _openStoreListing();
    toast(unavailable);
  }
}
