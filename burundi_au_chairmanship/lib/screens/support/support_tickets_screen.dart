import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loading.dart';

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

  void _checkForUnratedResolved() {
    final unrated = _tickets.where((t) =>
        t['status'] == 'resolved' && (t['rating'] == null || t['rating'] == 0));
    if (unrated.isNotEmpty) {
      // Show rating dialog for the first unrated resolved ticket
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRatingDialog(unrated.first);
      });
    }
  }

  Future<void> _showRatingDialog(Map<String, dynamic> ticket) async {
    int selectedRating = 0;
    final commentController = TextEditingController();

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
              title: const Text('Rate Your Support'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your ticket "${ticket['subject']}" has been resolved. How was your experience?',
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
                      hintText: 'Optional comment...',
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: selectedRating > 0
                      ? () async {
                          try {
                            await _apiService.rateTicket(
                              ticket['id'],
                              selectedRating,
                              comment: commentController.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Thank you for your feedback!'),
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
                                  content: Text('Failed to submit rating: $e'),
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
                  child: const Text('Submit'),
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
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: const Text('Support')),
      body: _isLoading
          ? const ShimmerListItemSkeleton()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Ds.muted(context)),
                      const SizedBox(height: 16),
                      Text('Failed to load tickets',
                          style: TextStyle(color: Ds.body(context))),
                      const SizedBox(height: 16),
                      DsOutlineButton('Retry', radius: Ds.rPill, onTap: _loadTickets),
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
                        const DsGroupLabel('My tickets',
                            padding: EdgeInsets.fromLTRB(22, 20, 22, 8)),
                        for (final ticket in _tickets) _buildTicketCard(ticket),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildNewTicketCard() {
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
                Text('New ticket',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Ds.ink(context))),
                const SizedBox(height: 2),
                Text('Nouveau ticket', style: Ds.meta(context)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Ds.chevron),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          Icon(Icons.support_agent_rounded, size: 64, color: Ds.muted(context)),
          const SizedBox(height: 16),
          Text('No support tickets',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Ds.ink(context))),
          const SizedBox(height: 8),
          Text('Open a ticket above and our team will get back to you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: Ds.body(context))),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final status = (ticket['status'] ?? 'open').toString();
    final rating = ticket['rating'] as int? ?? 0;
    final reference = ticket['id'] == null ? '' : '#T-${ticket['id']}';
    final meta = [
      if (reference.isNotEmpty) reference,
      if (_timeAgo(ticket['updated_at']).isNotEmpty)
        'Updated ${_timeAgo(ticket['updated_at'])}',
    ].join(' · ');

    return DsCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket['subject'] ?? 'No subject',
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
