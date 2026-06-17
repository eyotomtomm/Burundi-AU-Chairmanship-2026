import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/app_colors.dart';
import '../../models/api_models.dart';
import '../../widgets/fullscreen_back_button.dart';

class InAppWebViewScreen extends StatefulWidget {
  final ApiLiveFeed feed;

  const InAppWebViewScreen({super.key, required this.feed});

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;
  String _errorMessage = '';

  /// The allowed host for this WebView session, derived from the initial URL.
  late final String _allowedHost;

  /// Known safe streaming/embedding domains that navigations may redirect to.
  static const _trustedDomains = {
    'youtube.com', 'www.youtube.com', 'youtu.be',
    'player.vimeo.com', 'vimeo.com',
    'zoom.us', 'us02web.zoom.us', 'us04web.zoom.us', 'us05web.zoom.us', 'us06web.zoom.us',
    'teams.microsoft.com', 'teams.live.com',
    'meet.google.com',
    'webex.com', 'meetingsamer.webex.com',
    'facebook.com', 'www.facebook.com', 'web.facebook.com',
    'livestream.com', 'twitch.tv', 'www.twitch.tv',
    'dailymotion.com', 'www.dailymotion.com',
  };

  bool _isAllowedUrl(Uri uri) {
    // Only allow https (and the initial load which is already validated)
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;

    final host = uri.host.toLowerCase();

    // Allow the original stream host
    if (host == _allowedHost || host.endsWith('.$_allowedHost')) return true;

    // Allow known streaming/meeting platform domains
    for (final domain in _trustedDomains) {
      if (host == domain || host.endsWith('.$domain')) return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    // Allow landscape so embedded videos can go fullscreen
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    // Derive the allowed host from the initial stream URL
    final initialUri = Uri.tryParse(widget.feed.streamUrl);
    _allowedHost = initialUri?.host.toLowerCase() ?? '';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || !_isAllowedUrl(uri)) {
              // Block navigation to untrusted domains — offer to open externally
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Blocked navigation to external site'),
                    action: SnackBarAction(
                      label: 'Open',
                      onPressed: () async {
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    backgroundColor: AppColors.burundiRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loadingProgress = 100);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.feed.streamUrl));
  }

  IconData _getPlatformIcon(String streamType) {
    switch (streamType) {
      case 'zoom':
        return Icons.videocam;
      case 'teams':
        return Icons.groups;
      case 'webex':
        return Icons.video_call;
      case 'meet':
        return Icons.video_camera_front;
      case 'youtube':
        return Icons.play_arrow;
      default:
        return Icons.language;
    }
  }

  Color _getPlatformColor(String streamType) {
    switch (streamType) {
      case 'zoom':
        return const Color(0xFF2D8CFF);
      case 'teams':
        return const Color(0xFF6264A7);
      case 'webex':
        return const Color(0xFF00BCF2);
      case 'meet':
        return const Color(0xFF00897B);
      case 'youtube':
        return const Color(0xFFFF0000);
      default:
        return AppColors.burundiGreen;
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.feed.streamUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${widget.feed.platformName}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _loadingProgress = 0;
    });
    _controller.loadRequest(Uri.parse(widget.feed.streamUrl));
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platformColor = _getPlatformColor(widget.feed.streamType);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // In landscape, show fullscreen WebView with a back button overlay
    if (isLandscape) {
      return Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.black,
            body: WebViewWidget(controller: _controller),
          ),
          FullscreenBackButton(
            title: widget.feed.getTitle(langCode),
            onBack: () {
              // Just rotate back to portrait instead of popping the screen
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]);
              Future.delayed(const Duration(milliseconds: 500), () {
                SystemChrome.setPreferredOrientations(DeviceOrientation.values);
              });
            },
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _getPlatformIcon(widget.feed.streamType),
              color: platformColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.feed.getTitle(langCode),
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open externally',
            onPressed: _openExternally,
          ),
        ],
      ),
      body: _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 56,
                      color: AppColors.burundiRed.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load page',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.burundiGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _openExternally,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open Externally'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loadingProgress < 100)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: _loadingProgress / 100,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(platformColor),
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
    );
  }
}
