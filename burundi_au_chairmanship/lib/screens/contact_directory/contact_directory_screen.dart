import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_colors.dart';

class ContactDirectoryScreen extends StatefulWidget {
  const ContactDirectoryScreen({super.key});

  @override
  State<ContactDirectoryScreen> createState() => _ContactDirectoryScreenState();
}

class _ContactDirectoryScreenState extends State<ContactDirectoryScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      _contacts = await _api.getContactDirectory();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final q = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final dept = (c['department'] ?? '').toString().toLowerCase();
      final title = (c['title'] ?? '').toString().toLowerCase();
      return name.contains(q) || dept.contains(q) || title.contains(q);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedByDepartment {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final c in _filteredContacts) {
      final dept = (c['department'] ?? 'Other').toString();
      map.putIfAbsent(dept, () => []).add(c);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('contact_directory')),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: l10n.translate('search_contacts'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredContacts.isEmpty
                      ? Center(child: Text('No contacts found', style: TextStyle(color: Colors.grey[500])))
                      : RefreshIndicator(
                          onRefresh: _loadContacts,
                          child: ListView(
                            children: _groupedByDepartment.entries.map((entry) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                    child: Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.burundiGreen,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  ...entry.value.map((contact) => _buildContactTile(contact, isDark)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> contact, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: contact['photo'] != null
            ? CircleAvatar(backgroundImage: NetworkImage(contact['photo']), radius: 24)
            : CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.burundiGreen.withValues(alpha: 0.1),
                child: Text(
                  (contact['name'] ?? 'C')[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.burundiGreen),
                ),
              ),
        title: Text(contact['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(contact['title'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contact['phone'] != null && contact['phone'].toString().isNotEmpty)
              IconButton(
                icon: const Icon(Icons.phone, size: 20),
                color: AppColors.burundiGreen,
                onPressed: () => launchUrl(Uri.parse('tel:${contact['phone']}')),
              ),
            if (contact['email'] != null && contact['email'].toString().isNotEmpty)
              IconButton(
                icon: const Icon(Icons.email, size: 20),
                color: const Color(0xFFFFB74D),
                onPressed: () => launchUrl(Uri.parse('mailto:${contact['email']}')),
              ),
          ],
        ),
      ),
    );
  }
}
