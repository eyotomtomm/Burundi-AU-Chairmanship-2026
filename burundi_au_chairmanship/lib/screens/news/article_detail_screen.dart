import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../config/environment.dart';
import '../../widgets/image_gallery_viewer.dart';
import '../../services/haptic_service.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/translate_button.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/comment_ban_dialog.dart';
import '../../services/like_service.dart';
import '../../utils/input_sanitizer.dart';
import '../../services/share_service.dart';
import '../../widgets/app_network_image.dart';

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
  final ValueNotifier<double> _readingProgress = ValueNotifier(0.0);
  bool? _isBookmarked; // null = unknown / not logged in
  bool _bookmarkBusy = false;
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
    _loadBookmarkState();
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
    _readingProgress.dispose();
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
        if ((progress - _readingProgress.value).abs() > 0.005) {
          _readingProgress.value = progress;
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
          SnackBar(content: Text(AppLocalizations.of(context).translate('generic_error'))),
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
          SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).translate('generic_error'))),
        );
      }
    }
  }

  // ── Bookmark ─────────────────────────────────────────────

  Future<void> _loadBookmarkState() async {
    if (!_authProvider.isAuthenticated) return;
    try {
      final res = await ApiService().checkBookmark('article', int.parse(_article.id));
      if (mounted) setState(() => _isBookmarked = res['is_bookmarked'] == true);
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    if (!_authProvider.isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return;
    }
    if (_bookmarkBusy) return;
    final was = _isBookmarked ?? false;
    setState(() { _isBookmarked = !was; _bookmarkBusy = true; }); // optimistic
    HapticService.light();
    try {
      final id = int.parse(_article.id);
      if (was) {
        // check/ endpoint has no bookmark id; find it in the user's list.
        final list = await ApiService().get('bookmarks/?content_type=article', auth: true);
        final items = list is Map ? (list['results'] as List? ?? const []) : (list as List);
        final match = items.cast<Map>().where((b) => b['content_id'] == id).toList();
        if (match.isNotEmpty) await ApiService().removeBookmark(match.first['id'] as int);
      } else {
        await ApiService().addBookmark('article', id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBookmarked = was);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).translate('generic_error'))),
      );
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
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
    final isAuthenticated = context.select<AuthProvider, bool>((a) => a.isAuthenticated);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      // Continue Reading floating indicator
      floatingActionButton: (_showContinueReading && !_restoredPosition)
          ? FloatingActionButton.extended(
              onPressed: _scrollToSavedPosition,
              backgroundColor: Ds.green,
              icon: const Icon(Icons.bookmark_rounded, color: Colors.white),
              label: Text(
                langCode == 'fr'
                    ? 'Continuer ($_savedProgressPercent%)'
                    : 'Continue ($_savedProgressPercent%)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      // Comp's pinned action bar: reactions on the left, comment CTA on the right.
      bottomNavigationBar: DsBottomBar(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    _article.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 26,
                    color: _article.isLiked ? Ds.red : Ds.body(context)),
                const SizedBox(width: 7),
                Text('${_article.likeCount}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _article.isLiked ? Ds.red : Ds.body(context))),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Icon(Icons.mode_comment_outlined, size: 24, color: Ds.body(context)),
          const SizedBox(width: 7),
          Text('${_article.commentCount}',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Ds.body(context))),
          const Spacer(),
          DsPrimaryButton(
            langCode == 'fr' ? 'Commenter' : 'Comment',
            icon: Icons.mode_comment_rounded,
            expand: false,
            radius: Ds.rPill,
            onTap: _scheduleScrollToComments,
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Green header from the comp (replaces the default AppBar).
          SliverToBoxAdapter(
            child: DsHeader(
              title: l10n.translate('news'),
              actions: [
                DsHeaderAction(
                  Icons.headphones_rounded,
                  label: l10n.translate('art_listen'),
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: _article.getContent(langCode)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.translate('art_text_copied_tts'),
                          style: const TextStyle(fontSize: 13),
                        ),
                        duration: const Duration(seconds: 4),
                        backgroundColor: Ds.green,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                DsHeaderAction(
                  _isBookmarked == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: l10n.translate('bookmark'),
                  onTap: _toggleBookmark,
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (btnContext) => DsHeaderAction(
                    Icons.share_rounded,
                    label: l10n.translate('share'),
                    onTap: () => ShareService.item(
                      btnContext,
                      kind: 'articles',
                      id: _article.id,
                      title: _article.getTitle(langCode),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Reading progress bar
          SliverToBoxAdapter(
            child: Container(
              height: 3,
              color: Ds.outline(context),
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<double>(
                valueListenable: _readingProgress,
                builder: (context, progress, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 3,
                  width: MediaQuery.of(context).size.width * progress,
                  color: Ds.green,
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + timestamp
                  Row(
                    children: [
                      if (_article.category != null) ...[
                        DsPill(_article.category!
                            .getDisplayName(langCode)
                            .toUpperCase()),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          DateFormat.yMMMMd(langCode).add_Hm().format(_article.publishDate),
                          style: Ds.meta(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    _article.getTitle(langCode),
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.25,
                      color: Ds.ink(context),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Byline
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: Ds.tint(context), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          _article.author.isEmpty
                              ? '?'
                              : _article.author
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .take(2)
                                  .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
                                  .join(),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Ds.green),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_article.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Ds.ink(context))),
                            Text(
                                langCode == 'fr'
                                    ? 'Officiel'
                                    : 'Official',
                                style: Ds.meta(context)),
                          ],
                        ),
                      ),
                      const TranslateButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Article photo
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                HapticService.light();
                final allImages = <String>[Environment.fixMediaUrl(_article.imageUrl)];
                final allCaptions = <String>[_article.getTitle(langCode)];
                for (final m in _article.media) {
                  if (m.isImage && m.imageUrl.isNotEmpty) {
                    allImages.add(Environment.fixMediaUrl(m.imageUrl));
                    allCaptions.add(m.getCaption(langCode));
                  }
                }
                ImageGalleryViewer.show(context,
                    images: allImages, initialIndex: 0, captions: allCaptions);
              },
              child: Container(
                margin: const EdgeInsets.all(16),
                height: 200,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Ds.rCard)),
                child: AppNetworkImage(
                  imageUrl: Environment.fixMediaUrl(_article.imageUrl),
                  hero: true,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, _) => const DsImagePlaceholder(radius: 0),
                  errorWidget: (_, _, _) => const DsImagePlaceholder(
                      radius: 0, icon: Icons.article_rounded),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                  child: AppNetworkImage(
                                    imageUrl: Environment.fixMediaUrl(m.imageUrl),
                                    hero: true,
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
                  if (isAuthenticated)
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
                              tooltip: AppLocalizations.of(context).translate('send'),
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
                        isAuthenticated: isAuthenticated,
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
                            isAuthenticated: isAuthenticated,
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
              child: AppNetworkImage(
                imageUrl: Environment.fixMediaUrl(article.imageUrl),
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
                          DateFormat.MMMd(langCode).format(article.publishDate),
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


}
