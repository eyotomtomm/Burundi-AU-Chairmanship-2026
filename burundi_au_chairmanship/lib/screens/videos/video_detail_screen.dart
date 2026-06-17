import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/liked_by_avatars.dart';
import '../../services/like_service.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/comment_ban_dialog.dart';
import '../../widgets/fullscreen_back_button.dart';

class VideoDetailScreen extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool scrollToComments;

  const VideoDetailScreen({
    super.key,
    required this.video,
    this.scrollToComments = false,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubeController;
  bool _isYouTube = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isLoading = true;
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  // Chapters
  List<Map<String, dynamic>> _chapters = [];

  // Subtitles
  List<Map<String, dynamic>> _subtitles = [];
  bool _subtitlesEnabled = false;

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
    // Allow all orientations so YoutubePlayerBuilder can go landscape for fullscreen
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    final likers = widget.video['recent_likers'] is List
        ? (widget.video['recent_likers'] as List)
            .map((l) => Liker.fromJson(l as Map<String, dynamic>))
            .toList()
        : <Liker>[];
    _likeService.seed(
      EntityType.video, widget.video['id'],
      isLiked: widget.video['is_liked'] == true,
      likeCount: widget.video['like_count'] ?? 0,
      recentLikers: likers,
    );
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key == 'video:${widget.video['id']}' && mounted) setState(() {});
    });
    // Parse chapters and subtitles from video data
    if (widget.video['chapters'] != null) {
      _chapters = List<Map<String, dynamic>>.from(widget.video['chapters']);
    }
    if (widget.video['subtitles'] != null) {
      _subtitles = List<Map<String, dynamic>>.from(widget.video['subtitles']);
      // Auto-enable if there's a default subtitle
      _subtitlesEnabled = _subtitles.any((s) => s['is_default'] == true);
    }
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
      await ApiService().recordVideoView(widget.video['id'].toString());
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    try {
      final data = await ApiService().getVideoComments(widget.video['id'].toString());
      if (mounted) setState(() { _comments = data; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _postingComment = true);
    try {
      await ApiService().postVideoComment(
        widget.video['id'].toString(),
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
      await ApiService().deleteVideoComment(widget.video['id'].toString(), commentId);
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
    _likeService.toggle(EntityType.video, widget.video['id']);
  }

  Future<void> _initPlayer() async {
    final videoUrl = widget.video['video_url'] as String?;

    if (videoUrl == null || videoUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video URL provided';
        _isLoading = false;
      });
      return;
    }

    // Check if it's a YouTube URL
    final youtubeId = YoutubePlayer.convertUrlToId(videoUrl);

    if (youtubeId != null) {
      // It's a YouTube video
      _isYouTube = true;
      _initYouTubePlayer(youtubeId);
    } else {
      // It's a direct video URL (local or remote)
      _initDirectVideoPlayer(videoUrl);
    }
  }

  void _initYouTubePlayer(String videoId) {
    try {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
          controlsVisibleAtStart: true,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load YouTube video: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initDirectVideoPlayer(String videoUrl) async {
    try {
      // Fix URL if it's a media URL
      final fixedUrl = Environment.fixMediaUrl(videoUrl);

      // Determine if it's a network or local file
      final isNetwork = fixedUrl.startsWith('http://') || fixedUrl.startsWith('https://');

      if (isNetwork) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(fixedUrl));
      } else {
        // For local files, you might need to handle file:// URLs
        _videoController = VideoPlayerController.networkUrl(Uri.parse(fixedUrl));
      }

      await _videoController!.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        deviceOrientationsOnEnterFullScreen: DeviceOrientation.values,
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        routePageBuilder: (context, animation, secondAnimation, controllerProvider) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) => Scaffold(
              resizeToAvoidBottomInset: false,
              body: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    controllerProvider,
                    FullscreenBackButton(
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
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

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _seekToChapter(int timestampSeconds) {
    final duration = Duration(seconds: timestampSeconds);
    if (_videoController != null) {
      _videoController!.seekTo(duration);
      if (!_videoController!.value.isPlaying) {
        _videoController!.play();
      }
    } else if (_youtubeController != null) {
      _youtubeController!.seekTo(duration);
    }
  }

  String _formatTimestamp(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildChaptersList(bool isDark) {
    if (_chapters.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.list_rounded, size: 20, color: AppColors.auGold),
            const SizedBox(width: 8),
            Text(
              'Chapters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_chapters.length, (index) {
          final chapter = _chapters[index];
          final timestamp = chapter['timestamp_seconds'] as int? ?? 0;
          final title = chapter['title'] as String? ?? '';
          return InkWell(
            onTap: () => _seekToChapter(timestamp),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.auGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatTimestamp(timestamp),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.auGold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 20,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
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
              setState(() {
                _hasError = false;
                _errorMessage = '';
                _isLoading = true;
              });
              _chewieController?.dispose();
              _videoController?.dispose();
              _youtubeController?.dispose();
              _initPlayer();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    _chewieController?.dispose();
    _videoController?.dispose();
    _youtubeController?.dispose();
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

    final title = langCode == 'fr'
        ? (widget.video['title_fr'] ?? widget.video['title'])
        : widget.video['title'];
    final description = langCode == 'fr'
        ? (widget.video['description_fr'] ?? widget.video['description'])
        : widget.video['description'];

    // YouTube: use YoutubePlayerBuilder which handles fullscreen natively
    if (_isYouTube && _youtubeController != null && !_isLoading && !_hasError) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.burundiGreen,
          progressColors: ProgressBarColors(
            playedColor: AppColors.burundiGreen,
            handleColor: AppColors.auGold,
          ),
        ),
        builder: (context, player) {
          // In landscape (fullscreen), show only the player with a close button
          final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
          if (isLandscape) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  Center(child: player),
                  FullscreenBackButton(
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          }
          return _buildScaffold(title, description, isDark, theme, playerWidget: player);
        },
      );
    }

    // Non-YouTube / loading / error
    return _buildScaffold(title, description, isDark, theme);
  }

  Widget _buildScaffold(String? title, String? description, bool isDark, ThemeData theme, {Widget? playerWidget}) {
    final likeState = _likeService.getState(EntityType.video, widget.video['id']);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title ?? 'Video',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // Video player area
          if (playerWidget != null)
            playerWidget
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.auGold),
                    )
                  : _hasError
                      ? _buildErrorWidget(_errorMessage)
                      : _chewieController != null
                          ? Chewie(controller: _chewieController!)
                          : const Center(
                              child: CircularProgressIndicator(color: AppColors.auGold),
                            ),
            ),

          // Video info
          Expanded(
            child: Container(
              color: isDark ? AppColors.darkBackground : Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title ?? '',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stats row
                    Row(
                      children: [
                        Icon(Icons.visibility,
                            size: 16,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatViewCount(widget.video['view_count'])} views',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: _toggleLike,
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
                        if (likeState.recentLikers.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          LikedByAvatars(
                            likers: likeState.recentLikers,
                            totalLikes: likeState.likeCount,
                            avatarRadius: 10,
                          ),
                        ],
                        const SizedBox(width: 16),
                        if (widget.video['duration'] != null) ...[
                          Icon(Icons.access_time,
                              size: 16,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.video['duration'],
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        // Subtitle toggle button
                        if (_subtitles.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _subtitlesEnabled = !_subtitlesEnabled;
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  _subtitlesEnabled
                                      ? Icons.closed_caption_rounded
                                      : Icons.closed_caption_off_rounded,
                                  size: 20,
                                  color: _subtitlesEnabled
                                      ? AppColors.auGold
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _subtitlesEnabled ? 'CC ON' : 'CC OFF',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _subtitlesEnabled
                                        ? AppColors.auGold
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Description
                    if (description != null && description.isNotEmpty) ...[
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ],

                    // Chapters list
                    _buildChaptersList(isDark),

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
                    // Comment input
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
                        final videoId = widget.video['id'].toString();
                        return CommentTile.fromMap(
                          comment,
                          key: ValueKey(comment['id']),
                          isAuthenticated: auth.isAuthenticated,
                          onReply: () => setState(() {
                            _replyingToId = comment['id'];
                            _replyingToName = comment['user_name'];
                          }),
                          onPostReply: (content, parentId) async {
                            await ApiService().postVideoComment(videoId, content, parentId: parentId);
                            await _loadComments();
                          },
                          onDelete: () => _deleteComment(comment['id']),
                          onToggleLike: () => ApiService().toggleVideoCommentLike(videoId, comment['id']),
                          onEdit: (content) => ApiService().editVideoComment(videoId, comment['id'], content),
                          replyBuilder: (reply) => CommentTile.fromMap(
                            reply,
                            key: ValueKey(reply['id']),
                            isReply: true,
                            isAuthenticated: auth.isAuthenticated,
                            onDelete: () => _deleteComment(reply['id']),
                            onToggleLike: () => ApiService().toggleVideoCommentLike(videoId, reply['id']),
                            onEdit: (content) => ApiService().editVideoComment(videoId, reply['id'], content),
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

  String _formatViewCount(dynamic count) {
    if (count == null) return '0';
    final n = count is int ? count : int.tryParse(count.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
