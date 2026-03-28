import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io';
import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/verified_badge.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
                                        isLoggedIn ? (authProvider.userName ?? 'User') : 'Guest User',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isLoggedIn && authProvider.isVerified) ...[
                                      const SizedBox(width: 6),
                                      VerifiedBadge(badgeType: authProvider.badgeType, size: 18),
                                    ],
                                  ],
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
                      onTap: () => _showAboutDialog(context, l10n),
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
                      subtitle: 'Get help and support',
                      isDark: isDark,
                      onTap: () => _showSupportOptions(context, isDark),
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
                              onTap: () => _exportUserData(context),
                            ),
                            _buildMenuItem(
                              context: context,
                              icon: Icons.manage_accounts_rounded,
                              iconBgColor: Colors.red,
                              title: 'Manage Account',
                              subtitle: 'Deactivate or delete your account',
                              isDark: isDark,
                              isLast: true,
                              onTap: () => _showAccountManageSheet(context, isDark, authProvider),
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
    ));
  }

  void _exportUserData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final api = ApiService();
      final data = await api.exportUserData();

      // Add branding to the export
      final brandedExport = {
        '______________________________': '______________________________',
        'app': 'Burundi AU Chairmanship 2026',
        'brand': 'Burundi4Africa',
        'website': 'https://burundi4africa.com',
        'export_type': 'Personal Data Export (GDPR)',
        '________________________________': '________________________________',
        ...data,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(brandedExport);

      // Save to temp file and share
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/burundi4africa_data_export_$timestamp.json');
      await file.writeAsString(jsonString);

      if (!context.mounted) return;
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Burundi4Africa - My Data Export',
        text: 'Your personal data export from Burundi AU Chairmanship 2026 app.',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) async {
    // Fetch about info from backend, fallback to hardcoded values
    String description = 'Official application for the Burundi African Union Chairmanship 2026.';
    String summitTheme = AppConstants.summitTheme;
    String developerName = 'Eyosias Tamene';
    String developerUrl = 'https://eyosias.dev';

    try {
      final settings = await ApiService().getSettings();
      if (settings != null) {
        final langCode = l10n.locale.languageCode;
        description = settings.getDescription(langCode).isNotEmpty
            ? settings.getDescription(langCode)
            : description;
        summitTheme = settings.getTheme(langCode).isNotEmpty
            ? settings.getTheme(langCode)
            : summitTheme;
        if (settings.developerName.isNotEmpty) {
          developerName = settings.developerName;
        }
        if (settings.developerUrl.isNotEmpty) {
          developerUrl = settings.developerUrl;
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.burundiGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.stars, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              AppConstants.appName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              'v${AppConstants.appVersion}',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            Text(summitTheme, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(developerUrl), mode: LaunchMode.externalApplication),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                  children: [
                    TextSpan(text: '${l10n.translate('designed_by')} '),
                    TextSpan(
                      text: developerName,
                      style: const TextStyle(
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
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
                title: const Text('Email Support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: const Text('We respond within 24 hours'),
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
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: liveAgentOnline ? Colors.blue : Colors.grey,
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
                  liveAgentOnline ? 'Chat with a support agent now' : 'No agents available right now',
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
