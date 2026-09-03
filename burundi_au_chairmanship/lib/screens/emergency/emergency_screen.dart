import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../providers/language_provider.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  String? _error;
  String _sosTitle = 'Emergency / SOS';
  String _sosTitleFr = 'Urgence / SOS';
  bool _liveAgentOnline = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getEmergencyContacts(),
        api.getSettings(),
      ]);
      if (mounted) {
        final settings = results[1] as AppSettingsModel?;
        setState(() {
          _contacts = results[0] as List<Map<String, dynamic>>;
          if (settings != null) {
            _sosTitle = settings.sosTitle.isNotEmpty ? settings.sosTitle : 'Emergency / SOS';
            _sosTitleFr = settings.sosTitleFr.isNotEmpty ? settings.sosTitleFr : 'Urgence / SOS';
            _liveAgentOnline = settings.liveAgentOnline;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load emergency contacts';
          _isLoading = false;
        });
      }
    }
  }

  IconData _iconFromName(String? name) {
    const map = {
      'local_police': Icons.local_police,
      'local_fire_department': Icons.local_fire_department,
      'medical_services': Icons.medical_services,
      'local_hospital': Icons.local_hospital,
      'health_and_safety': Icons.health_and_safety,
      'support_agent': Icons.support_agent,
      'emergency': Icons.emergency,
      'shield': Icons.shield,
      'phone': Icons.phone,
      'sos': Icons.sos,
    };
    return map[name] ?? Icons.phone;
  }

  Future<void> _handleAction(Map<String, dynamic> contact) async {
    HapticFeedback.mediumImpact();
    final actionType = contact['action_type'] as String? ?? 'call';
    final value = contact['contact_value'] as String? ?? '';

    if (actionType == 'route') {
      if (mounted) Navigator.pushNamed(context, value);
      return;
    }

    Uri? uri;
    switch (actionType) {
      case 'call':
        uri = Uri.parse('tel:$value');
        break;
      case 'sms':
        uri = Uri.parse('sms:$value');
        break;
      case 'email':
        uri = Uri.parse('mailto:$value');
        break;
      case 'whatsapp':
      case 'url':
        uri = Uri.parse(value);
        break;
    }

    if (uri != null) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $value')),
          );
        }
      }
    }
  }

  Future<void> _handleLiveAgent() async {
    HapticFeedback.mediumImpact();
    if (!_liveAgentOnline) return;
    try {
      final api = ApiService();
      final result = await api.createTicket(
        'Live Chat Support',
        'Started a live chat session.',
      );
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/ticket-conversation',
          arguments: result['id'],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start live chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _categoryLabel(String? category, [String langCode = 'en']) {
    if (langCode == 'fr') {
      switch (category) {
        case 'police':
          return 'Police';
        case 'fire':
          return 'Pompiers';
        case 'medical':
          return 'Services Médicaux';
        case 'support':
          return 'Assistance';
        default:
          return 'Autres Services';
      }
    }
    switch (category) {
      case 'police':
        return 'Police';
      case 'fire':
        return 'Fire';
      case 'medical':
        return 'Medical Services';
      case 'support':
        return 'Support';
      default:
        return 'Other Services';
    }
  }

  /// The number the big SOS control dials — the first "call" contact the
  /// backend returns, so admins control it without an app release.
  Map<String, dynamic>? get _primaryCall {
    for (final c in _contacts) {
      if ((c['action_type'] as String? ?? 'call') == 'call') return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<LanguageProvider>().languageCode;
    final fr = langCode == 'fr';
    final title = fr ? _sosTitleFr : _sosTitle;

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Ds.muted(context)),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Ds.body(context))),
                      const SizedBox(height: 16),
                      DsOutlineButton(fr ? 'Réessayer' : 'Retry',
                          radius: Ds.rPill,
                          onTap: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _loadContacts();
                          }),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Ds.green,
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await _loadContacts();
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      DsHeader(
                        title: title,
                        color: Ds.redDeep,
                        bottomPad: 24,
                        bottom: _buildSosDial(fr),
                      ),
                      const SizedBox(height: 16),
                      _buildLiveAgentCard(fr),
                      ..._buildCategorySections(fr),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSosDial(bool fr) {
    final primary = _primaryCall;
    return Column(
      children: [
        const SizedBox(height: 6),
        GestureDetector(
          onLongPress: primary == null ? null : () => _handleAction(primary),
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: Ds.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.white.withValues(alpha: 0.12),
                    spreadRadius: 14,
                    blurRadius: 0),
                BoxShadow(
                    color: Colors.white.withValues(alpha: 0.06),
                    spreadRadius: 28,
                    blurRadius: 0),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('SOS',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(fr ? 'Maintenir 3 s' : 'Hold 3 sec',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          fr
              ? "Appelle le service d'urgence principal · Envoie votre position"
              : 'Calls the primary emergency line · Sends your location',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
        ),
      ],
    );
  }

  Widget _buildLiveAgentCard(bool fr) {
    return DsTileGroup(children: [
      DsTile(
        icon: Icons.support_agent_rounded,
        iconTint: _liveAgentOnline ? Ds.tint(context) : Ds.subtle(context),
        iconColor: _liveAgentOnline ? Ds.green : Ds.muted(context),
        title: fr ? 'Agent en direct' : 'Live agent',
        subtitle: _liveAgentOnline
            ? (fr ? 'En ligne · Répond maintenant' : 'Online · Responding now')
            : (fr ? 'Hors ligne' : 'Offline'),
        chevron: _liveAgentOnline,
        onTap: _liveAgentOnline ? _handleLiveAgent : null,
      ),
    ]);
  }

  List<Widget> _buildCategorySections(bool fr) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final c in _contacts) {
      grouped.putIfAbsent(c['category'] as String? ?? 'other', () => []).add(c);
    }

    if (grouped.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
          child: Column(
            children: [
              Icon(Icons.phone_disabled_rounded, size: 48, color: Ds.muted(context)),
              const SizedBox(height: 12),
              Text(
                fr
                    ? "Aucun contact d'urgence disponible"
                    : 'No emergency contacts available',
                textAlign: TextAlign.center,
                style: TextStyle(color: Ds.body(context)),
              ),
            ],
          ),
        ),
      ];
    }

    final langCode = fr ? 'fr' : 'en';
    return [
      for (final entry in grouped.entries) ...[
        DsGroupLabel(_categoryLabel(entry.key, langCode),
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8)),
        DsTileGroup(
          children: [
            for (final contact in entry.value) _buildContactTile(contact, langCode),
          ],
        ),
      ],
    ];
  }

  Widget _buildContactTile(Map<String, dynamic> contact, String langCode) {
    final fr = langCode == 'fr';
    final icon = _iconFromName(contact['icon_name'] as String?);
    final name = (fr && (contact['name_fr'] as String? ?? '').isNotEmpty)
        ? contact['name_fr'] as String
        : contact['name_en'] as String? ?? '';
    final description = (fr && (contact['description_fr'] as String? ?? '').isNotEmpty)
        ? contact['description_fr'] as String
        : contact['description_en'] as String? ?? '';
    final actionType = contact['action_type'] as String? ?? 'call';
    final contactValue = contact['contact_value'] as String? ?? '';
    final isEmergencyLine = actionType == 'call';

    return DsTile(
      icon: icon,
      // Emergency lines get the red tint; support contacts get the green one.
      iconTint: isEmergencyLine ? Ds.redTintOf(context) : Ds.tint(context),
      iconColor: isEmergencyLine ? Ds.red : Ds.green,
      title: name,
      subtitle: description.isEmpty ? null : description,
      value: contactValue.isEmpty ? null : contactValue,
      onTap: () => _handleAction(contact),
    );
  }
}
