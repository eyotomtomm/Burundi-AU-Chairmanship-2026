import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _prefs = {};
  bool _loading = true;

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
    setState(() => _loading = true);
    try {
      _prefs = await _api.getNotificationPreferences();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updatePref(String key, bool value) async {
    setState(() => _prefs[key] = value);
    try {
      await _api.updateNotificationPreferences({key: value});
    } catch (_) {
      if (mounted) setState(() => _prefs[key] = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: Text(l10n.translate('notification_preferences'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              children: [
                // Master switch sits alone in the comp, on a green-tinted icon.
                DsTileGroup(children: [
                  _toggle('push_enabled', fr ? 'Notifications push' : 'Push notifications',
                      Icons.notifications_active_rounded, primary: true),
                  _toggle('email_enabled', fr ? 'Notifications e-mail' : 'Email notifications',
                      Icons.mail_rounded, primary: true),
                ]),
                DsGroupLabel(fr ? 'Sujets' : 'Topics',
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8)),
                DsTileGroup(children: [
                  _toggle('articles_enabled',
                      fr ? 'Actualités' : 'Breaking news', Icons.newspaper_rounded),
                  _toggle('events_enabled',
                      fr ? 'Rappels d’événements' : 'Event reminders', Icons.event_rounded),
                  _toggle('live_feeds_enabled',
                      fr ? 'Alertes de direct' : 'Live stream alerts', Icons.live_tv_rounded),
                  _toggle('magazines_enabled',
                      fr ? 'Nouveaux numéros' : 'New magazine issues', Icons.auto_stories_rounded),
                ]),
                DsGroupLabel(fr ? 'Participation' : 'Engagement',
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8)),
                DsTileGroup(children: [
                  if (_discussionsFeatureEnabled)
                    _toggle('discussions_enabled',
                        fr ? 'Discussions' : 'Discussions', Icons.forum_rounded),
                  if (_pollsFeatureEnabled)
                    _toggle('polls_enabled', fr ? 'Sondages' : 'Polls', Icons.ballot_rounded),
                  _toggle('messages_enabled', fr ? 'Messages' : 'Messages', Icons.chat_rounded),
                ]),
                DsGroupLabel(fr ? 'Horaires' : 'Schedule',
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8)),
                DsTileGroup(children: [
                  _toggle('quiet_hours_enabled',
                      fr ? 'Heures silencieuses' : 'Quiet hours', Icons.nights_stay_rounded),
                ]),
                DsFootnote(fr
                    ? 'Heures silencieuses 22:00–07:00 · Les notifications sont muettes la nuit.'
                    : 'Quiet hours 22:00–07:00.'),
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
