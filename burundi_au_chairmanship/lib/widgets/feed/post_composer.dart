import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

/// A file queued in the composer, not yet uploaded.
class ComposerAttachment {
  final File file;
  final bool isVideo;
  const ComposerAttachment(this.file, this.isVideo);
}

/// The compose sheet from `B4Africa Social Feed`, shared by the Explore feed
/// and the discussions board.
///
/// Posting requires a filled-in profile; the completion endpoint already knows
/// which fields count, so this asks it rather than re-deriving the list.
class PostComposer {
  static const maxAttachments = 4;

  static const _requiredProfileFields = [
    'name', 'email', 'profile_picture', 'nationality', 'gender',
    'date_of_birth', 'phone',
  ];

  static const categories = [
    {'value': 'general', 'label': 'General'},
    {'value': 'arise', 'label': 'A-RISE'},
    {'value': 'events', 'label': 'Events'},
    {'value': 'culture', 'label': 'Culture'},
    {'value': 'politics', 'label': 'Politics'},
    {'value': 'business', 'label': 'Business'},
  ];

  /// Runs the gate, then opens the composer. Returns true when a post landed.
  ///
  /// A full page rather than a half-sheet: with text, up to four attachments,
  /// a poll builder and the topic banner, a sheet fights the keyboard for room.
  ///
  /// [pickOnOpen] ('image' or 'video') jumps straight to the picker once the
  /// gate passes, so the feed's Photo/Video buttons land in the composer with
  /// the file already attached. The gate runs first either way — no point
  /// making someone choose a video and then telling them they can't post.
  static Future<bool> open(
    BuildContext context, {
    String? category,
    bool requireTitle = false,
    String? pickOnOpen,
    Map<String, dynamic>? topic,
  }) async {
    if (!await _ensureCanPost(context)) return false;
    if (!context.mounted) return false;

    final initial = <ComposerAttachment>[];
    if (pickOnOpen != null) {
      final picked = await _pick(isVideo: pickOnOpen == 'video');
      if (!context.mounted) return false;
      if (picked != null && _rejectReason(context, picked) == null) {
        initial.add(picked);
      } else if (picked != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_rejectReason(context, picked)!)));
      }
    }

    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ComposerPage(
          category: category,
          requireTitle: requireTitle,
          topic: topic,
          initialAttachments: initial,
        ),
      ),
    );
    return posted == true;
  }

  /// Server ceilings, checked here so a long upload over mobile data cannot
  /// end in a rejection after every byte has already been sent.
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxVideoBytes = 200 * 1024 * 1024;
  static const Duration maxVideoDuration = Duration(minutes: 5);

  static Future<ComposerAttachment?> _pick({required bool isVideo}) async {
    final picker = ImagePicker();
    final picked = isVideo
        ? await picker.pickVideo(
            source: ImageSource.gallery, maxDuration: maxVideoDuration)
        // Re-encoding at 85 turns a 4 MB phone photo into a few hundred KB
        // with no visible difference at the size the feed shows it.
        : await picker.pickImage(
            source: ImageSource.gallery, maxWidth: 2048, imageQuality: 85);
    return picked == null ? null : ComposerAttachment(File(picked.path), isVideo);
  }

  /// Null when the file is fine, otherwise why it was refused.
  static String? _rejectReason(BuildContext context, ComposerAttachment a) {
    final limit = a.isVideo ? maxVideoBytes : maxImageBytes;
    if (a.file.lengthSync() <= limit) return null;
    final mb = (limit / (1024 * 1024)).round();
    return '${AppLocalizations.of(context).translate('w_file_too_large')} ($mb MB)';
  }

  static Future<bool> _ensureCanPost(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return false;
    }
    try {
      final data = await ApiService().getProfileCompletion();
      final fields = (data['fields'] as Map?) ?? {};
      final missing =
          _requiredProfileFields.where((f) => fields[f] != true).toList();
      if (missing.isEmpty) return true;
      if (!context.mounted) return false;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx).translate('w_complete_profile_title')),
          content: Text(
            '${AppLocalizations.of(ctx).translate('w_complete_profile_body')}'
            '${missing.map(_fieldLabel).join(', ')}.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(ctx).translate('w_not_now'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(ctx)
                    .translate('explore_terms_complete_profile'))),
          ],
        ),
      );
      if (go == true && context.mounted) {
        await Navigator.pushNamed(context, '/profile-completion');
      }
      return false;
    } catch (_) {
      // Offline or endpoint unavailable: let the server decide on submit.
      return true;
    }
  }

  static String _fieldLabel(String field) => switch (field) {
        'profile_picture' => 'profile photo',
        'date_of_birth' => 'date of birth',
        _ => field.replaceAll('_', ' '),
      };

  /// Creates the post, then attaches the poll and uploads each file, showing
  /// real upload progress — a 300 MB video otherwise looks like a hang.
  static Future<bool> _submit(
    BuildContext context,
    String title,
    String content,
    String category,
    List<ComposerAttachment> attachments, {
    String pollQuestion = '',
    List<String> pollOptions = const [],
    int? topicId,
  }) async {
    final api = ApiService();
    final progress = ValueNotifier<_UploadState>(
        const _UploadState(index: 0, total: 0, fraction: 0));

    var dialogOpen = false;
    void closeDialog() {
      if (!dialogOpen) return;
      dialogOpen = false;
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    void showProgress() {
      if (attachments.isEmpty || !context.mounted) return;
      dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UploadDialog(progress: progress),
      );
    }

    try {
      final created =
          await api.createDiscussion(title, content, category, topicId: topicId);
      final id = created['id'] as int?;

      if (id != null && pollQuestion.isNotEmpty && pollOptions.length >= 2) {
        try {
          await api.addPostPoll(id, pollQuestion, pollOptions);
        } on ApiException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('w_poll_skipped')}: ${e.message}')));
          }
        }
      }

      if (id != null && attachments.isNotEmpty) {
        showProgress();
        final failed = <ComposerAttachment>[];
        for (var i = 0; i < attachments.length; i++) {
          final a = attachments[i];
          progress.value =
              _UploadState(index: i + 1, total: attachments.length, fraction: 0);
          try {
            await api.uploadDiscussionMedia(
              id,
              a.file,
              isVideo: a.isVideo,
              onProgress: (f) => progress.value = _UploadState(
                  index: i + 1, total: attachments.length, fraction: f),
            );
          } catch (_) {
            // The post is already live; a dropped attachment shouldn't lose
            // it — and a timeout is at least as likely here as a rejection,
            // so this catches everything rather than ApiException alone.
            failed.add(a);
          }
        }
        closeDialog();
        if (failed.isNotEmpty && context.mounted) {
          _offerRetry(context, id, failed);
        }
      }
      return true;
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('generic_error'))));
      }
      return false;
    } finally {
      // The dialog blocks its barrier, so leaving it up on an error path is an
      // unrecoverable hang — close it before the notifier it listens to goes.
      closeDialog();
      progress.dispose();
    }
  }
}

/// Attachments that did not make it: say so, and let one tap try again.
void _offerRetry(BuildContext context, int postId, List<ComposerAttachment> failed) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    duration: const Duration(seconds: 8),
    content: Text('${l10n.translate('w_attachment_skipped')} (${failed.length})'),
    action: SnackBarAction(
      label: l10n.translate('retry'),
      onPressed: () async {
        final api = ApiService();
        final stillFailed = <ComposerAttachment>[];
        for (final a in failed) {
          try {
            await api.uploadDiscussionMedia(postId, a.file, isVideo: a.isVideo);
          } catch (_) {
            stillFailed.add(a);
          }
        }
        if (context.mounted && stillFailed.isNotEmpty) {
          _offerRetry(context, postId, stillFailed);
        }
      },
    ),
  ));
}

class _UploadState {
  final int index;
  final int total;
  final double fraction;
  const _UploadState(
      {required this.index, required this.total, required this.fraction});
}

class _UploadDialog extends StatelessWidget {
  final ValueNotifier<_UploadState> progress;

  const _UploadDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Ds.surface(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ds.rCard)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ValueListenableBuilder<_UploadState>(
          valueListenable: progress,
          builder: (_, state, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.total > 1
                    ? 'Uploading ${state.index} of ${state.total}'
                    : 'Uploading',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Ds.ink(context)),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(Ds.rPill),
                child: LinearProgressIndicator(
                  value: state.fraction == 0 ? null : state.fraction,
                  minHeight: 8,
                  backgroundColor: Ds.subtle(context),
                  valueColor: const AlwaysStoppedAnimation(Ds.green),
                ),
              ),
              const SizedBox(height: 10),
              Text('${(state.fraction * 100).round()}%',
                  style: TextStyle(fontSize: 13, color: Ds.body(context))),
            ],
          ),
        ),
      ),
    );
  }
}


/// The composer itself: a full page so the keyboard, attachments and poll
/// builder each have room instead of competing inside a half-sheet.
class _ComposerPage extends StatefulWidget {
  final String? category;
  final bool requireTitle;
  final Map<String, dynamic>? topic;
  final List<ComposerAttachment> initialAttachments;

  const _ComposerPage({
    this.category,
    required this.requireTitle,
    this.topic,
    required this.initialAttachments,
  });

  @override
  State<_ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<_ComposerPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _pollQuestion = TextEditingController();
  final _pollOptions = [TextEditingController(), TextEditingController()];
  late final List<ComposerAttachment> _attachments =
      List.of(widget.initialAttachments);
  late String _category = widget.category ?? 'general';
  bool _pollOn = false;
  bool _busy = false;

  bool get _canPost =>
      _contentCtrl.text.trim().isNotEmpty &&
      (!widget.requireTitle || _titleCtrl.text.trim().isNotEmpty);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _pollQuestion.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add({required bool isVideo}) async {
    if (_attachments.length >= PostComposer.maxAttachments) return;
    final picked = await PostComposer._pick(isVideo: isVideo);
    if (picked == null || !mounted) return;
    // Refuse it here rather than after the whole file has gone up the wire.
    final reason = PostComposer._rejectReason(context, picked);
    if (reason != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(reason)));
      return;
    }
    setState(() => _attachments.add(picked));
  }

  Future<void> _post() async {
    if (!_canPost || _busy) return;
    setState(() => _busy = true);
    final ok = await PostComposer._submit(
      context,
      _titleCtrl.text.trim(),
      _contentCtrl.text.trim(),
      _category,
      _attachments,
      pollQuestion: _pollOn ? _pollQuestion.text.trim() : '',
      pollOptions: _pollOn
          ? _pollOptions
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList()
          : const [],
      topicId: widget.topic?['id'] as int?,
    );
    if (mounted) Navigator.pop(context, ok);
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          _header(context, fr),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (widget.topic != null) _topicBanner(context, fr),
                if (widget.requireTitle) ...[
                  TextField(
                    controller: _titleCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).translate('w_title'),
                      filled: true,
                      fillColor: Ds.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Ds.rTile),
                        borderSide: BorderSide(color: Ds.outline(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Ds.rTile),
                        borderSide: BorderSide(color: Ds.outline(context)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Ds.surface(context),
                    borderRadius: BorderRadius.circular(Ds.rCard),
                    boxShadow: Ds.shadow(context),
                  ),
                  child: TextField(
                    controller: _contentCtrl,
                    autofocus: _attachments.isEmpty,
                    minLines: 5,
                    maxLines: null,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                        fontSize: 16, height: 1.5, color: Ds.ink(context)),
                    decoration: InputDecoration(
                      hintText: fr
                          ? 'Que doit entendre le sommet ?'
                          : 'What should the summit hear?',
                      hintStyle:
                          TextStyle(fontSize: 16, color: Ds.muted(context)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachments.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => _thumb(context, _attachments[i],
                          () => setState(() => _attachments.removeAt(i))),
                    ),
                  ),
                ],
                if (_pollOn) ...[
                  const SizedBox(height: 14),
                  _pollBuilder(context, fr),
                ],
                const SizedBox(height: 18),
                Text(
                  AppLocalizations.of(context).translate('w_category'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Ds.muted(context)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in PostComposer.categories)
                      GestureDetector(
                        onTap: () => setState(() => _category = c['value']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: c['value'] == _category
                                ? Ds.green
                                : Ds.surface(context),
                            border: c['value'] == _category
                                ? null
                                : Border.all(color: Ds.outline(context)),
                            borderRadius: BorderRadius.circular(Ds.rPill),
                          ),
                          child: Text(
                            c['label']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c['value'] == _category
                                  ? Colors.white
                                  : Ds.body(context),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _attachBar(context, fr),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, bool fr) => Container(
        padding: EdgeInsets.fromLTRB(Ds.headerHPad,
            MediaQuery.viewPaddingOf(context).top + 12, Ds.headerHPad, 16),
        decoration: const BoxDecoration(
          color: Ds.green,
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(AppLocalizations.of(context).translate('w_new_post'),
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: Colors.white)),
            ),
            GestureDetector(
              onTap: _canPost && !_busy ? _post : null,
              // Dimming the whole pill left pale-green text on white; the
              // disabled state gets its own fill and ink instead.
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _canPost && !_busy
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(Ds.rPill),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalizations.of(context).translate('w_post'),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _canPost
                                ? Ds.greenDeep
                                : Colors.white.withValues(alpha: 0.9))),
              ),
            ),
          ],
        ),
      );

  Widget _topicBanner(BuildContext context, bool fr) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Ds.tint(context),
          borderRadius: BorderRadius.circular(Ds.rTile),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.forum_rounded, size: 17, color: Ds.greenDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).translate('w_answering'),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Ds.greenDeep)),
                  const SizedBox(height: 3),
                  Text(
                    widget.topic?['title'] as String? ?? '',
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Ds.ink(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _pollBuilder(BuildContext context, bool fr) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Ds.surface(context),
          borderRadius: BorderRadius.circular(Ds.rCard),
          border: Border.all(color: Ds.outline(context)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pollQuestion,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).translate('w_ask_question'),
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Ds.ink(context)),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _pollOn = false),
                  child: Icon(Icons.close_rounded,
                      size: 19, color: Ds.muted(context)),
                ),
              ],
            ),
            Divider(height: 16, color: Ds.hairline(context)),
            for (var i = 0; i < _pollOptions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _pollOptions[i],
                  decoration: InputDecoration(
                    hintText: '${AppLocalizations.of(context).translate('w_option')} ${i + 1}',
                    isDense: true,
                    filled: true,
                    fillColor: Ds.subtle(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Ds.rIcon),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            if (_pollOptions.length < 4)
              GestureDetector(
                onTap: () =>
                    setState(() => _pollOptions.add(TextEditingController())),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, size: 18, color: Ds.green),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).translate('w_add_option'),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Ds.green)),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _thumb(
          BuildContext context, ComposerAttachment a, VoidCallback onRemove) =>
      Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Ds.rTile),
            child: SizedBox(
              width: 96,
              height: 96,
              child: a.isVideo
                  ? Container(
                      color: Ds.greenDarker,
                      child: const Icon(Icons.videocam_rounded,
                          size: 30, color: Colors.white70),
                    )
                  : Image.file(a.file, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child:
                    const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      );

  Widget _attachBar(BuildContext context, bool fr) {
    final full = _attachments.length >= PostComposer.maxAttachments;
    return Container(
      padding: EdgeInsets.fromLTRB(
          8, 6, 16, MediaQuery.viewPaddingOf(context).bottom + 6),
      decoration: BoxDecoration(
        color: Ds.surface(context),
        border: Border(top: BorderSide(color: Ds.hairline(context))),
      ),
      child: Row(
        children: [
          _attachAction(context, Icons.photo_library_rounded,
              AppLocalizations.of(context).translate('w_photo'), !full, () => _add(isVideo: false)),
          _attachAction(context, Icons.videocam_rounded,
              AppLocalizations.of(context).translate('w_video'), !full, () => _add(isVideo: true)),
          _attachAction(context, Icons.bar_chart_rounded,
              AppLocalizations.of(context).translate('w_poll'), !_pollOn,
              () => setState(() => _pollOn = true)),
          const Spacer(),
          Text('${_attachments.length}/${PostComposer.maxAttachments}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Ds.muted(context))),
        ],
      ),
    );
  }

  Widget _attachAction(BuildContext context, IconData icon, String label,
          bool enabled, VoidCallback onTap) =>
      Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Ds.rTile),
          child: InkWell(
            borderRadius: BorderRadius.circular(Ds.rTile),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 21, color: Ds.green),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Ds.ink(context))),
                ],
              ),
            ),
          ),
        ),
      );
}
