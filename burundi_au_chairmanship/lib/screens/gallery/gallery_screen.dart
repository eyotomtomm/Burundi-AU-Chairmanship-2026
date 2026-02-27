import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Map<String, dynamic>> albums = [];
  bool _isLoading = true;

  // Mock fallback data
  static const List<Map<String, dynamic>> _mockAlbums = [
    {
      'id': 1,
      'title': 'AU Summit 2026 Highlights',
      'title_fr': 'Points forts du Sommet de l\'UA 2026',
      'photo_count': 24,
      'cover_image': null,
      'is_featured': true,
    },
    {
      'id': 2,
      'title': 'Cultural Heritage of Burundi',
      'title_fr': 'Patrimoine culturel du Burundi',
      'photo_count': 18,
      'cover_image': null,
      'is_featured': true,
    },
    {
      'id': 3,
      'title': 'Infrastructure Development',
      'title_fr': 'Développement des infrastructures',
      'photo_count': 15,
      'cover_image': null,
      'is_featured': false,
    },
    {
      'id': 4,
      'title': 'Youth & Education',
      'title_fr': 'Jeunesse et éducation',
      'photo_count': 12,
      'cover_image': null,
      'is_featured': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    try {
      final data = await ApiService().getGalleryAlbums();
      if (mounted) {
        setState(() {
          albums = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          albums = List<Map<String, dynamic>>.from(_mockAlbums);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAlbums,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    pinned: true,
                    backgroundColor: AppColors.burundiGreen,
                    flexibleSpace: FlexibleSpaceBar(
                      title: const Text(
                        'Photo Gallery',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.burundiGreen,
                              AppColors.burundiGreen.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Featured Albums
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Icon(Icons.star, color: AppColors.auGold, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Featured Albums',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final featuredAlbums = albums.where((a) => a['is_featured'] == true).toList();
                          if (index >= featuredAlbums.length) return null;
                          final album = featuredAlbums[index];
                          return _buildFeaturedAlbumCard(album);
                        },
                      ),
                    ),
                  ),

                  // All Albums
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: const Text(
                        'All Albums',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= albums.length) return null;
                          return _buildAlbumGridItem(albums[index]);
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

  Widget _buildCoverImage(String? coverUrl, {double iconSize = 50}) {
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Image.network(
        coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.photo_library, size: iconSize, color: Colors.grey),
          );
        },
      );
    }
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.photo_library, size: iconSize, color: Colors.grey),
    );
  }

  Widget _buildFeaturedAlbumCard(Map<String, dynamic> album) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening ${album['title']}')),
              );
            },
            child: Stack(
              children: [
                // Cover Image
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildCoverImage(album['cover_image']),
                ),

                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.photo, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${album['photo_count'] ?? 0} photos',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Featured Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.auGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Featured',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumGridItem(Map<String, dynamic> album) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Opening ${album['title']}')),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCoverImage(album['cover_image'], iconSize: 40),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${album['photo_count'] ?? 0} photos',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
