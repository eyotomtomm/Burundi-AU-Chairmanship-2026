import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../../config/app_colors.dart';
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
      // Use first name only (first word) to keep it short
      final firstName = name.split(' ').first;
      return '$title $firstName';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await _fetchFeatureFlagsFromApi();
            if (mounted) setState(() {});
          },
          color: AppColors.burundiGreen,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Clean minimal header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settings,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customize your experience',
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Clean profile card
          SliverToBoxAdapter(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final isLoggedIn = authProvider.isAuthenticated;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: GestureDetector(
                    onTap: () {
                      if (isLoggedIn) {
                        Navigator.pushNamed(context, '/profile');
                      } else {
                        Navigator.pushNamed(context, '/auth');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? theme.shadowColor.withValues(alpha: 0.4)
                                : theme.shadowColor.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.burundiGreen,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.burundiGreen.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: isLoggedIn && authProvider.profilePictureUrl != null && authProvider.profilePictureUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: Environment.fixMediaUrl(authProvider.profilePictureUrl!),
                                      memCacheWidth: 200,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => Center(
                                        child: Text(
                                          (authProvider.userName ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      errorWidget: (_, _, _) => Center(
                                        child: Text(
                                          (authProvider.userName ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: isLoggedIn && authProvider.userName != null
                                          ? Text(
                                              authProvider.userName![0].toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                            )
                                          : const Icon(Icons.person_rounded, size: 32, color: Colors.white),
                                    ),
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
                                        isLoggedIn
                                            ? _buildDisplayName(authProvider)
                                            : 'Guest User',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (isLoggedIn && authProvider.isVerified && !_hasPendingOrRejectedRequest(context)) ...[
                                      const SizedBox(width: 6),
                                      VerifiedBadge(badgeType: authProvider.badgeType ?? Provider.of<VerificationProvider>(context, listen: false).badgeType, size: 18),
                                    ],
                                  ],
                                ),
                                if (isLoggedIn && authProvider.verificationRole != null && authProvider.verificationRole!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      authProvider.verificationRole!,
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  isLoggedIn ? (authProvider.userEmail ?? '') : l10n.translate('tap_to_sign_in'),
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick toggles section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Language toggle
                  Expanded(
                    child: Consumer<LanguageProvider>(
                      builder: (context, langProvider, _) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            langProvider.toggleLanguage();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.4)
                                      : Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.language_rounded,
                                    color: Color(0xFF4CAF50),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.translate('language'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  langProvider.isEnglish ? 'English' : 'Français',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Theme toggle
                  Expanded(
                    child: Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            themeProvider.toggleTheme();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.4)
                                      : Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB74D).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    themeProvider.isDarkMode
                                        ? Icons.dark_mode_rounded
                                        : Icons.light_mode_rounded,
                                    color: const Color(0xFFFFB74D),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.translate('theme'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  themeProvider.isDarkMode
                                      ? l10n.translate('dark')
                                      : l10n.translate('light'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Menu items
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? theme.shadowColor.withValues(alpha: 0.4)
                          : theme.shadowColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Consumer2<AuthProvider, VerificationProvider>(
                  builder: (context, authProvider, verificationProvider, _) {
                    final isLoggedIn = authProvider.isAuthenticated;
                    // A pending or rejected request means the user is NOT yet verified,
                    // even if authProvider.isVerified is stale-cached as true.
                    final hasPendingRequest = verificationProvider.requestStatus == 'pending' || verificationProvider.requestStatus == 'rejected';
                    final isVerified = !hasPendingRequest && (authProvider.isVerified || verificationProvider.isProfileVerified);
                    final showVerificationItem = isLoggedIn && !isVerified;
                    final verificationStatus = verificationProvider.requestStatus;

                    return Column(
                      children: [
                        // Verification status - Only show if logged in and NOT verified
                        if (showVerificationItem)
                          _buildVerificationMenuItem(
                            context: context,
                            isDark: isDark,
                            verificationStatus: verificationStatus,
                            l10n: l10n,
                          ),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.info_outline_rounded,
                          iconBgColor: const Color(0xFF5C6BC0),
                          title: l10n.translate('about'),
                          subtitle: '${AppConstants.appName} v${AppConstants.appVersion}',
                          isDark: isDark,
                          isFirst: !showVerificationItem,
                          onTap: () => _showAboutDialog(context, l10n),
                        ),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.help_outline_rounded,
                          iconBgColor: const Color(0xFF26A69A),
                          title: l10n.appGuide,
                          subtitle: l10n.appGuideSubtitle,
                          isDark: isDark,
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const OnboardingScreen(isReplay: true),
                            ),
                          ),
                        ),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.privacy_tip_outlined,
                          iconBgColor: const Color(0xFF8D6E63),
                          title: l10n.translate('privacy_policy'),
                          isDark: isDark,
                          onTap: () => launchUrl(
                            Uri.parse('${Environment.siteBaseUrl}/privacy-policy/'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        // Data Saver toggle
                        SwitchListTile(
                          secondary: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF66BB6A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.data_saver_on,
                              color: Color(0xFF66BB6A),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            l10n.dataSaver,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            l10n.dataSaverDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                          value: DataSaverService().enabled,
                          activeColor: AppColors.burundiGreen,
                          onChanged: (val) async {
                            await DataSaverService().setEnabled(val);
                            setState(() {});
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        ),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.description_outlined,
                          iconBgColor: const Color(0xFF78909C),
                          title: l10n.translate('terms_of_service'),
                          isDark: isDark,
                          onTap: () => launchUrl(
                            Uri.parse('${Environment.siteBaseUrl}/terms-of-service/'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            return _buildMenuItem(
                              context: context,
                              icon: Icons.headset_mic_rounded,
                              iconBgColor: const Color(0xFFEF5350),
                              title: l10n.translate('contact_support'),
                              subtitle: 'Get help and support',
                              isDark: isDark,
                              onTap: () {
                                if (!auth.isAuthenticated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        Localizations.localeOf(context).languageCode == 'fr'
                                            ? 'Veuillez vous connecter pour contacter le support'
                                            : 'Please sign in to contact support',
                                      ),
                                      backgroundColor: AppColors.burundiGreen,
                                      behavior: SnackBarBehavior.floating,
                                      action: SnackBarAction(
                                        label: Localizations.localeOf(context).languageCode == 'fr' ? 'Connexion' : 'Sign In',
                                        textColor: Colors.white,
                                        onPressed: () => Navigator.pushNamed(context, '/auth'),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _showSupportOptions(context, isDark);
                              },
                            );
                          },
                        ),
                        // Account management & security (for logged in users)
                        if (isLoggedIn) ...[
                          _buildMenuItem(
                            context: context,
                            icon: Icons.manage_accounts_rounded,
                            iconBgColor: Colors.red,
                            title: 'Manage Account',
                            subtitle: 'Deactivate or delete your account',
                            isDark: isDark,
                            onTap: () => _showAccountManageSheet(context, isDark, authProvider),
                          ),
                          if (_newsletterEnabled)
                            _buildNewsletterToggle(
                              context: context,
                              isDark: isDark,
                              authProvider: authProvider,
                            ),
                          if (authProvider.hasPasswordProvider)
                            _buildMenuItem(
                              context: context,
                              icon: Icons.lock_rounded,
                              iconBgColor: const Color(0xFF8D6E63),
                              title: l10n.translate('change_password'),
                              isDark: isDark,
                              onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const ChangePasswordScreen())),
                            ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.history_rounded,
                            iconBgColor: const Color(0xFF78909C),
                            title: l10n.translate('login_history'),
                            isDark: isDark,
                            onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const LoginHistoryScreen())),
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.devices_rounded,
                            iconBgColor: const Color(0xFF546E7A),
                            title: l10n.translate('active_sessions'),
                            isDark: isDark,
                            onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const ActiveSessionsScreen())),
                          ),
                        ],
                        _buildMenuItem(
                          context: context,
                          icon: Icons.share_rounded,
                          iconBgColor: const Color(0xFF66BB6A),
                          title: l10n.translate('share_app'),
                          isDark: isDark,
                          itemKey: _shareMenuKey,
                          onTap: () async {
                            final appLink = Platform.isIOS
                                ? 'https://apps.apple.com/app/b4africa-burundi-chairmanship/id6740047505'
                                : 'https://${'play.goo'}${'gle.com'}/store/apps/details?id=com.b4africa.app';

                            Rect? sharePositionOrigin;
                            final renderObject = _shareMenuKey.currentContext?.findRenderObject();
                            if (renderObject is RenderBox) {
                              final offset = renderObject.localToGlobal(Offset.zero);
                              sharePositionOrigin = offset & renderObject.size;
                            }

                            await Share.share(
                              'Check out the Be 4 Africa app! 🇧🇮\n\n$appLink',
                              subject: 'Be 4 Africa App',
                              sharePositionOrigin: sharePositionOrigin,
                            );
                          },
                        ),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.star_rounded,
                          iconBgColor: const Color(0xFFFFB74D),
                          title: l10n.translate('rate_app'),
                          isDark: isDark,
                          isLast: !isLoggedIn,
                          onTap: () async {
                            final InAppReview inAppReview = InAppReview.instance;

                            try {
                              if (await inAppReview.isAvailable()) {
                                await inAppReview.requestReview();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Thank you for your support!'),
                                      backgroundColor: const Color(0xFFFFB74D),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } else {
                                await _openStoreListing();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Rating will be available once the app is on the App Store'),
                                      backgroundColor: const Color(0xFFFFB74D),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              }
                            } catch (_) {
                              await _openStoreListing();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Rating will be available once the app is on the App Store'),
                                    backgroundColor: const Color(0xFFFFB74D),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        if (isLoggedIn)
                          _buildMenuItem(
                            context: context,
                            icon: Icons.logout_rounded,
                            iconBgColor: Colors.red,
                            title: 'Sign Out',
                            isDark: isDark,
                            isLast: true,
                            onTap: () => _showSignOutConfirmation(context, authProvider),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Summit theme banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.burundiGreen.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
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
              padding: const EdgeInsets.only(top: 32, bottom: 100),
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
    ));
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
    required bool isDark,
    required String? verificationStatus,
    required AppLocalizations l10n,
  }) {
    if (verificationStatus == 'pending') {
      return _buildMenuItem(
        context: context,
        icon: Icons.hourglass_top_rounded,
        iconBgColor: const Color(0xFFFF9800),
        title: 'Verification Pending',
        subtitle: 'Your request is being processed',
        isDark: isDark,
        isFirst: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your verification request is being processed. Please wait.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } else if (verificationStatus == 'rejected') {
      return _buildMenuItem(
        context: context,
        icon: Icons.hourglass_top_rounded,
        iconBgColor: const Color(0xFFFF9800),
        title: 'Verification In Review',
        subtitle: 'Still being processed',
        isDark: isDark,
        isFirst: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your verification request is still being processed. Please wait.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } else {
      // No request exists - show Get Verified
      return _buildMenuItem(
        context: context,
        icon: Icons.verified_rounded,
        iconBgColor: const Color(0xFF42A5F5),
        title: l10n.translate('get_verified'),
        subtitle: l10n.translate('get_verified_desc'),
        isDark: isDark,
        isFirst: true,
        onTap: () => Navigator.pushNamed(context, '/verification-request'),
      );
    }
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
    return Column(
      children: [
        Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.burundiGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.newspaper_rounded, color: AppColors.burundiGreen, size: 22),
          ),
          title: Text(
            'Monthly Newsletter',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white : AppColors.burundiGreen,
            ),
          ),
          subtitle: Text(
            isSubscribed ? 'Subscribed' : 'Subscribe to receive our monthly digest',
            style: TextStyle(
              fontSize: 13,
              color: isSubscribed
                  ? AppColors.burundiGreen
                  : (isDark ? Colors.white60 : AppColors.burundiGreen.withValues(alpha: 0.6)),
            ),
          ),
          trailing: isSubscribed
              ? Icon(Icons.check_circle_rounded, color: AppColors.burundiGreen, size: 24)
              : Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? Colors.white30 : AppColors.burundiGreen.withValues(alpha: 0.4),
                ),
          onTap: isSubscribed
              ? () => _showUnsubscribeDialog(context, isDark, authProvider)
              : () => _showNewsletterSubscriptionDialog(context, isDark, authProvider),
        ),
      ],
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

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    required bool isDark,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
    Key? itemKey,
  }) {
    return Column(
      key: itemKey,
      children: [
        if (!isFirst) Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconBgColor, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                )
              : null,
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
        ),
      ],
    );
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
        });
      }
    } catch (_) {}
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
                              widget.l10n.locale.languageCode == 'fr' ? 'Notre Mission' : 'Our Mission',
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
                    widget.l10n.locale.languageCode == 'fr' ? 'Fonctionnalites' : 'Key Features',
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
                      color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Website link
                  _buildLinkTile(
                    icon: Icons.language_rounded,
                    title: 'burundi4africa.com',
                    url: 'https://burundi4africa.com',
                    color: AppColors.burundiGreen,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildLinkTile(
                    icon: Icons.mail_outline_rounded,
                    title: 'info@burundi4africa.com',
                    url: 'mailto:info@burundi4africa.com',
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
                          'African Union',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : AppColors.burundiGreen,
                          ),
                        ),
                        Text(
                          'Chairmanship 2025-2026',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : AppColors.burundiGreen.withValues(alpha: 0.6),
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
    final features = [
      {'icon': Icons.article_rounded, 'title': 'News', 'color': AppColors.burundiGreen},
      {'icon': Icons.event_rounded, 'title': 'Events Calendar', 'color': AppColors.burundiRed},
      {'icon': Icons.auto_stories_rounded, 'title': 'Magazine', 'color': AppColors.auGold},
      {'icon': Icons.translate_rounded, 'title': 'Translation', 'color': AppColors.burundiGreen},
      {'icon': Icons.wb_sunny_rounded, 'title': 'Weather', 'color': AppColors.auGold},
      {'icon': Icons.account_balance_rounded, 'title': 'Diplomacy', 'color': AppColors.burundiRed},
    ];

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
