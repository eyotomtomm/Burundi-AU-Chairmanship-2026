import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  String _selectedCategory = 'greetings';

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
    'emergency': [
      {'kirundi': 'Tabara!', 'en': 'Help!', 'fr': 'Au secours!'},
      {'kirundi': 'Hamagara abapolisi', 'en': 'Call the police', 'fr': 'Appelez la police'},
      {'kirundi': 'Ndakeneye muganga', 'en': 'I need a doctor', 'fr': 'J\'ai besoin d\'un médecin'},
      {'kirundi': 'Ivyibitungwa', 'en': 'Hospital', 'fr': 'Hôpital'},
      {'kirundi': 'Umuriro!', 'en': 'Fire!', 'fr': 'Au feu!'},
      {'kirundi': 'Ni ibiki?', 'en': 'What happened?', 'fr': 'Que s\'est-il passé?'},
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
    'emergency': Icons.emergency_rounded,
    'diplomacy': Icons.account_balance_rounded,
  };

  static const Map<String, String> _categoryLabelsEn = {
    'greetings': 'Greetings',
    'directions': 'Directions',
    'emergency': 'Emergency',
    'diplomacy': 'Diplomacy',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('translate'),
          style: GoogleFonts.oswald(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
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
                            color: isSelected ? Colors.white : AppColors.burundiGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(labels[entry.key]!),
                        ],
                      ),
                      labelStyle: GoogleFonts.oswald(
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
                  child: Text('Kirundi', style: GoogleFonts.oswald(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.burundiGreen)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('English', style: GoogleFonts.oswald(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.burundiRed)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Français', style: GoogleFonts.oswald(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.auGold)),
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
              separatorBuilder: (_, __) => Divider(
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
                          style: GoogleFonts.oswald(
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
                          style: GoogleFonts.oswald(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          phrase['fr']!,
                          style: GoogleFonts.oswald(
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
      ),
    );
  }
}
