import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/verification_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/verification_dialogs.dart';
import '../../widgets/popup_dialog.dart';
import '../../widgets/app_update_dialog.dart';
import '../../widgets/whats_new_dialog.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/confetti_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/popup_service.dart';
import '../../services/haptic_service.dart';
import '../../services/api_service.dart';
import '../../config/app_constants.dart';
import '../../widgets/promotional_splash_overlay.dart';
import '../maintenance/maintenance_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/magazine_tab.dart';
import '../news/news_screen.dart';
import 'tabs/more_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _maintenanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check verification status and show popups after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationStatus();
      _checkAndShowPopups();
      _checkPromotionalSplash();
      _checkForAppUpdate();
      _showWhatsNew();
    });
    // Check maintenance every 60 seconds
    _maintenanceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkMaintenance();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMaintenance();
      // Re-check verification status when app resumes in case admin verified
      _checkVerificationStatus();
    }
  }

  Future<void> _checkMaintenance() async {
    try {
      final status = await ApiService().getMaintenanceStatus();
      if (!mounted) return;
      if (status['in_maintenance'] == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MaintenanceScreen(maintenanceData: status),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Maintenance check failed: $e');
    }
  }

  /// Check verification status and show popup if needed
  Future<void> _checkVerificationStatus() async {
    final authProvider = context.read<AuthProvider>();
    final verificationProvider = context.read<VerificationProvider>();

    // Only check if user is authenticated
    if (!authProvider.isAuthenticated) return;

    // Check status from backend
    await verificationProvider.checkVerificationStatus(silent: true);

    final status = verificationProvider.requestStatus;

    // Sync badge state: refresh auth profile whenever the cached isVerified
    // flag disagrees with the backend verification status.
    // - User just got approved / admin-verified  → set badge to true
    // - Cached isVerified is stale (e.g. pending) → correct badge to false
    final backendVerified = status == 'approved' || verificationProvider.isProfileVerified;
    if (backendVerified != authProvider.isVerified) {
      await authProvider.refreshProfile();
    }

    // Check if we should show popup
    final shouldShow = await verificationProvider.shouldShowStatusPopup();
    if (!shouldShow || !mounted) return;

    if (status == 'approved') {
      // Show approval dialog with confetti celebration
      final badgeType = verificationProvider.badgeType ?? 'BLUE';
      HapticService.success();
      ConfettiOverlay.show(context);
      await showVerificationApprovedDialog(
        context,
        badgeType: badgeType,
      );

      // Mark as shown
      await verificationProvider.markStatusPopupShown();

      // Refresh auth profile to get updated badge
      await authProvider.refreshProfile();
    } else if (status == 'rejected') {
      // Rejected users see "In Review" in the More tab settings.
      // Suppress the rejection popup — just mark as shown silently.
      await verificationProvider.markStatusPopupShown();
    }
  }

  /// Check and show popup announcements
  Future<void> _checkAndShowPopups() async {
    final authProvider = context.read<AuthProvider>();

    // Only show popups if user is authenticated
    if (!authProvider.isAuthenticated) return;

    try {
      final popupService = PopupService();
      final languageProvider = context.read<LanguageProvider>();
      final languageCode = languageProvider.locale.languageCode;

      // Get popups that should be shown
      final popups = await popupService.getPopupsToShow();

      if (popups.isEmpty || !mounted) return;

      // Show popups one by one (highest priority first)
      for (final popup in popups) {
        if (!mounted) break;

        // Show popup dialog
        await PopupDialog.show(
          context: context,
          popup: popup,
          languageCode: languageCode,
        );

        // Mark as seen
        await popupService.markPopupAsSeen(popup.id);

        // Small delay between popups if there are multiple
        if (popups.length > 1 && popup != popups.last) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      // Silently fail - don't disrupt user experience
    }
  }

  /// Check and show promotional splash screen
  Future<void> _checkPromotionalSplash() async {
    try {
      final splash = await ApiService().getActivePromotionalSplash();
      if (splash == null || !mounted) return;

      // Check show_once via SharedPreferences
      if (splash['show_once'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final seenKey = 'seen_splash_${splash['id']}';
        if (prefs.getBool(seenKey) == true) return;
        await prefs.setBool(seenKey, true);
      }

      if (!mounted) return;
      final languageProvider = context.read<LanguageProvider>();
      final languageCode = languageProvider.locale.languageCode;

      await PromotionalSplashOverlay.show(
        context: context,
        splash: splash,
        languageCode: languageCode,
      );
    } catch (e) {
      if (kDebugMode) print('Promotional splash check failed: $e');
    }
  }

  /// Check for app updates on home screen load
  Future<void> _checkForAppUpdate() async {
    final langCode = Localizations.localeOf(context).languageCode;
    await AppUpdateDialog.check(
      context: context,
      currentVersion: AppConstants.appVersion,
      langCode: langCode,
    );
  }

  /// Show What's New dialog if there's a new version
  Future<void> _showWhatsNew() async {
    // Delay slightly so it doesn't compete with other popups
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final langCode = Localizations.localeOf(context).languageCode;
    await WhatsNewDialog.showIfNeeded(
      context: context,
      currentVersion: AppConstants.appVersion,
      langCode: langCode,
    );
  }

  @override
  void dispose() {
    _maintenanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                HomeTab(onSwitchTab: (index) => setState(() => _currentIndex = index)),
                MagazineTab(onBackToHome: () => setState(() => _currentIndex = 0)),
                NewsScreen(isTab: true, onBackToHome: () => setState(() => _currentIndex = 0)),
                MoreTab(),
              ],
            ),
          ),
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
          onTap: (index) {
            HapticService.selection();
            setState(() => _currentIndex = index);
          },
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
              icon: const Icon(Icons.newspaper_rounded),
              activeIcon: const Icon(Icons.newspaper_rounded),
              label: l10n.translate('news'),
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
