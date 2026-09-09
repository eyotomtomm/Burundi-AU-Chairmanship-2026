import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../widgets/app_network_image.dart';
import 'package:intl/intl.dart';
import '../../../config/app_ds.dart';
import '../../../widgets/ds/ds_widgets.dart';
import '../../../config/environment.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../models/magazine_model.dart';
import '../../../services/api_service.dart';
import '../../../services/content_cache_service.dart';
import '../../../widgets/login_gate.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../../widgets/async_content_view.dart';
import '../../../services/like_service.dart';
import '../../magazine/magazine_detail_screen.dart';

class MagazineTab extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const MagazineTab({super.key, this.onBackToHome});

  @override
  State<MagazineTab> createState() => _MagazineTabState();
}

class _MagazineTabState extends State<MagazineTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MagazineEdition>? _editions;
  bool _isLoading = true;
  bool _hasError = false;
  final LikeService _likeService = LikeService();
  VoidCallback? _removeLikeListener;

  // Search & filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedYear;
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _removeLikeListener = _likeService.addListener((key, state) {
      if (key.startsWith('magazine:') && mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _removeLikeListener?.call();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService();
      final editions = await api.getMagazines();
      if (!mounted) return;
      // Cache on success
      ContentCacheService().cacheMagazines(editions);
      setState(() {
        _editions = editions;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Fall back to cache
      final cached = ContentCacheService().getMagazines();
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _editions = cached;
          _isLoading = false;
          _hasError = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }


  void _openMagazineDetail(BuildContext context, MagazineEdition edition) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => MagazineDetailScreen(
          magazine: edition,
          scrollToComments: false,
        ),
      ),
    );
  }

  List<MagazineEdition> get _filteredEditions {
    var list = _editions ?? [];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) =>
          e.title.toLowerCase().contains(q) ||
          e.titleFr.toLowerCase().contains(q)).toList();
    }
    if (_selectedYear != null) {
      list = list.where((e) => e.publishDate.year == _selectedYear).toList();
    }
    if (_selectedMonth != null) {
      list = list.where((e) => e.publishDate.month == _selectedMonth).toList();
    }
    return list;
  }

  Set<int> get _availableYears {
    return (_editions ?? []).map((e) => e.publishDate.year).toSet();
  }

  /// Months that actually have an issue, narrowed to the selected year when
  /// there is one. Offering all twelve every time meant most taps landed on an
  /// empty list.
  Set<int> get _availableMonths {
    return (_editions ?? [])
        .where((e) => _selectedYear == null || e.publishDate.year == _selectedYear)
        .map((e) => e.publishDate.month)
        .toSet();
  }

  /// Picking a year can strand a month selection on a month that year has no
  /// issue for, which would show an empty list with two filters lit up.
  void _selectYear(int? year) {
    setState(() {
      _selectedYear = year;
      if (_selectedMonth != null && !_availableMonths.contains(_selectedMonth)) {
        _selectedMonth = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LanguageProvider>().languageCode;

    final AsyncContentState contentState;
    if (_isLoading) {
      contentState = AsyncContentState.loading;
    } else if (_hasError) {
      contentState = AsyncContentState.error;
    } else if ((_editions ?? []).isEmpty) {
      contentState = AsyncContentState.empty;
    } else {
      contentState = AsyncContentState.content;
    }

    return Scaffold(
      backgroundColor: Ds.bg(context),
      body: Column(
        children: [
          DsHeader(
            title: l10n.digitalMagazine,
            large: true,
            showBack: widget.onBackToHome != null,
          ),
          Expanded(
            child: contentState != AsyncContentState.content
                ? AsyncContentView(
                    state: contentState,
                    loadingWidget: const ShimmerMagazineGridSkeleton(),
                    emptyIcon: Icons.auto_stories,
                    emptyMessage: l10n.noData,
                    onRetry: () {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                      });
                      _loadData();
                    },
                    onRefresh: () async {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                      });
                      await _loadData();
                    },
                    child: const SizedBox.shrink(),
                  )
                : RefreshIndicator(
                    color: Ds.green,
                    onRefresh: () async {
                      HapticFeedback.mediumImpact();
                      await _loadData();
                    },
                    child: _buildMagazinesList(context, langCode, l10n),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return DsCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: Ds.muted(context)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(fontSize: 14, color: Ds.ink(context)),
              decoration: InputDecoration(
                hintText: l10n.translate('search'),
                hintStyle: TextStyle(fontSize: 14, color: Ds.muted(context)),
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Icon(Icons.close_rounded, size: 18, color: Ds.muted(context)),
            ),
        ],
      ),
    );
  }

  /// Year / month filters as design-system pills. Only periods that have an
  /// issue behind them are offered.
  Widget _buildFilterChips(String langCode) {
    final years = _availableYears.toList()..sort((a, b) => b.compareTo(a));
    final months = _availableMonths.toList()..sort();
    final monthNames = langCode == 'fr'
        ? const ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
                 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.']
        : const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    // One year and one month is not a filter, it is a label — hide the row.
    if (years.length < 2 && months.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [
          if (years.length > 1)
            for (final year in years)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DsFilterChip('$year',
                    selected: _selectedYear == year,
                    onTap: () => _selectYear(_selectedYear == year ? null : year)),
              ),
          if (months.length > 1)
            for (final month in months)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DsFilterChip(monthNames[month - 1],
                    selected: _selectedMonth == month,
                    onTap: () => setState(() =>
                        _selectedMonth = _selectedMonth == month ? null : month)),
              ),
        ],
      ),
    );
  }

  Widget _buildMagazinesList(
      BuildContext context, String langCode, AppLocalizations l10n) {
    final filtered = _filteredEditions;
    final isAuth = context.watch<AuthProvider>().isAuthenticated;
    final featured = filtered.where((e) => e.isFeatured).toList();
    final hero = featured.isNotEmpty ? featured.first : (filtered.isNotEmpty ? filtered.first : null);
    final past = hero == null
        ? filtered
        : filtered.where((e) => e.id != hero.id).toList();
    final fr = langCode == 'fr';

    return ListView(
      padding: EdgeInsets.only(bottom: Ds.navSpace(context)),
      children: [
        _buildSearchField(l10n),
        _buildFilterChips(langCode),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 48, color: Ds.muted(context)),
                const SizedBox(height: 12),
                Text(AppLocalizations.of(context).translate('no_magazines_found'),
                    style: TextStyle(color: Ds.body(context), fontSize: 14)),
              ],
            ),
          )
        else ...[
          if (hero != null) _buildFeaturedHero(context, hero, langCode),
          if (past.isNotEmpty) ...[
            DsSectionTitle(fr ? 'Anciens numéros' : 'Past issues',
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10)),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              mainAxisSpacing: 20,
              crossAxisSpacing: 14,
              // A 3:4 cover plus two caption lines.
              childAspectRatio: 0.56,
              children: [
                for (final mag in past) _buildMagazineCard(context, mag, langCode),
              ],
            ),
          ],
        ],
        if (!isAuth) const LoginGateBanner(),
      ],
    );
  }

  /// The artwork at its own aspect, nothing cropped away.
  Widget _coverContained(MagazineEdition magazine) => AppNetworkImage(
        imageUrl: Environment.fixMediaUrl(magazine.coverImageUrl),
        fit: BoxFit.contain,
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) =>
            const DsImagePlaceholder(radius: 0, icon: Icons.auto_stories_rounded),
      );

  Widget _cover(MagazineEdition magazine) => AppNetworkImage(
        imageUrl: Environment.fixMediaUrl(magazine.coverImageUrl),
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            const DsImagePlaceholder(radius: 0, icon: Icons.auto_stories_rounded),
        errorWidget: (_, _, _) =>
            const DsImagePlaceholder(radius: 0, icon: Icons.auto_stories_rounded),
      );

  /// A cover is a designed object; the old hero cropped it to a 210px
  /// landscape strip, which threw away the part people recognise. Here it runs
  /// at magazine proportions with the title set over its foot.
  Widget _buildFeaturedHero(
      BuildContext context, MagazineEdition magazine, String langCode) {
    final fr = langCode == 'fr';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _openMagazineDetail(context, magazine),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: _coverPlate(
                    magazine,
                    radius: Ds.rCard,
                    overlay: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          magazine.getTitle(langCode),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.22,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${DateFormat('MMMM yyyy', langCode).format(magazine.publishDate)}  ·  EN / FR',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                      ],
                    ),
                    badge: fr ? 'NOUVEAU NUMÉRO' : 'NEW ISSUE',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DsPrimaryButton(
                  fr ? 'Lire' : 'Read now',
                  onTap: () => _openMagazineDetail(context, magazine),
                ),
              ),
              if (magazine.hasPdf) ...[
                const SizedBox(width: 10),
                DsOutlineButton(
                  fr ? 'Hors ligne' : 'Offline',
                  icon: Icons.download_rounded,
                  onTap: () => _openMagazineDetail(context, magazine),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// One cover, drawn as a physical issue: full bleed at its own aspect, a
  /// darkening foot so text over it stays readable whatever the artwork does,
  /// and a spine edge down the binding side.
  Widget _coverPlate(
    MagazineEdition magazine, {
    required double radius,
    Widget? overlay,
    String? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The editions are not all portrait covers — several are landscape
            // event posters — so cropping to fill sliced the titles off at both
            // edges. The artwork is shown whole, over a blurred copy of itself
            // so the frame is still filled rather than letterboxed on grey.
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: _cover(magazine),
            ),
            Container(color: Colors.black.withValues(alpha: 0.18)),
            Padding(
              padding: const EdgeInsets.all(6),
              child: _coverContained(magazine),
            ),
            // Spine: a narrow shaded band on the binding edge.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.black.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ),
            if (overlay != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.42, 0.62, 1.0],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: overlay,
                  ),
                ),
              ),
            if (badge != null)
              Positioned(
                left: 14,
                top: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Ds.gold,
                    borderRadius: BorderRadius.circular(Ds.rPill),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Ds.goldInkDeep,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMagazineCard(
      BuildContext context, MagazineEdition magazine, String langCode) {
    return GestureDetector(
      onTap: () => _openMagazineDetail(context, magazine),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: _coverPlate(magazine, radius: Ds.rTile),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            magazine.getTitle(langCode),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.28,
              color: Ds.ink(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('MMM yyyy', langCode).format(magazine.publishDate),
            style: TextStyle(fontSize: 11, color: Ds.muted(context)),
          ),
        ],
      ),
    );
  }
}
