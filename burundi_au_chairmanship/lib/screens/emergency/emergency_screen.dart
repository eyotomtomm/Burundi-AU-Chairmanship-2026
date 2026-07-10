import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../providers/language_provider.dart';
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
        final settings = results[1];
        setState(() {
          _contacts = results[0] as List<Map<String, dynamic>>;
          if (settings != null) {
            _sosTitle = (settings.sosTitle.isNotEmpty) ? settings.sosTitle : 'Emergency / SOS';
            _sosTitleFr = (settings.sosTitleFr.isNotEmpty) ? settings.sosTitleFr : 'Urgence / SOS';
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

  Color _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.burundiRed;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  IconData _iconFromName(String? name) {
    const map = {
      'local_police': Icons.local_police,
      'local_fire_department': Icons.local_fire_department,
      'medical_services': Icons.medical_services,
      'support_agent': Icons.support_agent,
      'emergency': Icons.emergency,
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

  String _categoryLabel(String? category) {
    switch (category) {
      case 'police':
        return 'Police';
      case 'fire':
        return 'Fire';
      case 'medical':
        return 'Medical';
      case 'support':
        return 'Support';
      default:
        return 'Other';
    }
  }

  String _actionLabel(String? actionType) {
    switch (actionType) {
      case 'call':
        return 'Call';
      case 'whatsapp':
        return 'WhatsApp';
      case 'sms':
        return 'SMS';
      case 'email':
        return 'Email';
      case 'url':
        return 'Open';
      case 'route':
        return 'Open';
      default:
        return 'Contact';
    }
  }

  IconData _actionIcon(String? actionType) {
    switch (actionType) {
      case 'call':
        return Icons.call;
      case 'whatsapp':
        return Icons.chat;
      case 'sms':
        return Icons.sms;
      case 'email':
        return Icons.email;
      case 'url':
        return Icons.open_in_new;
      case 'route':
        return Icons.arrow_forward;
      default:
        return Icons.call;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCode = context.watch<LanguageProvider>().languageCode;
    final title = langCode == 'fr' ? _sosTitleFr : _sosTitle;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48,
                          color: isDark ? Colors.white54 : Colors.grey),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadContacts();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await _loadContacts();
                  },
                  child: CustomScrollView(
                    slivers: [
                      // App Bar
                      SliverAppBar(
                        expandedHeight: 140,
                        pinned: true,
                        backgroundColor: const Color(0xFFE53935),
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFE53935),
                                  Color(0xFFB71C1C),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                Icon(
                                  Icons.sos,
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Info banner
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935)
                                  .withValues(alpha: isDark ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFE53935)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFE53935)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    langCode == 'fr'
                                        ? 'En cas d\'urgence, contactez immédiatement les services ci-dessous.'
                                        : 'In case of emergency, immediately contact the services below.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Live Agent card
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildLiveAgentCard(isDark, langCode),
                        ),
                      ),

                      // Contacts grouped by category
                      ..._buildCategorySections(isDark, langCode),

                      const SliverPadding(
                          padding: EdgeInsets.only(bottom: 20)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLiveAgentCard(bool isDark, String langCode) {
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final agentColor = _liveAgentOnline ? AppColors.burundiGreen : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _liveAgentOnline ? () => _handleLiveAgent() : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: agentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(Icons.support_agent_rounded,
                        color: agentColor, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Live Agent',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _liveAgentOnline
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _liveAgentOnline
                                  ? Colors.green
                                  : Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _liveAgentOnline ? 'ONLINE' : 'OFFLINE',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _liveAgentOnline
                            ? (langCode == 'fr'
                                ? 'Réponse rapide via le chat support'
                                : 'Quick response via support chat')
                            : (langCode == 'fr'
                                ? 'Aucun agent disponible pour le moment'
                                : 'No agents available right now'),
                        style: TextStyle(
                          fontSize: 13,
                          color: _liveAgentOnline
                              ? (isDark ? Colors.white60 : Colors.grey[600])
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_liveAgentOnline)
                  Icon(Icons.chevron_right,
                      color: isDark ? Colors.white54 : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategorySections(bool isDark, String langCode) {
    // Group contacts by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final c in _contacts) {
      final cat = c['category'] as String? ?? 'other';
      grouped.putIfAbsent(cat, () => []);
      grouped[cat]!.add(c);
    }

    if (grouped.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_disabled, size: 48,
                    color: isDark ? Colors.white38 : Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  langCode == 'fr'
                      ? 'Aucun contact d\'urgence disponible'
                      : 'No emergency contacts available',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // Render each category section
    final sections = <Widget>[];
    for (final entry in grouped.entries) {
      // Section header
      sections.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              _categoryLabel(entry.key),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ),
      );

      // Contact cards
      sections.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= entry.value.length) return null;
                return _buildContactCard(entry.value[index], isDark, langCode);
              },
              childCount: entry.value.length,
            ),
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildContactCard(
      Map<String, dynamic> contact, bool isDark, String langCode) {
    final color = _parseHexColor(contact['color'] as String?);
    final icon = _iconFromName(contact['icon_name'] as String?);
    final name = (langCode == 'fr' && (contact['name_fr'] as String? ?? '').isNotEmpty)
        ? contact['name_fr'] as String
        : contact['name_en'] as String? ?? '';
    final description =
        (langCode == 'fr' && (contact['description_fr'] as String? ?? '').isNotEmpty)
            ? contact['description_fr'] as String
            : contact['description_en'] as String? ?? '';
    final actionType = contact['action_type'] as String? ?? 'call';
    final contactValue = contact['contact_value'] as String? ?? '';
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleAction(contact),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                ),

                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (actionType == 'call' ||
                          actionType == 'sms' ||
                          actionType == 'email') ...[
                        const SizedBox(height: 6),
                        Text(
                          contactValue,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Action button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_actionIcon(actionType), size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        _actionLabel(actionType),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
