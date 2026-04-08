import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/translate_button.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  List<Map<String, dynamic>> _podcasts = [];
  bool _loading = true;
  String? _error;

  // Currently playing podcast
  int? _playingIndex;
  VideoPlayerController? _audioController;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadPodcasts();
  }

  @override
  void dispose() {
    _audioController?.dispose();
    super.dispose();
  }

  Future<void> _loadPodcasts() async {
    try {
      final podcasts = await ApiService().getPodcasts();
      if (mounted) {
        setState(() {
          _podcasts = podcasts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _playPodcast(int index) async {
    final podcast = _podcasts[index];
    final audioUrl = podcast['audio_file'] as String? ?? '';

    if (audioUrl.isEmpty) return;

    // If tapping the same podcast, toggle play/pause
    if (_playingIndex == index && _audioController != null) {
      if (_isPlaying) {
        await _audioController!.pause();
      } else {
        await _audioController!.play();
      }
      setState(() => _isPlaying = !_isPlaying);
      return;
    }

    // Dispose previous controller
    _audioController?.dispose();
    setState(() {
      _playingIndex = index;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    try {
      final fixedUrl = Environment.fixMediaUrl(audioUrl);
      _audioController = VideoPlayerController.networkUrl(Uri.parse(fixedUrl));
      await _audioController!.initialize();

      _audioController!.addListener(() {
        if (!mounted) return;
        final pos = _audioController!.value.position;
        final dur = _audioController!.value.duration;
        final playing = _audioController!.value.isPlaying;

        if (pos != _position || dur != _duration || playing != _isPlaying) {
          setState(() {
            _position = pos;
            _duration = dur;
            _isPlaying = playing;
          });
        }

        // Auto-stop at end
        if (_audioController!.value.position >= _audioController!.value.duration &&
            _audioController!.value.duration > Duration.zero) {
          setState(() {
            _isPlaying = false;
          });
        }
      });

      await _audioController!.play();
      setState(() => _isPlaying = true);
    } catch (e) {
      // Fallback: open audio externally
      if (mounted) {
        final uri = Uri.parse(Environment.fixMediaUrl(audioUrl));
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  void _seekTo(double value) {
    if (_audioController != null && _duration > Duration.zero) {
      _audioController!.seekTo(Duration(
        milliseconds: (value * _duration.inMilliseconds).round(),
      ));
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDurationFromSeconds(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<LanguageProvider>().languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          langCode == 'fr' ? 'Podcasts' : 'Podcasts',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [TranslateButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48,
                          color: isDark ? Colors.white38 : Colors.black38),
                      const SizedBox(height: 12),
                      Text(
                        l10n.translate('error_loading'),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadPodcasts();
                        },
                        child: Text(l10n.translate('retry')),
                      ),
                    ],
                  ),
                )
              : _podcasts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.podcasts, size: 64,
                              color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 16),
                          Text(
                            langCode == 'fr'
                                ? 'Aucun podcast disponible'
                                : 'No podcasts available',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Podcast list
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _podcasts.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _buildPodcastTile(index, langCode, isDark),
                          ),
                        ),

                        // Player bar at bottom
                        if (_playingIndex != null) _buildPlayerBar(isDark, langCode),
                      ],
                    ),
    );
  }

  Widget _buildPodcastTile(int index, String langCode, bool isDark) {
    final podcast = _podcasts[index];
    final title = langCode == 'fr'
        ? (podcast['title_fr']?.toString().isNotEmpty == true
            ? podcast['title_fr']
            : podcast['title'])
        : podcast['title'];
    final description = langCode == 'fr'
        ? (podcast['description_fr']?.toString().isNotEmpty == true
            ? podcast['description_fr']
            : podcast['description'])
        : podcast['description'];
    final coverImage = podcast['cover_image'] as String?;
    final episodeNumber = podcast['episode_number'] ?? 1;
    final durationSeconds = podcast['duration_seconds'] ?? 0;
    final isCurrentlyPlaying = _playingIndex == index;

    return GestureDetector(
      onTap: () => _playPodcast(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentlyPlaying
              ? AppColors.burundiGreen.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentlyPlaying
                ? AppColors.burundiGreen.withValues(alpha: 0.3)
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
        ),
        child: Row(
          children: [
            // Cover art
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverImage != null && coverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: Environment.fixMediaUrl(coverImage),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _coverPlaceholder(),
                      errorWidget: (_, _, _) => _coverPlaceholder(),
                    )
                  : _coverPlaceholder(),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EP. $episodeNumber',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.burundiGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description != null && description.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (durationSeconds > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDurationFromSeconds(durationSeconds),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Play/pause button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCurrentlyPlaying && _isPlaying
                    ? AppColors.burundiGreen
                    : AppColors.burundiGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCurrentlyPlaying && _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: isCurrentlyPlaying && _isPlaying
                    ? Colors.white
                    : AppColors.burundiGreen,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.burundiGreen.withValues(alpha: 0.2),
            AppColors.auGold.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.podcasts, color: AppColors.burundiGreen, size: 28),
    );
  }

  Widget _buildPlayerBar(bool isDark, String langCode) {
    final podcast = _podcasts[_playingIndex!];
    final title = langCode == 'fr'
        ? (podcast['title_fr']?.toString().isNotEmpty == true
            ? podcast['title_fr']
            : podcast['title'])
        : podcast['title'];
    final progress = _duration > Duration.zero
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seek bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: AppColors.burundiGreen,
                inactiveTrackColor: AppColors.burundiGreen.withValues(alpha: 0.2),
                thumbColor: AppColors.burundiGreen,
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: _seekTo,
              ),
            ),
            // Time labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Title + controls
            Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Rewind 15s
                IconButton(
                  icon: const Icon(Icons.replay_10, size: 24),
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  onPressed: () {
                    if (_audioController != null) {
                      final newPos = _position - const Duration(seconds: 10);
                      _audioController!.seekTo(
                        newPos < Duration.zero ? Duration.zero : newPos,
                      );
                    }
                  },
                ),
                // Play/Pause
                GestureDetector(
                  onTap: () => _playPodcast(_playingIndex!),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.burundiGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                // Forward 30s
                IconButton(
                  icon: const Icon(Icons.forward_30, size: 24),
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  onPressed: () {
                    if (_audioController != null) {
                      final newPos = _position + const Duration(seconds: 30);
                      _audioController!.seekTo(
                        newPos > _duration ? _duration : newPos,
                      );
                    }
                  },
                ),
                // Stop
                IconButton(
                  icon: const Icon(Icons.stop_rounded, size: 24),
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  onPressed: () {
                    _audioController?.pause();
                    _audioController?.seekTo(Duration.zero);
                    setState(() {
                      _isPlaying = false;
                      _playingIndex = null;
                    });
                    _audioController?.dispose();
                    _audioController = null;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
