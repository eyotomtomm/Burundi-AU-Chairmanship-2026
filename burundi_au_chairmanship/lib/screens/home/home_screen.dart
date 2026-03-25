import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/verification_provider.dart';
import '../../widgets/verification_dialogs.dart';
import 'tabs/home_tab.dart';
import 'tabs/magazine_tab.dart';
import 'tabs/agenda_tab.dart';
import 'tabs/more_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check verification status after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationStatus();
    });
  }

  /// Check verification status and show popup if needed
  Future<void> _checkVerificationStatus() async {
    final authProvider = context.read<AuthProvider>();
    final verificationProvider = context.read<VerificationProvider>();

    // Only check if user is authenticated
    if (!authProvider.isAuthenticated) return;

    // Check status from backend
    await verificationProvider.checkVerificationStatus(silent: true);

    // Check if we should show popup
    final shouldShow = await verificationProvider.shouldShowStatusPopup();
    if (!shouldShow || !mounted) return;

    final status = verificationProvider.requestStatus;

    if (status == 'approved') {
      // Show approval dialog
      final badgeType = verificationProvider.badgeType ?? 'BLUE';
      await showVerificationApprovedDialog(
        context,
        badgeType: badgeType,
      );

      // Mark as shown
      await verificationProvider.markStatusPopupShown();

      // Refresh auth profile to get updated badge
      await authProvider.refreshProfile();
    } else if (status == 'rejected') {
      // Show rejection dialog with appeal option
      await showVerificationRejectedDialog(
        context,
        reason: verificationProvider.rejectionReason ?? 'No reason provided',
        onAppeal: () => _showAppealDialog(),
      );

      // Mark as shown
      await verificationProvider.markStatusPopupShown();
    }
  }

  /// Show appeal submission dialog
  void _showAppealDialog() {
    showAppealDialog(
      context,
      onSubmit: (appealMessage) async {
        final verificationProvider = context.read<VerificationProvider>();

        final success = await verificationProvider.submitAppeal(appealMessage);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Appeal submitted successfully. We will review your request.'
                  : 'Failed to submit appeal. Please try again.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTab(onSwitchTab: (index) => setState(() => _currentIndex = index)),
          MagazineTab(),
          AgendaTab(),
          MoreTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(l10n),
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              activeIcon: const Icon(Icons.home_rounded),
              label: l10n.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_stories_rounded),
              activeIcon: const Icon(Icons.auto_stories_rounded),
              label: l10n.magazine,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.flag_rounded),
              activeIcon: const Icon(Icons.flag_rounded),
              label: 'Agenda',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.more_horiz_rounded),
              activeIcon: const Icon(Icons.more_horiz_rounded),
              label: l10n.more,
            ),
          ],
        ),
      ),
    );
  }
}
