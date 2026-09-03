import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../config/app_ds.dart';
import '../../config/environment.dart';

/// Minimal in-app player for a feature card's media video.
///
/// Deliberately NOT [VideoDetailScreen]: that screen is bound to a Video
/// record and records views, fetches comments and toggles likes against its
/// id. A FeatureCardMedia row has its own id space, so reusing it would write
/// engagement against whatever Video happened to share the same number.
class MediaVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String caption;

  const MediaVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.caption = '',
  });

  /// The YouTube id for [url], or null when it isn't a YouTube link.
  static String? youtubeId(String url) => YoutubePlayer.convertUrlToId(url);

  /// Poster frame for a YouTube video, free from the URL. Null for anything
  /// else — uploaded files carry no thumbnail.
  static String? posterFor(String url) {
    final id = youtubeId(url);
    return id == null ? null : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  @override
  State<MediaVideoPlayerScreen> createState() => _MediaVideoPlayerScreenState();
}

class _MediaVideoPlayerScreenState extends State<MediaVideoPlayerScreen> {
  YoutubePlayerController? _youtube;
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = MediaVideoPlayerScreen.youtubeId(widget.videoUrl);
    if (id != null) {
      _youtube = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(autoPlay: true),
      );
      if (mounted) setState(() {});
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
          Uri.parse(Environment.fixMediaUrl(widget.videoUrl)));
      _video = controller;
      await controller.initialize();
      if (!mounted) return;
      _chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        materialProgressColors: ChewieProgressColors(playedColor: Ds.green),
      );
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _youtube?.dispose();
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      body: Center(child: _buildPlayer()),
    );
  }

  Widget _buildPlayer() {
    if (_failed) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This video could not be played.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (_youtube != null) {
      return YoutubePlayer(
        controller: _youtube!,
        showVideoProgressIndicator: true,
        progressColors: const ProgressBarColors(playedColor: Ds.green),
      );
    }
    if (_chewie != null) {
      return AspectRatio(
        aspectRatio: _video!.value.aspectRatio,
        child: Chewie(controller: _chewie!),
      );
    }
    return const CircularProgressIndicator(color: Ds.green);
  }
}
