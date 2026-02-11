class HeroSlide {
  final int id;
  final String image;
  final String label;
  final String labelFr;
  final int order;

  HeroSlide({
    required this.id,
    required this.image,
    required this.label,
    required this.labelFr,
    required this.order,
  });

  factory HeroSlide.fromJson(Map<String, dynamic> json) {
    return HeroSlide(
      id: json['id'] ?? 0,
      image: json['image'] ?? '',
      label: json['label'] ?? '',
      labelFr: json['label_fr'] ?? '',
      order: json['order'] ?? 0,
    );
  }

  String getLabel(String langCode) => langCode == 'fr' ? labelFr : label;
}

class ApiLiveFeed {
  final int id;
  final String title;
  final String titleFr;
  final String streamUrl;
  final String thumbnail;
  final String status;
  final int viewerCount;
  final String duration;
  final DateTime? scheduledTime;

  ApiLiveFeed({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.streamUrl,
    required this.thumbnail,
    required this.status,
    required this.viewerCount,
    required this.duration,
    this.scheduledTime,
  });

  factory ApiLiveFeed.fromJson(Map<String, dynamic> json) {
    return ApiLiveFeed(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      streamUrl: json['stream_url'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      status: json['status'] ?? 'upcoming',
      viewerCount: json['viewer_count'] ?? 0,
      duration: json['duration'] ?? '',
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.tryParse(json['scheduled_time'])
          : null,
    );
  }

  String getTitle(String langCode) => langCode == 'fr' ? titleFr : title;

  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';
  bool get isRecorded => status == 'recorded';

  Duration? get parsedDuration {
    if (duration.isEmpty) return null;
    final parts = duration.toLowerCase().split(' ');
    int hours = 0, minutes = 0;
    for (final part in parts) {
      if (part.endsWith('h')) {
        hours = int.tryParse(part.replaceAll('h', '')) ?? 0;
      } else if (part.endsWith('m')) {
        minutes = int.tryParse(part.replaceAll('m', '')) ?? 0;
      }
    }
    return Duration(hours: hours, minutes: minutes);
  }
}

class ApiResource {
  final int id;
  final String title;
  final String titleFr;
  final String category;
  final String file;
  final String fileSize;
  final String fileType;

  ApiResource({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.category,
    required this.file,
    required this.fileSize,
    required this.fileType,
  });

  factory ApiResource.fromJson(Map<String, dynamic> json) {
    return ApiResource(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      category: json['category'] ?? '',
      file: json['file'] ?? '',
      fileSize: json['file_size'] ?? '',
      fileType: json['file_type'] ?? 'pdf',
    );
  }

  String getTitle(String langCode) => langCode == 'fr' ? titleFr : title;

  String get categoryDisplayName {
    switch (category) {
      case 'official_documents': return 'Official Documents';
      case 'country_info': return 'Country Information';
      case 'media': return 'Media Resources';
      case 'reference': return 'Reference Guides';
      default: return category;
    }
  }

  String get categoryDisplayNameFr {
    switch (category) {
      case 'official_documents': return 'Documents officiels';
      case 'country_info': return 'Informations sur le pays';
      case 'media': return 'Ressources médiatiques';
      case 'reference': return 'Guides de référence';
      default: return category;
    }
  }

  String getCategoryName(String langCode) =>
      langCode == 'fr' ? categoryDisplayNameFr : categoryDisplayName;
}

class ApiEmergencyContact {
  final int id;
  final String name;
  final String nameFr;
  final String phoneNumber;
  final String type;
  final int order;

  ApiEmergencyContact({
    required this.id,
    required this.name,
    required this.nameFr,
    required this.phoneNumber,
    required this.type,
    required this.order,
  });

  factory ApiEmergencyContact.fromJson(Map<String, dynamic> json) {
    return ApiEmergencyContact(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameFr: json['name_fr'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      type: json['type'] ?? '',
      order: json['order'] ?? 0,
    );
  }

  String getName(String langCode) => langCode == 'fr' ? nameFr : name;
}

class AppSettingsModel {
  final String summitYear;
  final String summitTheme;
  final String summitThemeFr;
  final String websiteUrl;
  final String facebookUrl;
  final String twitterUrl;
  final String instagramUrl;

  AppSettingsModel({
    required this.summitYear,
    required this.summitTheme,
    required this.summitThemeFr,
    required this.websiteUrl,
    required this.facebookUrl,
    required this.twitterUrl,
    required this.instagramUrl,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      summitYear: json['summit_year'] ?? '2026',
      summitTheme: json['summit_theme'] ?? '',
      summitThemeFr: json['summit_theme_fr'] ?? '',
      websiteUrl: json['website_url'] ?? '',
      facebookUrl: json['facebook_url'] ?? '',
      twitterUrl: json['twitter_url'] ?? '',
      instagramUrl: json['instagram_url'] ?? '',
    );
  }

  String getTheme(String langCode) => langCode == 'fr' ? summitThemeFr : summitTheme;
}
