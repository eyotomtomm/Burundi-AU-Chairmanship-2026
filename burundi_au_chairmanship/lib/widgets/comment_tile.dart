import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';

/// Shared comment tile widget used across all content types.
///
/// Supports like, edit (2-min window), reply, delete, and nested replies.
class CommentTile extends StatefulWidget {
  final int commentId;
  final String userName;
  final String? username; // @handle
  final String? profilePicture;
  final String? badgeType;
  final String content;
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;
  final bool isOwner;
  final bool canEdit;
  final bool isEdited;
  final bool isReply;
  final bool isAuthenticated;
  final List<Map<String, dynamic>> replies;
  final String userNameKey; // 'user_name' or 'author_name'

  // Callbacks
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final Future<Map<String, dynamic>> Function()? onToggleLike;
  final Future<Map<String, dynamic>> Function(String content)? onEdit;

  // Builder for nested reply tiles
  final Widget Function(Map<String, dynamic> reply)? replyBuilder;

  const CommentTile({
    super.key,
    required this.commentId,
    required this.userName,
    this.username,
    this.profilePicture,
    this.badgeType,
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
    this.isOwner = false,
    this.canEdit = false,
    this.isEdited = false,
    this.isReply = false,
    this.isAuthenticated = false,
    this.replies = const [],
    this.userNameKey = 'user_name',
    this.onReply,
    this.onDelete,
    this.onToggleLike,
    this.onEdit,
    this.replyBuilder,
  });

  /// Build a CommentTile from a raw JSON map.
  factory CommentTile.fromMap(
    Map<String, dynamic> map, {
    Key? key,
    bool isReply = false,
    bool isAuthenticated = false,
    String userNameKey = 'user_name',
    VoidCallback? onReply,
    VoidCallback? onDelete,
    Future<Map<String, dynamic>> Function()? onToggleLike,
    Future<Map<String, dynamic>> Function(String content)? onEdit,
    Widget Function(Map<String, dynamic> reply)? replyBuilder,
  }) {
    return CommentTile(
      key: key,
      commentId: map['id'] ?? 0,
      userName: (map[userNameKey] ?? map['user_name'] ?? map['author_name'] ?? 'User') as String,
      username: map['username'] as String?,
      profilePicture: map['profile_picture'] as String?,
      badgeType: map['badge_type'] as String?,
      content: (map['content'] ?? '') as String,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      likeCount: (map['like_count'] ?? 0) as int,
      isLiked: (map['is_liked'] ?? false) as bool,
      isOwner: (map['is_owner'] ?? false) as bool,
      canEdit: (map['can_edit'] ?? false) as bool,
      isEdited: (map['is_edited'] ?? false) as bool,
      isReply: isReply,
      isAuthenticated: isAuthenticated,
      replies: isReply
          ? const []
          : ((map['replies'] as List<dynamic>?) ?? [])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList(),
      userNameKey: userNameKey,
      onReply: onReply,
      onDelete: onDelete,
      onToggleLike: onToggleLike,
      onEdit: onEdit,
      replyBuilder: replyBuilder,
    );
  }

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  late bool _isLiked;
  late int _likeCount;
  late String _content;
  late bool _isEdited;
  late bool _canEdit;

  bool _isEditing = false;
  bool _likePending = false;
  Timer? _editTimer;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;
    _content = widget.content;
    _isEdited = widget.isEdited;
    _canEdit = widget.canEdit;

    if (_canEdit) {
      _startEditTimer();
    }
  }

  @override
  void dispose() {
    _editTimer?.cancel();
    _editController.dispose();
    super.dispose();
  }

  void _startEditTimer() {
    final elapsed = DateTime.now().difference(widget.createdAt);
    final remaining = const Duration(seconds: 120) - elapsed;
    if (remaining.isNegative) {
      _canEdit = false;
      return;
    }
    _editTimer = Timer(remaining, () {
      if (mounted) setState(() => _canEdit = false);
    });
  }

  Future<void> _handleToggleLike() async {
    if (_likePending || widget.onToggleLike == null) return;
    _likePending = true;

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final result = await widget.onToggleLike!();
      if (mounted) {
        setState(() {
          _isLiked = result['is_liked'] ?? _isLiked;
          _likeCount = result['like_count'] ?? _likeCount;
        });
      }
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      _likePending = false;
    }
  }

  void _startEditing() {
    _editController.text = _content;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  Future<void> _saveEdit() async {
    final newContent = _editController.text.trim();
    if (newContent.isEmpty || newContent.length < 2 || widget.onEdit == null) return;

    try {
      await widget.onEdit!(newContent);
      if (mounted) {
        setState(() {
          _content = newContent;
          _isEdited = true;
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarRadius = widget.isReply ? 14.0 : 18.0;
    final nameSize = widget.isReply ? 12.5 : 13.0;

    return Padding(
      padding: EdgeInsets.only(left: widget.isReply ? 44.0 : 0.0, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.15),
                backgroundImage: widget.profilePicture != null && widget.profilePicture!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.profilePicture!)
                    : null,
                child: widget.profilePicture == null || widget.profilePicture!.isEmpty
                    ? Text(
                        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.burundiGreen,
                          fontSize: widget.isReply ? 11 : 13,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: name, badge, handle, time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            widget.userName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: nameSize,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                          ),
                        ),
                        if (widget.badgeType != null && widget.badgeType!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: widget.badgeType == 'GOLD'
                                ? const Color(0xFFD4AF37)
                                : AppColors.burundiGreen,
                          ),
                        ],
                        if (widget.username != null && widget.username!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '@${widget.username}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          '· ${_timeAgo(widget.createdAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Content or edit mode
                    if (_isEditing)
                      _buildEditField(isDark)
                    else
                      _buildContentText(isDark),

                    // Action row
                    const SizedBox(height: 6),
                    _buildActionRow(isDark),
                  ],
                ),
              ),
            ],
          ),

          // Nested replies
          if (!widget.isReply && widget.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: widget.replies.map((reply) {
                  if (widget.replyBuilder != null) {
                    return widget.replyBuilder!(reply);
                  }
                  return CommentTile.fromMap(
                    reply,
                    isReply: true,
                    isAuthenticated: widget.isAuthenticated,
                    userNameKey: widget.userNameKey,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentText(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMentionRichText(_content, isDark),
        if (_isEdited) ...[
          const SizedBox(height: 2),
          Text(
            '(edited)',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMentionRichText(String content, bool isDark) {
    final mentionRegex = RegExp(r'@(\w+)');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: AppColors.auGold,
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: content));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: isDark ? Colors.white.withValues(alpha: 0.85) : AppColors.lightText,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildEditField(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _editController,
          maxLines: null,
          autofocus: true,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : AppColors.lightText,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.burundiGreen.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.burundiGreen),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            GestureDetector(
              onTap: _saveEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.burundiGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _cancelEditing,
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionRow(bool isDark) {
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      children: [
        // Like button
        if (widget.isAuthenticated)
          GestureDetector(
            onTap: _handleToggleLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: _isLiked ? AppColors.burundiRed : secondaryColor,
                ),
                if (_likeCount > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '$_likeCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isLiked ? AppColors.burundiRed : secondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          )
        else if (_likeCount > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, size: 14, color: secondaryColor),
              const SizedBox(width: 3),
              Text(
                '$_likeCount',
                style: TextStyle(fontSize: 12, color: secondaryColor),
              ),
            ],
          ),

        // Reply button
        if (!widget.isReply && widget.isAuthenticated && widget.onReply != null) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: widget.onReply,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply_rounded, size: 16, color: secondaryColor),
                const SizedBox(width: 3),
                Text(
                  'Reply',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryColor),
                ),
              ],
            ),
          ),
        ],

        // Edit button
        if (_canEdit && widget.isOwner && widget.onEdit != null && !_isEditing) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _startEditing,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 14, color: secondaryColor),
                const SizedBox(width: 3),
                Text(
                  'Edit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryColor),
                ),
              ],
            ),
          ),
        ],

        const Spacer(),

        // Delete button
        if (widget.isOwner && widget.onDelete != null)
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Icons.delete_outline_rounded, size: 18, color: secondaryColor),
          ),
      ],
    );
  }
}
