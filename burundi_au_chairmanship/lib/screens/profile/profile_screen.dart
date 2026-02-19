import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return CustomScrollView(
            slivers: [
              // Header with gradient
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.burundiGreen, Color(0xFF0D7A25)],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          // Avatar
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Center(
                              child: authProvider.userName != null &&
                                      authProvider.userName!.isNotEmpty
                                  ? Text(
                                      authProvider.userName![0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : const Icon(Icons.person,
                                      size: 44, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Name
                          Text(
                            authProvider.userName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Email
                          Text(
                            authProvider.userEmail ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Personal Information Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    l10n.translate('personal_info'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.burundiGreen,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
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
                        // Name row with edit
                        ListTile(
                          leading: const Icon(Icons.person_outline,
                              color: AppColors.burundiGreen),
                          title: Text(l10n.translate('full_name')),
                          subtitle: Text(authProvider.userName ?? 'Not set'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.burundiGreen, size: 20),
                            onPressed: () =>
                                _showEditNameDialog(context, authProvider, l10n),
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        // Email row (read-only)
                        ListTile(
                          leading: const Icon(Icons.email_outlined,
                              color: AppColors.auGold),
                          title: Text(l10n.translate('email')),
                          subtitle: Text(authProvider.userEmail ?? 'Not set'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Data & Privacy Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    l10n.translate('data_privacy'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.burundiGreen,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
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
                        // Export Data
                        ListTile(
                          leading: const Icon(Icons.download_outlined,
                              color: AppColors.info),
                          title: Text(l10n.translate('export_data')),
                          subtitle: Text(l10n.translate('export_data_desc')),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => _handleExportData(context),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        // Sign Out
                        ListTile(
                          leading: const Icon(Icons.logout,
                              color: AppColors.warning),
                          title: Text(l10n.translate('sign_out')),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () =>
                              _handleSignOut(context, authProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Danger Zone Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    l10n.translate('danger_zone'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever_outlined,
                          color: AppColors.error),
                      title: Text(
                        l10n.translate('delete_account'),
                        style: const TextStyle(color: AppColors.error),
                      ),
                      subtitle: Text(l10n.translate('delete_account_desc')),
                      trailing: const Icon(Icons.chevron_right,
                          size: 20, color: AppColors.error),
                      onTap: () =>
                          _handleDeleteAccount(context, authProvider, l10n),
                    ),
                  ),
                ),
              ),

              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 48),
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

  void _handleExportData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final api = ApiService();
      final data = await api.exportUserData();

      if (context.mounted) {
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
        content: Text(l10n.translate('delete_account_confirm')),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.translate('account_deleted')),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/auth', (route) => false);
                } else {
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
}
