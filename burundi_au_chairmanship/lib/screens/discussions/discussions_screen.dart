import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'discussion_detail_screen.dart';

class DiscussionsScreen extends StatefulWidget {
  const DiscussionsScreen({super.key});

  @override
  State<DiscussionsScreen> createState() => _DiscussionsScreenState();
}

class _DiscussionsScreenState extends State<DiscussionsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _discussions = [];
  bool _loading = true;
  String? _selectedCategory;

  final List<Map<String, String>> _categories = [
    {'value': 'general', 'label': 'General'},
    {'value': 'events', 'label': 'Events'},
    {'value': 'culture', 'label': 'Culture'},
    {'value': 'diplomacy', 'label': 'Diplomacy'},
    {'value': 'development', 'label': 'Development'},
    {'value': 'youth', 'label': 'Youth'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDiscussions();
  }

  Future<void> _loadDiscussions() async {
    setState(() => _loading = true);
    try {
      _discussions = await _api.getDiscussions(category: _selectedCategory);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'general';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Start a Discussion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!))).toList(),
              onChanged: (v) => category = v ?? 'general',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _api.createDiscussion(titleCtrl.text, contentCtrl.text, category);
                  _loadDiscussions();
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Post Discussion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('discussions')),
        elevation: 0,
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
                : _discussions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No discussions yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          await _loadDiscussions();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _discussions.length,
                          itemBuilder: (context, index) {
                            final d = _discussions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DiscussionDetailScreen(discussionId: d['id'], scrollToComments: context.read<AuthProvider>().isAuthenticated)),
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
