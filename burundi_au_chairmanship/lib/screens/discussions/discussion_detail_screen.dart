import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/like_service.dart';
import '../../widgets/liked_by_avatars.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/comment_ban_dialog.dart';
import '../../utils/input_sanitizer.dart';

class DiscussionDetailScreen extends StatefulWidget {
  final int discussionId;
  final bool scrollToComments;
  const DiscussionDetailScreen({super.key, required this.discussionId, this.scrollToComments = false});

  @override
  State<DiscussionDetailScreen> createState() => _DiscussionDetailScreenState();
}

class _DiscussionDetailScreenState extends State<DiscussionDetailScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _replyCtrl = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  Map<String, dynamic>? _discussion;
  List<Map<String, dynamic>> _replies = [];
  bool _loading = true;
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  // Scroll to comments (replies)
  final GlobalKey _commentsSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key == 'discussion:${widget.discussionId}' && mounted) setState(() {});
    });
    _loadData();
    _recordView();
    if (widget.scrollToComments) {
      _scheduleScrollToComments();
    }
  }

  void _scheduleScrollToComments() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return _loading && mounted;
    }).then((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _commentsSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic).then((_) {
            if (mounted) _replyFocusNode.requestFocus();
          });
        }
      });
    });
  }

  Future<void> _recordView() async {
    try {
      await _api.recordDiscussionView(widget.discussionId);
    } catch (_) {}
  }

  void _toggleLike() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('login_to_like'))),
      );
      return;
    }
    _likeService.toggle(EntityType.discussion, widget.discussionId);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _discussion = await _api.getDiscussionDetail(widget.discussionId);
      if (_discussion != null) {
        final likers = _discussion!['recent_likers'] is List
            ? (_discussion!['recent_likers'] as List)
                .map((l) => Liker.fromJson(l as Map<String, dynamic>))
                .toList()
            : <Liker>[];
        _likeService.seed(
          EntityType.discussion, widget.discussionId,
          isLiked: _discussion!['is_liked'] == true,
          likeCount: _discussion!['like_count'] ?? 0,
          recentLikers: likers,
        );
      }
      _replies = await _api.getDiscussionReplies(widget.discussionId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _postReply() async {
    final text = InputSanitizer.sanitizeComment(_replyCtrl.text);
    if (text.isEmpty) return;

    final validationError = InputSanitizer.validateComment(text);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
      }
      return;
    }

    try {
      await _api.postDiscussionReply(widget.discussionId, text);
      _replyCtrl.clear();
      FocusScope.of(context).unfocus();
      _loadData();
    } on ApiException catch (e) {
      if (mounted) showCommentErrorDialog(context, e.message, e.statusCode, referenceId: e.referenceId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    _replyCtrl.dispose();
    _replyFocusNode.dispose();
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
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _toggleLike,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                          children: [
                                            Icon(
                                              _likeService.getState(EntityType.discussion, widget.discussionId).isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              size: 22,
                                              color: _likeService.getState(EntityType.discussion, widget.discussionId).isLiked ? Colors.redAccent : Colors.grey,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '${_likeService.getState(EntityType.discussion, widget.discussionId).likeCount}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _likeService.getState(EntityType.discussion, widget.discussionId).isLiked ? Colors.redAccent : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Like',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _likeService.getState(EntityType.discussion, widget.discussionId).isLiked ? Colors.redAccent : Colors.grey,
                                              ),
                                            ),
                                            if (_likeService.getState(EntityType.discussion, widget.discussionId).recentLikers.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              LikedByAvatars(
                                                likers: _likeService.getState(EntityType.discussion, widget.discussionId).recentLikers,
                                                totalLikes: _likeService.getState(EntityType.discussion, widget.discussionId).likeCount,
                                                avatarRadius: 10,
                                              ),
                                            ],
                                          ],
                                        ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(key: _commentsSectionKey, height: 0),
                            Text('Replies (${_replies.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ..._replies.map((reply) {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final discussionId = widget.discussionId;
                              return CommentTile.fromMap(
                                reply,
                                key: ValueKey(reply['id']),
                                userNameKey: 'author_name',
                                isAuthenticated: auth.isAuthenticated,
                                onDelete: () async {
                                  try {
                                    await ApiService().deleteDiscussionReply(discussionId, reply['id']);
                                    _loadData();
                                  } catch (_) {}
                                },
                                onToggleLike: () => ApiService().toggleDiscussionReplyLike(discussionId, reply['id']),
                                onEdit: (content) => ApiService().editDiscussionReply(discussionId, reply['id'], content),
                              );
                            }),
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
                                focusNode: _replyFocusNode,
                                maxLength: InputSanitizer.maxCommentLength,
                                decoration: InputDecoration(
                                  hintText: 'Write a reply...',
                                  counterText: '',
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

}
