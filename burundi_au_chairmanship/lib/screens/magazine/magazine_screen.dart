import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import 'pdf_viewer_screen.dart';

class MagazineScreen extends StatefulWidget {
  const MagazineScreen({super.key});

  @override
  State<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends State<MagazineScreen> {
  List<MagazineEdition>? _magazines;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMagazines();
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
      await ApiService().post('magazines/${magazine.id}/toggle_like/', {});
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
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          pdfUrl: url,
          title: magazine.getTitle(langCode),
          magazineId: magazine.id,
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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Portrait image gallery (cover + additional images)
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
              Text(
                magazine.getTitle(langCode),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMMM dd, yyyy').format(magazine.publishDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              // Stats row
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
              const SizedBox(height: 20),
              Text(
                magazine.getDescription(langCode),
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
              const SizedBox(height: 24),
              // Open PDF button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openPdf(magazine, langCode);
                  },
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.magazine,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
            onRefresh: _loadMagazines,
            child: Builder(builder: (context) {
          final magazines = _magazines ?? MagazineData.getMockEditions();

          return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.58,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: magazines.length,
              itemBuilder: (context, index) {
                final mag = magazines[index];
                return _buildMagazineCard(context, mag, langCode, isDark);
              },
            );
          }),
          ),
    );
  }

  Widget _buildMagazineCard(BuildContext context, MagazineEdition magazine, String langCode, bool isDark) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openPdf(magazine, langCode),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image - takes full top portion
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: magazine.coverImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: AppColors.burundiGreen.withValues(alpha: 0.1),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.burundiGreen.withValues(alpha: 0.2),
                            AppColors.burundiGreen.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_stories_rounded, size: 40, color: AppColors.burundiGreen),
                          SizedBox(height: 4),
                          Text('Magazine', style: TextStyle(color: AppColors.burundiGreen, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  // Gradient overlay at bottom of image
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Info button (top-right)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _showEditionInfo(magazine, langCode),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.info_outline, size: 16, color: AppColors.burundiGreen),
                      ),
                    ),
                  ),
                  // Featured badge (top-left)
                  if (magazine.isFeatured)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.auGold,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'FEATURED',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  // PDF badge (bottom-left of image)
                  if (magazine.hasPdf)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.burundiRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text('PDF', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title and date
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Text(
                magazine.getTitle(langCode),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                DateFormat('MMM yyyy').format(magazine.publishDate),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // White stat boxes row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Row(
                children: [
                  _statPill(Icons.visibility, '${magazine.viewCount}', isDark),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _toggleLike(magazine),
                    child: _statPill(
                      magazine.isLiked ? Icons.favorite : Icons.favorite_border,
                      '${magazine.likeCount}',
                      isDark,
                      iconColor: magazine.isLiked ? Colors.red : Colors.red[400],
                    ),
                  ),
                  if (magazine.pageCount > 0) ...[
                    const Spacer(),
                    _statPill(Icons.description, '${magazine.pageCount}p', isDark),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(IconData icon, String value, bool isDark, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? (isDark ? Colors.grey[400] : Colors.grey[500])),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
