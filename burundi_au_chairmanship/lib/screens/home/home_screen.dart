import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_ds.dart';
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
import '../../services/app_link_service.dart';
import '../../main.dart' show messagingService;
import '../../config/app_constants.dart';
import '../../widgets/promotional_splash_overlay.dart';
import '../maintenance/maintenance_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/magazine_tab.dart';
import 'tabs/explore_tab.dart';
import 'widgets/home_nav_bar.dart';
import '../news/news_screen.dart';
import 'tabs/more_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 2;

  /// Drives the fade/rise of the incoming tab. Short on purpose: long enough
  /// to read as a transition, short enough that the bar still feels instant.
  late final AnimationController _tabAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  Timer? _maintenanceTimer;
  bool _showingVerificationPopup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check verification status and show popups after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Any link the app was launched with is routed here, once home exists.
      AppLinkService().flushPendingLink();
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
      // Re-register FCM token so the backend always has a fresh, valid token
      messagingService?.refreshToken();
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
    if (!shouldShow || !mounted || _showingVerificationPopup) return;

    final isAdminVerified = verificationProvider.isProfileVerified && status == null;

    if (status == 'approved' || isAdminVerified) {
      // Mark as shown BEFORE displaying the dialog to prevent duplicate
      // popups when the app resumes or the user navigates while it's open.
      _showingVerificationPopup = true;
      await verificationProvider.markStatusPopupShown();

      // Show approval dialog with confetti celebration
      final badgeType = verificationProvider.badgeType ?? 'BLUE';
      HapticService.success();
      ConfettiOverlay.show(context);
      await showVerificationApprovedDialog(
        context,
        badgeType: badgeType,
      );

      _showingVerificationPopup = false;

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

  /// Check and show promotional splash screen (round-robin rotation).
  Future<void> _checkPromotionalSplash() async {
    try {
      final splashes = await ApiService().getAllActivePromotionalSplashes();
      if (splashes.isEmpty || !mounted) return;

      final prefs = await SharedPreferences.getInstance();

      // Filter out show_once splashes that have already been seen
      final eligible = splashes.where((s) {
        if (s['show_once'] == true) {
          return prefs.getBool('seen_splash_${s['id']}') != true;
        }
        return true;
      }).toList();

      if (eligible.isEmpty || !mounted) return;

      // Round-robin: find the next splash after the last shown one
      final lastShownId = prefs.getInt('last_shown_splash_id');
      Map<String, dynamic> chosen;

      if (lastShownId == null) {
        chosen = eligible.first;
      } else {
        final lastIndex = eligible.indexWhere((s) => s['id'] == lastShownId);
        if (lastIndex == -1 || lastIndex == eligible.length - 1) {
          // Not found or was the last item → wrap to first
          chosen = eligible.first;
        } else {
          chosen = eligible[lastIndex + 1];
        }
      }

      // Save the chosen splash ID for next rotation
      await prefs.setInt('last_shown_splash_id', chosen['id']);

      // Mark show_once splashes as seen
      if (chosen['show_once'] == true) {
        await prefs.setBool('seen_splash_${chosen['id']}', true);
      }

      if (!mounted) return;
      final languageProvider = context.read<LanguageProvider>();
      final languageCode = languageProvider.locale.languageCode;

      await PromotionalSplashOverlay.show(
        context: context,
        splash: chosen,
        languageCode: languageCode,
      );

      // Track the view for the splash that was actually shown
      ApiService().trackPromotionalSplashView(chosen['id']);
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
    _tabAnim.dispose();
    _maintenanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Every tab change goes through here.
  void _goToTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _tabAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      // The notch bar floats over the content; every tab pads its scrollable
      // by Ds.navSpace so nothing is trapped underneath it.
      extendBody: true,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            // IndexedStack keeps every tab alive, so switching back is instant
            // and scroll positions survive; the fade/rise is layered on top so
            // the swap reads as a transition without costing a rebuild.
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _tabAnim, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.012),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: _tabAnim, curve: Curves.easeOutCubic)),
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    MagazineTab(onBackToHome: () => _goToTab(2)),
                    NewsScreen(isTab: true, onBackToHome: () => _goToTab(2)),
                    HomeTab(onSwitchTab: _goToTab),
                    ExploreTab(onBackToHome: () => _goToTab(2)),
                    MoreTab(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(l10n),
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    // Home is pinned to the raised centre button and never moves.
    return HomeNavBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        HapticService.selection();
        _goToTab(index);
      },
      items: [
        HomeNavItem(Icons.auto_stories_rounded, l10n.magazine),
        HomeNavItem(Icons.newspaper_rounded, l10n.translate('news')),
        HomeNavItem(Icons.home_rounded, l10n.home),
        HomeNavItem(Icons.explore_rounded, l10n.translate('agenda')),
        HomeNavItem(Icons.more_horiz_rounded, l10n.more),
      ],
    );
  }
}
