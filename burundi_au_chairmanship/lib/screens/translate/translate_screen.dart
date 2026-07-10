import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  List<_PhrasebookCategory> _categories = [];
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;

  static const Map<String, IconData> _iconMap = {
    'waving_hand': Icons.waving_hand_rounded,
    'explore': Icons.explore_rounded,
    'account_balance': Icons.account_balance_rounded,
    'tag': Icons.tag_rounded,
    'restaurant': Icons.restaurant_rounded,
    'flight': Icons.flight_rounded,
    'theater_comedy': Icons.theater_comedy_rounded,
    'business_center': Icons.business_center_rounded,
    'translate': Icons.translate_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fetchPhrases();
  }

  Future<void> _fetchPhrases() async {
    try {
      final data = await ApiService().get('phrasebook/');
      final List<dynamic> items = data is List ? data : [];
      setState(() {
        _categories = items.map((cat) {
          final phrases = (cat['phrases'] as List<dynamic>? ?? [])
              .map((p) => _Phrase(
                    kirundi: p['kirundi'] ?? '',
                    english: p['english'] ?? '',
                    french: p['french'] ?? '',
                  ))
              .toList();
          return _PhrasebookCategory(
            key: cat['category'] ?? '',
            label: cat['label'] ?? '',
            icon: _iconMap[cat['icon']] ?? Icons.translate_rounded,
            phrases: phrases,
          );
        }).toList();
        _selectedIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load phrasebook.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('phrasebook'),
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 48, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: () { setState(() { _loading = true; _error = null; }); _fetchPhrases(); }, child: const Text('Retry')),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? Center(child: Text('No phrases available.', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)))
                  : _buildPhrasebook(isDark),
    );
  }

  Widget _buildPhrasebook(bool isDark) {
    final selectedCategory = _categories[_selectedIndex];

    return Column(
      children: [
        // Category chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(_categories.length, (i) {
                  final cat = _categories[i];
                  final isSelected = _selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : (isDark ? AppColors.auGold : AppColors.burundiGreen),
                          ),
                          const SizedBox(width: 6),
                          Text(cat.label),
                        ],
                      ),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText),
                      ),
                      selectedColor: AppColors.burundiGreen,
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                      side: BorderSide(
                        color: isSelected ? AppColors.burundiGreen : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                      ),
                      onSelected: (_) => setState(() => _selectedIndex = i),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Kirundi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.burundiGreen)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('English', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.burundiRed)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Fran\u00e7ais', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.auGold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Phrase list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: selectedCategory.phrases.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              ),
              itemBuilder: (context, index) {
                final phrase = selectedCategory.phrases[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          phrase.kirundi,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          phrase.english,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          phrase.french,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
  }
}

class _PhrasebookCategory {
  final String key;
  final String label;
  final IconData icon;
  final List<_Phrase> phrases;

  _PhrasebookCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.phrases,
  });
}

class _Phrase {
  final String kirundi;
  final String english;
  final String french;

  _Phrase({required this.kirundi, required this.english, required this.french});
}
