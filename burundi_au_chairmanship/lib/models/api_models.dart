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
  final String description;
  final String descriptionFr;
  final String streamUrl;
  final String streamType;
  final String meetingId;
  final String passcode;
  final String thumbnail;
  final String status;
  final int viewerCount;
  final String duration;
  final DateTime? scheduledTime;

  ApiLiveFeed({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.description,
    required this.descriptionFr,
    required this.streamUrl,
    required this.streamType,
    required this.meetingId,
    required this.passcode,
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
      description: json['description'] ?? '',
      descriptionFr: json['description_fr'] ?? '',
      streamUrl: json['stream_url'] ?? '',
      streamType: json['stream_type'] ?? 'video',
      meetingId: json['meeting_id'] ?? '',
      passcode: json['passcode'] ?? '',
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
  String getDescription(String langCode) => langCode == 'fr' ? descriptionFr : description;

  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';
  bool get isRecorded => status == 'recorded';

  bool get isExternalPlatform => streamType != 'video';
  bool get isZoom => streamType == 'zoom';
  bool get isYouTube => streamType == 'youtube';
  bool get isTeams => streamType == 'teams';
  bool get isWebex => streamType == 'webex';
  bool get isGoogleMeet => streamType == 'meet';

  String get platformName {
    switch (streamType) {
      case 'zoom': return 'Zoom';
      case 'youtube': return 'YouTube';
      case 'teams': return 'Teams';
      case 'webex': return 'Webex';
      case 'meet': return 'Google Meet';
      default: return '';
    }
  }

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

class AppSettingsModel {
  final String summitYear;
  final String summitTheme;
  final String summitThemeFr;
  final String websiteUrl;
  final String facebookUrl;
  final String twitterUrl;
  final String instagramUrl;
  final String appDescription;
  final String appDescriptionFr;
  final String developerName;
  final String developerUrl;
  final bool smsVerificationEnabled;
  final bool whatsappVerificationEnabled;
  final bool liveAgentOnline;

  AppSettingsModel({
    required this.summitYear,
    required this.summitTheme,
    required this.summitThemeFr,
    required this.websiteUrl,
    required this.facebookUrl,
    required this.twitterUrl,
    required this.instagramUrl,
    required this.appDescription,
    required this.appDescriptionFr,
    required this.developerName,
    required this.developerUrl,
    required this.smsVerificationEnabled,
    required this.whatsappVerificationEnabled,
    required this.liveAgentOnline,
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
      appDescription: json['app_description'] ?? 'Official application for the Burundi African Union Chairmanship 2026.',
      appDescriptionFr: json['app_description_fr'] ?? 'Application officielle de la Présidence de l\'Union Africaine du Burundi 2026.',
      developerName: json['developer_name'] ?? 'Eyosias Tamene',
      developerUrl: json['developer_url'] ?? 'https://eyosias.dev',
      smsVerificationEnabled: json['sms_verification_enabled'] ?? false,
      whatsappVerificationEnabled: json['whatsapp_verification_enabled'] ?? false,
      liveAgentOnline: json['live_agent_online'] ?? false,
    );
  }

  bool get phoneVerificationEnabled => smsVerificationEnabled || whatsappVerificationEnabled;

  String getTheme(String langCode) => langCode == 'fr' ? summitThemeFr : summitTheme;
  String getDescription(String langCode) => langCode == 'fr' ? appDescriptionFr : appDescription;
}

class WeatherCity {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? backgroundImage;
  final int order;
  final bool isDefault;

  WeatherCity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.backgroundImage,
    required this.order,
    required this.isDefault,
  });

  factory WeatherCity.fromJson(Map<String, dynamic> json) {
    return WeatherCity(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      backgroundImage: json['background_image'],
      order: json['order'] ?? 0,
      isDefault: json['is_default'] ?? false,
    );
  }
}
