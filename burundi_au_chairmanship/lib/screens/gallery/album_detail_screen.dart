import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/image_gallery_viewer.dart';
import '../../widgets/liked_by_avatars.dart';
import '../../widgets/comment_tile.dart';
import '../../services/like_service.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Map<String, dynamic> album;

  const AlbumDetailScreen({
    super.key,
    required this.album,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  // Comments
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;
  int _commentCount = 0;
  final _commentController = TextEditingController();
  bool _postingComment = false;
  int? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    final likers = widget.album['recent_likers'] is List
        ? (widget.album['recent_likers'] as List)
            .map((l) => Liker.fromJson(l as Map<String, dynamic>))
            .toList()
        : <Liker>[];
    _likeService.seed(
      EntityType.gallery, widget.album['id'],
      isLiked: widget.album['is_liked'] == true,
      likeCount: widget.album['like_count'] ?? 0,
      recentLikers: likers,
    );
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key == 'gallery:${widget.album['id']}' && mounted) setState(() {});
    });
    _enableScreenProtection();
    _recordView();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final data = await ApiService().getGalleryComments(widget.album['id'].toString());
      if (mounted) {
        setState(() {
          _comments = data;
          _commentCount = data.fold<int>(0, (sum, c) => sum + 1 + ((c['replies'] as List?)?.length ?? 0));
          _loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _postingComment = true);
    try {
      await ApiService().postGalleryComment(
        widget.album['id'].toString(),
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
      await ApiService().deleteGalleryComment(widget.album['id'].toString(), commentId);
      await _loadComments();
    } catch (_) {}
  }

  void _showCommentsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Comments ($_commentCount)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: _loadingComments
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? Center(child: Text('No comments yet', style: TextStyle(color: Colors.grey[500])))
                        : ListView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _comments.length,
                            itemBuilder: (ctx, i) {
                              final comment = _comments[i];
                              final albumId = widget.album['id']?.toString() ?? '';
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              return CommentTile.fromMap(
                                comment,
                                isAuthenticated: auth.isAuthenticated,
                                onReply: () => setState(() {
                                  _replyingToId = comment['id'];
                                  _replyingToName = comment['user_name'];
                                }),
                                onDelete: () => _deleteComment(comment['id']),
                                onToggleLike: () => ApiService().toggleGalleryCommentLike(albumId, comment['id']),
                                onEdit: (content) => ApiService().editGalleryComment(albumId, comment['id'], content),
                                replyBuilder: (reply) => CommentTile.fromMap(
                                  reply,
                                  isReply: true,
                                  isAuthenticated: auth.isAuthenticated,
                                  onDelete: () => _deleteComment(reply['id']),
                                  onToggleLike: () => ApiService().toggleGalleryCommentLike(albumId, reply['id']),
                                  onEdit: (content) => ApiService().editGalleryComment(albumId, reply['id'], content),
                                ),
                              );
                            },
                          ),
              ),
              // Input
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: _replyingToName != null ? 'Reply to $_replyingToName...' : 'Add a comment...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            suffixIcon: _replyingToId != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      setState(() { _replyingToId = null; _replyingToName = null; });
                                      setSheetState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _postingComment
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: AppColors.burundiGreen),
                        onPressed: _postingComment
                            ? null
                            : () async {
                                await _postComment();
                                setSheetState(() {});
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _recordView() {
    final id = widget.album['id'];
    if (id != null) {
      ApiService().recordGalleryAlbumView(id.toString()).catchError((_) => <String, dynamic>{});
    }
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
    _likeService.toggle(EntityType.gallery, widget.album['id']);
  }

  /// Enable screenshot and screen recording prevention
  Future<void> _enableScreenProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      if (kDebugMode) debugPrint('Screen protection error: $e');
    }
  }

  /// Disable screen protection when leaving
  Future<void> _disableScreenProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      if (kDebugMode) debugPrint('Screen protection disable error: $e');
    }
  }

  /// Open fullscreen photo viewer with swipe support
  void _openPhotoViewer(int initialIndex) {
    final photos = widget.album['photos'] as List? ?? [];
    final langCode = Localizations.localeOf(context).languageCode;

    final imageUrls = <String>[];
    final captions = <String>[];

    for (final photo in photos) {
      imageUrls.add(Environment.fixMediaUrl(photo['image'] ?? ''));
      final caption = langCode == 'fr'
          ? (photo['caption_fr'] ?? photo['caption'] ?? '')
          : (photo['caption'] ?? '');
      captions.add(caption?.toString() ?? '');
    }

    ImageGalleryViewer.show(
      context,
      images: imageUrls,
      initialIndex: initialIndex,
      captions: captions,
      heroTagPrefix: 'album_${widget.album['id']}',
    );
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    _commentController.dispose();
    _disableScreenProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likeState = _likeService.getState(EntityType.gallery, widget.album['id']);
    final photos = widget.album['photos'] as List? ?? [];
    final langCode = Localizations.localeOf(context).languageCode;
    final title = langCode == 'fr'
        ? (widget.album['title_fr'] ?? widget.album['title'])
        : widget.album['title'];

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Album'),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
        actions: [
          // Comments button
          IconButton(
            icon: Badge(
              label: _commentCount > 0 ? Text('$_commentCount', style: const TextStyle(fontSize: 10)) : null,
              isLabelVisible: _commentCount > 0,
              child: const Icon(Icons.comment_outlined, color: Colors.white),
            ),
            tooltip: 'Comments',
            onPressed: _showCommentsSheet,
          ),
          // Like button
          IconButton(
            icon: Icon(
              likeState.isLiked ? Icons.favorite : Icons.favorite_border,
              color: likeState.isLiked ? Colors.red : Colors.white,
            ),
            tooltip: likeState.isLiked ? 'Unlike' : 'Like',
            onPressed: _toggleLike,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Photo Grid with liked-by header
          Column(
            children: [
              if (likeState.recentLikers.isNotEmpty || likeState.likeCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      LikedByAvatars(
                        likers: likeState.recentLikers,
                        totalLikes: likeState.likeCount,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        likeState.likeCount == 1 ? '1 like' : '${likeState.likeCount} likes',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Text(
                        '${photos.length} photos',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return _buildPhotoTile(photo, index);
            },
          ),
              ),
            ],
          ),

          // Screenshot protection badge
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Text(
                    'Protected content',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile(Map<String, dynamic> photo, int index) {
    final imageUrl = Environment.fixMediaUrl(photo['image'] ?? '');

    return GestureDetector(
      onTap: () => _openPhotoViewer(index),
      child: Hero(
        tag: 'album_${widget.album['id']}_$index',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 400,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}

