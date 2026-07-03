import 'package:flutter/material.dart';

class FactCategory {
  final int id;
  final String name;
  final String nameFr;
  final String iconName;
  final String color;

  FactCategory({
    required this.id,
    required this.name,
    this.nameFr = '',
    this.iconName = '',
    this.color = '#1EB53A',
  });

  factory FactCategory.fromJson(Map<String, dynamic> json) {
    return FactCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameFr: json['name_fr'] ?? '',
      iconName: json['icon_name'] ?? '',
      color: json['color'] ?? '#1EB53A',
    );
  }

  String getDisplayName(String langCode) {
    if (langCode == 'fr' && nameFr.isNotEmpty) return nameFr;
    return name;
  }

  Color get parsedColor {
    String hex = color.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class Fact {
  final int id;
  final String title;
  final String titleFr;
  final String content;
  final String contentFr;
  final String contentPreview;
  final String contentPreviewFr;
  final FactCategory? category;
  final String factType;
  final String source;
  final String sourceFr;
  final String authorName;
  final String authorTitle;
  final String authorTitleFr;
  final String image;
  final bool isFeatured;
  final int viewCount;
  final DateTime createdAt;

  Fact({
    required this.id,
    required this.title,
    this.titleFr = '',
    this.content = '',
    this.contentFr = '',
    this.contentPreview = '',
    this.contentPreviewFr = '',
    this.category,
    this.factType = 'fact',
    this.source = '',
    this.sourceFr = '',
    this.authorName = '',
    this.authorTitle = '',
    this.authorTitleFr = '',
    this.image = '',
    this.isFeatured = false,
    this.viewCount = 0,
    required this.createdAt,
  });

  factory Fact.fromJson(Map<String, dynamic> json) {
    FactCategory? cat;
    final rawCat = json['category'];
    if (rawCat is Map<String, dynamic>) {
      cat = FactCategory.fromJson(rawCat);
    }

    return Fact(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      content: json['content'] ?? '',
      contentFr: json['content_fr'] ?? '',
      contentPreview: json['content_preview'] ?? '',
      contentPreviewFr: json['content_preview_fr'] ?? '',
      category: cat,
      factType: json['fact_type'] ?? 'fact',
      source: json['source'] ?? '',
      sourceFr: json['source_fr'] ?? '',
      authorName: json['author_name'] ?? '',
      authorTitle: json['author_title'] ?? '',
      authorTitleFr: json['author_title_fr'] ?? '',
      image: json['image'] ?? '',
      isFeatured: json['is_featured'] ?? false,
      viewCount: json['view_count'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  String getTitle(String langCode) {
    if (langCode == 'fr' && titleFr.isNotEmpty) return titleFr;
    return title.isNotEmpty ? title : titleFr;
  }

  String getContent(String langCode) {
    if (langCode == 'fr' && contentFr.isNotEmpty) return contentFr;
    return content.isNotEmpty ? content : contentFr;
  }

  String getContentPreview(String langCode) {
    if (langCode == 'fr' && contentPreviewFr.isNotEmpty) return contentPreviewFr;
    return contentPreview.isNotEmpty ? contentPreview : contentPreviewFr;
  }

  String getSource(String langCode) {
    if (langCode == 'fr' && sourceFr.isNotEmpty) return sourceFr;
    return source;
  }

  String getAuthorTitle(String langCode) {
    if (langCode == 'fr' && authorTitleFr.isNotEmpty) return authorTitleFr;
    return authorTitle;
  }

  bool get isQuote => factType == 'quote';
  bool get isFact => factType == 'fact';
}
