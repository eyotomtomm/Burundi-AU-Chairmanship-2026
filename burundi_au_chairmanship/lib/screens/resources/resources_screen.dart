import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../widgets/african_pattern.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  List<ApiResource>? _resources;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ApiService();
      final resources = await api.getResources();
      if (!mounted) return;
      setState(() {
        _resources = resources;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// Group resources by category
  Map<String, List<ApiResource>> get _grouped {
    final map = <String, List<ApiResource>>{};
    for (final r in _resources ?? []) {
      map.putIfAbsent(r.category, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resources),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && (_resources == null || _resources!.isEmpty)
              ? _buildError()
              : AfricanPatternBackground(
                  opacity: 0.03,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      setState(() => _isLoading = true);
                      await _loadData();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _grouped.length,
                      itemBuilder: (context, index) {
                        final category = _grouped.keys.elementAt(index);
                        final items = _grouped[category]!;
                        return _buildCategorySection(context, category, items, langCode);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: AppColors.burundiGreen.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('Could not load resources'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'official_documents':
        return Icons.description;
      case 'country_info':
        return Icons.info;
      case 'media':
        return Icons.photo_library;
      case 'reference':
        return Icons.menu_book;
      default:
        return Icons.folder;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'official_documents':
        return AppColors.burundiGreen;
      case 'country_info':
        return AppColors.auGold;
      case 'media':
        return AppColors.burundiRed;
      case 'reference':
        return AppColors.patternOrange;
      default:
        return AppColors.info;
    }
  }

  Widget _buildCategorySection(BuildContext context, String category, List<ApiResource> items, String langCode) {
    final theme = Theme.of(context);
    final color = _categoryColor(category);
    final categoryName = items.first.getCategoryName(langCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_categoryIcon(category), color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              categoryName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items.map((item) => _buildResourceItem(context, item, color, langCode)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildResourceItem(BuildContext context, ApiResource item, Color accentColor, String langCode) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getTypeColor(item.fileType).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTypeIcon(item.fileType),
            color: _getTypeColor(item.fileType),
            size: 24,
          ),
        ),
        title: Text(
          item.getTitle(langCode),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getTypeColor(item.fileType).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.fileType.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getTypeColor(item.fileType),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(item.fileSize, style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              color: accentColor,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening: ${item.getTitle(langCode)}'),
                    backgroundColor: AppColors.burundiGreen,
                  ),
                );
              },
              tooltip: 'View',
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              color: accentColor,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloading: ${item.getTitle(langCode)}'),
                    backgroundColor: AppColors.burundiGreen,
                    action: SnackBarAction(label: 'Cancel', textColor: Colors.white, onPressed: () {}),
                  ),
                );
              },
              tooltip: 'Download',
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return AppColors.burundiRed;
      case 'zip':
        return AppColors.patternOrange;
      default:
        return AppColors.lightTextSecondary;
    }
  }
}
