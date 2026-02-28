import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'dart:convert';
import 'dart:io';
import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
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
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customize your experience',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white60 : Colors.black45,
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
                                ? Colors.black.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.04),
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
                            child: Center(
                              child: isLoggedIn && authProvider.userName != null
                                  ? Text(
                                      authProvider.userName![0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : const Icon(Icons.person_rounded, size: 32, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isLoggedIn ? (authProvider.userName ?? 'User') : 'Guest User',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isLoggedIn ? (authProvider.userEmail ?? '') : l10n.translate('tap_to_sign_in'),
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: isDark ? Colors.white30 : Colors.black26,
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
                          onTap: () => langProvider.toggleLanguage(),
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
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  langProvider.isEnglish ? 'English' : 'Français',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
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
                          onTap: () => themeProvider.toggleTheme(),
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
                                    color: isDark ? Colors.white70 : Colors.black54,
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
                                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
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
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      context: context,
                      icon: Icons.info_outline_rounded,
                      iconBgColor: const Color(0xFF5C6BC0),
                      title: l10n.translate('about'),
                      subtitle: '${AppConstants.appName} v${AppConstants.appVersion}',
                      isDark: isDark,
                      isFirst: true,
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: AppConstants.appName,
                          applicationVersion: AppConstants.appVersion,
                          applicationIcon: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.burundiGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.stars, color: Colors.white, size: 28),
                          ),
                          children: [
                            Text(AppConstants.summitTheme),
                            const SizedBox(height: 8),
                            const Text('Official application for the Burundi African Union Chairmanship 2026.'),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => launchUrl(Uri.parse('https://eyosias.dev')),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                  children: const [
                                    TextSpan(text: 'Designed and developed by '),
                                    TextSpan(
                                      text: 'Eyosias Tamene',
                                      style: TextStyle(
                                        color: AppColors.burundiGreen,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.privacy_tip_outlined,
                      iconBgColor: const Color(0xFF8D6E63),
                      title: l10n.translate('privacy_policy'),
                      isDark: isDark,
                      onTap: () => launchUrl(Uri.parse(AppConstants.websiteUrl)),
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.share_rounded,
                      iconBgColor: const Color(0xFF66BB6A),
                      title: l10n.translate('share_app'),
                      isDark: isDark,
                      onTap: () async {
                        final appLink = Platform.isIOS
                            ? 'https://apps.apple.com/app/burundi-au-chairmanship/id123456789'
                            : 'https://play.google.com/store/apps/details?id=com.burundi.au.chairmanship';

                        await Share.share(
                          'Check out the Burundi AU Chairmanship 2026 app! 🇧🇮\n\n$appLink',
                          subject: 'Burundi AU Chairmanship 2026 App',
                        );
                      },
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.star_rounded,
                      iconBgColor: const Color(0xFFFFB74D),
                      title: l10n.translate('rate_app'),
                      isDark: isDark,
                      onTap: () async {
                        final InAppReview inAppReview = InAppReview.instance;

                        if (await inAppReview.isAvailable()) {
                          // Request in-app review (iOS/Android native prompt)
                          await inAppReview.requestReview();
                        } else {
                          // Fallback: Open store listing
                          final appId = Platform.isIOS
                              ? 'id123456789'
                              : 'com.burundi.au.chairmanship';

                          await inAppReview.openStoreListing(
                            appStoreId: appId,
                          );
                        }

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
                      },
                    ),
                    _buildMenuItem(
                      context: context,
                      icon: Icons.headset_mic_rounded,
                      iconBgColor: const Color(0xFFEF5350),
                      title: l10n.translate('contact_support'),
                      subtitle: 'support@burundi.gov.bi',
                      isDark: isDark,
                      onTap: () {
                        final uri = Uri(
                          scheme: 'mailto',
                          path: 'support@burundi.gov.bi',
                          queryParameters: {
                            'subject': 'Burundi AU Chairmanship App Support',
                            'body': 'Hello,\n\nI need assistance with:\n\n',
                          },
                        );
                        launchUrl(uri);
                      },
                    ),
                    // Export Data & Delete Account - Only show if logged in
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final isLoggedIn = authProvider.isAuthenticated;
                        if (!isLoggedIn) return const SizedBox.shrink();

                        return Column(
                          children: [
                            _buildMenuItem(
                              context: context,
                              icon: Icons.download_rounded,
                              iconBgColor: const Color(0xFF42A5F5),
                              title: 'Export My Data',
                              subtitle: 'Download all your account data',
                              isDark: isDark,
                              onTap: () async {
                                // Show loading
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                try {
                                  final api = ApiService();
                                  final data = await api.exportUserData();

                                  // Close loading
                                  if (context.mounted) {
                                    Navigator.pop(context);

                                    // Show data in dialog
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Your Data Export'),
                                        content: SingleChildScrollView(
                                          child: SelectableText(
                                            const JsonEncoder.withIndent('  ').convert(data),
                                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Close'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              // Copy to clipboard
                                              final jsonString = const JsonEncoder.withIndent('  ').convert(data);
                                              await Clipboard.setData(ClipboardData(text: jsonString));

                                              if (context.mounted) {
                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Data copied! You can paste it into a file.'),
                                                    backgroundColor: AppColors.success,
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text('Copy'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // Close loading
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to export data: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            _buildMenuItem(
                              context: context,
                              icon: Icons.delete_forever_rounded,
                              iconBgColor: Colors.red,
                              title: 'Delete Account',
                              subtitle: 'Permanently delete your account and data',
                              isDark: isDark,
                              isLast: true,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete Account?'),
                                    content: const Text(
                                      'This will permanently delete your account and all associated data. '
                                      'This action cannot be undone.\n\n'
                                      'Are you sure you want to continue?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(dialogContext);

                                          // Show loading indicator
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (ctx) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );

                                          // Delete account
                                          final success = await authProvider.deleteAccount();

                                          // Close loading
                                          if (context.mounted) {
                                            Navigator.pop(context);

                                            if (success) {
                                              // Show success message
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Your account has been deleted.'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              // Navigate to auth screen
                                              Navigator.pushNamedAndRemoveUntil(
                                                context,
                                                '/auth',
                                                (route) => false,
                                              );
                                            } else {
                                              // Show error
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
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
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
                      color: isDark ? Colors.white30 : Colors.black26,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v${AppConstants.appVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
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
  }) {
    return Column(
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
