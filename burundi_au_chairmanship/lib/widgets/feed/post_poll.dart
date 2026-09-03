import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

/// A poll attached to a post: tap to vote, then the bars reveal the split.
class PostPoll extends StatefulWidget {
  final Map<String, dynamic> poll;

  const PostPoll({super.key, required this.poll});

  @override
  State<PostPoll> createState() => _PostPollState();
}

class _PostPollState extends State<PostPoll> {
  late Map<String, dynamic> _poll = Map<String, dynamic>.from(widget.poll);
  bool _busy = false;

  int? get _myVote => _poll['my_vote'] as int?;
  bool get _voted => _myVote != null;
  bool get _ended => _poll['has_ended'] == true;

  Future<void> _vote(int optionId) async {
    if (_busy || _ended) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.pushNamed(context, '/auth');
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.selectionClick();

    // Optimistic: move the tally locally, then reconcile from the response.
    final previous = Map<String, dynamic>.from(_poll);
    setState(() {
      final options = (_poll['options'] as List).cast<Map<String, dynamic>>();
      for (final o in options) {
        if (o['id'] == optionId) o['vote_count'] = (o['vote_count'] as int) + 1;
        if (o['id'] == _myVote) o['vote_count'] = (o['vote_count'] as int) - 1;
      }
      if (!_voted) _poll['total_votes'] = (_poll['total_votes'] as int? ?? 0) + 1;
      _poll['my_vote'] = optionId;
    });

    try {
      await ApiService().votePoll(_poll['id'] as int, optionId);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _poll = previous);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = (_poll['options'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final total = _poll['total_votes'] as int? ?? 0;
    final revealed = _voted || _ended;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Ds.outline(context)),
        borderRadius: BorderRadius.circular(Ds.rTile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _poll['title'] as String? ?? '',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Ds.ink(context)),
          ),
          const SizedBox(height: 10),
          for (final o in options) _option(context, o, total, revealed),
          const SizedBox(height: 4),
          Text(
            [
              '$total ${total == 1 ? 'vote' : 'votes'}',
              if (_ended) 'closed',
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: Ds.muted(context)),
          ),
        ],
      ),
    );
  }

  Widget _option(
      BuildContext context, Map<String, dynamic> option, int total, bool revealed) {
    final count = option['vote_count'] as int? ?? 0;
    final mine = option['id'] == _myVote;
    final share = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: revealed ? null : () => _vote(option['id'] as int),
        child: Stack(
          children: [
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Ds.subtle(context),
                borderRadius: BorderRadius.circular(Ds.rIcon),
                border: mine ? Border.all(color: Ds.green, width: 1.5) : null,
              ),
            ),
            if (revealed)
              // The fill is the result; it only appears once a vote is cast.
              FractionallySizedBox(
                widthFactor: share.clamp(0.0, 1.0),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: mine ? Ds.tint(context) : Ds.subtle(context),
                    borderRadius: BorderRadius.circular(Ds.rIcon),
                  ),
                ),
              ),
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (mine)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.check_circle_rounded, size: 16, color: Ds.green),
                      ),
                    Expanded(
                      child: Text(
                        option['text'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: mine ? FontWeight.w700 : FontWeight.w600,
                          color: Ds.ink(context),
                        ),
                      ),
                    ),
                    if (revealed)
                      Text('${(share * 100).round()}%',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Ds.body(context))),
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
