import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../l10n/app_localizations.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tickets = await _apiService.getTickets();
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
      _checkForUnratedResolved();
    } catch (e) {
      if (kDebugMode) debugPrint('Tickets load error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  static const _dismissedKey = 'dismissed_rating_ticket_ids';

  Future<void> _checkForUnratedResolved() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_dismissedKey) ?? const [];
    final unrated = _tickets.where((t) =>
        t['status'] == 'resolved' &&
        (t['rating'] == null || t['rating'] == 0) &&
        !dismissed.contains('${t['id']}'));
    if (unrated.isNotEmpty && mounted) {
      // Show rating dialog for the first unrated resolved ticket
      _showRatingDialog(unrated.first);
    }
  }

  /// Remember a skipped rating so the modal doesn't come back every load.
  Future<void> _dismissRating(dynamic ticketId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_dismissedKey) ?? [];
    if (!ids.contains('$ticketId')) {
      await prefs.setStringList(_dismissedKey, [...ids, '$ticketId']);
    }
  }

  Future<void> _showRatingDialog(Map<String, dynamic> ticket) async {
    int selectedRating = 0;
    bool submitting = false;
    final commentController = TextEditingController();
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(l10n.translate('sup_rate_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.translate('sup_ticket_resolved_prefix')} "${ticket['subject']}" ${l10n.translate('sup_ticket_resolved_suffix')}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        onPressed: () {
                          setDialogState(() => selectedRating = star);
                        },
                        icon: Icon(
                          star <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 36,
                          color: star <= selectedRating
                              ? Colors.amber
                              : Colors.grey,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: l10n.translate('sup_optional_comment'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          _dismissRating(ticket['id']);
                          Navigator.pop(ctx);
                        },
                  child: Text(l10n.translate('skip')),
                ),
                ElevatedButton(
                  onPressed: selectedRating > 0 && !submitting
                      ? () async {
                          setDialogState(() => submitting = true);
                          try {
                            await _apiService.rateTicket(
                              ticket['id'],
                              selectedRating,
                              comment: commentController.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.translate('sup_thanks_feedback')),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _loadTickets();
                            }
                          } catch (e) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e is ApiException
                                      ? e.message
                                      : l10n.translate('sup_failed_rating')),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burundiGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.translate('submit')),
                ),
              ],
            );
          },
        );
      },
    );
    commentController.dispose();
  }

  DsTone _statusTone(String status) {
    switch (status) {
      case 'open':
        return DsTone.gold;
      case 'in_progress':
      case 'resolved':
        return DsTone.green;
      default:
        return DsTone.neutral;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
      case 'in_progress':
      case 'resolved':
      case 'closed':
        return AppLocalizations.of(context).translate('sup_status_$status');
      default:
        return status;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final l10n = AppLocalizations.of(context);
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return l10n.translate('just_now');
      if (diff.inMinutes < 60) return '${diff.inMinutes} ${l10n.translate('minutes_ago')}';
      if (diff.inHours < 24) return '${diff.inHours}${l10n.translate('hours_ago')}';
      if (diff.inDays < 7) return '${diff.inDays}${l10n.translate('days_ago')}';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: Text(l10n.translate('sup_title'))),
      body: _isLoading
          ? const ShimmerListItemSkeleton()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Ds.muted(context)),
                      const SizedBox(height: 16),
                      Text(l10n.translate('sup_failed_load_tickets'),
                          style: TextStyle(color: Ds.body(context))),
                      const SizedBox(height: 16),
                      DsOutlineButton(l10n.translate('retry'), radius: Ds.rPill, onTap: _loadTickets),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Ds.green,
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await _loadTickets();
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _buildNewTicketCard(),
                      if (_tickets.isEmpty)
                        _buildEmptyState()
                      else ...[
                        DsGroupLabel(l10n.translate('sup_my_tickets'),
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 8)),
                        for (final ticket in _tickets) _buildTicketCard(ticket),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildNewTicketCard() {
    final l10n = AppLocalizations.of(context);
    return DsCard(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      onTap: () async {
        HapticFeedback.lightImpact();
        final result = await Navigator.pushNamed(context, '/contact-support');
        if (result == true) _loadTickets();
      },
      child: Row(
        children: [
          DsIconSquare(Icons.chat_rounded,
              tint: Ds.tint(context), color: Ds.green, size: 44, radius: Ds.rTile),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate('sup_new_ticket'),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Ds.ink(context))),
                const SizedBox(height: 2),
                Text(l10n.translate('sup_new_ticket_sub'), style: Ds.meta(context)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Ds.chevron),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          Icon(Icons.support_agent_rounded, size: 64, color: Ds.muted(context)),
          const SizedBox(height: 16),
          Text(l10n.translate('sup_no_tickets'),
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Ds.ink(context))),
          const SizedBox(height: 8),
          Text(l10n.translate('sup_no_tickets_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: Ds.body(context))),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final l10n = AppLocalizations.of(context);
    final status = (ticket['status'] ?? 'open').toString();
    final rating = ticket['rating'] as int? ?? 0;
    final reference = ticket['id'] == null ? '' : '#T-${ticket['id']}';
    final meta = [
      if (reference.isNotEmpty) reference,
      if (_timeAgo(ticket['updated_at']).isNotEmpty)
        '${l10n.translate('sup_updated')} ${_timeAgo(ticket['updated_at'])}',
    ].join(' · ');

    return DsCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: ticket['id'] is int
          ? () => Navigator.pushNamed(context, '/ticket-conversation',
                  arguments: ticket['id'] as int)
              .then((_) => _loadTickets())
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket['subject'] ?? l10n.translate('sup_no_subject'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ds.cardTitle(context),
                ),
              ),
              const SizedBox(width: 8),
              DsPill(_statusLabel(status), tone: _statusTone(status), dense: true),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(meta, style: Ds.meta(context)),
          ],
          if (status == 'resolved' && rating > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (i) => Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: i < rating ? Ds.gold : Ds.outline(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
