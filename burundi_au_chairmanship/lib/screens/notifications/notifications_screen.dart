import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loading.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.get('notifications/');
      List<Map<String, dynamic>> items;
      if (response is Map && response['results'] != null) {
        items = List<Map<String, dynamic>>.from(response['results']);
      } else if (response is List) {
        items = List<Map<String, dynamic>>.from(response);
      } else {
        items = [];
      }
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
      // Mark all as read on the server so the badge clears when user goes back
      await _markAllAsRead();
    } catch (e) {
      if (kDebugMode) debugPrint('Notifications load error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsAsRead();
      // Update local state so cards look read
      setState(() {
        for (final n in _notifications) {
          n['is_read'] = true;
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to mark all notifications as read: $e');
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await _apiService.post('notifications/$notificationId/mark-as-read/', {});
      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      // Silently fail - not critical
      if (kDebugMode) debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    final notificationId = notification['id'] as int;
    final actionType = notification['action_type'] as String?;
    final actionValue = notification['action_value'] as String?;

    // Mark as read
    if (notification['is_read'] != true) {
      await _markAsRead(notificationId);
    }

    // Handle action
    if (actionType == null || actionValue == null || actionValue.isEmpty || actionType == 'none') {
      return;
    }

    if (actionType == 'route') {
      if (!mounted) return;
      Navigator.pushNamed(context, actionValue);
    } else if (actionType == 'url') {
      final uri = Uri.parse(actionValue);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final langCode = Provider.of<LanguageProvider>(context).languageCode;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('notifications')),
        backgroundColor: AppColors.burundiGreen,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(isDarkMode, langCode, loc),
    );
  }

  Widget _buildBody(bool isDarkMode, String langCode, AppLocalizations? loc) {
    if (_isLoading) {
      return const ShimmerListItemSkeleton();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 64, color: isDarkMode ? Colors.grey[500] : Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                loc?.translate('error_loading_notifications') ?? 'Could not load notifications',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(loc?.translate('retry') ?? 'Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burundiGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              loc?.translate('no_notifications') ?? 'No notifications',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await _loadNotifications();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification, isDarkMode, langCode);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, bool isDarkMode, String langCode) {
    final isRead = notification['is_read'] == true;
    final title = langCode == 'fr'
        ? (notification['title_fr'] ?? notification['title'] ?? '')
        : (notification['title'] ?? '');
    final message = langCode == 'fr'
        ? (notification['message_fr'] ?? notification['message'] ?? '')
        : (notification['message'] ?? '');
    final notificationType = notification['notification_type'] as String? ?? 'general';
    final imageUrl = notification['image'] as String?;
    final createdAt = notification['created_at'] as String?;

    // Icon based on notification type
    IconData icon;
    Color iconColor;
    switch (notificationType) {
      case 'article':
        icon = Icons.article;
        iconColor = AppColors.burundiGreen;
        break;
      case 'magazine':
        icon = Icons.auto_stories;
        iconColor = AppColors.auGold;
        break;
      case 'event':
        icon = Icons.event;
        iconColor = AppColors.burundiRed;
        break;
      case 'system':
        icon = Icons.info;
        iconColor = AppColors.burundiGreen;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isRead ? 0 : 2,
      color: isRead
          ? (isDarkMode ? Colors.grey[850] : Colors.grey[100])
          : (isDarkMode ? Colors.grey[800] : Colors.white),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.burundiGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 100,
                              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                    if (createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
