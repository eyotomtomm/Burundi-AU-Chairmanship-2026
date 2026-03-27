import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../config/app_colors.dart';
import '../../models/api_models.dart';
import 'in_app_webview_screen.dart';

class YouTubePlayerScreen extends StatefulWidget {
  final ApiLiveFeed feed;

  const YouTubePlayerScreen({super.key, required this.feed});

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  YoutubePlayerController? _controller;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final videoId = YoutubePlayer.convertUrlToId(widget.feed.streamUrl);

    if (videoId == null) {
      // Fallback to WebView if we can't extract a YouTube ID
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => InAppWebViewScreen(feed: widget.feed),
            ),
          );
        }
      });
      return;
    }

    try {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          isLive: widget.feed.isLive,
          enableCaption: true,
          controlsVisibleAtStart: true,
        ),
      );
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load YouTube video: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          // YouTube player area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _hasError
                ? _buildErrorWidget()
                : _controller != null
                    ? YoutubePlayer(
                        controller: _controller!,
                        showVideoProgressIndicator: true,
                        progressIndicatorColor: AppColors.burundiGreen,
                        progressColors: ProgressBarColors(
                          playedColor: AppColors.burundiGreen,
                          handleColor: AppColors.auGold,
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.auGold),
                      ),
          ),

          // Feed info
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
                        if (widget.feed.isLive &&
                            widget.feed.viewerCount > 0) ...[
                          Icon(Icons.visibility,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatViewerCount(widget.feed.viewerCount)} watching',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (widget.feed.parsedDuration != null) ...[
                          Icon(Icons.access_time,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.feed.duration,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                    if (widget.feed.getDescription(langCode).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.feed.getDescription(langCode),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.burundiRed, size: 48),
          const SizedBox(height: 16),
          Text(
            'Unable to play video',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
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
              });
              _controller?.dispose();
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
