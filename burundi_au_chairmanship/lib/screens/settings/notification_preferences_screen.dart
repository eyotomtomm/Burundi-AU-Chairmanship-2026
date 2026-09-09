import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../widgets/async_content_view.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _prefs = {};
  bool _loading = true;
  String? _error;

  // Feature toggles from admin
  bool _discussionsFeatureEnabled = true;
  bool _pollsFeatureEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadFeatureFlags();
    _load();
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _discussionsFeatureEnabled = prefs.getBool('feature_discussions_enabled') ?? true;
          _pollsFeatureEnabled = prefs.getBool('feature_polls_enabled') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _prefs = await _api.getNotificationPreferences();
    } catch (e) {
      // Don't render every toggle as "on" when we don't actually know.
      if (mounted) {
        _error = e is ApiException
            ? e.message
            : AppLocalizations.of(context).translate('st_could_not_load_prefs');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updatePref(String key, bool value) async {
    setState(() => _prefs[key] = value);
    try {
      await _api.updateNotificationPreferences({key: value});
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs[key] = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException
            ? e.message
            : AppLocalizations.of(context).translate('st_could_not_save_pref')),
        backgroundColor: Ds.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: Text(l10n.translate('notification_preferences'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? AsyncContentView(
                  state: AsyncContentState.error,
                  errorSubtitle: _error,
                  onRetry: _load,
                  child: const SizedBox.shrink(),
                )
              : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              children: [
                // Master switch sits alone in the comp, on a green-tinted icon.
                DsTileGroup(children: [
                  _toggle('push_enabled', l10n.translate('st_push_notifications'),
                      Icons.notifications_active_rounded, primary: true),
                  _toggle('email_enabled', l10n.translate('st_email_notifications'),
                      Icons.mail_rounded, primary: true),
                ]),
                DsGroupLabel(l10n.translate('st_topics'),
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8)),
                DsTileGroup(children: [
                  _toggle('articles_enabled',
                      l10n.translate('st_breaking_news'), Icons.newspaper_rounded),
                  _toggle('events_enabled',
                      l10n.translate('st_event_reminders'), Icons.event_rounded),
                  _toggle('live_feeds_enabled',
                      l10n.translate('st_live_alerts'), Icons.live_tv_rounded),
                  _toggle('magazines_enabled',
                      l10n.translate('st_new_issues'), Icons.auto_stories_rounded),
                ]),
                DsGroupLabel(l10n.translate('st_engagement'),
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8)),
                DsTileGroup(children: [
                  if (_discussionsFeatureEnabled)
                    _toggle('discussions_enabled',
                        l10n.translate('discussions'), Icons.forum_rounded),
                  if (_pollsFeatureEnabled)
                    _toggle('polls_enabled', l10n.translate('polls'), Icons.ballot_rounded),
                  _toggle('messages_enabled', l10n.translate('st_messages'), Icons.chat_rounded),
                ]),
                DsGroupLabel(l10n.translate('st_schedule'),
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8)),
                DsTileGroup(children: [
                  _toggle('quiet_hours_enabled',
                      l10n.translate('st_quiet_hours'), Icons.nights_stay_rounded),
                ]),
                DsFootnote(l10n.translate('st_quiet_hours_note')),
              ],
            ),
    );
  }

  Widget _toggle(String key, String title, IconData icon, {bool primary = false}) {
    final value = _prefs[key] ?? true;
    return DsTile(
      icon: icon,
      iconTint: primary ? Ds.tint(context) : null,
      iconColor: primary ? Ds.green : null,
      title: title,
      onTap: () => _updatePref(key, !value),
      trailing: DsSwitch(value: value, onChanged: (v) => _updatePref(key, v)),
    );
  }
}
