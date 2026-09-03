import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../config/app_ds.dart';

class TicketConversationScreen extends StatefulWidget {
  const TicketConversationScreen({super.key});

  @override
  State<TicketConversationScreen> createState() => _TicketConversationScreenState();
}

class _TicketConversationScreenState extends State<TicketConversationScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _ticketId;
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ticketId == null && _error == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final id = args is int ? args : int.tryParse('$args');
      if (id != null) {
        _ticketId = id;
        _loadTicket();
      } else {
        // Bad deep link / missing argument: error state instead of a spinner
        _isLoading = false;
        _error = 'missing_ticket';
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _status => _ticket?['status'] ?? 'open';
  bool get _isClosed => _status == 'closed';
  bool get _isResolved => _status == 'resolved';
  bool get _canReply => !_isClosed;
  bool get _canRate => (_isResolved || _isClosed) && (_ticket?['rating'] == null);
  bool get _hasRated => _ticket?['rating'] != null;

  Future<void> _loadTicket() async {
    if (_ticketId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getTicketDetail(_ticketId!);
      setState(() {
        _ticket = data;
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      // Fire-and-forget: a failed read receipt must not turn into a load error.
      _apiService.markTicketRead(_ticketId!).catchError((_) => <String, dynamic>{});
    } catch (e) {
      if (kDebugMode) debugPrint('Ticket load error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _ticketId == null || !_canReply) return;

    setState(() => _isSending = true);

    try {
      final data = await _apiService.replyToTicket(_ticketId!, text);
      _messageController.clear();
      setState(() {
        _ticket = data;
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        _isSending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e is ApiException
                  ? e.message
                  : AppLocalizations.of(context).translate('sup_failed_to_send')),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _submitRating(int stars, String comment) async {
    if (_ticketId == null) return;

    try {
      final data = await _apiService.rateTicket(_ticketId!, stars, comment: comment);
      setState(() {
        _ticket = data;
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('sup_thanks_feedback')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e is ApiException
                  ? e.message
                  : AppLocalizations.of(context).translate('sup_failed_rating')),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showRatingDialog() {
    int selectedStars = 0;
    final commentController = TextEditingController();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.translate('sup_rate_experience_title'), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.translate('sup_how_was_experience'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return Semantics(
                    button: true,
                    label: '$star/5',
                    child: GestureDetector(
                      onTap: () => setDialogState(() => selectedStars = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          star <= selectedStars ? Icons.star_rounded : Icons.star_border_rounded,
                          color: star <= selectedStars ? Colors.amber : Colors.grey[400],
                          size: 40,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: l10n.translate('sup_additional_feedback'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.translate('maybe_later')),
            ),
            ElevatedButton(
              onPressed: selectedStars > 0
                  ? () {
                      final comment = commentController.text.trim();
                      Navigator.pop(ctx);
                      _submitRating(selectedStars, comment);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.translate('submit')),
            ),
          ],
        ),
      ),
    ).then((_) => commentController.dispose());
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      String time =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

      if (diff.inDays == 0) {
        return time;
      } else if (diff.inDays == 1) {
        return '${AppLocalizations.of(context).translate('sup_yesterday')} $time';
      } else if (diff.inDays < 7) {
        return '${DateFormat.E(Localizations.localeOf(context).languageCode).format(date)} $time';
      }
      return '${date.day}/${date.month} $time';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(
          _ticket?['subject'] ?? l10n.translate('sup_ticket_title'),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_isResolved || _isClosed)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text(
                  l10n.translate(_isClosed ? 'sup_status_closed' : 'sup_status_resolved'),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: Colors.white24,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(l10n.translate(_ticketId == null
                          ? 'sup_ticket_not_found'
                          : 'sup_failed_load_conversation')),
                      if (_ticketId != null)
                        TextButton(onPressed: _loadTicket, child: Text(l10n.translate('retry')))
                      else
                        TextButton(
                            onPressed: () => Navigator.maybePop(context),
                            child: Text(MaterialLocalizations.of(context).backButtonTooltip)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Messages list
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(child: Text(l10n.translate('sup_no_messages')))
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) =>
                                  _buildMessageBubble(_messages[index], isDark),
                            ),
                    ),

                    // Rating card when resolved
                    if (_canRate) _buildRatingPrompt(isDark),

                    // Already rated
                    if (_hasRated) _buildRatedBanner(isDark),

                    // Closed banner
                    if (_isClosed && !_hasRated && !_canRate) _buildClosedBanner(isDark),

                    // Input bar (hidden when closed)
                    if (_canReply) _buildInputBar(isDark),

                    // Closed message
                    if (_isClosed) _buildClosedInputBar(isDark),
                  ],
                ),
    );
  }

  Widget _buildRatingPrompt(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('sup_ticket_resolved'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.translate('sup_please_rate'),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _showRatingDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(l10n.translate('sup_rate'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRatedBanner(bool isDark) {
    final rating = _ticket?['rating'] ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Text('${AppLocalizations.of(context).translate('sup_you_rated')} ', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ...List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber,
            size: 18,
          )),
        ],
      ),
    );
  }

  Widget _buildClosedBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey[500], size: 18),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context).translate('sup_ticket_closed'),
            style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushReplacementNamed(context, '/contact-support'),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context).translate('sup_start_new_ticket')),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.burundiGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isDark) {
    final isAdmin = msg['is_admin_reply'] == true;
    final alignment = isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final bubbleColor = isAdmin
        ? (isDark ? Colors.grey[800]! : Colors.grey[200]!)
        : AppColors.burundiGreen.withValues(alpha: isDark ? 0.3 : 0.15);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: isAdmin ? 4 : 0,
              right: isAdmin ? 0 : 4,
              bottom: 4,
            ),
            child: Text(
              AppLocalizations.of(context).translate(isAdmin ? 'sup_support_team' : 'sup_you'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isAdmin
                    ? AppColors.burundiGreen
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isAdmin ? 4 : 16),
                bottomRight: Radius.circular(isAdmin ? 16 : 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg['message'] ?? '',
                  style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(msg['created_at']),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: MediaQuery.of(context).viewPadding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: l10n.translate(_isResolved ? 'sup_reply_reopen' : 'sup_type_message'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  onPressed: _sendMessage,
                  tooltip: l10n.translate('send'),
                  icon: const Icon(Icons.send_rounded, color: AppColors.burundiGreen),
                  iconSize: 28,
                ),
        ],
      ),
    );
  }
}
