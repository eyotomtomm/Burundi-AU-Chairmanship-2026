import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';

class DiscussionDetailScreen extends StatefulWidget {
  final int discussionId;
  const DiscussionDetailScreen({super.key, required this.discussionId});

  @override
  State<DiscussionDetailScreen> createState() => _DiscussionDetailScreenState();
}

class _DiscussionDetailScreenState extends State<DiscussionDetailScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _replyCtrl = TextEditingController();
  Map<String, dynamic>? _discussion;
  List<Map<String, dynamic>> _replies = [];
  bool _loading = true;
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _recordView();
  }

  Future<void> _recordView() async {
    try {
      await _api.recordDiscussionView(widget.discussionId);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like this discussion')),
      );
      return;
    }
    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    setState(() {
      _isLiked = !wasLiked;
      _likeCount = prevCount + (wasLiked ? -1 : 1);
    });
    try {
      final result = await _api.toggleDiscussionLike(widget.discussionId);
      if (mounted) {
        setState(() {
          _isLiked = result['is_liked'] == true;
          _likeCount = result['like_count'] ?? _likeCount;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = wasLiked;
        _likeCount = prevCount;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _discussion = await _api.getDiscussionDetail(widget.discussionId);
      _replies = await _api.getDiscussionReplies(widget.discussionId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _postReply() async {
    if (_replyCtrl.text.isEmpty) return;
    try {
      await _api.postDiscussionReply(widget.discussionId, _replyCtrl.text);
      _replyCtrl.clear();
      FocusScope.of(context).unfocus();
      _loadData();
    } catch (_) {}
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _discussion == null
              ? const Center(child: Text('Discussion not found'))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          await _loadData();
                        },
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Original post
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.1),
                                        child: Text(
                                          (_discussion!['author_name'] ?? 'A')[0].toUpperCase(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.burundiGreen),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_discussion!['author_name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(_discussion!['created_at'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _discussion!['title'] ?? '',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _discussion!['content'] ?? '',
                                    style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.burundiGreen.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _discussion!['category_display'] ?? _discussion!['category'] ?? '',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.burundiGreen),
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: _toggleLike,
                                        child: Row(
                                          children: [
                                            Icon(
                                              _isLiked ? Icons.favorite : Icons.favorite_border,
                                              size: 20,
                                              color: _isLiked ? Colors.redAccent : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_likeCount',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: _isLiked ? Colors.redAccent : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text('Replies (${_replies.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ..._replies.map((reply) => _buildReplyCard(reply, isDark)),
                            if (_replies.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text('No replies yet. Be the first!', style: TextStyle(color: Colors.grey[500])),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Reply input
                    if (_discussion!['is_locked'] != true)
                      Container(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Write a reply...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                  filled: true,
                                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                maxLines: null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _postReply,
                              icon: const Icon(Icons.send, color: AppColors.burundiGreen),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildReplyCard(Map<String, dynamic> reply, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey[300],
                child: Text((reply['author_name'] ?? 'A')[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(reply['author_name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text(reply['created_at'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 8),
          Text(reply['content'] ?? '', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700])),
        ],
      ),
    );
  }
}
