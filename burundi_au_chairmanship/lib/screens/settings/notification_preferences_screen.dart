import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_colors.dart';

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
      setState(() => _prefs[key] = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('notification_preferences')),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('General', [
                  _buildToggle('push_enabled', 'Push Notifications', 'Receive push notifications', Icons.notifications),
                  _buildToggle('email_enabled', 'Email Notifications', 'Receive email updates', Icons.email),
                ], isDark),
                const SizedBox(height: 16),
                _buildSection('Content', [
                  _buildToggle('articles_enabled', 'News', 'New news published', Icons.article),
                  _buildToggle('magazines_enabled', 'Magazines', 'New magazine editions', Icons.menu_book),
                  _buildToggle('events_enabled', 'Events', 'Upcoming events', Icons.event),
                  _buildToggle('live_feeds_enabled', 'Live Feeds', 'Live stream notifications', Icons.live_tv),
                ], isDark),
                const SizedBox(height: 16),
                _buildSection('Engagement', [
                  if (_discussionsFeatureEnabled)
                    _buildToggle('discussions_enabled', 'Discussions', 'Forum replies and mentions', Icons.forum),
                  if (_pollsFeatureEnabled)
                    _buildToggle('polls_enabled', 'Polls', 'New polls available', Icons.ballot),
                  _buildToggle('messages_enabled', 'Messages', 'Direct messages', Icons.chat),
                ], isDark),
                const SizedBox(height: 16),
                _buildSection('Schedule', [
                  _buildToggle('quiet_hours_enabled', 'Quiet Hours', 'Mute notifications during set hours', Icons.nights_stay),
                ], isDark),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggle(String key, String title, String subtitle, IconData icon) {
    return SwitchListTile(
      value: _prefs[key] ?? true,
      onChanged: (v) => _updatePref(key, v),
      title: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.burundiGreen),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ),
      activeColor: AppColors.burundiGreen,
    );
  }
}
