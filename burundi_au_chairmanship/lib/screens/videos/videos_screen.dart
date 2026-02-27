import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/api_service.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  String selectedCategory = 'all';
  List<Map<String, dynamic>> _allVideos = [];
  bool _isLoading = true;

  final Map<String, String> categoryLabels = {
    'all': 'All Videos',
    'highlight': 'Highlights',
    'speech': 'Speeches',
    'documentary': 'Documentaries',
    'interview': 'Interviews',
    'event': 'Events',
    'cultural': 'Cultural',
  };

  // Mock fallback data
  static const List<Map<String, dynamic>> _mockVideos = [
    {
      'id': 1,
      'title': 'AU Chairmanship Opening Ceremony',
      'duration': '1:45:30',
      'category': 'highlight',
      'view_count': 15420,
      'thumbnail': null,
      'is_featured': true,
    },
    {
      'id': 2,
      'title': 'President\'s Vision for Africa',
      'duration': '32:15',
      'category': 'speech',
      'view_count': 8750,
      'thumbnail': null,
      'is_featured': true,
    },
    {
      'id': 3,
      'title': 'Burundi: Heart of Africa Documentary',
      'duration': '28:40',
      'category': 'documentary',
      'view_count': 12300,
      'thumbnail': null,
      'is_featured': true,
    },
    {
      'id': 4,
      'title': 'AU Leaders Summit Roundtable',
      'duration': '1:15:20',
      'category': 'event',
      'view_count': 5640,
      'thumbnail': null,
      'is_featured': false,
    },
    {
      'id': 5,
      'title': 'Traditional Burundian Drumming',
      'duration': '8:45',
      'category': 'cultural',
      'view_count': 9200,
      'thumbnail': null,
      'is_featured': false,
    },
    {
      'id': 6,
      'title': 'Interview: Peace & Security',
      'duration': '18:30',
      'category': 'interview',
      'view_count': 3850,
      'thumbnail': null,
      'is_featured': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final data = await ApiService().getVideos();
      if (mounted) {
        setState(() {
          _allVideos = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allVideos = List<Map<String, dynamic>>.from(_mockVideos);
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get filteredVideos {
    if (selectedCategory == 'all') return _allVideos;
    return _allVideos.where((v) => v['category'] == selectedCategory).toList();
  }

  String _formatViewCount(dynamic count) {
    if (count == null) return '0';
    final n = count is int ? count : int.tryParse(count.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVideos,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    pinned: true,
                    backgroundColor: AppColors.burundiRed,
                    flexibleSpace: FlexibleSpaceBar(
                      title: const Text(
                        'Videos',
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
                              AppColors.burundiRed,
                              AppColors.burundiRed.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Category Filter
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categoryLabels.entries.map((entry) {
                            final isSelected = selectedCategory == entry.key;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(entry.value),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    selectedCategory = entry.key;
                                  });
                                },
                                selectedColor: AppColors.burundiRed,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // Video List
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= filteredVideos.length) return null;
                          final video = filteredVideos[index];
                          return _buildVideoCard(video);
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

  Widget _buildVideoCard(Map<String, dynamic> video) {
    final thumbnailUrl = video['thumbnail'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Record view
          final id = video['id'];
          if (id != null) {
            ApiService().recordVideoView(id.toString()).catchError((_) => <String, dynamic>{});
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playing ${video['title']}')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                        ? Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.play_circle_outline, size: 60, color: Colors.grey),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.play_circle_outline, size: 60, color: Colors.grey),
                          ),
                  ),
                ),

                // Play Button Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      color: Colors.black.withOpacity(0.2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Duration Badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      video['duration'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Featured Badge
                if (video['is_featured'] == true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.auGold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Featured',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatViewCount(video['view_count'])} views',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(video['category'] ?? '').withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          categoryLabels[video['category']] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getCategoryColor(video['category'] ?? ''),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'highlight':
        return AppColors.burundiGreen;
      case 'speech':
        return AppColors.auGold;
      case 'documentary':
        return AppColors.info;
      case 'interview':
        return AppColors.burundiRed;
      case 'event':
        return Colors.purple;
      case 'cultural':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
