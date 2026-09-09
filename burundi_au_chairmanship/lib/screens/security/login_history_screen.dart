import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_ds.dart';
import '../../widgets/async_content_view.dart';

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _history = await _api.getLoginHistory();
    } catch (e) {
      if (mounted) {
        _error = e is ApiException
            ? e.message
            : AppLocalizations.of(context).translate('sec_could_not_load_history');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'firebase_google': return Icons.g_mobiledata;
      case 'firebase_apple': return Icons.apple;
      case 'firebase_email': return Icons.email;
      default: return Icons.lock;
    }
  }

  String _formatTime(BuildContext context, dynamic iso) {
    if (iso == null) return '';
    try {
      final date = DateTime.parse(iso.toString()).toLocal();
      return DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(date);
    } catch (_) {
      return iso.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _loading
        ? AsyncContentState.loading
        : _error != null
            ? AsyncContentState.error
            : _history.isEmpty
                ? AsyncContentState.empty
                : AsyncContentState.content;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(l10n.translate('login_history')),
      ),
      body: AsyncContentView(
        state: state,
        loadingWidget: const Center(child: CircularProgressIndicator()),
        errorSubtitle: _error,
        emptyIcon: Icons.history_rounded,
        emptyMessage: l10n.translate('sec_no_login_history'),
        onRetry: _load,
        onRefresh: _load,
        child: RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await _load();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      final success = entry['success'] ?? true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Ds.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: success
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (success ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                success ? Icons.check_circle : Icons.error,
                                color: success ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(_methodIcon(entry['method'] ?? ''), size: 16, color: Ds.muted(context)),
                                      const SizedBox(width: 6),
                                      Text(
                                        (entry['method'] ?? 'email').toString().replaceAll('_', ' ').toUpperCase(),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Ds.muted(context)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(context, entry['created_at']),
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  if (entry['ip_address'] != null)
                                    Text('IP: ${entry['ip_address']}', style: TextStyle(fontSize: 12, color: Ds.muted(context))),
                                  if (entry['device_info'] != null && entry['device_info'].toString().isNotEmpty)
                                    Text(entry['device_info'], style: TextStyle(fontSize: 12, color: Ds.muted(context))),
                                ],
                              ),
                            ),
                            Text(
                              l10n.translate(success ? 'success' : 'sec_failed'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: success ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}
