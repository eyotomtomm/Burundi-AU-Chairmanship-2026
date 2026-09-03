import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config/environment.dart';
import 'haptic_service.dart';

/// One way to share anything in the app.
///
/// Every share hands out the backend's share-card link rather than a bare
/// title, so the item lands in WhatsApp or X as a rendered 1200x630 preview
/// with a headline — and opens straight back into the app when tapped.
class ShareService {
  const ShareService._();

  static const String iosStoreUrl =
      'https://apps.apple.com/app/b4africa-burundi-chairmanship/id6740047505';
  static const String androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.b4africa.app';

  /// Share one piece of content. [kind] must be a share kind the backend
  /// knows: articles, magazines, events, facts, videos, gallery, features,
  /// discussions.
  static Future<void> item(
    BuildContext context, {
    required String kind,
    required Object id,
    required String title,
    String? note,
  }) {
    final lang = Localizations.localeOf(context).languageCode;
    final headline = title.trim();
    final body = [
      if (headline.isNotEmpty) headline,
      if (note != null && note.trim().isNotEmpty) note.trim(),
      Environment.shareUrl(kind, id, lang: lang),
    ].join('\n\n');
    return _send(context, body, subject: headline.isEmpty ? 'Be 4 Africa' : headline);
  }

  /// Share the app itself.
  static Future<void> app(BuildContext context) {
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    final pitch = isFrench
        ? 'Découvrez l’application Be 4 Africa ! 🇧🇮'
        : 'Check out the Be 4 Africa app! 🇧🇮';
    final store = Platform.isIOS ? iosStoreUrl : androidStoreUrl;
    return _send(context, '$pitch\n\n$store', subject: 'Be 4 Africa');
  }

  /// Share a plain URL or message that has no share card behind it.
  static Future<void> text(BuildContext context, String body, {String? subject}) =>
      _send(context, body, subject: subject);

  static Future<void> _send(BuildContext context, String body, {String? subject}) async {
    HapticService.light();
    await Share.share(
      body,
      subject: subject,
      sharePositionOrigin: originOf(context),
    );
  }

  /// iPad anchors the share sheet to a rect as a popover; share_plus throws
  /// without one. Pass the context of the button that was tapped.
  static Rect originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
  }
}
