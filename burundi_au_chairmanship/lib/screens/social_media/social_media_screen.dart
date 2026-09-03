import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_ds.dart';
import '../../services/api_service.dart';
import '../../widgets/ds/ds_widgets.dart';
import '../../widgets/async_content_view.dart';
import '../../utils/color_utils.dart';
import '../../l10n/app_localizations.dart';

class SocialMediaScreen extends StatefulWidget {
  const SocialMediaScreen({super.key});

  @override
  State<SocialMediaScreen> createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends State<SocialMediaScreen> {
  List<Map<String, dynamic>> socialMedia = [];
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _refreshTimer;

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
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = socialMedia.isEmpty;
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

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('could_not_open_link'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      backgroundColor: Ds.bg(context),
      appBar: AppBar(title: Text(fr ? 'Suivez-nous' : 'Follow us')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _hasError
              ? AsyncContentView(
                  state: AsyncContentState.error,
                  onRetry: () {
                    setState(() => _isLoading = true);
                    _loadSocialMedia();
                  },
                  onRefresh: _loadSocialMedia,
                  child: const SizedBox.shrink(),
                )
              : RefreshIndicator(
              color: Ds.green,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await _loadSocialMedia();
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  DsCard(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Column(
                      children: [
                        Text(
                          fr
                              ? 'Restez connecté avec la présidence'
                              : 'Stay connected with the chairmanship',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Ds.ink(context)),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          fr
                              ? 'Canaux officiels uniquement — cherchez le badge vérifié.'
                              : 'Official channels only — look for the verified badge.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, height: 1.5, color: Ds.body(context)),
                        ),
                      ],
                    ),
                  ),
                  for (final social in socialMedia)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _buildSocialMediaCard(social, fr),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSocialMediaCard(Map<String, dynamic> social, bool fr) {
    final color = hexToColor((social['icon_color'] as String?) ?? '');
    final icon = _platformIcon(social['platform'] as String?);
    final platform = social['platform'] as String?;
    final followers = social['follower_count']?.toString() ?? '';

    return DsCard(
      onTap: () => _launchURL(social['url'] ?? ''),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(Ds.rTile),
            ),
            child: Center(child: FaIcon(icon, color: Colors.white, size: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  social['handle']?.toString().isNotEmpty == true
                      ? social['handle']
                      : (social['display_name'] ?? social['name'] ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ds.cardTitle(context),
                ),
                if (followers.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('$followers ${_followerLabel(platform)}',
                      style: Ds.meta(context)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          DsOutlineButton(fr ? 'Suivre' : 'Follow',
              radius: Ds.rPill, onTap: () => _launchURL(social['url'] ?? '')),
        ],
      ),
    );
  }
}
