import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../l10n/app_localizations.dart';

/// Slot classification for a rendered index when gating content for guests.
enum LoginGateSlot { free, banner, blurred, hidden }

/// Static helpers for gating content behind a login-wall for guest users.
///
/// The gate follows a simple pattern for every list screen:
///   [free items] → [banner] → [blurred tease items]
///
/// Authenticated users bypass all gating entirely.
class LoginGate {
  LoginGate._();

  /// Default number of free (unblurred) items shown to guests before the gate.
  static const int defaultFreeItems = 2;

  /// Free items for the Priority Agenda screen (only 3 agendas total).
  static const int agendaFreeItems = 1;

  /// Maximum number of blurred "tease" items shown past the gate.
  static const int maxBlurredTeases = 3;

  /// Effective item count a list should render for the current auth state.
  ///  - authenticated → actualCount
  ///  - guest → freeShown + 1 (banner) + min(maxBlurred, remaining)
  static int itemCountFor({
    required int actualCount,
    required bool isAuthenticated,
    int freeItems = defaultFreeItems,
    int maxBlurred = maxBlurredTeases,
  }) {
    if (isAuthenticated) return actualCount;
    if (actualCount <= 0) return 0;
    final freeShown = actualCount < freeItems ? actualCount : freeItems;
    final remaining = actualCount - freeShown;
    if (remaining <= 0) {
      // Still show a banner so guests always see the CTA.
      return freeShown + 1;
    }
    final blurredShown = remaining < maxBlurred ? remaining : maxBlurred;
    return freeShown + 1 + blurredShown;
  }

  /// Classifies a render-index for guests: free | banner | blurred | hidden.
  static LoginGateSlot slotFor({
    required int index,
    required int actualCount,
    required bool isAuthenticated,
    int freeItems = defaultFreeItems,
    int maxBlurred = maxBlurredTeases,
  }) {
    if (isAuthenticated) return LoginGateSlot.free;
    final freeShown = actualCount < freeItems ? actualCount : freeItems;
    if (index < freeShown) return LoginGateSlot.free;
    if (index == freeShown) return LoginGateSlot.banner;
    final blurredIndex = index - freeShown - 1;
    final remaining = actualCount - freeShown;
    if (remaining <= 0) return LoginGateSlot.hidden;
    final blurredShown = remaining < maxBlurred ? remaining : maxBlurred;
    if (blurredIndex < blurredShown) return LoginGateSlot.blurred;
    return LoginGateSlot.hidden;
  }

  /// Maps a rendered index back to the underlying data index for blurred slots.
  /// Returns null if the index does not correspond to a real data item.
  static int? dataIndexFor(int renderIndex, int freeItems) {
    if (renderIndex < freeItems) return renderIndex;
    // Skip the banner at renderIndex == freeItems.
    if (renderIndex == freeItems) return null;
    return renderIndex - 1;
  }

  /// Unified "open auth screen" action used everywhere in the app.
  static void promptLogin(BuildContext context) {
    Navigator.of(context).pushNamed('/auth');
  }
}

/// Wraps any existing content card. When [locked] is true the child is
/// rendered under a backdrop blur with a lock overlay and all taps are
/// intercepted to route the user to the auth screen.
///
/// When [locked] is false, the child is rendered directly with zero overhead.
class LockedContentWrap extends StatelessWidget {
  final Widget child;
  final bool locked;
  final double blurSigma;
  final BorderRadius borderRadius;

  const LockedContentWrap({
    super.key,
    required this.child,
    required this.locked,
    this.blurSigma = 8,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => LoginGate.promptLogin(context),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Prevent the child's own gesture detectors from firing.
            IgnorePointer(ignoring: true, child: child),
            // Blur layer.
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: Container(
                  color: AppColors.burundiGreen.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Lock badge + label.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.burundiGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.translate('login_gate_locked_badge'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width "Sign in to continue" banner used as the gate divider in
/// vertical lists. Styled to match Material 3 theme with burundiGreen accent.
class LoginGateBanner extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const LoginGateBanner({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.burundiGreen.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.burundiGreen.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.burundiGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.translate('login_gate_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('login_gate_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: subColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => LoginGate.promptLogin(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.burundiGreen, width: 1.5),
                    foregroundColor: AppColors.burundiGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.translate('login_gate_login'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => LoginGate.promptLogin(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.burundiGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.translate('login_gate_signup'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact card variant of [LoginGateBanner] used at the end of horizontal
/// carousels. Matches the 280-wide card dimensions of existing home carousels.
class LoginGateCarouselCard extends StatelessWidget {
  final double width;
  final double? height;
  final EdgeInsetsGeometry margin;

  const LoginGateCarouselCard({
    super.key,
    this.width = 280,
    this.height,
    this.margin = const EdgeInsets.only(right: 12),
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: () => LoginGate.promptLogin(context),
      child: Container(
        width: width,
        height: height,
        margin: margin,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.burundiGreen.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.burundiGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('login_gate_title'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                l10n.translate('login_gate_subtitle'),
                style: TextStyle(fontSize: 10, color: subColor, height: 1.25),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => LoginGate.promptLogin(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                l10n.translate('login_gate_signup'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
