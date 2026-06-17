import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Liker {
  final int userId;
  final String name;
  final String? profilePicture;

  Liker({required this.userId, required this.name, this.profilePicture});

  factory Liker.fromJson(Map<String, dynamic> json) {
    return Liker(
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      profilePicture: json['profile_picture'],
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'profile_picture': profilePicture,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class LikedByAvatars extends StatelessWidget {
  final List<Liker> likers;
  final int totalLikes;
  final double avatarRadius;
  final double overlap;

  const LikedByAvatars({
    super.key,
    required this.likers,
    required this.totalLikes,
    this.avatarRadius = 12,
    this.overlap = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (likers.isEmpty || totalLikes == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shown = likers.take(3).toList();
    final remaining = totalLikes - shown.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown.length * (avatarRadius * 2 - overlap) + overlap,
          height: avatarRadius * 2 + 2,
          child: Stack(
            children: List.generate(shown.length, (index) {
              final liker = shown[index];
              return Positioned(
                left: index * (avatarRadius * 2 - overlap),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.grey[900]! : Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: isDark
                        ? Colors.grey[700]
                        : Colors.grey[300],
                    backgroundImage: liker.profilePicture != null
                        ? CachedNetworkImageProvider(liker.profilePicture!, maxWidth: 100)
                        : null,
                    child: liker.profilePicture == null
                        ? Text(
                            liker.initials,
                            style: TextStyle(
                              fontSize: avatarRadius * 0.8,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        if (remaining > 0) ...[
          const SizedBox(width: 4),
          Text(
            '+$remaining',
            style: TextStyle(
              fontSize: avatarRadius * 0.85,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}
