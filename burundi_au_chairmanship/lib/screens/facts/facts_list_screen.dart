import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/fact_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../auth/auth_screen.dart';
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

  void _onFactTap(Fact fact) {
    final isLoggedIn = context.read<AuthProvider>().isAuthenticated;
    if (!isLoggedIn) {
      final langCode = context.read<LanguageProvider>().languageCode;
      _showSignInPrompt(langCode);
      return;
    }
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => FactDetailScreen(factId: fact.id, fact: fact)),
    );
  }

  void _showSignInPrompt(String langCode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.burundiGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 28, color: AppColors.burundiGreen),
            ),
            const SizedBox(height: 16),
            Text(
              langCode == 'fr' ? 'Connectez-vous pour continuer' : 'Sign in to continue',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              langCode == 'fr'
                  ? 'Créez un compte ou connectez-vous pour lire le contenu complet.'
                  : 'Create an account or sign in to read the full content.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, CupertinoPageRoute(builder: (_) => const AuthScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  langCode == 'fr' ? 'Se connecter' : 'Sign In',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                langCode == 'fr' ? 'Plus tard' : 'Maybe later',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<LanguageProvider>().languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F6F2),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Elegant header
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F6F2),
            foregroundColor: isDark ? Colors.white : Colors.black87,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        langCode == 'fr' ? "Découvrir l'Afrique" : 'Discover Africa',
                        style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        langCode == 'fr' ? 'Faits, citations et histoires' : 'Facts, quotes & stories',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Filters
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(
              isDark: isDark,
              child: Container(
                color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F6F2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category chips
                    if (_categories.isNotEmpty)
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildCategoryChip(langCode == 'fr' ? 'Tous' : 'All', null, null, isDark),
                            ..._categories.map((cat) => _buildCategoryChip(
                              cat.getDisplayName(langCode), cat.id, cat.parsedColor, isDark,
                            )),
                          ],
                        ),
                      ),
                    // Type toggles
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          _buildTypeChip(langCode == 'fr' ? 'Tous' : 'All', null, null, isDark),
                          const SizedBox(width: 8),
                          _buildTypeChip(langCode == 'fr' ? 'Faits' : 'Facts', 'fact', Icons.auto_awesome, isDark),
                          const SizedBox(width: 8),
                          _buildTypeChip(langCode == 'fr' ? 'Citations' : 'Quotes', 'quote', Icons.format_quote_rounded, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.burundiGreen)),
            )
          else if (_facts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_off_rounded, size: 56, color: isDark ? Colors.white12 : Colors.black12),
                    const SizedBox(height: 12),
                    Text(
                      langCode == 'fr' ? 'Aucun contenu trouvé' : 'No content found',
                      style: TextStyle(fontSize: 15, color: isDark ? Colors.white30 : Colors.black26),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _FactListCard(
                    fact: _facts[index],
                    langCode: langCode,
                    index: index,
                    onTap: () => _onFactTap(_facts[index]),
                  ),
                  childCount: _facts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, int? categoryId, Color? color, bool isDark) {
    final isSelected = _selectedCategoryId == categoryId;
    final chipColor = color ?? AppColors.burundiGreen;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () { _selectedCategoryId = categoryId; _loadFacts(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? chipColor.withValues(alpha: 0.5) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? chipColor : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String? type, IconData? icon, bool isDark) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () { _selectedType = type; _loadFacts(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.burundiGreen.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15,
                color: isSelected ? AppColors.burundiGreen : (isDark ? Colors.white30 : Colors.black26)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.burundiGreen : (isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Persistent header delegate for pinned filters
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final Widget child;
  _FilterHeaderDelegate({required this.isDark, required this.child});

  @override
  double get minExtent => 100;
  @override
  double get maxExtent => 100;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) => true;
}

// ── Palette & constants (matching home carousel) ────────────
const _gold = Color(0xFFFCD116);

const _palettes = [
  [Color(0xFF0E2E11), Color(0xFF1A4A1E), Color(0xFF8A7010)],
  [Color(0xFF3D0A0E), Color(0xFF5E1218), Color(0xFF8A7010)],
  [Color(0xFF0C2410), Color(0xFF1C3E20), Color(0xFF2E5432)],
  [Color(0xFF2E0808), Color(0xFF4A1010), Color(0xFF6B4A12)],
  [Color(0xFF0A1F0D), Color(0xFF163A1A), Color(0xFF5A1515)],
];

// ── Elegant list card ───────────────────────────────────────
class _FactListCard extends StatelessWidget {
  final Fact fact;
  final String langCode;
  final int index;
  final VoidCallback onTap;

  const _FactListCard({required this.fact, required this.langCode, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _palettes[index % _palettes.length];
    final isQuote = fact.isQuote;
    final categoryColor = fact.category?.parsedColor ?? AppColors.burundiGreen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: palette[0].withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette,
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Subtle accent strips
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        palette[2].withValues(alpha: 0.0),
                        palette[2].withValues(alpha: 0.6),
                        palette[2].withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _gold.withValues(alpha: 0.0),
                        _gold.withValues(alpha: 0.4),
                        _gold.withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side: icon
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _gold.withValues(alpha: 0.25)),
                        ),
                        child: Icon(
                          isQuote ? Icons.format_quote_rounded : Icons.auto_awesome,
                          size: 18, color: _gold,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _gold.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: Text(
                                fact.category?.getDisplayName(langCode) ?? '',
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  color: _gold, letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Title or quote
                            if (isQuote) ...[
                              Text(
                                '\u201C${fact.getContentPreview(langCode)}\u201D',
                                style: const TextStyle(
                                  fontSize: 14, fontStyle: FontStyle.italic,
                                  color: Colors.white, height: 1.5,
                                ),
                                maxLines: 3, overflow: TextOverflow.ellipsis,
                              ),
                              if (fact.authorName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(children: [
                                    Container(width: 16, height: 1.5,
                                      decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(1))),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(
                                      fact.authorName,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _gold),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    )),
                                  ]),
                                ),
                            ] else ...[
                              Text(
                                fact.getTitle(langCode),
                                style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Colors.white, height: 1.3,
                                ),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                fact.getContentPreview(langCode),
                                style: TextStyle(
                                  fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.4,
                                ),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                              if (fact.source.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    fact.getSource(langCode),
                                    style: TextStyle(fontSize: 10, color: _gold.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),

                      // Arrow
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white.withValues(alpha: 0.3)),
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
