import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  /// Year / month filters as design-system pills.
  Widget _buildFilterChips(String langCode) {
    final years = _availableYears.toList()..sort((a, b) => b.compareTo(a));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [
          for (final year in years)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DsFilterChip('$year',
                  selected: _selectedYear == year,
                  onTap: () => setState(
                      () => _selectedYear = _selectedYear == year ? null : year)),
            ),
          for (var i = 0; i < months.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DsFilterChip(months[i],
                  selected: _selectedMonth == i + 1,
                  onTap: () => setState(() =>
                      _selectedMonth = _selectedMonth == i + 1 ? null : i + 1)),
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
                Text('No magazines found',
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
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
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

  Widget _cover(MagazineEdition magazine) => CachedNetworkImage(
        imageUrl: Environment.fixMediaUrl(magazine.coverImageUrl),
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            const DsImagePlaceholder(radius: 0, icon: Icons.auto_stories_rounded),
        errorWidget: (_, _, _) =>
            const DsImagePlaceholder(radius: 0, icon: Icons.auto_stories_rounded),
      );

  Widget _buildFeaturedHero(
      BuildContext context, MagazineEdition magazine, String langCode) {
    final fr = langCode == 'fr';
    return DsCard(
      margin: const EdgeInsets.all(16),
      featured: true,
      clip: true,
      onTap: () => _openMagazineDetail(context, magazine),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _cover(magazine),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Ds.gold,
                      borderRadius: BorderRadius.circular(Ds.rPill),
                    ),
                    child: Text(
                      fr ? 'NOUVEAU NUMÉRO' : 'NEW ISSUE',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Ds.goldInkDeep),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  magazine.getTitle(langCode),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      letterSpacing: -0.2,
                      color: Ds.ink(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${DateFormat('MMMM yyyy').format(magazine.publishDate)} · EN / FR',
                  style: TextStyle(fontSize: 13, color: Ds.body(context)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    DsPrimaryButton(fr ? 'Lire' : 'Read now',
                        expand: false,
                        onTap: () => _openMagazineDetail(context, magazine)),
                    if (magazine.hasPdf) ...[
                      const SizedBox(width: 8),
                      DsOutlineButton(fr ? 'Hors ligne' : 'Offline',
                          icon: Icons.download_rounded,
                          onTap: () => _openMagazineDetail(context, magazine)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMagazineCard(
      BuildContext context, MagazineEdition magazine, String langCode) {
    return DsCard(
      clip: true,
      onTap: () => _openMagazineDetail(context, magazine),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 120, width: double.infinity, child: _cover(magazine)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      magazine.getTitle(langCode),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: Ds.ink(context)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(DateFormat('MMM yyyy').format(magazine.publishDate),
                      style: TextStyle(fontSize: 11, color: Ds.muted(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
