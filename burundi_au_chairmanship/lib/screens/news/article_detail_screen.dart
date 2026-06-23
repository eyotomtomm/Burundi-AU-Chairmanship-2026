import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../widgets/image_gallery_viewer.dart';
import '../../services/haptic_service.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/translate_button.dart';
import '../../widgets/liked_by_avatars.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/comment_ban_dialog.dart';
import '../../services/like_service.dart';
import '../../utils/input_sanitizer.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final bool scrollToComments;

  const ArticleDetailScreen({super.key, required this.article, this.scrollToComments = false});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Article _article;
  List<ArticleComment> _comments = [];
  bool _loadingComments = true;
  final _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _postingComment = false;
  int? _replyingToId;
  String? _replyingToName;

  // Reading progress tracking
  final ScrollController _scrollController = ScrollController();
  Timer? _readingProgressTimer;
  int _savedScrollPosition = 0;
  int _savedProgressPercent = 0;
  bool _showContinueReading = false;
  bool _restoredPosition = false;
  double _readingProgress = 0.0;
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  // Cached provider reference — safe to use in dispose() where context is invalid
  late final AuthProvider _authProvider;

  // Related articles
  List<Article> _relatedArticles = [];
  bool _loadingRelated = true;

  // Scroll to comments
  final GlobalKey _commentsSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _likeService.seed(
      EntityType.article, _article.id,
      isLiked: _article.isLiked,
      likeCount: _article.likeCount,
      recentLikers: _article.recentLikers,
    );
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key == 'article:${_article.id}' && mounted) {
        setState(() {
          _article = _article.copyWith(
            isLiked: state.isLiked,
            likeCount: state.likeCount,
            recentLikers: state.recentLikers,
          );
        });
      }
    });
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _recordView();
    _loadComments();
    _loadRelatedArticles();
    _loadReadingProgress();
    _scrollController.addListener(_onScroll);
    if (widget.scrollToComments) {
      _scheduleScrollToComments();
    }
  }

  void _scheduleScrollToComments() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return _loadingComments && mounted;
    }).then((_) {
      if (!mounted || _showContinueReading) return;
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

  @override
  void dispose() {
    _readingProgressTimer?.cancel();
    _saveReadingProgressNow();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _removeLikeListener?.call();
    super.dispose();
  }

  // ── Reading Progress ─────────────────────────────────────

  void _onScroll() {
    // Update visual reading progress bar
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
        if ((progress - _readingProgress).abs() > 0.005) {
          setState(() => _readingProgress = progress);
        }
      }
    }

    // Debounced save: every 5 seconds while scrolling
    _readingProgressTimer?.cancel();
    _readingProgressTimer = Timer(const Duration(seconds: 5), () {
      _saveReadingProgressNow();
    });
  }

  Future<void> _loadReadingProgress() async {
    if (!_authProvider.isAuthenticated) return;
    try {
      final data = await ApiService().getArticleReadingProgress(_article.id);
      final scrollPos = data['scroll_position'] as int? ?? 0;
      final progressPct = data['progress_percent'] as int? ?? 0;
      if (mounted && scrollPos > 0 && progressPct < 90) {
        setState(() {
          _savedScrollPosition = scrollPos;
          _savedProgressPercent = progressPct;
          _showContinueReading = true;
        });
      }
    } catch (_) {
      // Silently fail - reading progress is non-critical
    }
  }

  void _scrollToSavedPosition() {
    if (_savedScrollPosition > 0 && _scrollController.hasClients) {
      _scrollController.animateTo(
        _savedScrollPosition.toDouble(),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      setState(() {
        _showContinueReading = false;
        _restoredPosition = true;
      });
    }
  }

  Future<void> _saveReadingProgressNow() async {
    if (!_authProvider.isAuthenticated || !_scrollController.hasClients) return;

    final scrollPos = _scrollController.offset.toInt();
    final maxScroll = _scrollController.position.maxScrollExtent;
    final progressPct = maxScroll > 0 ? ((scrollPos / maxScroll) * 100).toInt() : 0;

    try {
      await ApiService().saveArticleReadingProgress(
        _article.id,
        scrollPos,
        progressPct.clamp(0, 100),
      );
    } catch (_) {
      // Silently fail
    }
  }

  // ── Related Articles ─────────────────────────────────────

  Future<void> _loadRelatedArticles() async {
    try {
      final articles = await ApiService().getRelatedArticles(_article.id);
      if (mounted) {
        setState(() {
          _relatedArticles = articles;
          _loadingRelated = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRelated = false);
    }
  }

  // ── Existing methods ─────────────────────────────────────

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

  int _totalCommentCount(List<ArticleComment> list) {
    int n = 0;
    for (final c in list) {
      n += 1 + c.replyCount;
    }
    return n;
  }

  Future<void> _loadComments() async {
    try {
      final comments = await ApiService().getArticleComments(_article.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _loadingComments = false;
          _article = _article.copyWith(commentCount: _totalCommentCount(comments));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _startReply(ArticleComment comment) {
    setState(() {
      _replyingToId = comment.id;
      _replyingToName = comment.username.isNotEmpty ? comment.username : comment.userName;
    });
    // Prefill @mention so the target user actually gets notified.
    if (comment.username.isNotEmpty) {
      final prefix = '@${comment.username} ';
      _commentController.text = prefix;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: prefix.length),
      );
    }
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
    _commentController.clear();
  }

  Future<void> _postComment() async {
    final text = InputSanitizer.sanitizeComment(_commentController.text);
    if (text.isEmpty) return;

    final validationError = InputSanitizer.validateComment(text);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _postingComment = true);
    try {
      final comment = await ApiService().postArticleComment(
        _article.id,
        text,
        parentId: _replyingToId,
      );
      if (!mounted) return;
      // Reload to get the fresh nested tree from the server (handles
      // reply attribution + @mention expansion correctly).
      _commentController.clear();
      _replyingToId = null;
      _replyingToName = null;
      setState(() => _postingComment = false);
      // Optimistic update for top-level, full reload otherwise.
      if (comment.parentId == null) {
        setState(() {
          _comments.insert(0, comment);
          _article = _article.copyWith(commentCount: _totalCommentCount(_comments));
        });
      } else {
        await _loadComments();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _postingComment = false);
        showCommentErrorDialog(context, e.message, e.statusCode, referenceId: e.referenceId);
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

  void _toggleLike() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('login_to_like')),
          action: SnackBarAction(
            label: l10n.translate('sign_in'),
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/auth'),
          ),
        ),
      );
      return;
    }
    _likeService.toggle(EntityType.article, _article.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      // Continue Reading floating indicator
      floatingActionButton: (_showContinueReading && !_restoredPosition)
          ? FloatingActionButton.extended(
              onPressed: _scrollToSavedPosition,
              backgroundColor: AppColors.burundiGreen,
              icon: const Icon(Icons.bookmark_rounded, color: Colors.white),
              label: Text(
                langCode == 'fr'
                    ? 'Continuer ($_savedProgressPercent%)'
                    : 'Continue ($_savedProgressPercent%)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Hero image SliverAppBar
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            actions: [
              // Listen button - copies article text for device TTS
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 20),
                ),
                tooltip: langCode == 'fr' ? 'Ecouter' : 'Listen',
                onPressed: () {
                  final articleText = _article.getContent(langCode);
                  Clipboard.setData(ClipboardData(text: articleText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              langCode == 'fr'
                                  ? 'Texte copie - utilisez la fonctionnalite de synthese vocale de votre appareil'
                                  : 'Text copied - use your device\'s text-to-speech feature to listen',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 4),
                      backgroundColor: AppColors.burundiGreen,
                    ),
                  );
                },
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  HapticService.light();
                  final shareUrl = '${Environment.siteBaseUrl}/articles/${_article.id}/share/';
                  Share.share(
                    '${_article.getTitle(Provider.of<LanguageProvider>(context, listen: false).languageCode)}\n\n$shareUrl',
                  );
                },
              ),
              const TranslateButton(),
            ],
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
              background: GestureDetector(
                onTap: () {
                  HapticService.light();
                  // Collect all images: hero image + media images
                  final allImages = <String>[Environment.fixMediaUrl(_article.imageUrl)];
                  final allCaptions = <String>[_article.getTitle(langCode)];
                  for (final m in _article.media) {
                    if (m.isImage && m.imageUrl.isNotEmpty) {
                      allImages.add(Environment.fixMediaUrl(m.imageUrl));
                      allCaptions.add(m.getCaption(langCode));
                    }
                  }
                  ImageGalleryViewer.show(
                    context,
                    images: allImages,
                    initialIndex: 0,
                    captions: allCaptions,
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: Environment.fixMediaUrl(_article.imageUrl),
                      memCacheWidth: 800,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.auGold.withValues(alpha: 0.2)),
                      errorWidget: (_, _, _) => Container(
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
          ),

          // Reading progress bar
          SliverToBoxAdapter(
            child: Container(
              height: 3,
              color: isDark ? AppColors.darkSurface : Colors.grey.shade200,
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 3,
                width: MediaQuery.of(context).size.width * _readingProgress,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.burundiGreen, AppColors.auGold],
                  ),
                ),
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
                      Flexible(
                        child: Text(
                          _article.author,
                          style: TextStyle(fontSize: 14, color: AppColors.auGold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                  // Liked-by avatars
                  if (_article.recentLikers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 4),
                      child: Row(
                        children: [
                          LikedByAvatars(
                            likers: _article.recentLikers,
                            totalLikes: _article.likeCount,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _article.likeCount == 1 ? '1 like' : '${_article.likeCount} likes',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                              GestureDetector(
                                onTap: () {
                                  HapticService.light();
                                  final imageMedia = _article.media
                                      .where((media) => media.isImage && media.imageUrl.isNotEmpty)
                                      .toList();
                                  final imageUrls = imageMedia
                                      .map((media) => media.imageUrl)
                                      .toList();
                                  final captions = imageMedia
                                      .map((media) => media.getCaption(langCode))
                                      .toList();
                                  final index = imageUrls.indexOf(m.imageUrl);
                                  ImageGalleryViewer.show(
                                    context,
                                    images: imageUrls,
                                    initialIndex: index >= 0 ? index : 0,
                                    captions: captions,
                                    heroTagPrefix: 'article_media_${_article.id}',
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: Environment.fixMediaUrl(m.imageUrl),
                                    memCacheWidth: 800,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(
                                      height: 200,
                                      color: AppColors.auGold.withValues(alpha: 0.1),
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      height: 200,
                                      color: AppColors.auGold.withValues(alpha: 0.1),
                                      child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                    ),
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

                  // Related Articles section
                  if (!_loadingRelated && _relatedArticles.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Icon(Icons.recommend_rounded, size: 20, color: AppColors.auGold),
                        const SizedBox(width: 8),
                        Text(
                          langCode == 'fr' ? 'Articles similaires' : 'Related Articles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _relatedArticles.length,
                        itemBuilder: (context, index) {
                          final related = _relatedArticles[index];
                          return _buildRelatedArticleCard(related, langCode, isDark);
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Comments section header
                  SizedBox(key: _commentsSectionKey, height: 0),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_replyingToName != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.auGold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.auGold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.reply_rounded,
                                    size: 16, color: AppColors.auGold),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Replying to @$_replyingToName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.auGold,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _cancelReply,
                                  child: const Icon(Icons.close_rounded,
                                      size: 16, color: AppColors.auGold),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                maxLength: InputSanitizer.maxCommentLength,
                                decoration: InputDecoration(
                                  hintText: _replyingToName != null
                                      ? 'Write a reply…'
                                      : l10n.translate('add_comment'),
                                  hintStyle: TextStyle(fontSize: 14),
                                  counterText: '',
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
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/auth'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.auGold.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.auGold.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.login_rounded, size: 16, color: AppColors.auGold),
                            const SizedBox(width: 8),
                            Text(
                              l10n.translate('login_to_comment'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.auGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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
                      final c = _comments[index];
                      return CommentTile.fromMap(
                        c.toMap(),
                        key: ValueKey(c.id),
                        isReply: false,
                        isAuthenticated: auth.isAuthenticated,
                        onReply: () => _startReply(c),
                        onPostReply: (content, parentId) async {
                          try {
                            await ApiService().postArticleComment(
                              widget.article.id, content, parentId: parentId);
                            await _loadComments();
                          } on ApiException catch (e) {
                            if (mounted) showCommentErrorDialog(context, e.message, e.statusCode, referenceId: e.referenceId);
                          }
                        },
                        onDelete: () => _deleteComment(c),
                        onToggleLike: () => ApiService().toggleArticleCommentLike(
                          widget.article.id, c.id),
                        onEdit: (content) => ApiService().editArticleComment(
                          widget.article.id, c.id, content),
                        replyBuilder: (reply) {
                          final rc = ArticleComment.fromJson(reply);
                          return CommentTile.fromMap(
                            reply,
                            key: ValueKey(rc.id),
                            isReply: true,
                            isAuthenticated: auth.isAuthenticated,
                            onDelete: () => _deleteComment(rc),
                            onToggleLike: () => ApiService().toggleArticleCommentLike(
                              widget.article.id, rc.id),
                            onEdit: (content) => ApiService().editArticleComment(
                              widget.article.id, rc.id, content),
                          );
                        },
                      );
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

  Widget _buildRelatedArticleCard(Article article, String langCode, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ArticleDetailScreen(article: article, scrollToComments: false),
          ),
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: Environment.fixMediaUrl(article.imageUrl),
                memCacheWidth: 400,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  height: 110,
                  color: AppColors.auGold.withValues(alpha: 0.1),
                ),
                errorWidget: (_, _, _) => Container(
                  height: 110,
                  color: AppColors.auGold.withValues(alpha: 0.1),
                  child: const Icon(Icons.article_rounded, color: Colors.grey),
                ),
              ),
            ),
            // Title and metadata
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.getTitle(langCode),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.visibility_rounded, size: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${article.viewCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d').format(article.publishDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

}
