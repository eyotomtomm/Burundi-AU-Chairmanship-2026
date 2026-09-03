import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/app_ds.dart';
import '../../config/environment.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../models/fact_model.dart';
import '../../services/api_service.dart';
import '../../widgets/async_content_view.dart';
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
  bool _loadFailed = false;
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
          _loadFailed = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _loadFailed = true; });
    }
  }

  Future<void> _loadFacts() async {
    setState(() => _isLoading = true);
    try {
      final facts = await ApiService().getFacts(
        category: _selectedCategoryId,
        factType: _selectedType,
      );
      if (mounted) setState(() { _facts = facts; _isLoading = false; _loadFailed = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _loadFailed = true; });
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
      backgroundColor: Ds.bg(context),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Elegant header
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: Ds.bg(context),
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
              extent: MediaQuery.textScalerOf(context).scale(100),
              child: Container(
                color: Ds.bg(context),
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
          else if (_loadFailed)
            SliverFillRemaining(
              child: AsyncContentView(
                state: AsyncContentState.error,
                onRetry: _categories.isEmpty ? _loadData : _loadFacts,
                child: const SizedBox.shrink(),
              ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DsFilterChip(
        label,
        selected: _selectedCategoryId == categoryId,
        onTap: () {
          _selectedCategoryId = categoryId;
          _loadFacts();
        },
      ),
    );
  }

  Widget _buildTypeChip(String label, String? type, IconData? icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DsFilterChip(
        label,
        selected: _selectedType == type,
        onTap: () {
          _selectedType = type;
          _loadFacts();
        },
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final Widget child;

  final double extent;
  _FilterHeaderDelegate({required this.isDark, required this.child, required this.extent});

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) => true;
}

// ── Discover list card ──────────────────────────────────────
/// Full-width "Discover" row: photo, kicker, then the fact or quote.
class _FactListCard extends StatelessWidget {
  final Fact fact;
  final String langCode;
  final int index;
  final VoidCallback onTap;

  const _FactListCard({
    required this.fact,
    required this.langCode,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isQuote = fact.isQuote;
    final imageUrl = Environment.fixMediaUrl(fact.image);
    final kicker = (fact.category?.getDisplayName(langCode) ??
            (isQuote
                ? (langCode == 'fr' ? 'CITATION' : 'QUOTE')
                : (langCode == 'fr' ? 'LE SAVIEZ-VOUS' : 'DID YOU KNOW')))
        .toUpperCase();

    return DsCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Ds.rTile),
            child: SizedBox(
              width: 92,
              height: 78,
              child: imageUrl.isEmpty
                  ? DsImagePlaceholder(
                      radius: 0,
                      icon: isQuote
                          ? Icons.format_quote_rounded
                          : Icons.auto_awesome_rounded,
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const DsImagePlaceholder(radius: 0),
                      errorWidget: (_, _, _) => const DsImagePlaceholder(
                          radius: 0, icon: Icons.auto_awesome_rounded),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Ds.green)),
                const SizedBox(height: 3),
                Text(
                  isQuote ? fact.getContentPreview(langCode) : fact.getTitle(langCode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
                    color: Ds.ink(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isQuote && fact.authorName.isNotEmpty
                      ? '— ${fact.authorName}'
                      : fact.getContentPreview(langCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ds.meta(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
