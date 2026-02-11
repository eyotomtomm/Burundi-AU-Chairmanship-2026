import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../models/magazine_model.dart';
import '../../services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class MagazineScreen extends StatefulWidget {
  const MagazineScreen({super.key});

  @override
  State<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends State<MagazineScreen> {
  late Future<List<MagazineEdition>> _magazinesFuture;

  @override
  void initState() {
    super.initState();
    _magazinesFuture = _loadMagazines();
  }

  Future<List<MagazineEdition>> _loadMagazines() async {
    try {
      return await ApiService().getMagazines();
    } catch (_) {
      return MagazineData.getMockEditions();
    }
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
          style: GoogleFonts.oswald(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<MagazineEdition>>(
        future: _magazinesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final magazines = snapshot.data ?? MagazineData.getMockEditions();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _magazinesFuture = _loadMagazines();
              });
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: magazines.length,
              itemBuilder: (context, index) {
                final mag = magazines[index];
                return _buildMagazineCard(context, mag, langCode, isDark);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMagazineCard(BuildContext context, MagazineEdition magazine, String langCode, bool isDark) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (magazine.pdfUrl.isNotEmpty) {
            launchUrl(Uri.parse(magazine.pdfUrl), mode: LaunchMode.externalApplication);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              flex: 3,
              child: CachedNetworkImage(
                imageUrl: magazine.coverImageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.burundiGreen.withValues(alpha: 0.1),
                  child: const Icon(Icons.auto_stories_rounded, size: 40, color: AppColors.burundiGreen),
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (magazine.isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: AppColors.auGold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'FEATURED',
                          style: GoogleFonts.oswald(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        magazine.getTitle(langCode),
                        style: GoogleFonts.oswald(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat('MMM yyyy').format(magazine.publishDate),
                      style: GoogleFonts.oswald(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
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
