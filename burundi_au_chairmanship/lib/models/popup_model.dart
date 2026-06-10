class PopupModel {
  final int id;
  final String title;
  final String titleFr;
  final String message;
  final String messageFr;
  final String? image;
  final String actionText;
  final String actionTextFr;
  final String actionUrl;
  final String popupType;
  final int priority;
  final bool showOnce;
  final DateTime createdAt;

  PopupModel({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.message,
    required this.messageFr,
    this.image,
    required this.actionText,
    required this.actionTextFr,
    required this.actionUrl,
    required this.popupType,
    required this.priority,
    required this.showOnce,
    required this.createdAt,
  });

  factory PopupModel.fromJson(Map<String, dynamic> json) {
    return PopupModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      message: json['message'] ?? '',
      messageFr: json['message_fr'] ?? '',
      image: json['image'],
      actionText: json['action_text'] ?? '',
      actionTextFr: json['action_text_fr'] ?? '',
      actionUrl: json['action_url'] ?? '',
      popupType: json['popup_type'] ?? 'general',
      priority: json['priority'] ?? 0,
      showOnce: json['show_once'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String getTitle(String langCode) {
    if (langCode == 'fr') return titleFr.isNotEmpty ? titleFr : title;
    return title.isNotEmpty ? title : titleFr;
  }

  String getMessage(String langCode) {
    if (langCode == 'fr') return messageFr.isNotEmpty ? messageFr : message;
    return message.isNotEmpty ? message : messageFr;
  }

  String getActionText(String langCode) {
    if (langCode == 'fr') return actionTextFr.isNotEmpty ? actionTextFr : actionText;
    return actionText.isNotEmpty ? actionText : actionTextFr;
  }
}
