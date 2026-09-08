import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_ds.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/haptic_service.dart';

/// Bookmark toggle for any bookmarkable item.
///
/// The backend and the Bookmarks screen both handle articles, magazines,
/// videos, events and feature cards, but only the article page ever had a
/// button — so four of the filters on that screen could never fill. This is
/// that button, written once instead of five times.
class BookmarkButton extends StatefulWidget {
  /// One of the backend's `Bookmark.CONTENT_TYPE_CHOICES`:
  /// article, magazine, video, event, feature_card.
  final String contentType;
  final int contentId;

  /// Draws for a coloured header (white glyph) rather than a page body.
  final bool onDarkHeader;
  final double size;

  const BookmarkButton({
    super.key,
    required this.contentType,
    required this.contentId,
    this.onDarkHeader = false,
    this.size = 20,
  });

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton> {
  bool? _saved;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!context.read<AuthProvider>().isAuthenticated) return;
    try {
      final res = await ApiService()
          .checkBookmark(widget.contentType, widget.contentId);
      if (mounted) {
        setState(() => _saved = res['is_bookmarked'] == true ||
            res['bookmarked'] == true);
      }
    } catch (_) {
      // Signed out or offline — leave it unset and let the tap find out.
    }
  }

  Future<void> _toggle() async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return;
    }
    if (_busy) return;
    final was = _saved ?? false;
    setState(() {
      _saved = !was; // optimistic; reverted below if the call fails
      _busy = true;
    });
    HapticService.light();
    final l10n = AppLocalizations.of(context);
    try {
      if (was) {
        // The check endpoint returns no bookmark id, so find the row.
        final list = await ApiService()
            .get('bookmarks/?content_type=${widget.contentType}', auth: true);
        final items = list is Map
            ? (list['results'] as List? ?? const [])
            : (list as List);
        final match = items
            .cast<Map>()
            .where((b) => b['content_id'] == widget.contentId)
            .toList();
        if (match.isNotEmpty) {
          await ApiService().removeBookmark(match.first['id'] as int);
        }
      } else {
        await ApiService().addBookmark(widget.contentType, widget.contentId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saved = was);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : l10n.translate('generic_error')),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved ?? false;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.translate(saved ? 'w_bookmarked' : 'w_bookmark'),
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            size: widget.size,
            color: widget.onDarkHeader
                ? Colors.white
                : (saved ? Ds.green : Ds.body(context)),
          ),
        ),
      ),
    );
  }
}
