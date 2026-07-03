import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/fact_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import 'fact_detail_screen.dart';

class FactsListScreen extends StatefulWidget {
  const FactsListScreen({super.key});

  @override
  State<FactsListScreen> createState() => _FactsListScreenState();
}

class _FactsListScreenState extends State<FactsListScreen> {
  List<FactCategory> _categories = [];
  List<Fact> _facts = [];
  bool _isLoading = true;
  int? _selectedCategoryId;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getFactCategories(),
        api.getFacts(category: _selectedCategoryId, factType: _selectedType),
      ]);
      if (mounted) {
        setState(() {
          _categories = results[0] as List<FactCategory>;
          _facts = results[1] as List<Fact>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFacts() async {
    setState(() => _isLoading = true);
    try {
      final facts = await ApiService().getFacts(
        category: _selectedCategoryId,
        factType: _selectedType,
      );
      if (mounted) setState(() { _facts = facts; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<LanguageProvider>().languageCode;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(langCode == 'fr' ? 'Faits & Citations' : 'Facts & Quotes'),
      ),
      body: Column(
        children: [
          // Category filter chips
          if (_categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _FilterChip(
                    label: langCode == 'fr' ? 'Tous' : 'All',
                    isSelected: _selectedCategoryId == null,
                    onTap: () {
                      _selectedCategoryId = null;
                      _loadFacts();
                    },
                  ),
                  ..._categories.map((cat) => _FilterChip(
                    label: cat.getDisplayName(langCode),
                    isSelected: _selectedCategoryId == cat.id,
                    color: cat.parsedColor,
                    onTap: () {
                      _selectedCategoryId = cat.id;
                      _loadFacts();
                    },
                  )),
                ],
              ),
            ),
          // Type filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _TypeToggle(
                  label: langCode == 'fr' ? 'Tous' : 'All',
                  isSelected: _selectedType == null,
                  onTap: () { _selectedType = null; _loadFacts(); },
                ),
                const SizedBox(width: 8),
                _TypeToggle(
                  label: langCode == 'fr' ? 'Faits' : 'Facts',
                  icon: Icons.lightbulb_outline_rounded,
                  isSelected: _selectedType == 'fact',
                  onTap: () { _selectedType = 'fact'; _loadFacts(); },
                ),
                const SizedBox(width: 8),
                _TypeToggle(
                  label: langCode == 'fr' ? 'Citations' : 'Quotes',
                  icon: Icons.format_quote_rounded,
                  isSelected: _selectedType == 'quote',
                  onTap: () { _selectedType = 'quote'; _loadFacts(); },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _facts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              langCode == 'fr' ? 'Aucun contenu' : 'No content found',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFacts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _facts.length,
                          itemBuilder: (context, index) => _FactListCard(
                            fact: _facts[index],
                            langCode: langCode,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? chipColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? chipColor : Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? chipColor : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeToggle({required this.label, this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactListCard extends StatelessWidget {
  final Fact fact;
  final String langCode;

  const _FactListCard({required this.fact, required this.langCode});

  @override
  Widget build(BuildContext context) {
    final categoryColor = fact.category?.parsedColor ?? const Color(0xFF1EB53A);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => FactDetailScreen(factId: fact.id, fact: fact)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: categoryColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                fact.isQuote ? Icons.format_quote_rounded : Icons.lightbulb_outline_rounded,
                size: 20,
                color: categoryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fact.isFact)
                    Text(
                      fact.getTitle(langCode),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    fact.isQuote
                        ? '"${fact.getContentPreview(langCode)}"'
                        : fact.getContentPreview(langCode),
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: fact.isQuote ? FontStyle.italic : FontStyle.normal,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          fact.category?.getDisplayName(langCode) ?? '',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: categoryColor),
                        ),
                      ),
                      if (fact.isQuote && fact.authorName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '-- ${fact.authorName}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                      if (fact.isFact && fact.source.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fact.getSource(langCode),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
