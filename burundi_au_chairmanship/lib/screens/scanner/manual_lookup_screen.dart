import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import 'qr_scan_result_screen.dart';
import '../../config/app_ds.dart';
import '../../l10n/app_localizations.dart';

class ManualLookupScreen extends StatefulWidget {
  final String? mode;
  final String? programmeName;

  const ManualLookupScreen({super.key, this.mode, this.programmeName});

  @override
  State<ManualLookupScreen> createState() => _ManualLookupScreenState();
}

class _ManualLookupScreenState extends State<ManualLookupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // By Code tab
  final _codeController = TextEditingController();

  // By Name & Email tab
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // By Name tab (name search with optional filters)
  final _nameSearchController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _roleController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _error = null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _nameSearchController.dispose();
    _nationalityController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _lookupByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).translate('scan_enter_code_error'));
      return;
    }
    await _performLookup(lookupType: 'code', code: code);
  }

  Future<void> _lookupByNameEmail() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).translate('scan_name_email_required'));
      return;
    }
    await _performLookup(lookupType: 'name_email', name: name, email: email);
  }

  Future<void> _lookupByName() async {
    final name = _nameSearchController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).translate('scan_enter_name_error'));
      return;
    }
    final nationality = _nationalityController.text.trim();
    final role = _roleController.text.trim();
    await _performLookup(
      lookupType: 'name_search',
      name: name,
      nationality: nationality.isNotEmpty ? nationality : null,
      role: role.isNotEmpty ? role : null,
    );
  }

  Future<void> _performLookup({
    required String lookupType,
    String? code,
    String? name,
    String? email,
    String? nationality,
    String? role,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService().manualLookup(
        lookupType: lookupType,
        code: code,
        name: name,
        email: email,
        nationality: nationality,
        role: role,
      );

      if (!mounted) return;

      // Multiple matches — show pick list
      if (result['multiple'] == true) {
        final matches = (result['matches'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        _showPickList(matches);
        return;
      }

      // Single result — go to result screen
      _navigateToResult(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).translate('generic_error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToResult(Map<String, dynamic> result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScanResultScreen(
          result: result,
          mode: widget.mode,
          programmeName: widget.programmeName,
        ),
      ),
    );
  }

  void _showPickList(List<Map<String, dynamic>> matches) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    AppLocalizations.of(context).translate('scan_multiple_matches'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    AppLocalizations.of(context).translate('scan_select_person'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = matches[i];
                      final isYd = m['match_type'] == 'youth_dialogue';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isYd
                              ? AppColors.burundiGreen.withValues(alpha: 0.15)
                              : Colors.blue.withValues(alpha: 0.15),
                          child: Icon(
                            isYd ? Icons.badge_rounded : Icons.confirmation_number_rounded,
                            color: isYd ? AppColors.burundiGreen : Colors.blue,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          m['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if ((m['nationality'] as String?)?.isNotEmpty == true)
                              m['nationality'] as String,
                            if ((m['role'] as String?)?.isNotEmpty == true)
                              m['role'] as String,
                            if ((m['email'] as String?)?.isNotEmpty == true)
                              m['email'] as String,
                            if ((m['event'] as String?)?.isNotEmpty == true)
                              m['event'] as String,
                          ].take(2).join('\n'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          AppLocalizations.of(context).translate(isYd ? 'scan_credential' : 'scan_ticket'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isYd ? AppColors.burundiGreen : Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          // Re-lookup this specific match by code/ID
                          _performLookup(
                            lookupType: 'code',
                            code: m['id'] as String?,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(l10n.translate('scan_manual_lookup')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: l10n.translate('scan_tab_code')),
            Tab(text: l10n.translate('scan_tab_name_email')),
            Tab(text: l10n.translate('scan_tab_name')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCodeTab(isDark),
          _buildNameEmailTab(isDark),
          _buildNameSearchTab(isDark),
        ],
      ),
    );
  }

  Widget _buildCodeTab(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('scan_enter_code_title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('scan_code_example'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _lookupByCode(),
            decoration: InputDecoration(
              hintText: l10n.translate('scan_code_hint'),
              prefixIcon: const Icon(Icons.confirmation_number_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null && _tabController.index == 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Ds.redTintOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Ds.red.withValues(alpha: 0.4)),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _lookupByCode,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                l10n.translate(_loading ? 'scan_looking_up' : 'scan_look_up'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameEmailTab(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('scan_search_name_email'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('scan_search_name_email_sub'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: l10n.translate('full_name'),
              prefixIcon: const Icon(Icons.person_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _lookupByNameEmail(),
            decoration: InputDecoration(
              hintText: l10n.translate('more_email_address'),
              prefixIcon: const Icon(Icons.email_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null && _tabController.index == 1 && !_loading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Ds.redTintOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Ds.red.withValues(alpha: 0.4)),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _lookupByNameEmail,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                l10n.translate(_loading ? 'scan_searching' : 'search'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSearchTab(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('scan_search_by_name'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('scan_search_by_name_sub'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameSearchController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: l10n.translate('scan_name_required_hint'),
              prefixIcon: const Icon(Icons.person_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nationalityController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: l10n.translate('scan_nationality_hint'),
              prefixIcon: const Icon(Icons.flag_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _roleController,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _lookupByName(),
            decoration: InputDecoration(
              hintText: l10n.translate('scan_role_hint'),
              prefixIcon: const Icon(Icons.badge_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null && _tabController.index == 2 && !_loading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Ds.redTintOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Ds.red.withValues(alpha: 0.4)),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _lookupByName,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                l10n.translate(_loading ? 'scan_searching' : 'search'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burundiGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
