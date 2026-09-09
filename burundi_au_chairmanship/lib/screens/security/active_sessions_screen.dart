import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/async_content_view.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _sessions = [];
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
      _sessions = await _api.getActiveSessions();
    } catch (e) {
      if (mounted) {
        _error = e is ApiException
            ? e.message
            : AppLocalizations.of(context).translate('sec_could_not_load_sessions');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _revokeSession(int sessionId) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('sec_revoke_session')),
        content: Text(l10n.translate('sec_revoke_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('sec_revoke'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.revokeSession(sessionId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : l10n.translate('sec_could_not_revoke')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  String _formatTime(BuildContext context, dynamic iso) {
    if (iso == null) return AppLocalizations.of(context).translate('unknown');
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
            : _sessions.isEmpty
                ? AsyncContentState.empty
                : AsyncContentState.content;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(l10n.translate('active_sessions')),
      ),
      body: AsyncContentView(
        state: state,
        loadingWidget: const Center(child: CircularProgressIndicator()),
        errorSubtitle: _error,
        emptyIcon: Icons.devices_rounded,
        emptyMessage: l10n.translate('sec_no_active_sessions'),
        onRetry: _load,
        onRefresh: _load,
        child: RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await _load();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final isCurrent = session['is_current'] ?? false;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Ds.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: isCurrent
                              ? Border.all(color: AppColors.burundiGreen, width: 2)
                              : null,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isCurrent ? AppColors.burundiGreen : Colors.grey).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                session['device_name']?.toString().toLowerCase().contains('iphone') == true
                                    ? Icons.phone_iphone
                                    : Icons.devices,
                                color: isCurrent ? AppColors.burundiGreen : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          session['device_name'] ?? l10n.translate('sec_unknown_device'),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.burundiGreen.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(l10n.translate('sec_current'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.burundiGreen)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (session['ip_address'] != null)
                                    Text('IP: ${session['ip_address']}', style: TextStyle(fontSize: 12, color: Ds.muted(context))),
                                  Text('${l10n.translate('sec_last_active')}: ${_formatTime(context, session['last_active'])}', style: TextStyle(fontSize: 12, color: Ds.muted(context))),
                                ],
                              ),
                            ),
                            if (!isCurrent && session['id'] is int)
                              IconButton(
                                onPressed: () => _revokeSession(session['id'] as int),
                                icon: const Icon(Icons.logout, color: Colors.red),
                                tooltip: l10n.translate('sec_revoke'),
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
