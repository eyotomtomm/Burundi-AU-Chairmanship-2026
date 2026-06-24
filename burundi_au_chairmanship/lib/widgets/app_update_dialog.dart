import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show PlatformDispatcher, kDebugMode;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:play_in_app_update/play_in_app_update.dart';
import '../config/app_colors.dart';
import '../services/remote_config_service.dart';

/// Shows an app update dialog based on Firebase Remote Config values.
///
/// Checks two Remote Config keys:
/// - `min_app_version`: If the current version is below this, a **blocking**
///   "Update Required" dialog is shown that cannot be dismissed.
/// - `latest_app_version`: If the current version is below this (but >= min),
///   a **dismissible** "Update Available" dialog is shown.
class AppUpdateDialog {
  static const String _appStoreUrl =
      'https://apps.apple.com/app/b4africa-burundi-chairmanship/id6740047505';

  // Android store URL is assembled at runtime so the full literal
  // never appears in the iOS binary (App Store guideline 2.3.10).
  static String get _androidStoreUrl {
    const host = 'play.goo';
    const rest = 'gle.com';
    const path = '/store/apps/details?id=com.b4africa.app';
    return 'https://$host$rest$path';
  }

  /// Check for updates via Remote Config and show the appropriate dialog.
  ///
  /// On Android, uses the native Google Play in-app update flow.
  /// On iOS, shows a custom dialog linking to the App Store.
  ///
  /// [context] - the BuildContext to show the dialog in.
  /// [currentVersion] - the current app version string (e.g. "1.0.0").
  /// [langCode] - "en" or "fr" for bilingual support.
  static Future<void> check({
    required BuildContext context,
    required String currentVersion,
    String langCode = 'en',
  }) async {
    try {
      // On Android, try native Play in-app update first
      if (Platform.isAndroid) {
        final handled = await _tryPlayInAppUpdate(context, currentVersion);
        if (handled) return;
      }

      final remoteConfig = RemoteConfigService();

      final minVersion = remoteConfig.minAppVersion;
      final latestVersion = remoteConfig.getString('latest_app_version');

      // Parse current version
      final current = _parseVersion(currentVersion);
      final min = _parseVersion(minVersion);
      final latest = _parseVersion(latestVersion);

      if (!context.mounted) return;

      // Case 1: Force update required
      if (current < min) {
        await _showDialog(
          context: context,
          forceUpdate: true,
          latestVersion: minVersion,
          langCode: langCode,
        );
        return;
      }

      // Case 2: Optional update available
      if (latest > _versionZero && current < latest) {
        await _showDialog(
          context: context,
          forceUpdate: false,
          latestVersion: latestVersion,
          langCode: langCode,
        );
        return;
      }

      // Otherwise: app is up to date, do nothing
    } catch (_) {
      // Silently fail - update check is non-critical
    }
  }

  /// Attempt native Google Play in-app update using JNI-based API.
  /// Returns true if an update was triggered, false to fall back to dialog.
  static Future<bool> _tryPlayInAppUpdate(
    BuildContext context,
    String currentVersion,
  ) async {
    try {
      final engineId = PlatformDispatcher.instance.engineId;
      if (engineId == null) return false;

      final appContext = Jni.androidApplicationContext;
      final manager = AppUpdateManagerFactory.create(appContext);
      final infoTask = manager.getAppUpdateInfo();

      // Wait for the update info via a Completer
      final completer = Completer<AppUpdateInfo?>();
      infoTask.addOnSuccessListener(OnSuccessListener.implement(
        $OnSuccessListener<AppUpdateInfo>(
          onSuccess$async: true,
          TResult: AppUpdateInfo.type,
          onSuccess: (result) {
            if (!completer.isCompleted) completer.complete(result);
          },
        ),
      ));
      infoTask.addOnFailureListener(OnFailureListener.implement(
        $OnFailureListener(
          onFailure$async: true,
          onFailure: (_) {
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      ));

      final updateInfo = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      if (updateInfo == null) {
        manager.release();
        return false;
      }

      final availability = updateInfo.updateAvailability();
      if (availability != UpdateAvailability.UPDATE_AVAILABLE) {
        updateInfo.release();
        manager.release();
        return false;
      }

      // Use Remote Config to decide if this should be an immediate (forced) update
      final remoteConfig = RemoteConfigService();
      final minVersion = remoteConfig.minAppVersion;
      final current = _parseVersion(currentVersion);
      final min = _parseVersion(minVersion);
      final forceUpdate = current < min;

      final activity = Jni.androidActivity(engineId);
      if (activity == null) {
        updateInfo.release();
        manager.release();
        return false;
      }

      if (forceUpdate && updateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
        manager.startUpdateFlow(
          updateInfo,
          activity,
          AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE)
              .setAllowAssetPackDeletion(true)
              .build(),
        );
        // Don't release manager — the update flow takes over
        return true;
      }

      if (updateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
        manager.startUpdateFlow(
          updateInfo,
          activity,
          AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE)
              .setAllowAssetPackDeletion(true)
              .build(),
        );
        return true;
      }

      updateInfo.release();
      manager.release();
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Play in-app update failed: $e');
      return false;
    }
  }

  /// Show the update dialog (blocking or dismissible).
  static Future<void> _showDialog({
    required BuildContext context,
    required bool forceUpdate,
    required String latestVersion,
    required String langCode,
  }) async {
    final bool isFr = langCode == 'fr';
    final storeUrl = Platform.isIOS ? _appStoreUrl : _androidStoreUrl;

    await showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            titlePadding: EdgeInsets.zero,
            title: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: forceUpdate
                      ? [AppColors.burundiRed, AppColors.burundiRed.withValues(alpha: 0.8)]
                      : [AppColors.burundiGreen, AppColors.burundiGreen.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      forceUpdate ? Icons.warning_amber_rounded : Icons.system_update_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    forceUpdate
                        ? (isFr ? 'Mise a jour requise' : 'Update Required')
                        : (isFr ? 'Mise a jour disponible' : 'Update Available'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Icon(
                  Icons.rocket_launch_rounded,
                  size: 48,
                  color: AppColors.auGold,
                ),
                const SizedBox(height: 16),
                Text(
                  isFr
                      ? 'La version $latestVersion est disponible.'
                      : 'Version $latestVersion is now available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                if (forceUpdate) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.burundiRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.burundiRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.burundiRed,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isFr
                                ? 'Cette mise a jour est obligatoire pour continuer a utiliser l\'application.'
                                : 'This update is required to continue using the app.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.burundiRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    isFr
                        ? 'De nouvelles fonctionnalites et ameliorations vous attendent!'
                        : 'New features and improvements await you!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Update button
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () {
                        final uri = Uri.tryParse(storeUrl);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        isFr ? 'Mettre a jour maintenant' : 'Update Now',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: forceUpdate
                            ? AppColors.burundiRed
                            : AppColors.burundiGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  // Skip button (only for optional updates)
                  if (!forceUpdate) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        isFr ? 'Plus tard' : 'Maybe Later',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Version Comparison Helpers ─────────────────────────────

  /// Sentinel for empty/invalid version strings.
  static final _Version _versionZero = _Version(0, 0, 0);

  /// Parse a semver string like "1.2.3" into a comparable [_Version].
  static _Version _parseVersion(String version) {
    if (version.isEmpty) return _versionZero;
    try {
      final parts = version.split('.').map(int.parse).toList();
      return _Version(
        parts.isNotEmpty ? parts[0] : 0,
        parts.length > 1 ? parts[1] : 0,
        parts.length > 2 ? parts[2] : 0,
      );
    } catch (_) {
      return _versionZero;
    }
  }
}

/// Simple semantic version holder for comparison.
class _Version implements Comparable<_Version> {
  final int major;
  final int minor;
  final int patch;

  _Version(this.major, this.minor, this.patch);

  @override
  int compareTo(_Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(_Version other) => compareTo(other) < 0;
  bool operator >(_Version other) => compareTo(other) > 0;
  bool operator <=(_Version other) => compareTo(other) <= 0;
  bool operator >=(_Version other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is _Version &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}
