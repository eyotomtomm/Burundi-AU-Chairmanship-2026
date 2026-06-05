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

class VideoDetailScreen extends StatefulWidget {
  final Map<String, dynamic> video;

  const VideoDetailScreen({
    super.key,
    required this.video,
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
  bool _isLiked = false;
  int _likeCount = 0;
  List<Liker> _recentLikers = [];
  bool _isTogglingLike = false;
  bool _ytFullScreen = false;

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
  int? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video['is_liked'] == true;
    _likeCount = widget.video['like_count'] ?? 0;
    if (widget.video['recent_likers'] is List) {
      _recentLikers = (widget.video['recent_likers'] as List)
          .map((l) => Liker.fromJson(l as Map<String, dynamic>))
          .toList();
    }
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
    } catch (_) {}
    if (mounted) setState(() => _postingComment = false);
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await ApiService().deleteVideoComment(widget.video['id'].toString(), commentId);
      await _loadComments();
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_isTogglingLike) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_to_like'))),
      );
      return;
    }
    _isTogglingLike = true;
    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    setState(() {
      _isLiked = !wasLiked;
      _likeCount = prevCount + (wasLiked ? -1 : 1);
    });
    try {
      final result = await ApiService().toggleVideoLike(widget.video['id'].toString());
      if (mounted) {
        List<Liker> likers = [];
        if (result['recent_likers'] is List) {
          likers = (result['recent_likers'] as List)
              .map((l) => Liker.fromJson(l as Map<String, dynamic>))
              .toList();
        }
        setState(() {
          _isLiked = result['is_liked'] == true;
          _likeCount = result['like_count'] ?? _likeCount;
          _recentLikers = likers;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = wasLiked;
        _likeCount = prevCount;
      });
    } finally {
      _isTogglingLike = false;
    }
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

      _youtubeController!.addListener(_onYtFullScreenChange);

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

  void _onYtFullScreenChange() {
    final isFs = _youtubeController!.value.isFullScreen;
    if (isFs == _ytFullScreen) return;
    setState(() => _ytFullScreen = isFs);
    if (isFs) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    _youtubeController?.removeListener(_onYtFullScreenChange);
    _chewieController?.dispose();
    _videoController?.dispose();
    _youtubeController?.dispose();
    _commentController.dispose();
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

    return PopScope(
      canPop: !_ytFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _ytFullScreen) {
          _youtubeController?.toggleFullScreenMode();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: _ytFullScreen ? null : AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title ?? 'Video',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _ytFullScreen
          ? YoutubePlayer(
              controller: _youtubeController!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: AppColors.burundiGreen,
              progressColors: ProgressBarColors(
                playedColor: AppColors.burundiGreen,
                handleColor: AppColors.auGold,
              ),
            )
          : Column(
        children: [
          // Video player area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.auGold),
                  )
                : _hasError
                    ? _buildErrorWidget(_errorMessage)
                    : _isYouTube && _youtubeController != null
                        ? YoutubePlayer(
                            controller: _youtubeController!,
                            showVideoProgressIndicator: true,
                            progressIndicatorColor: AppColors.burundiGreen,
                            progressColors: ProgressBarColors(
                              playedColor: AppColors.burundiGreen,
                              handleColor: AppColors.auGold,
                            ),
                          )
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
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: _isLiked ? Colors.red : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_likeCount',
                                style: TextStyle(
                                  color: _isLiked ? Colors.red : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_recentLikers.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          LikedByAvatars(
                            likers: _recentLikers,
                            totalLikes: _likeCount,
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
                      ..._comments.map((c) => _buildCommentTile(c, isDark)),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment, bool isDark) {
    final isOwn = Provider.of<AuthProvider>(context, listen: false).userId?.toString() == comment['user_id']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: comment['profile_picture'] != null
                    ? NetworkImage(comment['profile_picture'])
                    : null,
                backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.1),
                child: comment['profile_picture'] == null
                    ? Text((comment['user_name'] ?? 'A')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.burundiGreen))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(comment['user_name'] ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (comment['badge_type'] != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified, size: 14, color: AppColors.burundiGreen),
                        ],
                        const Spacer(),
                        if (isOwn)
                          GestureDetector(
                            onTap: () => _deleteComment(comment['id']),
                            child: Icon(Icons.delete_outline, size: 16, color: Colors.grey[400]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(comment['content'] ?? '', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyingToId = comment['id'];
                        _replyingToName = comment['user_name'];
                      }),
                      child: Text('Reply', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Nested replies
          if (comment['replies'] != null && (comment['replies'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 8),
              child: Column(
                children: (comment['replies'] as List).map<Widget>((r) {
                  final reply = r as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: reply['profile_picture'] != null ? NetworkImage(reply['profile_picture']) : null,
                          backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.1),
                          child: reply['profile_picture'] == null
                              ? Text((reply['user_name'] ?? 'A')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.burundiGreen))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reply['user_name'] ?? 'User',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              Text(reply['content'] ?? '', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
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
