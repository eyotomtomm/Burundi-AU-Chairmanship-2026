import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../news/article_detail_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _bookmarks = [];
  bool _loading = true;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _loading = true);
    try {
      _bookmarks = await _api.getBookmarks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : AppLocalizations.of(context).translate('failed_to_load')),
          backgroundColor: Ds.red,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredBookmarks {
    if (_filterType == 'all') return _bookmarks;
    return _bookmarks.where((b) => b['content_type'] == _filterType).toList();
  }

  /// Removes on the server first; the row only leaves the list on success.
  Future<bool> _removeBookmark(int bookmarkId) async {
    try {
      await _api.removeBookmark(bookmarkId);
      _bookmarks.removeWhere((b) => b['id'] == bookmarkId);
      if (mounted) setState(() {});
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {}); // rebuild so a half-swiped row snaps back
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : AppLocalizations.of(context).translate('bm_could_not_remove')),
          backgroundColor: Ds.red,
        ));
      }
      return false;
    }
  }

  Future<void> _open(Map<String, dynamic> bookmark) async {
    final type = bookmark['content_type'];
    final id = bookmark['content_id'];
    if (type != 'article' || id == null) {
      // ponytail: only articles have a detail screen we can reach by id today.
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('bm_type_not_supported'))));
      return;
    }
    try {
      final article = await _api.getArticle(id.toString());
      if (!mounted) return;
      Navigator.push(context,
          CupertinoPageRoute(builder: (_) => ArticleDetailScreen(article: article)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException
            ? e.message
            : AppLocalizations.of(context).translate('bm_could_not_open_article')),
        backgroundColor: Ds.red,
      ));
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'article': return Icons.newspaper_rounded;
      case 'magazine': return Icons.auto_stories_rounded;
      case 'video': return Icons.smart_display_rounded;
      case 'event': return Icons.event_rounded;
      case 'feature_card': return Icons.auto_awesome_rounded;
      default: return Icons.bookmark_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          DsHeader(title: l10n.translate('bookmarks')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('all', l10n.translate('all')),
                  _chip('article', l10n.translate('articles')),
                  _chip('magazine', l10n.translate('magazines')),
                  _chip('video', l10n.translate('videos')),
                  _chip('event', l10n.translate('events')),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _filteredBookmarks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border_rounded,
                                size: 56, color: Ds.muted(context)),
                            const SizedBox(height: 16),
                            Text(l10n.translate('no_bookmarks'),
                                style: TextStyle(color: Ds.body(context), fontSize: 15)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: Ds.green,
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          await _loadBookmarks();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _filteredBookmarks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final bookmark = _filteredBookmarks[index];
                            return Dismissible(
                              key: Key('bookmark_${bookmark['id']}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Ds.red,
                                  borderRadius: BorderRadius.circular(Ds.rCard),
                                ),
                                child: const Icon(Icons.delete_rounded, color: Colors.white),
                              ),
                              confirmDismiss: (_) => _removeBookmark(bookmark['id']),
                              child: _bookmarkCard(bookmark),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _bookmarkCard(Map<String, dynamic> bookmark) {
    final type = (bookmark['content_type'] ?? '').toString();
    final l10n = AppLocalizations.of(context);
    const typeKeys = {'article': 'article', 'magazine': 'magazine', 'video': 'video', 'event': 'event'};
    return DsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _open(bookmark),
      child: Row(
        children: [
          DsIconSquare(_iconForType(type),
              tint: Ds.tint(context), color: Ds.green, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookmark['content_title'] ?? l10n.translate('bm_untitled'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: Ds.ink(context)),
                ),
                const SizedBox(height: 3),
                Text(
                    typeKeys.containsKey(type)
                        ? l10n.translate(typeKeys[type]!)
                        : type.isEmpty ? '' : type[0].toUpperCase() + type.substring(1),
                    style: Ds.meta(context)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: l10n.translate('remove'),
            child: GestureDetector(
              onTap: () => _removeBookmark(bookmark['id']),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.bookmark_rounded, size: 19, color: Ds.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DsFilterChip(label,
            selected: _filterType == value,
            onTap: () => setState(() => _filterType = value)),
      );
}
