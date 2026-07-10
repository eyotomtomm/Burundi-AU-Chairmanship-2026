import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../models/api_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/liked_by_avatars.dart';
import '../../services/like_service.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/comment_ban_dialog.dart';
import '../../utils/input_sanitizer.dart';
import '../../widgets/fullscreen_back_button.dart';

class VideoPlayerScreen extends StatefulWidget {
  final ApiLiveFeed feed;
  final bool scrollToComments;

  const VideoPlayerScreen({super.key, required this.feed, this.scrollToComments = false});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String _errorMessage = '';

  // Likes
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  // Comments
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  bool _postingComment = false;
  final _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  int? _replyingToId;
  String? _replyingToName;

  // Scroll to comments
  final GlobalKey _commentsSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Allow all orientations so Chewie fullscreen can go landscape
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _likeService.seed(
      EntityType.livefeed, widget.feed.id,
      isLiked: widget.feed.isLiked,
      likeCount: widget.feed.likeCount,
      recentLikers: widget.feed.recentLikers
          .map((l) => Liker.fromJson(l))
          .toList(),
    );
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key == 'livefeed:${widget.feed.id}' && mounted) setState(() {});
    });
    _initPlayer();
    _recordView();
    _loadComments();
    if (widget.scrollToComments) {
      _scheduleScrollToComments();
    }
  }

  void _scheduleScrollToComments() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return _loadingComments && mounted;
    }).then((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _commentsSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic).then((_) {
            if (mounted) _commentFocusNode.requestFocus();
          });
        }
      });
    });
  }

  Future<void> _recordView() async {
    try {
      await ApiService().recordLiveFeedView(widget.feed.id);
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    try {
      final data = await ApiService().getLiveFeedComments(widget.feed.id);
      if (mounted) setState(() { _comments = data; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _postComment() async {
    final content = InputSanitizer.sanitizeComment(_commentController.text);
    if (content.isEmpty) return;
    setState(() => _postingComment = true);
    try {
      await ApiService().postLiveFeedComment(
        widget.feed.id,
        content,
        parentId: _replyingToId,
      );
      _commentController.clear();
      _replyingToId = null;
      _replyingToName = null;
      await _loadComments();
    } on ApiException catch (e) {
      if (mounted) showCommentErrorDialog(context, e.message, e.statusCode, referenceId: e.referenceId);
    } catch (_) {}
    if (mounted) setState(() => _postingComment = false);
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await ApiService().deleteLiveFeedComment(widget.feed.id, commentId);
      await _loadComments();
    } catch (_) {}
  }

  void _toggleLike() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_to_like'))),
      );
      return;
    }
    _likeService.toggle(EntityType.livefeed, widget.feed.id);
  }

  Future<void> _initPlayer() async {
    try {
      final fixedUrl = Environment.fixMediaUrl(widget.feed.streamUrl);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(fixedUrl));

      await _videoController.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: widget.feed.isLive,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        deviceOrientationsOnEnterFullScreen: DeviceOrientation.values,
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        routePageBuilder: (context, animation, secondAnimation, controllerProvider) {
          final langCode = Localizations.localeOf(context).languageCode;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) => Stack(
              children: [
                Scaffold(
                  resizeToAvoidBottomInset: false,
                  body: Container(
                    alignment: Alignment.center,
                    color: Colors.black,
                    child: controllerProvider,
                  ),
                ),
                FullscreenBackButton(
                  title: widget.feed.getTitle(langCode),
                  onBack: () {
                    // Pop the fullscreen route on the root navigator
                    // (Chewie pushes fullscreen with rootNavigator: true)
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
              ],
            ),
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.burundiGreen,
          handleColor: AppColors.auGold,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: AppColors.burundiGreen.withValues(alpha: 0.3),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.auGold),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.burundiRed, size: 48),
          const SizedBox(height: 16),
          Text(
            'Unable to play video',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() { _hasError = false; _errorMessage = ''; });
              _chewieController?.dispose();
              _videoController.dispose();
              _initPlayer();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.burundiGreen),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    _chewieController?.dispose();
    _videoController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final likeState = _likeService.getState(EntityType.livefeed, widget.feed.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.feed.getTitle(langCode),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (widget.feed.isLive)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.burundiRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Video player area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _hasError
                ? _buildErrorWidget(_errorMessage)
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const Center(
                        child: CircularProgressIndicator(color: AppColors.auGold),
                      ),
          ),

          // Feed info + likes + comments
          Expanded(
            child: Container(
              color: isDark ? AppColors.darkBackground : Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.feed.getTitle(langCode),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.feed.isLive && widget.feed.viewerCount > 0) ...[
                          Icon(Icons.visibility,
                              size: 16,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatViewerCount(widget.feed.viewerCount)} watching',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (widget.feed.parsedDuration != null) ...[
                          Icon(Icons.access_time,
                              size: 16,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.feed.duration,
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        // Like button
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleLike,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                            children: [
                              Icon(
                                likeState.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 22,
                                color: likeState.isLiked ? Colors.red : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${likeState.likeCount}',
                                style: TextStyle(
                                  color: likeState.isLiked ? Colors.red : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Like',
                                style: TextStyle(
                                  color: likeState.isLiked ? Colors.red : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                        if (likeState.recentLikers.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          LikedByAvatars(
                            likers: likeState.recentLikers,
                            totalLikes: likeState.likeCount,
                            avatarRadius: 10,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // Comments section
                    const SizedBox(height: 24),
                    const Divider(),
                    SizedBox(key: _commentsSectionKey, height: 0),
                    const SizedBox(height: 16),
                    Text(
                      'Comments (${_comments.fold<int>(0, (sum, c) => sum + 1 + ((c['replies'] as List?)?.length ?? 0))})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            decoration: InputDecoration(
                              hintText: _replyingToName != null
                                  ? 'Reply to $_replyingToName...'
                                  : 'Add a comment...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              suffixIcon: _replyingToId != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setState(() { _replyingToId = null; _replyingToName = null; }),
                                    )
                                  : null,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: _postingComment
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_rounded, color: AppColors.burundiGreen),
                          onPressed: _postingComment ? null : _postComment,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingComments)
                      const Center(child: CircularProgressIndicator())
                    else
                      ..._comments.map((comment) {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final feedId = widget.feed.id;
                        return CommentTile.fromMap(
                          comment,
                          key: ValueKey(comment['id']),
                          isAuthenticated: auth.isAuthenticated,
                          onReply: () => setState(() {
                            _replyingToId = comment['id'];
                            _replyingToName = comment['user_name'];
                          }),
                          onPostReply: (content, parentId) async {
                            await ApiService().postLiveFeedComment(feedId, content, parentId: parentId);
                            await _loadComments();
                          },
                          onDelete: () => _deleteComment(comment['id']),
                          onToggleLike: () => ApiService().toggleLiveFeedCommentLike(feedId, comment['id']),
                          onEdit: (content) => ApiService().editLiveFeedComment(feedId, comment['id'], content),
                          replyBuilder: (reply) => CommentTile.fromMap(
                            reply,
                            key: ValueKey(reply['id']),
                            isReply: true,
                            isAuthenticated: auth.isAuthenticated,
                            onDelete: () => _deleteComment(reply['id']),
                            onToggleLike: () => ApiService().toggleLiveFeedCommentLike(feedId, reply['id']),
                            onEdit: (content) => ApiService().editLiveFeedComment(feedId, reply['id'], content),
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    if (widget.feed.isLive) return AppColors.burundiRed;
    if (widget.feed.isUpcoming) return AppColors.auGold;
    return AppColors.burundiGreen;
  }

  String get _statusLabel {
    if (widget.feed.isLive) return 'LIVE NOW';
    if (widget.feed.isUpcoming) return 'UPCOMING';
    return 'RECORDED';
  }

  String _formatViewerCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
