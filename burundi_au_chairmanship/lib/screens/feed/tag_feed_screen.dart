import 'package:flutter/material.dart';

import '../../config/app_ds.dart';
import '../../services/api_service.dart';
import '../../widgets/async_content_view.dart';
import '../../widgets/feed/post_card.dart';
import '../../widgets/feed/repost_sheet.dart';
import '../discussions/discussion_detail_screen.dart';
import 'user_profile_screen.dart';

/// Everything posted under one hashtag, or under one admin topic.
class TagFeedScreen extends StatefulWidget {
  final String? tag;
  final int? topicId;
  final String? topicTitle;

  const TagFeedScreen({super.key, this.tag, this.topicId, this.topicTitle});

  @override
  State<TagFeedScreen> createState() => _TagFeedScreenState();
}

class _TagFeedScreenState extends State<TagFeedScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _posts = await _api.getFeed(tag: widget.tag, topicId: widget.topicId);
      _loadFailed = false;
    } catch (_) {
      _posts = [];
      _loadFailed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final title = widget.tag != null ? '#${widget.tag}' : (widget.topicTitle ?? '');

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(Ds.headerHPad,
                MediaQuery.viewPaddingOf(context).top + 12, Ds.headerHPad, 18),
            decoration: const BoxDecoration(
              color: Ds.green,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(Ds.rHeader)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: Ds.green,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Ds.green))
                  : _loadFailed
                      ? AsyncContentView(
                          state: AsyncContentState.error,
                          onRetry: _load,
                          onRefresh: _load,
                          child: const SizedBox.shrink(),
                        )
                  : _posts.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
                          children: [
                            Text(
                              fr
                                  ? 'Personne n\'a encore publié ici.'
                                  : 'Nobody has posted here yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: Ds.body(context)),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                              16, 14, 16, Ds.navSpace(context)),
                          itemCount: _posts.length,
                          itemBuilder: (_, i) {
                            final post = _posts[i];
                            return PostCard(
                              post: post,
                              onRepost: () async {
                                if (await RepostSheet.open(context, post)) _load();
                              },
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DiscussionDetailScreen(
                                      discussionId: post['id'] as int),
                                ),
                              ).then((_) => _load()),
                              onAuthorTap: (id) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(userId: id)),
                              ),
                              onTopicTap: (id, title) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TagFeedScreen(topicId: id, topicTitle: title),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
