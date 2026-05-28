import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/haptic_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> with SingleTickerProviderStateMixin {
  String _selectedCategory = 'greetings';
  late TabController _tabController;
  final _inputController = TextEditingController();
  String _translatedText = '';
  bool _isTranslating = false;
  String _sourceLang = 'en';
  String _targetLang = 'fr';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });
    try {
      final result = await ApiService().autoTranslate(text, _sourceLang, _targetLang);
      if (mounted) {
        HapticService.light();
        setState(() {
          _translatedText = result['translated_text'] ?? result['translation'] ?? '';
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Translation error: $e');
      if (mounted) {
        setState(() {
          _translatedText = '';
          _isTranslating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Translation failed. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      if (_translatedText.isNotEmpty) {
        _inputController.text = _translatedText;
        _translatedText = '';
      }
    });
    HapticService.selection();
  }

  static const Map<String, List<Map<String, String>>> _phrases = {
    'greetings': [
      {'kirundi': 'Amahoro', 'en': 'Hello / Peace', 'fr': 'Bonjour / Paix'},
      {'kirundi': 'Mwaramutse', 'en': 'Good morning', 'fr': 'Bonjour (matin)'},
      {'kirundi': 'Mwiriwe', 'en': 'Good afternoon', 'fr': 'Bon après-midi'},
      {'kirundi': 'Ijoro ryiza', 'en': 'Good night', 'fr': 'Bonne nuit'},
      {'kirundi': 'Urakoze', 'en': 'Thank you', 'fr': 'Merci'},
      {'kirundi': 'Ego', 'en': 'Yes', 'fr': 'Oui'},
      {'kirundi': 'Oya', 'en': 'No', 'fr': 'Non'},
      {'kirundi': 'Bite?', 'en': 'How are you?', 'fr': 'Comment allez-vous?'},
      {'kirundi': 'Ndagukunda', 'en': 'I love you', 'fr': 'Je t\'aime'},
      {'kirundi': 'Turabonana', 'en': 'See you later', 'fr': 'À bientôt'},
    ],
    'directions': [
      {'kirundi': 'Iburyo', 'en': 'Right', 'fr': 'Droite'},
      {'kirundi': 'Ibubamfu', 'en': 'Left', 'fr': 'Gauche'},
      {'kirundi': 'Ruguru', 'en': 'Straight ahead', 'fr': 'Tout droit'},
      {'kirundi': 'Hafi', 'en': 'Near / Close', 'fr': 'Près'},
      {'kirundi': 'Kure', 'en': 'Far', 'fr': 'Loin'},
      {'kirundi': 'Mu gisagara', 'en': 'In the city', 'fr': 'En ville'},
      {'kirundi': 'Ahabanza', 'en': 'First / Here', 'fr': 'Ici / D\'abord'},
      {'kirundi': 'Aho', 'en': 'There', 'fr': 'Là-bas'},
    ],
    'diplomacy': [
      {'kirundi': 'Umunyamabanga', 'en': 'Secretary', 'fr': 'Secrétaire'},
      {'kirundi': 'Umukuru w\'igihugu', 'en': 'Head of State', 'fr': 'Chef d\'État'},
      {'kirundi': 'Ambasade', 'en': 'Embassy', 'fr': 'Ambassade'},
      {'kirundi': 'Ubumwe', 'en': 'Unity', 'fr': 'Unité'},
      {'kirundi': 'Amajambere', 'en': 'Development', 'fr': 'Développement'},
      {'kirundi': 'Demokarasi', 'en': 'Democracy', 'fr': 'Démocratie'},
      {'kirundi': 'Intahe', 'en': 'Justice', 'fr': 'Justice'},
      {'kirundi': 'Umugambi', 'en': 'Conference', 'fr': 'Conférence'},
    ],
  };

  static const Map<String, IconData> _categoryIcons = {
    'greetings': Icons.waving_hand_rounded,
    'directions': Icons.explore_rounded,
    'diplomacy': Icons.account_balance_rounded,
  };

  static const Map<String, String> _categoryLabelsEn = {
    'greetings': 'Greetings',
    'directions': 'Directions',
    'diplomacy': 'Diplomacy',
  };

  static const Map<String, String> _langNames = {
    'en': 'English',
    'fr': 'Français',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('translate'),
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.auGold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.translate, size: 18), text: 'Translate'),
            Tab(icon: Icon(Icons.menu_book, size: 18), text: 'Phrasebook'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Free Translation
          _buildTranslateTab(isDark),
          // Tab 2: Phrasebook
          _buildPhrasebookTab(isDark, l10n),
        ],
      ),
    );
  }

  Widget _buildTranslateTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Language selector row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _langNames[_sourceLang] ?? _sourceLang,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.swap_horiz_rounded, color: isDark ? AppColors.auGold : AppColors.burundiGreen),
                onPressed: _swapLanguages,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _langNames[_targetLang] ?? _targetLang,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Input field
          TextField(
            controller: _inputController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _sourceLang == 'en' ? 'Enter text to translate...' : 'Entrez le texte à traduire...',
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.burundiGreen, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Translate button
          ElevatedButton.icon(
            onPressed: _isTranslating ? null : _translate,
            icon: _isTranslating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.translate, size: 18),
            label: Text(_isTranslating ? 'Translating...' : 'Translate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burundiGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          // Translation result
          if (_translatedText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.burundiGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.burundiGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: AppColors.burundiGreen),
                      const SizedBox(width: 6),
                      Text(
                        _langNames[_targetLang] ?? _targetLang,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.burundiGreen, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _translatedText,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhrasebookTab(bool isDark, AppLocalizations l10n) {
    return Column(
      children: [
        // Category chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _categoryIcons.entries.map((entry) {
                  final isSelected = _selectedCategory == entry.key;
                  final labels = _categoryLabelsEn;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.value,
                            size: 16,
                            color: isSelected ? Colors.white : (isDark ? AppColors.auGold : AppColors.burundiGreen),
                          ),
                          const SizedBox(width: 6),
                          Text(labels[entry.key]!),
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
                      onSelected: (_) => setState(() => _selectedCategory = entry.key),
                    ),
                  );
                }).toList(),
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
                  child: Text('Français', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.auGold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Phrase list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _phrases[_selectedCategory]!.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              ),
              itemBuilder: (context, index) {
                final phrase = _phrases[_selectedCategory]![index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          phrase['kirundi']!,
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
                          phrase['en']!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          phrase['fr']!,
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
