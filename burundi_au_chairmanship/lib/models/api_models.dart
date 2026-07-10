class HeroSlide {
  final int id;
  final String image;
  final String thumbnailUrl;
  final String mediumUrl;
  final String label;
  final String labelFr;
  final int order;

  HeroSlide({
    required this.id,
    required this.image,
    this.thumbnailUrl = '',
    this.mediumUrl = '',
    required this.label,
    required this.labelFr,
    required this.order,
  });

  factory HeroSlide.fromJson(Map<String, dynamic> json) {
    return HeroSlide(
      id: json['id'] ?? 0,
      image: json['image'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      mediumUrl: json['medium_url'] ?? '',
      label: json['label'] ?? '',
      labelFr: json['label_fr'] ?? '',
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'image': image,
        'thumbnail_url': thumbnailUrl,
        'medium_url': mediumUrl,
        'label': label,
        'label_fr': labelFr,
        'order': order,
      };

  String getLabel(String langCode) {
    if (langCode == 'fr') return labelFr.isNotEmpty ? labelFr : label;
    return label.isNotEmpty ? label : labelFr;
  }
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
  int viewerCount;
  final String duration;
  final DateTime? scheduledTime;
  final int? eventId;
  final String? eventName;
  final DateTime? eventDate;
  final List<Map<String, dynamic>> speakers;
  final bool isLiked;
  final int likeCount;
  final List<Map<String, dynamic>> recentLikers;

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
    this.eventId,
    this.eventName,
    this.eventDate,
    this.speakers = const [],
    this.isLiked = false,
    this.likeCount = 0,
    this.recentLikers = const [],
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
      eventId: json['event'],
      eventName: json['event_name'],
      eventDate: json['event_date'] != null
          ? DateTime.tryParse(json['event_date'])
          : null,
      speakers: (json['speakers'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
      isLiked: json['is_liked'] == true,
      likeCount: json['like_count'] ?? 0,
      recentLikers: (json['recent_likers'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
    );
  }

  String getTitle(String langCode) {
    if (langCode == 'fr') return titleFr.isNotEmpty ? titleFr : title;
    return title.isNotEmpty ? title : titleFr;
  }

  String getDescription(String langCode) {
    if (langCode == 'fr') return descriptionFr.isNotEmpty ? descriptionFr : description;
    return description.isNotEmpty ? description : descriptionFr;
  }

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

  String getTitle(String langCode) {
    if (langCode == 'fr') return titleFr.isNotEmpty ? titleFr : title;
    return title.isNotEmpty ? title : titleFr;
  }

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
  final bool liveAgentOnline;
  final bool bookmarksEnabled;
  final bool discussionsEnabled;
  final bool pollsEnabled;
  final bool newsletterEnabled;
  final String appStoreUrl;
  final String playStoreUrl;
  final String appStoreId;
  final String playStoreId;
  final String aboutMissionTitle;
  final String aboutMissionTitleFr;
  final String aboutFeaturesTitle;
  final String aboutFeaturesTitleFr;
  final String developerRole;
  final String appOwnershipText;
  final String contactWebsite;
  final String contactWebsiteUrl;
  final String contactEmail;

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
    required this.liveAgentOnline,
    this.bookmarksEnabled = true,
    this.discussionsEnabled = true,
    this.pollsEnabled = true,
    this.newsletterEnabled = true,
    this.appStoreUrl = '',
    this.playStoreUrl = '',
    this.appStoreId = '6740047505',
    this.playStoreId = 'com.b4africa.app',
    this.aboutMissionTitle = 'Our Mission',
    this.aboutMissionTitleFr = 'Notre Mission',
    this.aboutFeaturesTitle = 'Key Features',
    this.aboutFeaturesTitleFr = 'Fonctionnalit\u00e9s',
    this.developerRole = 'Lead Developer',
    this.appOwnershipText = 'Property of Burundi Embassy in Addis Ababa',
    this.contactWebsite = 'burundi4africa.com',
    this.contactWebsiteUrl = 'https://burundi4africa.com',
    this.contactEmail = 'info@burundi4africa.com',
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
      appDescription: json['app_description'] ?? 'Official application for Be 4 Africa.',
      appDescriptionFr: json['app_description_fr'] ?? 'Application officielle de la Pr\u00e9sidence de l\'Union Africaine du Burundi 2026.',
      developerName: json['developer_name'] ?? 'Eyosias Tamene',
      developerUrl: json['developer_url'] ?? 'https://eyosias.dev',
      liveAgentOnline: json['live_agent_online'] ?? false,
      bookmarksEnabled: json['bookmarks_enabled'] ?? true,
      discussionsEnabled: json['discussions_enabled'] ?? true,
      pollsEnabled: json['polls_enabled'] ?? true,
      newsletterEnabled: json['newsletter_enabled'] ?? true,
      appStoreUrl: json['app_store_url'] ?? '',
      playStoreUrl: json['play_store_url'] ?? '',
      appStoreId: json['app_store_id'] ?? '6740047505',
      playStoreId: json['play_store_id'] ?? 'com.b4africa.app',
      aboutMissionTitle: json['about_mission_title'] ?? 'Our Mission',
      aboutMissionTitleFr: json['about_mission_title_fr'] ?? 'Notre Mission',
      aboutFeaturesTitle: json['about_features_title'] ?? 'Key Features',
      aboutFeaturesTitleFr: json['about_features_title_fr'] ?? 'Fonctionnalit\u00e9s',
      developerRole: json['developer_role'] ?? 'Lead Developer',
      appOwnershipText: json['app_ownership_text'] ?? 'Property of Burundi Embassy in Addis Ababa',
      contactWebsite: json['contact_website'] ?? 'burundi4africa.com',
      contactWebsiteUrl: json['contact_website_url'] ?? 'https://burundi4africa.com',
      contactEmail: json['contact_email'] ?? 'info@burundi4africa.com',
    );
  }


  String getTheme(String langCode) {
    if (langCode == 'fr') return summitThemeFr.isNotEmpty ? summitThemeFr : summitTheme;
    return summitTheme.isNotEmpty ? summitTheme : summitThemeFr;
  }

  String getDescription(String langCode) {
    if (langCode == 'fr') return appDescriptionFr.isNotEmpty ? appDescriptionFr : appDescription;
    return appDescription.isNotEmpty ? appDescription : appDescriptionFr;
  }

  String getMissionTitle(String langCode) {
    if (langCode == 'fr') return aboutMissionTitleFr.isNotEmpty ? aboutMissionTitleFr : aboutMissionTitle;
    return aboutMissionTitle.isNotEmpty ? aboutMissionTitle : aboutMissionTitleFr;
  }

  String getFeaturesTitle(String langCode) {
    if (langCode == 'fr') return aboutFeaturesTitleFr.isNotEmpty ? aboutFeaturesTitleFr : aboutFeaturesTitle;
    return aboutFeaturesTitle.isNotEmpty ? aboutFeaturesTitle : aboutFeaturesTitleFr;
  }
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
