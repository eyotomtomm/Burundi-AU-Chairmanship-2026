import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/liked_by_avatars.dart';
import '../../widgets/login_gate.dart';
import 'pdf_viewer_screen.dart';

class MagazineScreen extends StatefulWidget {
  const MagazineScreen({super.key});

  @override
  State<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends State<MagazineScreen> {
  List<MagazineEdition>? _magazines;
  bool _isLoading = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadMagazines();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMagazines() async {
    try {
      final list = await ApiService().getMagazines();
      if (!mounted) return;
      setState(() { _magazines = list; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _magazines = MagazineData.getMockEditions(); _isLoading = false; });
    }
  }

  Future<void> _toggleLike(MagazineEdition magazine) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('login_to_like')),
          action: SnackBarAction(
            label: l10n.translate('sign_in'),
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/auth'),
          ),
        ),
      );
      return;
    }

    final index = _magazines?.indexWhere((e) => e.id == magazine.id) ?? -1;
    if (index == -1) return;
    final wasLiked = magazine.isLiked;
    setState(() {
      _magazines![index] = magazine.copyWith(
        isLiked: !wasLiked,
        likeCount: magazine.likeCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      final result = await ApiService().toggleMagazineLike(magazine.id);
      if (mounted) {
        List<Liker> likers = [];
        if (result['recent_likers'] is List) {
          likers = (result['recent_likers'] as List)
              .map((l) => Liker.fromJson(l as Map<String, dynamic>))
              .toList();
        }
        setState(() {
          _magazines![index] = magazine.copyWith(
            isLiked: result['is_liked'],
            likeCount: result['like_count'],
            recentLikers: likers,
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _magazines![index] = magazine; });
    }
  }

  void _openPdf(MagazineEdition magazine, String langCode) {
    final url = magazine.openablePdfUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF not available yet. Please check back later.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => PdfViewerScreen(
          pdfUrl: url,
          title: magazine.getTitle(langCode),
          magazineId: magazine.id,
          initialIsLiked: magazine.isLiked,
          initialLikeCount: magazine.likeCount,
        ),
      ),
    );
  }

  void _showEditionInfo(MagazineEdition magazine, String langCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (magazine.coverImageUrl.isNotEmpty || magazine.images.isNotEmpty)
                SizedBox(
                  height: 280,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 1 + magazine.images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final imageUrl = index == 0
                          ? magazine.coverImageUrl
                          : magazine.images[index - 1].imageUrl;
                      final caption = index == 0
                          ? null
                          : magazine.images[index - 1].getCaption(langCode);
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: caption != null && caption.isNotEmpty ? 250 : 280,
                              width: 190,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                width: 190,
                                height: caption != null && caption.isNotEmpty ? 250 : 280,
                                decoration: BoxDecoration(
                                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                          if (caption != null && caption.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: SizedBox(
                                width: 190,
                                child: Text(
                                  caption,
                                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Text(magazine.getTitle(langCode),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(DateFormat('MMMM dd, yyyy').format(magazine.publishDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _infoStatChip(Icons.visibility, '${magazine.viewCount}', 'Views'),
                  const SizedBox(width: 16),
                  _infoStatChip(Icons.favorite, '${magazine.likeCount}', 'Likes'),
                  if (magazine.pageCount > 0) ...[
                    const SizedBox(width: 16),
                    _infoStatChip(Icons.description, '${magazine.pageCount}', 'Pages'),
                  ],
                  if (magazine.fileSize.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    _infoStatChip(Icons.storage, magazine.fileSize, 'Size'),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              LikedByAvatars(likers: magazine.recentLikers, totalLikes: magazine.likeCount),
              const SizedBox(height: 20),
              Text(magazine.getDescription(langCode),
                style: const TextStyle(fontSize: 16, height: 1.6)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _openPdf(magazine, langCode); },
                  icon: const Icon(Icons.menu_book),
                  label: Text(magazine.hasPdf ? 'Read Magazine' : 'PDF Not Available'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burundiGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoStatChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.burundiGreen),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.magazine, style: const TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _loadMagazines();
              },
              child: _buildBody(langCode, isDark, isAuth),
            ),
    );
  }

  Widget _buildBody(String langCode, bool isDark, bool isAuth) {
    final magazines = _magazines ?? MagazineData.getMockEditions();
    final featured = magazines.where((e) => e.isFeatured).toList();
    final rest = magazines.where((e) => !e.isFeatured).toList();
    // For guests, only the first "rest" page (up to 2 cards) is visible,
    // and the rest of the body is replaced with a LoginGateBanner.
    final pageCount = isAuth
        ? (rest.length / 2).ceil()
        : (rest.isEmpty ? 0 : 1);

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Featured Hero (1 free for guests)
        if (featured.isNotEmpty)
          _buildFeaturedHero(featured.first, langCode, isDark),

        // 2-per-view carousel
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 310,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: pageCount,
              itemBuilder: (context, pageIndex) {
                final startIdx = pageIndex * 2;
                final endIdx = (startIdx + 2).clamp(0, rest.length);
                final pageMags = rest.sublist(startIdx, endIdx);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: pageMags.map((mag) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildMagazineCard(mag, langCode, isDark),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          if (pageCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pageCount, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.burundiGreen
                          : AppColors.burundiGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],

        // Login gate banner for guests — replaces any remaining magazine content.
        if (!isAuth) const LoginGateBanner(),
      ],
    );
  }

  Widget _buildFeaturedHero(MagazineEdition magazine, String langCode, bool isDark) {
    return GestureDetector(
      onTap: () => _openPdf(magazine, langCode),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: magazine.coverImageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: AppColors.burundiGreen.withValues(alpha: 0.2),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ),
                errorWidget: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.burundiGreen, Color(0xFF065A1A)]),
                  ),
                  child: const Center(child: Icon(Icons.auto_stories, size: 48, color: Colors.white54)),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.2, 0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 14, left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.auGold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('FEATURED',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(magazine.getTitle(langCode),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                          fontFamily: 'HeatherGreen', height: 1.2,
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(DateFormat('MMMM yyyy').format(magazine.publishDate),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _heroStat(Icons.visibility, '${magazine.viewCount}'),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _toggleLike(magazine),
                            child: _heroStat(
                              magazine.isLiked ? Icons.favorite : Icons.favorite_border,
                              '${magazine.likeCount}',
                              iconColor: magazine.isLiked ? Colors.red : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          LikedByAvatars(
                            likers: magazine.recentLikers,
                            totalLikes: magazine.likeCount,
                            avatarRadius: 10,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.burundiGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.menu_book, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(langCode == 'fr' ? 'Lire' : 'Read Now',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, {Color? iconColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor ?? Colors.white70),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMagazineCard(MagazineEdition magazine, String langCode, bool isDark) {
    return GestureDetector(
      onTap: () => _openPdf(magazine, langCode),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: magazine.coverImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: AppColors.burundiGreen.withValues(alpha: 0.1),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.burundiGreen.withValues(alpha: 0.08),
                        child: const Center(child: Icon(Icons.auto_stories, size: 36, color: AppColors.burundiGreen)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => _showEditionInfo(magazine, langCode),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline, size: 14, color: AppColors.burundiGreen),
                      ),
                    ),
                  ),
                  if (magazine.hasPdf)
                    Positioned(
                      bottom: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.burundiRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(magazine.getTitle(langCode),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(DateFormat('MMM yyyy').format(magazine.publishDate),
                      style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const Spacer(),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLike(magazine),
                          child: Icon(
                            magazine.isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 14, color: magazine.isLiked ? Colors.red : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text('${magazine.likeCount}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LikedByAvatars(
                            likers: magazine.recentLikers,
                            totalLikes: magazine.likeCount,
                            avatarRadius: 8,
                            overlap: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
