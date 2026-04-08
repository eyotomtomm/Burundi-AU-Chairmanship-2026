import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_colors.dart';

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
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredBookmarks {
    if (_filterType == 'all') return _bookmarks;
    return _bookmarks.where((b) => b['content_type'] == _filterType).toList();
  }

  Future<void> _removeBookmark(int bookmarkId) async {
    try {
      await _api.removeBookmark(bookmarkId);
      _bookmarks.removeWhere((b) => b['id'] == bookmarkId);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'article': return Icons.article;
      case 'magazine': return Icons.menu_book;
      case 'video': return Icons.videocam;
      case 'event': return Icons.event;
      case 'feature_card': return Icons.auto_awesome;
      default: return Icons.bookmark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('bookmarks')),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', l10n.translate('all'), theme),
                const SizedBox(width: 8),
                _buildFilterChip('article', l10n.translate('articles'), theme),
                const SizedBox(width: 8),
                _buildFilterChip('magazine', l10n.translate('magazines'), theme),
                const SizedBox(width: 8),
                _buildFilterChip('video', l10n.translate('videos'), theme),
                const SizedBox(width: 8),
                _buildFilterChip('event', l10n.translate('events'), theme),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBookmarks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              l10n.translate('no_bookmarks'),
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBookmarks,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredBookmarks.length,
                          itemBuilder: (context, index) {
                            final bookmark = _filteredBookmarks[index];
                            return Dismissible(
                              key: Key('bookmark_${bookmark['id']}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.red,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _removeBookmark(bookmark['id']),
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.1),
                                    child: Icon(_iconForType(bookmark['content_type'] ?? ''), color: AppColors.burundiGreen),
                                  ),
                                  title: Text(
                                    bookmark['content_title'] ?? 'Untitled',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    (bookmark['content_type'] ?? '').toString().toUpperCase(),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.bookmark_remove, color: Colors.red),
                                    onPressed: () => _removeBookmark(bookmark['id']),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, ThemeData theme) {
    final selected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) => setState(() => _filterType = value),
      selectedColor: AppColors.burundiGreen,
      labelStyle: TextStyle(
        color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
