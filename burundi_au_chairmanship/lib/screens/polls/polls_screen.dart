import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_colors.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _polls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    setState(() => _loading = true);
    try {
      _polls = await _api.getPolls();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _vote(int pollId, int optionId) async {
    try {
      await _api.votePoll(pollId, optionId);
      _loadPolls();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('polls')),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _polls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ballot, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No active polls', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPolls,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _polls.length,
                    itemBuilder: (context, index) => _buildPollCard(_polls[index], isDark),
                  ),
                ),
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll, bool isDark) {
    final options = (poll['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalVotes = poll['total_votes'] ?? 0;
    final userVoted = poll['user_voted'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.ballot, color: Color(0xFFFFB74D), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    poll['title'] ?? '',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (poll['description'] != null && poll['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(poll['description'], style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
            const SizedBox(height: 16),
            ...options.map((opt) {
              final votes = opt['vote_count'] ?? 0;
              final pct = totalVotes > 0 ? votes / totalVotes : 0.0;
              final isUserChoice = opt['id'] == poll['user_vote_option'];

              return GestureDetector(
                onTap: userVoted ? null : () => _vote(poll['id'], opt['id']),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUserChoice ? AppColors.burundiGreen : Colors.grey.withValues(alpha: 0.3),
                      width: isUserChoice ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      children: [
                        if (userVoted)
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              height: 48,
                              color: (isUserChoice ? AppColors.burundiGreen : Colors.grey).withValues(alpha: 0.1),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              if (!userVoted)
                                Icon(Icons.radio_button_unchecked, size: 18, color: Colors.grey[400]),
                              if (userVoted && isUserChoice)
                                const Icon(Icons.check_circle, size: 18, color: AppColors.burundiGreen),
                              if (userVoted && !isUserChoice)
                                Icon(Icons.circle_outlined, size: 18, color: Colors.grey[400]),
                              const SizedBox(width: 10),
                              Expanded(child: Text(opt['text'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                              if (userVoted) Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              '$totalVotes votes',
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
