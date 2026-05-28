import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/translate_button.dart';

class SocialMediaScreen extends StatefulWidget {
  const SocialMediaScreen({super.key});

  @override
  State<SocialMediaScreen> createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends State<SocialMediaScreen> {
  List<Map<String, dynamic>> socialMedia = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Mock fallback data
  static final List<Map<String, dynamic>> _mockSocialMedia = [
    {
      'platform': 'facebook',
      'display_name': 'Burundi Chairmanship',
      'handle': '@BurundiAU2026',
      'url': 'https://facebook.com/BurundiAU2026',
      'follower_count': '125K',
      'description': 'Official Facebook page for updates and news',
      'icon_color': '#1877F2',
    },
    {
      'platform': 'twitter',
      'display_name': 'Burundi AU 2026',
      'handle': '@BurundiAU2026',
      'url': 'https://twitter.com/BurundiAU2026',
      'follower_count': '89K',
      'description': 'Follow us for real-time updates and live coverage',
      'icon_color': '#000000',
    },
    {
      'platform': 'instagram',
      'display_name': 'Burundi Chairmanship',
      'handle': '@burundiauchair2026',
      'url': 'https://instagram.com/burundiauchair2026',
      'follower_count': '67K',
      'description': 'Photos and stories from the Burundi Chairmanship',
      'icon_color': '#E4405F',
    },
    {
      'platform': 'youtube',
      'display_name': 'Burundi AU 2026',
      'handle': '@BurundiAU2026',
      'url': 'https://youtube.com/@BurundiAU2026',
      'follower_count': '45K',
      'description': 'Video content, speeches, and documentaries',
      'icon_color': '#FF0000',
    },
    {
      'platform': 'linkedin',
      'display_name': 'Burundi Chairmanship 2026',
      'handle': 'Burundi Chairmanship',
      'url': 'https://linkedin.com/company/burundi-au-chairmanship',
      'follower_count': '28K',
      'description': 'Professional network and policy updates',
      'icon_color': '#0A66C2',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSocialMedia();
    // Auto-refresh follower counts every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshFollowerCounts();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSocialMedia() async {
    try {
      final data = await ApiService().getSocialMediaLinks();
      if (mounted) {
        setState(() {
          socialMedia = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          socialMedia = List<Map<String, dynamic>>.from(_mockSocialMedia);
          _isLoading = false;
        });
      }
    }
  }

  /// Silently refresh follower counts without showing loading state
  Future<void> _refreshFollowerCounts() async {
    try {
      final data = await ApiService().getSocialMediaLinks();
      if (mounted && data.isNotEmpty) {
        setState(() {
          socialMedia = data;
        });
      }
    } catch (_) {
      // Silent fail — keep existing data
    }
  }

  IconData _platformIcon(String? platform) {
    switch (platform) {
      case 'facebook':
        return FontAwesomeIcons.facebookF;
      case 'twitter':
      case 'x':
        return FontAwesomeIcons.xTwitter;
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'youtube':
        return FontAwesomeIcons.youtube;
      case 'linkedin':
        return FontAwesomeIcons.linkedinIn;
      case 'tiktok':
        return FontAwesomeIcons.tiktok;
      case 'telegram':
        return FontAwesomeIcons.telegram;
      case 'whatsapp':
        return FontAwesomeIcons.whatsapp;
      case 'threads':
        return FontAwesomeIcons.threads;
      default:
        return FontAwesomeIcons.link;
    }
  }

  String _followerLabel(String? platform) {
    switch (platform) {
      case 'youtube':
        return 'subscribers';
      case 'facebook':
      case 'instagram':
      case 'tiktok':
      case 'threads':
        return 'followers';
      case 'twitter':
      case 'x':
        return 'followers';
      case 'linkedin':
        return 'followers';
      case 'telegram':
      case 'whatsapp':
        return 'members';
      default:
        return 'followers';
    }
  }

  Color _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.burundiGreen;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _loadSocialMedia();
              },
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 140,
                    pinned: true,
                    backgroundColor: AppColors.burundiGreen,
                    actions: const [TranslateButton()],
                    flexibleSpace: FlexibleSpaceBar(
                      title: const Text(
                        'Social Media',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.burundiGreen,
                              AppColors.auGold,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Icon(
                              Icons.share,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Info Section
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.info),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Stay connected with us on social media for the latest updates, news, and events.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Social Media Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= socialMedia.length) return null;
                          return _buildSocialMediaCard(socialMedia[index], isDark);
                        },
                      ),
                    ),
                  ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
                ],
              ),
            ),
    );
  }

  Widget _buildSocialMediaCard(Map<String, dynamic> social, bool isDark) {
    final color = _parseHexColor(social['icon_color'] as String?);
    final icon = _platformIcon(social['platform'] as String?);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final handleColor = isDark ? Colors.white54 : Colors.grey[600]!;
    final descriptionColor = isDark ? Colors.white60 : Colors.grey[700]!;
    final platform = social['platform'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchURL(social['url'] ?? ''),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Platform Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: FaIcon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        social['display_name'] ?? social['name'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        social['handle'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: handleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Follower count with label
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 14, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  '${social['follower_count'] ?? '0'} ${_followerLabel(platform)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (social['description'] != null && (social['description'] as String).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          social['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: descriptionColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Open Button
                Icon(
                  Icons.open_in_new,
                  color: color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
