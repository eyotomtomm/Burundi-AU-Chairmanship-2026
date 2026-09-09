import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/environment.dart';
import '../../l10n/app_localizations.dart';
import '../../models/api_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/african_pattern.dart';
import '../../widgets/login_gate.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/translate_button.dart';
import '../../config/app_ds.dart';

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
      backgroundColor: Ds.bg(context),
      appBar: AppBar(
        title: Text(l10n.resources),
        actions: const [TranslateButton()],
      ),
      body: _isLoading
          ? const ShimmerListItemSkeleton()
          : _error != null && (_resources == null || _resources!.isEmpty)
              ? _buildError()
              : _grouped.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_outlined, size: 56, color: Ds.muted(context)),
                            const SizedBox(height: 16),
                            Text(
                              l10n.translate('res_coming_soon'),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Ds.body(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.translate('res_coming_soon_desc'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Ds.muted(context), height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildResourcesList(context, langCode),
    );
  }

  Widget _buildResourcesList(BuildContext context, String langCode) {
    final isAuth = context.watch<AuthProvider>().isAuthenticated;

    // Flatten all resources into a single list with category info
    final allItems = <MapEntry<String, ApiResource>>[];
    for (final category in _grouped.keys) {
      for (final item in _grouped[category]!) {
        allItems.add(MapEntry(category, item));
      }
    }

    final itemCount = LoginGate.itemCountFor(
      actualCount: allItems.length,
      isAuthenticated: isAuth,
    );

    return AfricanPatternBackground(
      opacity: 0.03,
      child: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          setState(() => _isLoading = true);
          await _loadData();
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final slot = LoginGate.slotFor(
              index: index,
              actualCount: allItems.length,
              isAuthenticated: isAuth,
            );

            Widget buildItem(int dataIndex) {
              final entry = allItems[dataIndex];
              final color = _categoryColor(entry.key);
              return _buildResourceItem(context, entry.value, color, langCode);
            }

            // Show category header before the first item in each category
            Widget maybePrefixHeader(int dataIndex, Widget child) {
              if (dataIndex == 0) {
                final entry = allItems[dataIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryHeader(context, entry.key, _grouped[entry.key]!, langCode),
                    child,
                  ],
                );
              }
              final prevCategory = allItems[dataIndex - 1].key;
              final curCategory = allItems[dataIndex].key;
              if (prevCategory != curCategory) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildCategoryHeader(context, curCategory, _grouped[curCategory]!, langCode),
                    child,
                  ],
                );
              }
              return child;
            }

            switch (slot) {
              case LoginGateSlot.free:
                return maybePrefixHeader(index, buildItem(index));
              case LoginGateSlot.banner:
                return const LoginGateBanner(
                  margin: EdgeInsets.symmetric(vertical: 12),
                );
              case LoginGateSlot.blurred:
                final dataIndex = LoginGate.dataIndexFor(index, LoginGate.defaultFreeItems);
                if (dataIndex == null || dataIndex >= allItems.length) {
                  return const SizedBox.shrink();
                }
                return LockedContentWrap(
                  locked: true,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: buildItem(dataIndex),
                );
              case LoginGateSlot.hidden:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String category, List<ApiResource> items, String langCode) {
    final theme = Theme.of(context);
    final color = _categoryColor(category);
    final categoryName = items.first.getCategoryName(langCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
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
    );
  }

  Widget _buildError() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: AppColors.burundiGreen.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(l10n.translate('res_could_not_load')),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadData();
            },
            child: Text(l10n.translate('retry')),
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

  Widget _buildResourceItem(BuildContext context, ApiResource item, Color accentColor, String langCode) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

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
              onPressed: () => _view(item),
              tooltip: l10n.translate('res_view'),
            ),
            _downloading.contains(item.id)
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined),
                    color: accentColor,
                    onPressed: () => _download(item),
                    tooltip: l10n.translate('download'),
                  ),
          ],
        ),
      ),
    );
  }

  final Set<int> _downloading = {};

  void _snack(String key, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context).translate(key)),
      backgroundColor: error ? AppColors.error : AppColors.burundiGreen,
    ));
  }

  Future<void> _view(ApiResource item) async {
    if (item.file.isEmpty) {
      _snack('res_file_not_available', error: true);
      return;
    }
    ApiService().recordResourceView(item.id).catchError((_) => <String, dynamic>{});
    final uri = Uri.parse(Environment.fixMediaUrl(item.file));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('res_could_not_open_file', error: true);
    }
  }

  /// Same Dio → temp dir → OpenFilex flow as the magazine PDF viewer.
  Future<void> _download(ApiResource item) async {
    if (item.file.isEmpty) {
      _snack('res_file_not_available', error: true);
      return;
    }
    setState(() => _downloading.add(item.id));
    try {
      final url = Environment.fixMediaUrl(item.file);
      final name = Uri.parse(url).pathSegments.lastOrNull ?? 'resource_${item.id}';
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/resources/$name';
      await Directory('${dir.path}/resources').create(recursive: true);
      if (!File(path).existsSync()) {
        await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 120),
        )).download(url, path);
      }
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        _snack('res_downloaded_no_app');
      }
    } catch (_) {
      _snack('res_download_failed', error: true);
    } finally {
      if (mounted) setState(() => _downloading.remove(item.id));
    }
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
