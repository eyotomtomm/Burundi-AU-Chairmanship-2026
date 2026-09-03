import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import 'discussion_detail_screen.dart';
import '../../config/app_ds.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/async_content_view.dart';
import '../../widgets/feed/post_composer.dart';
import '../../services/feed_pager.dart';

class DiscussionsScreen extends StatefulWidget {
  /// Pre-selects a category chip, e.g. opening straight into A-RISE.
  final String? initialCategory;

  const DiscussionsScreen({super.key, this.initialCategory});

  @override
  State<DiscussionsScreen> createState() => _DiscussionsScreenState();
}

class _DiscussionsScreenState extends State<DiscussionsScreen> {
  final ApiService _api = ApiService();
  String? _selectedCategory;
  late final FeedPager _pager = FeedPager(_fetchPage);

  List<Map<String, dynamic>> get _discussions => _pager.posts;
  bool get _loading => _pager.loading;
  bool get _loadFailed => _pager.failed;

  final List<Map<String, String>> _categories = [
    {'value': 'general', 'label': 'General'},
    {'value': 'arise', 'label': 'A-RISE'},
    {'value': 'events', 'label': 'Events'},
    {'value': 'culture', 'label': 'Culture'},
    {'value': 'politics', 'label': 'Politics & Diplomacy'},
    {'value': 'business', 'label': 'Business & Trade'},
    {'value': 'announcements', 'label': 'Announcements'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _pager.addListener(_onPager);
    _loadDiscussions();
  }

  @override
  void dispose() {
    _pager.removeListener(_onPager);
    _pager.dispose();
    super.dispose();
  }

  void _onPager() {
    if (mounted) setState(() {});
  }

  Future<FeedPage> _fetchPage(int page) =>
      _api.getFeedPage(page: page, category: _selectedCategory);

  Future<void> _loadDiscussions() => _pager.load();

  Future<void> _showCreateDialog() async {
    // Same sheet the Explore feed uses; the forum keeps its title field.
    if (await PostComposer.open(context,
        category: _selectedCategory, requireTitle: true)) {
      _loadDiscussions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(l10n.translate('discussions')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.burundiGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildCategoryChip(null, 'All', theme),
                const SizedBox(width: 8),
                ..._categories.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildCategoryChip(c['value'], c['label']!, theme),
                )),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadFailed
                    ? AsyncContentView(
                        state: AsyncContentState.error,
                        onRetry: _loadDiscussions,
                        child: const SizedBox.shrink(),
                      )
                : _discussions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context).translate('rs_no_discussions_yet'), style: TextStyle(color: Ds.body(context), fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          await _loadDiscussions();
                        },
                        child: ListView.builder(
                          key: const PageStorageKey<String>('discussions_scroll'),
                          padding: const EdgeInsets.all(16),
                          controller: _pager.scroll,
                          itemCount: _discussions.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _discussions.length) {
                              return FeedPagerFooter(_pager,
                                  accent: AppColors.burundiGreen);
                            }
                            final d = _discussions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DiscussionDetailScreen(discussionId: d['id'], scrollToComments: false)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (d['is_pinned'] == true)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: Icon(Icons.push_pin, size: 16, color: const Color(0xFFFFB74D)),
                                            ),
                                          if (d['is_locked'] == true)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: Icon(Icons.lock, size: 16, color: Colors.orange[700]),
                                            ),
                                          Expanded(
                                            child: Text(
                                              d['title'] ?? '',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        d['content'] ?? '',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            d['author_name'] ?? 'Anonymous',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                          ),
                                          if (d['author_badge'] != null) ...[
                                            const SizedBox(width: 4),
                                            VerifiedBadge(badgeType: d['author_badge'] as String?, size: 13),
                                          ],
                                          if ((d['media'] as List?)?.isNotEmpty == true) ...[
                                            const SizedBox(width: 8),
                                            Icon(Icons.photo_library_rounded, size: 13, color: Colors.grey[500]),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${(d['media'] as List).length}',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ],
                                          const Spacer(),
                                          Icon(Icons.comment, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${d['reply_count'] ?? 0}',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.visibility, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${d['view_count'] ?? 0}',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
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

  Widget _buildCategoryChip(String? value, String label, ThemeData theme) {
    final selected = _selectedCategory == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) {
        setState(() => _selectedCategory = s ? value : null);
        _loadDiscussions();
      },
      selectedColor: AppColors.burundiGreen,
      labelStyle: TextStyle(
        color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
