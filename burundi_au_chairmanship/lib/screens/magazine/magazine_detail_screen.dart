import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../services/like_service.dart';
import '../../services/haptic_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/liked_by_avatars.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/comment_ban_dialog.dart';
import '../../utils/input_sanitizer.dart';
import '../../widgets/image_gallery_viewer.dart';
import 'pdf_viewer_screen.dart';

class MagazineDetailScreen extends StatefulWidget {
  final MagazineEdition magazine;
  final bool scrollToComments;

  const MagazineDetailScreen({
    super.key,
    required this.magazine,
    this.scrollToComments = false,
  });

  @override
  State<MagazineDetailScreen> createState() => _MagazineDetailScreenState();
}

class _MagazineDetailScreenState extends State<MagazineDetailScreen> {
  late MagazineEdition _magazine;
  List<ArticleComment> _comments = [];
  bool _loadingComments = true;
  final _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _postingComment = false;
  int? _replyingToId;
  String? _replyingToName;

  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  final GlobalKey _commentsSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  // Cover carousel
  late PageController _coverPageController;
  int _currentCoverPage = 0;
  Timer? _autoSlideTimer;

  List<String> get _allImages {
    final images = <String>[];
    final cover = _magazine.coverImageUrl;
    if (cover.isNotEmpty) images.add(Environment.fixMediaUrl(cover));
    for (final img in _magazine.images) {
      if (img.imageUrl.isNotEmpty) images.add(Environment.fixMediaUrl(img.imageUrl));
    }
    return images;
  }

  List<String> _allCaptions(String langCode) {
    final captions = <String>[_magazine.getTitle(langCode)];
    for (final img in _magazine.images) {
      captions.add(img.getCaption(langCode));
    }
    return captions;
  }

  @override
  void initState() {
    super.initState();
    _magazine = widget.magazine;
    _coverPageController = PageController();

    _likeService.seed(EntityType.magazine, _magazine.id,
        isLiked: _magazine.isLiked,
        likeCount: _magazine.likeCount,
        recentLikers: _magazine.recentLikers);
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key == 'magazine:${_magazine.id}' && mounted) {
        setState(() {
          _magazine = _magazine.copyWith(
              isLiked: state.isLiked,
              likeCount: state.likeCount,
              recentLikers: state.recentLikers);
        });
      }
    });
    _recordView();
    _loadComments();
    _startAutoSlide();
    if (widget.scrollToComments) _scheduleScrollToComments();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _coverPageController.dispose();
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _removeLikeListener?.call();
    super.dispose();
  }

  void _startAutoSlide() {
    if (_allImages.length <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_coverPageController.hasClients) return;
      final next = (_currentCoverPage + 1) % _allImages.length;
      _coverPageController.animateToPage(next,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
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
          Scrollable.ensureVisible(ctx,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic)
              .then((_) {
            if (mounted) _commentFocusNode.requestFocus();
          });
        }
      });
    });
  }

  Future<void> _recordView() async {
    try {
      await ApiService().recordMagazineView(_magazine.id);
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    try {
      final comments = await ApiService().getMagazineComments(_magazine.id);
      if (mounted) setState(() { _comments = comments; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  int _totalCommentCount(List<ArticleComment> list) {
    int n = 0;
    for (final c in list) { n += 1 + c.replyCount; }
    return n;
  }

  void _startReply(ArticleComment comment) {
    setState(() {
      _replyingToId = comment.id;
      _replyingToName = comment.username.isNotEmpty ? comment.username : comment.userName;
    });
    if (comment.username.isNotEmpty) {
      final prefix = '@${comment.username} ';
      _commentController.text = prefix;
      _commentController.selection = TextSelection.fromPosition(TextPosition(offset: prefix.length));
    }
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() { _replyingToId = null; _replyingToName = null; });
    _commentController.clear();
  }

  Future<void> _postComment() async {
    final text = InputSanitizer.sanitizeComment(_commentController.text);
    if (text.isEmpty) return;
    setState(() => _postingComment = true);
    try {
      final comment = await ApiService().postMagazineComment(_magazine.id, text, parentId: _replyingToId);
      if (!mounted) return;
      _commentController.clear();
      _replyingToId = null; _replyingToName = null;
      setState(() => _postingComment = false);
      if (comment.parentId == null) { setState(() => _comments.insert(0, comment)); }
      else { await _loadComments(); }
    } on ApiException catch (e) {
      if (mounted) { setState(() => _postingComment = false); showCommentErrorDialog(context, e.message, e.statusCode, referenceId: e.referenceId); }
    } catch (e) {
      if (mounted) { setState(() => _postingComment = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('delete_comment'), style: const TextStyle(color: AppColors.burundiRed))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().deleteMagazineComment(_magazine.id, comment.id);
      if (mounted) setState(() => _comments.removeWhere((c) => c.id == comment.id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _toggleLike() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.translate('login_to_like')),
        action: SnackBarAction(label: l10n.translate('sign_in'), textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, '/auth')),
      ));
      return;
    }
    _likeService.toggle(EntityType.magazine, _magazine.id);
  }

  void _openPdf() {
    final langCode = context.read<LanguageProvider>().languageCode;
    final url = _magazine.openablePdfUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF not available yet.'), behavior: SnackBarBehavior.floating));
      return;
    }
    Navigator.push(context, CupertinoPageRoute(
      builder: (_) => PdfViewerScreen(pdfUrl: url, title: _magazine.getTitle(langCode), magazineId: _magazine.id)));
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final commentCount = _totalCommentCount(_comments);
    final images = _allImages;
    final title = _magazine.getTitle(langCode);
    final description = _magazine.getDescription(langCode);
    final screenWidth = MediaQuery.of(context).size.width;
    final coverWidth = screenWidth * 0.75;
    final coverHeight = coverWidth * 1.4;

    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── Elegant warm background behind cover area ──
          Positioned(
            top: 0, left: 0, right: 0, height: 500,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1C2A1C),
                          const Color(0xFF162016),
                          AppColors.darkBackground,
                        ]
                      : [
                          const Color(0xFFF8F6F2),
                          const Color(0xFFF3F1ED),
                          bg,
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── Main content ──
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Simple transparent app bar
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.share_rounded, color: textPrimary, size: 20),
                    ),
                    onPressed: () {
                      HapticService.light();
                      Share.share('${_magazine.getTitle(langCode)}\n\n${Environment.siteBaseUrl}/magazines/${_magazine.id}/share/');
                    },
                  ),
                ],
              ),

              // ═══ Cover + Info (Apple Books style) ═══
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Centered cover — always slidable ──
                    SizedBox(
                      height: coverHeight,
                      child: images.isNotEmpty
                          ? PageView.builder(
                              controller: _coverPageController,
                              itemCount: images.length,
                              onPageChanged: (i) {
                                setState(() => _currentCoverPage = i);
                                _autoSlideTimer?.cancel();
                                _startAutoSlide();
                              },
                              itemBuilder: (_, i) => Center(
                                child: _buildCover(images[i], coverWidth, coverHeight, images, langCode, index: i),
                              ),
                            )
                          : Center(child: _buildCover('', coverWidth, coverHeight, images, langCode)),
                    ),

                    // Page dots
                    if (images.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (i) {
                            final active = i == _currentCoverPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 18 : 6, height: 6,
                              decoration: BoxDecoration(
                                color: active ? AppColors.burundiGreen : textSecondary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ── Title (centered) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'HeatherGreen',
                          color: textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Date + meta (centered) ──
                    Text(
                      DateFormat('MMMM yyyy').format(_magazine.publishDate),
                      style: TextStyle(fontSize: 15, color: textSecondary, fontWeight: FontWeight.w500),
                    ),
                    if (_magazine.pageCount > 0 || _magazine.fileSize.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [
                            if (_magazine.pageCount > 0) '${_magazine.pageCount} pages',
                            if (_magazine.fileSize.isNotEmpty) _magazine.fileSize,
                          ].join('  ·  '),
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ),

                    // ── Featured badge ──
                    if (_magazine.isFeatured)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFD4A017), Color(0xFFF4C430)]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('FEATURED EDITION',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ── Read Now button (full width) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: _magazine.hasPdf ? _openPdf : null,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _magazine.hasPdf ? AppColors.burundiGreen : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_stories_rounded, size: 22,
                                color: _magazine.hasPdf ? Colors.white : Colors.grey),
                              const SizedBox(width: 10),
                              Text(
                                _magazine.hasPdf
                                    ? (langCode == 'fr' ? 'Commencer la lecture' : 'Start Reading')
                                    : (langCode == 'fr' ? 'PDF non disponible' : 'PDF Not Available'),
                                style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700,
                                  color: _magazine.hasPdf ? Colors.white : Colors.grey,
                                ),
                              ),
                              if (_magazine.hasPdf) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white70),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Engagement row (inline, like live feed) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          // Views
                          Icon(Icons.visibility_rounded, size: 18, color: textSecondary),
                          const SizedBox(width: 5),
                          Text('${_magazine.viewCount}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary)),
                          const SizedBox(width: 4),
                          Text(l10n.translate('views'),
                            style: TextStyle(fontSize: 14, color: textSecondary)),

                          const SizedBox(width: 20),

                          // Like — tappable
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleLike,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    _magazine.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    size: 22,
                                    color: _magazine.isLiked ? AppColors.burundiRed : textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text('${_magazine.likeCount}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                      color: _magazine.isLiked ? AppColors.burundiRed : textSecondary)),
                                  const SizedBox(width: 4),
                                  Text(l10n.translate('like'),
                                    style: TextStyle(fontSize: 14,
                                      color: _magazine.isLiked ? AppColors.burundiRed : textSecondary)),
                                ],
                              ),
                            ),
                          ),

                          // Liked-by avatars
                          if (_magazine.recentLikers.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            LikedByAvatars(
                              likers: _magazine.recentLikers,
                              totalLikes: _magazine.likeCount,
                              avatarRadius: 10,
                            ),
                          ],

                          const Spacer(),

                          // Comments — tappable, scrolls to section
                          GestureDetector(
                            onTap: () {
                              final ctx = _commentsSectionKey.currentContext;
                              if (ctx != null) {
                                Scrollable.ensureVisible(ctx,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic);
                              }
                            },
                            child: Row(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 18, color: textSecondary),
                                const SizedBox(width: 5),
                                Text('$commentCount',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ═══ Divider ═══
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ),
              ),

              // ═══ Description + Comments (inline, padded) ═══
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      if (description.isNotEmpty) ...[
                        Text(
                          langCode == 'fr' ? 'A propos' : 'About',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: TextStyle(fontSize: 15, height: 1.7, color: textPrimary.withValues(alpha: 0.85)),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // ── Comments ──
                      SizedBox(key: _commentsSectionKey, height: 0),
                      Text(
                        '${l10n.translate('comments')} ($commentCount)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                      const SizedBox(height: 14),

                      if (auth.isAuthenticated)
                        _buildCommentInput(l10n, langCode, isDark)
                      else
                        _buildLoginPrompt(l10n, isDark),
                      const SizedBox(height: 14),

                      if (_loadingComments)
                        const Padding(padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      else if (_comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text(l10n.translate('no_comments_yet'), style: TextStyle(fontSize: 14, color: textSecondary))),
                        )
                      else
                        ...List.generate(_comments.length, (index) {
                          final c = _comments[index];
                          return CommentTile.fromMap(
                            c.toMap(), key: ValueKey(c.id), isReply: false, isAuthenticated: auth.isAuthenticated,
                            onReply: () => _startReply(c),
                            onPostReply: (content, parentId) async {
                              try { await ApiService().postMagazineComment(_magazine.id, content, parentId: parentId); await _loadComments(); }
                              on ApiException catch (e) { if (mounted) showCommentErrorDialog(context, e.message, e.statusCode, referenceId: e.referenceId); }
                            },
                            onDelete: () => _deleteComment(c),
                            onToggleLike: () => ApiService().toggleMagazineCommentLike(_magazine.id, c.id),
                            onEdit: (content) => ApiService().editMagazineComment(_magazine.id, c.id, content),
                            replyBuilder: (reply) {
                              final rc = ArticleComment.fromJson(reply);
                              return CommentTile.fromMap(reply, key: ValueKey(rc.id), isReply: true, isAuthenticated: auth.isAuthenticated,
                                onDelete: () => _deleteComment(rc),
                                onToggleLike: () => ApiService().toggleMagazineCommentLike(_magazine.id, rc.id),
                                onEdit: (content) => ApiService().editMagazineComment(_magazine.id, rc.id, content));
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
        ],
      ),
    );
  }

  // ─── Cover image with shadow (Apple Books style) ───────────────

  Widget _buildCover(String imageUrl, double width, double height, List<String> allImages, String langCode, {int index = 0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        if (allImages.isEmpty) return;
        HapticService.light();
        ImageGalleryViewer.show(context, images: allImages, initialIndex: index, captions: _allCaptions(langCode));
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 28, spreadRadius: 2, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  width: width,
                  height: height,
                  placeholder: (_, _) => _coverPlaceholder(),
                  errorWidget: (_, _, _) => _coverPlaceholder(),
                )
              : _coverPlaceholder(),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: AppColors.burundiGreen.withValues(alpha: 0.15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_rounded, size: 40, color: AppColors.burundiGreen.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text('Magazine', style: TextStyle(fontSize: 12, color: AppColors.burundiGreen.withValues(alpha: 0.4),
            fontWeight: FontWeight.w600, letterSpacing: 1)),
        ],
      ),
    );
  }


  // ─── Comment input ──────────────────────────────────────────────

  Widget _buildCommentInput(AppLocalizations l10n, String langCode, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            focusNode: _commentFocusNode,
            decoration: InputDecoration(
              hintText: _replyingToName != null
                  ? '${langCode == 'fr' ? 'Repondre a' : 'Reply to'} $_replyingToName...'
                  : l10n.translate('add_comment'),
              hintStyle: const TextStyle(fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              suffixIcon: _replyingToId != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _cancelReply,
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
    );
  }

  Widget _buildLoginPrompt(AppLocalizations l10n, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/auth'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.burundiGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.login_rounded, size: 16, color: AppColors.burundiGreen),
            const SizedBox(width: 8),
            Text(l10n.translate('login_to_comment'),
              style: const TextStyle(fontSize: 14, color: AppColors.burundiGreen, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
