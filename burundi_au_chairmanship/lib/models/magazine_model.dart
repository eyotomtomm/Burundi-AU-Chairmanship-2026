import 'package:flutter/material.dart';

class MagazineImage {
  final int id;
  final String imageUrl;
  final String caption;
  final String captionFr;
  final int order;

  MagazineImage({
    required this.id,
    required this.imageUrl,
    this.caption = '',
    this.captionFr = '',
    this.order = 0,
  });

  factory MagazineImage.fromJson(Map<String, dynamic> json) {
    return MagazineImage(
      id: json['id'],
      imageUrl: json['image'] ?? '',
      caption: json['caption'] ?? '',
      captionFr: json['caption_fr'] ?? '',
      order: json['order'] ?? 0,
    );
  }

  String getCaption(String langCode) {
    if (langCode == 'fr' && captionFr.isNotEmpty) return captionFr;
    return caption;
  }
}

class MagazineEdition {
  final String id;
  final String title;
  final String titleFr;
  final String description;
  final String descriptionFr;
  final String coverImageUrl;
  final String pdfUrl;
  final String externalUrl;
  final String effectivePdfUrl;
  final DateTime publishDate;
  final bool isFeatured;
  final int viewCount;
  final int likeCount;
  final int pageCount;
  final String fileSize;
  final List<MagazineImage> images;
  final bool isLiked;

  MagazineEdition({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.description,
    required this.descriptionFr,
    required this.coverImageUrl,
    required this.pdfUrl,
    this.externalUrl = '',
    this.effectivePdfUrl = '',
    required this.publishDate,
    this.isFeatured = false,
    this.viewCount = 0,
    this.likeCount = 0,
    this.pageCount = 0,
    this.fileSize = '',
    this.images = const [],
    this.isLiked = false,
  });

  factory MagazineEdition.fromJson(Map<String, dynamic> json) {
    List<MagazineImage> imageList = [];
    if (json['images'] is List) {
      imageList = (json['images'] as List)
          .map((img) => MagazineImage.fromJson(img as Map<String, dynamic>))
          .toList();
    }

    return MagazineEdition(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      description: json['description'] ?? '',
      descriptionFr: json['description_fr'] ?? '',
      coverImageUrl: json['cover_image'] ?? '',
      pdfUrl: json['pdf_file'] ?? '',
      externalUrl: json['external_url'] ?? '',
      effectivePdfUrl: json['effective_pdf_url'] ?? json['pdf_file'] ?? '',
      publishDate: DateTime.tryParse(json['publish_date'] ?? '') ?? DateTime.now(),
      isFeatured: json['is_featured'] ?? false,
      viewCount: json['view_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      pageCount: json['page_count'] ?? 0,
      fileSize: json['file_size'] ?? '',
      images: imageList,
      isLiked: json['is_liked'] == true,
    );
  }

  MagazineEdition copyWith({int? likeCount, bool? isLiked}) {
    return MagazineEdition(
      id: id,
      title: title,
      titleFr: titleFr,
      description: description,
      descriptionFr: descriptionFr,
      coverImageUrl: coverImageUrl,
      pdfUrl: pdfUrl,
      externalUrl: externalUrl,
      effectivePdfUrl: effectivePdfUrl,
      publishDate: publishDate,
      isFeatured: isFeatured,
      viewCount: viewCount,
      likeCount: likeCount ?? this.likeCount,
      pageCount: pageCount,
      fileSize: fileSize,
      images: images,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  /// Returns the best available PDF URL (uploaded file > external link)
  String get openablePdfUrl {
    if (effectivePdfUrl.isNotEmpty) return effectivePdfUrl;
    if (pdfUrl.isNotEmpty) return pdfUrl;
    return externalUrl;
  }

  bool get hasPdf => openablePdfUrl.isNotEmpty;

  String getTitle(String languageCode) => languageCode == 'fr' ? titleFr : title;
  String getDescription(String languageCode) => languageCode == 'fr' ? descriptionFr : description;
}

class Category {
  final int id;
  final String name;
  final String nameFr;
  final String color;
  final int order;

  Category({
    required this.id,
    required this.name,
    this.nameFr = '',
    this.color = '#1EB53A',
    this.order = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'] ?? '',
      nameFr: json['name_fr'] ?? '',
      color: json['color'] ?? '#1EB53A',
      order: json['order'] ?? 0,
    );
  }

  Color get parsedColor {
    String hex = color.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String getDisplayName(String langCode) {
    if (langCode == 'fr' && nameFr.isNotEmpty) return nameFr;
    return name;
  }
}

class ArticleMedia {
  final int id;
  final String mediaType;
  final String imageUrl;
  final String videoUrl;
  final String caption;
  final String captionFr;
  final int order;

  ArticleMedia({
    required this.id,
    required this.mediaType,
    this.imageUrl = '',
    this.videoUrl = '',
    this.caption = '',
    this.captionFr = '',
    this.order = 0,
  });

  factory ArticleMedia.fromJson(Map<String, dynamic> json) {
    return ArticleMedia(
      id: json['id'],
      mediaType: json['media_type'] ?? 'image',
      imageUrl: json['image'] ?? '',
      videoUrl: json['video_url'] ?? '',
      caption: json['caption'] ?? '',
      captionFr: json['caption_fr'] ?? '',
      order: json['order'] ?? 0,
    );
  }

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  String getCaption(String langCode) {
    if (langCode == 'fr' && captionFr.isNotEmpty) return captionFr;
    return caption;
  }
}

class Article {
  final String id;
  final String title;
  final String titleFr;
  final String content;
  final String contentFr;
  final String imageUrl;
  final String author;
  final DateTime publishDate;
  final Category? category;
  final bool isFeatured;
  final int viewCount;
  final int commentCount;
  final int likeCount;
  final bool isLiked;
  final List<ArticleMedia> media;

  Article({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.content,
    required this.contentFr,
    required this.imageUrl,
    required this.author,
    required this.publishDate,
    this.category,
    this.isFeatured = false,
    this.viewCount = 0,
    this.commentCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    this.media = const [],
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    Category? cat;
    final rawCat = json['category'];
    if (rawCat is Map<String, dynamic>) {
      cat = Category.fromJson(rawCat);
    }

    List<ArticleMedia> mediaList = [];
    if (json['media'] is List) {
      mediaList = (json['media'] as List)
          .map((m) => ArticleMedia.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    return Article(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      content: json['content'] ?? '',
      contentFr: json['content_fr'] ?? '',
      imageUrl: json['image'] ?? '',
      author: json['author'] ?? '',
      publishDate: DateTime.tryParse(json['publish_date'] ?? '') ?? DateTime.now(),
      category: cat,
      isFeatured: json['is_featured'] ?? false,
      viewCount: json['view_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      isLiked: json['is_liked'] == true,
      media: mediaList,
    );
  }

  /// Lowercase slug for backward-compat filtering
  String get categorySlug => category?.name.toLowerCase() ?? '';

  Article copyWith({
    int? viewCount,
    int? commentCount,
    int? likeCount,
    bool? isLiked,
  }) {
    return Article(
      id: id,
      title: title,
      titleFr: titleFr,
      content: content,
      contentFr: contentFr,
      imageUrl: imageUrl,
      author: author,
      publishDate: publishDate,
      category: category,
      isFeatured: isFeatured,
      viewCount: viewCount ?? this.viewCount,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      media: media,
    );
  }

  String getTitle(String languageCode) => languageCode == 'fr' ? titleFr : title;
  String getContent(String languageCode) => languageCode == 'fr' ? contentFr : content;
}

class ArticleComment {
  final int id;
  final int userId;
  final String userName;
  final String? profilePicture;
  final String content;
  final DateTime createdAt;

  ArticleComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.profilePicture,
    required this.content,
    required this.createdAt,
  });

  factory ArticleComment.fromJson(Map<String, dynamic> json) {
    return ArticleComment(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'] ?? '',
      profilePicture: json['profile_picture'],
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// Mock Data
class MagazineData {
  static List<MagazineEdition> getMockEditions() {
    return [
      MagazineEdition(
        id: '1',
        title: 'AU Summit Special Edition',
        titleFr: 'Édition spéciale du Sommet de l\'UA',
        description: 'Comprehensive coverage of the African Union Summit hosted by Burundi',
        descriptionFr: 'Couverture complète du Sommet de l\'Union africaine organisé par le Burundi',
        coverImageUrl: 'https://via.placeholder.com/400x600/1EB53A/FFFFFF?text=AU+Summit',
        pdfUrl: '',
        externalUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        publishDate: DateTime(2025, 2, 1),
        isFeatured: true,
        viewCount: 1240,
        likeCount: 89,
        pageCount: 24,
        fileSize: '3.2 MB',
      ),
      MagazineEdition(
        id: '2',
        title: 'Burundi: A Nation Rising',
        titleFr: 'Burundi: Une nation en essor',
        description: 'Explore Burundi\'s journey towards progress and development',
        descriptionFr: 'Explorez le parcours du Burundi vers le progrès et le développement',
        coverImageUrl: 'https://via.placeholder.com/400x600/CE1126/FFFFFF?text=Burundi',
        pdfUrl: '',
        externalUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        publishDate: DateTime(2025, 1, 15),
        viewCount: 856,
        likeCount: 62,
        pageCount: 18,
        fileSize: '2.1 MB',
      ),
      MagazineEdition(
        id: '3',
        title: 'African Unity in Action',
        titleFr: 'L\'unité africaine en action',
        description: 'Stories of collaboration and partnership across Africa',
        descriptionFr: 'Histoires de collaboration et de partenariat à travers l\'Afrique',
        coverImageUrl: 'https://via.placeholder.com/400x600/D4AF37/FFFFFF?text=Unity',
        pdfUrl: '',
        externalUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        publishDate: DateTime(2025, 1, 1),
        viewCount: 543,
        likeCount: 37,
        pageCount: 12,
        fileSize: '1.8 MB',
      ),
    ];
  }

  static List<Article> getMockArticles() {
    return [
      Article(
        id: '1',
        title: 'Burundi Takes the Helm of African Union',
        titleFr: 'Le Burundi prend la tête de l\'Union africaine',
        content: 'In a historic moment, Burundi assumes the chairmanship of the African Union...',
        contentFr: 'Dans un moment historique, le Burundi assume la présidence de l\'Union africaine...',
        imageUrl: 'https://via.placeholder.com/800x400/1EB53A/FFFFFF?text=Leadership',
        author: 'Editorial Team',
        publishDate: DateTime(2025, 2, 1),
        category: Category(id: 1, name: 'Politics', nameFr: 'Politique', color: '#CE1126'),
        isFeatured: true,
      ),
      Article(
        id: '2',
        title: 'Economic Development Initiatives',
        titleFr: 'Initiatives de développement économique',
        content: 'New programs aimed at boosting economic growth across the continent...',
        contentFr: 'Nouveaux programmes visant à stimuler la croissance économique sur le continent...',
        imageUrl: 'https://via.placeholder.com/800x400/CE1126/FFFFFF?text=Economy',
        author: 'Finance Desk',
        publishDate: DateTime(2025, 1, 28),
        category: Category(id: 2, name: 'Economy', nameFr: 'Économie', color: '#17a2b8'),
      ),
      Article(
        id: '3',
        title: 'Cultural Heritage Celebration',
        titleFr: 'Célébration du patrimoine culturel',
        content: 'A look at Burundi\'s rich cultural heritage and traditions...',
        contentFr: 'Un regard sur le riche patrimoine culturel et les traditions du Burundi...',
        imageUrl: 'https://via.placeholder.com/800x400/D4AF37/FFFFFF?text=Culture',
        author: 'Culture Editor',
        publishDate: DateTime(2025, 1, 20),
        category: Category(id: 3, name: 'Culture', nameFr: 'Culture', color: '#D4AF37'),
      ),
    ];
  }
}
