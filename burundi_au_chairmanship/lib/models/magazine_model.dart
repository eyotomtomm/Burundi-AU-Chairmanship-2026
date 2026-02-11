class MagazineEdition {
  final String id;
  final String title;
  final String titleFr;
  final String description;
  final String descriptionFr;
  final String coverImageUrl;
  final String pdfUrl;
  final DateTime publishDate;
  final bool isFeatured;

  MagazineEdition({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.description,
    required this.descriptionFr,
    required this.coverImageUrl,
    required this.pdfUrl,
    required this.publishDate,
    this.isFeatured = false,
  });

  factory MagazineEdition.fromJson(Map<String, dynamic> json) {
    return MagazineEdition(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      description: json['description'] ?? '',
      descriptionFr: json['description_fr'] ?? '',
      coverImageUrl: json['cover_image'] ?? '',
      pdfUrl: json['pdf_file'] ?? '',
      publishDate: DateTime.tryParse(json['publish_date'] ?? '') ?? DateTime.now(),
      isFeatured: json['is_featured'] ?? false,
    );
  }

  String getTitle(String languageCode) => languageCode == 'fr' ? titleFr : title;
  String getDescription(String languageCode) => languageCode == 'fr' ? descriptionFr : description;
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
  final String category;
  final bool isFeatured;

  Article({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.content,
    required this.contentFr,
    required this.imageUrl,
    required this.author,
    required this.publishDate,
    required this.category,
    this.isFeatured = false,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      content: json['content'] ?? '',
      contentFr: json['content_fr'] ?? '',
      imageUrl: json['image'] ?? '',
      author: json['author'] ?? '',
      publishDate: DateTime.tryParse(json['publish_date'] ?? '') ?? DateTime.now(),
      category: json['category'] ?? '',
      isFeatured: json['is_featured'] ?? false,
    );
  }

  String getTitle(String languageCode) => languageCode == 'fr' ? titleFr : title;
  String getContent(String languageCode) => languageCode == 'fr' ? contentFr : content;
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
        publishDate: DateTime(2025, 2, 1),
        isFeatured: true,
      ),
      MagazineEdition(
        id: '2',
        title: 'Burundi: A Nation Rising',
        titleFr: 'Burundi: Une nation en essor',
        description: 'Explore Burundi\'s journey towards progress and development',
        descriptionFr: 'Explorez le parcours du Burundi vers le progrès et le développement',
        coverImageUrl: 'https://via.placeholder.com/400x600/CE1126/FFFFFF?text=Burundi',
        pdfUrl: '',
        publishDate: DateTime(2025, 1, 15),
      ),
      MagazineEdition(
        id: '3',
        title: 'African Unity in Action',
        titleFr: 'L\'unité africaine en action',
        description: 'Stories of collaboration and partnership across Africa',
        descriptionFr: 'Histoires de collaboration et de partenariat à travers l\'Afrique',
        coverImageUrl: 'https://via.placeholder.com/400x600/D4AF37/FFFFFF?text=Unity',
        pdfUrl: '',
        publishDate: DateTime(2025, 1, 1),
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
        category: 'Politics',
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
        category: 'Economy',
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
        category: 'Culture',
      ),
    ];
  }
}
