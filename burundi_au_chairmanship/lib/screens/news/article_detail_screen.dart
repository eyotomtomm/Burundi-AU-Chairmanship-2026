import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Article _article;
  List<ArticleComment> _comments = [];
  bool _loadingComments = true;
  final _commentController = TextEditingController();
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _recordView();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _recordView() async {
    try {
      final result = await ApiService().recordArticleView(_article.id);
      if (mounted) {
        setState(() {
          _article = _article.copyWith(viewCount: result['view_count'] ?? _article.viewCount + 1);
        });
      }
    } catch (_) {
      // Silently fail — view count is non-critical
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await ApiService().getArticleComments(_article.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _loadingComments = false;
          _article = _article.copyWith(commentCount: comments.length);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _postingComment = true);
    try {
      final comment = await ApiService().postArticleComment(_article.id, text);
      if (mounted) {
        setState(() {
          _comments.insert(0, comment);
          _article = _article.copyWith(commentCount: _comments.length);
          _commentController.clear();
          _postingComment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _postingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteComment(ArticleComment comment) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('delete_comment')),
        content: Text(l10n.translate('delete_comment_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('delete_comment'),
                style: const TextStyle(color: AppColors.burundiRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService().deleteArticleComment(_article.id, comment.id);
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
          _article = _article.copyWith(commentCount: _comments.length);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_to_like'))),
      );
      return;
    }

    // Optimistic UI
    final wasLiked = _article.isLiked;
    setState(() {
      _article = _article.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? _article.likeCount - 1 : _article.likeCount + 1,
      );
    });

    try {
      final result = await ApiService().toggleArticleLike(_article.id);
      if (mounted) {
        setState(() {
          _article = _article.copyWith(
            isLiked: result['is_liked'],
            likeCount: result['like_count'],
          );
        });
      }
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _article = _article.copyWith(isLiked: wasLiked, likeCount: wasLiked ? _article.likeCount + 1 : _article.likeCount - 1);
        });
      }
    }
  }

  String _timeAgo(DateTime date, AppLocalizations l10n) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return l10n.translate('just_now');
    if (diff.inHours < 1) return '${diff.inMinutes} ${l10n.translate('minutes_ago')}';
    if (diff.inDays < 1) return '${diff.inHours} ${l10n.translate('hours_ago')}';
    return '${diff.inDays} ${l10n.translate('days_ago')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image SliverAppBar
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _article.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.auGold.withValues(alpha: 0.2)),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.auGold.withValues(alpha: 0.2),
                      child: const Icon(Icons.article_rounded, size: 48, color: Colors.white54),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _article.getTitle(langCode),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Author + date
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 16, color: AppColors.auGold),
                      const SizedBox(width: 6),
                      Text(_article.author, style: TextStyle(fontSize: 14, color: AppColors.auGold)),
                      const SizedBox(width: 20),
                      const Icon(Icons.schedule_rounded, size: 16, color: AppColors.auGold),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMMM d, yyyy').format(_article.publishDate),
                        style: TextStyle(fontSize: 14, color: AppColors.auGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Engagement stats bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildEngagementStat(
                          Icons.visibility_rounded,
                          '${_article.viewCount}',
                          l10n.translate('views'),
                          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        ),
                        _buildEngagementStat(
                          Icons.chat_bubble_outline_rounded,
                          '${_article.commentCount}',
                          l10n.translate('comments'),
                          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        ),
                        GestureDetector(
                          onTap: _toggleLike,
                          child: _buildEngagementStat(
                            _article.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            '${_article.likeCount}',
                            l10n.translate('like'),
                            _article.isLiked ? AppColors.burundiRed : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Article content
                  Text(
                    _article.getContent(langCode),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),

                  // Media gallery
                  if (_article.media.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Icon(Icons.photo_library_rounded, size: 20, color: AppColors.auGold),
                        const SizedBox(width: 8),
                        Text(
                          l10n.translate('gallery'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._article.media.map((m) {
                      if (m.isImage && m.imageUrl.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: m.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    height: 200,
                                    color: AppColors.auGold.withValues(alpha: 0.1),
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    height: 200,
                                    color: AppColors.auGold.withValues(alpha: 0.1),
                                    child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                  ),
                                ),
                              ),
                              if (m.getCaption(langCode).isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  m.getCaption(langCode),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      } else if (m.isVideo && m.videoUrl.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(m.videoUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.burundiRed.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.play_circle_filled_rounded, color: AppColors.burundiRed, size: 32),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.translate('watch_video'),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.darkText : AppColors.lightText,
                                          ),
                                        ),
                                        if (m.getCaption(langCode).isNotEmpty)
                                          Text(
                                            m.getCaption(langCode),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.open_in_new_rounded, size: 18,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],

                  const SizedBox(height: 32),

                  // Comments section header
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_rounded, size: 20, color: AppColors.auGold),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.translate('comments')} (${_comments.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Comment input or login prompt
                  if (auth.isAuthenticated)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: l10n.translate('add_comment'),
                              hintStyle: TextStyle(fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.auGold),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            style: TextStyle(fontSize: 14),
                            maxLines: null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _postingComment ? null : _postComment,
                          icon: _postingComment
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, color: AppColors.auGold),
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.auGold.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.auGold.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        l10n.translate('login_to_comment'),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.auGold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Comments list
                  if (_loadingComments)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          l10n.translate('no_comments_yet'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_comments.length, (index) {
                      return _buildCommentTile(_comments[index], auth, l10n, isDark);
                    }),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementStat(IconData icon, String count, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _buildCommentTile(ArticleComment comment, AuthProvider auth, AppLocalizations l10n, bool isDark) {
    final isOwn = auth.isAuthenticated && auth.userId == comment.userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.auGold.withValues(alpha: 0.15),
            backgroundImage: comment.profilePicture != null
                ? CachedNetworkImageProvider(comment.profilePicture!)
                : null,
            child: comment.profilePicture == null
                ? Text(
                    comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.auGold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt, l10n),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (isOwn)
                      GestureDetector(
                        onTap: () => _deleteComment(comment),
                        child: Icon(Icons.delete_outline_rounded, size: 18,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
