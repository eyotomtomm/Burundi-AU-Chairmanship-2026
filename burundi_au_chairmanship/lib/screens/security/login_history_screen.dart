import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _history = await _api.getLoginHistory();
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('login_history')),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No login history'))
              : RefreshIndicator(
                  onRefresh: _load,
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
                          color: isDark ? Colors.grey[850] : Colors.white,
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
                                      Icon(_methodIcon(entry['method'] ?? ''), size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 6),
                                      Text(
                                        (entry['method'] ?? 'email').toString().replaceAll('_', ' ').toUpperCase(),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry['created_at'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  if (entry['ip_address'] != null)
                                    Text('IP: ${entry['ip_address']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  if (entry['device_info'] != null && entry['device_info'].toString().isNotEmpty)
                                    Text(entry['device_info'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            Text(
                              success ? 'Success' : 'Failed',
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
    );
  }
}
