class EventRegistrationModel {
  final int id;
  final String cardType;
  final String eventType;
  final String? categoryName;
  final String? categoryNameFr;
  final String? categoryColor;
  final String eventTitle;
  final String eventTitleFr;
  final String eventDescription;
  final String eventDescriptionFr;
  final String? eventPoster;
  final DateTime? eventDate;
  final DateTime? eventEndDate;
  final String venue;
  final String venueFr;
  final String venueAddress;
  final String contactEmail;
  final String contactPhone;
  final bool isRegistrationEnabled;
  final DateTime? registrationDeadline;
  final int maxRegistrations;
  final bool allowProxyRegistration;
  final String confirmationMessage;
  final String confirmationMessageFr;
  final bool showPhotos;
  final bool showAttendees;
  final bool showComments;
  final bool isActive;
  final int order;
  final List<RegistrationFormField> formFields;
  final bool hasRegistered;
  final String? userSubmissionStatus;
  final bool isRegistrationOpen;
  final int currentRegistrationCount;
  final int? spotsRemaining;
  final int? userSubmissionId;

  EventRegistrationModel({
    required this.id,
    required this.cardType,
    this.eventType = 'in_person',
    this.categoryName,
    this.categoryNameFr,
    this.categoryColor,
    required this.eventTitle,
    this.eventTitleFr = '',
    this.eventDescription = '',
    this.eventDescriptionFr = '',
    this.eventPoster,
    this.eventDate,
    this.eventEndDate,
    this.venue = '',
    this.venueFr = '',
    this.venueAddress = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.isRegistrationEnabled = true,
    this.registrationDeadline,
    this.maxRegistrations = 0,
    this.allowProxyRegistration = false,
    this.confirmationMessage = '',
    this.confirmationMessageFr = '',
    this.showPhotos = true,
    this.showAttendees = true,
    this.showComments = true,
    this.isActive = true,
    this.order = 0,
    this.formFields = const [],
    this.hasRegistered = false,
    this.userSubmissionStatus,
    this.userSubmissionId,
    this.isRegistrationOpen = true,
    this.currentRegistrationCount = 0,
    this.spotsRemaining,
  });

  factory EventRegistrationModel.fromJson(Map<String, dynamic> json) {
    return EventRegistrationModel(
      id: json['id'] as int,
      cardType: json['card_type'] as String? ?? 'event',
      eventType: json['event_type'] as String? ?? 'in_person',
      categoryName: (json['category_data'] as Map<String, dynamic>?)?['name'] as String?,
      categoryNameFr: (json['category_data'] as Map<String, dynamic>?)?['name_fr'] as String?,
      categoryColor: (json['category_data'] as Map<String, dynamic>?)?['color'] as String?,
      eventTitle: json['event_title'] as String? ?? '',
      eventTitleFr: json['event_title_fr'] as String? ?? '',
      eventDescription: json['event_description'] as String? ?? '',
      eventDescriptionFr: json['event_description_fr'] as String? ?? '',
      eventPoster: json['event_poster'] as String?,
      eventDate: json['event_date'] != null ? DateTime.tryParse(json['event_date']) : null,
      eventEndDate: json['event_end_date'] != null ? DateTime.tryParse(json['event_end_date']) : null,
      venue: json['venue'] as String? ?? '',
      venueFr: json['venue_fr'] as String? ?? '',
      venueAddress: json['venue_address'] as String? ?? '',
      contactEmail: json['contact_email'] as String? ?? '',
      contactPhone: json['contact_phone'] as String? ?? '',
      isRegistrationEnabled: json['is_registration_enabled'] as bool? ?? true,
      registrationDeadline: json['registration_deadline'] != null ? DateTime.tryParse(json['registration_deadline']) : null,
      maxRegistrations: json['max_registrations'] as int? ?? 0,
      allowProxyRegistration: json['allow_proxy_registration'] as bool? ?? false,
      confirmationMessage: json['confirmation_message'] as String? ?? '',
      confirmationMessageFr: json['confirmation_message_fr'] as String? ?? '',
      showPhotos: json['show_photos'] as bool? ?? true,
      showAttendees: json['show_attendees'] as bool? ?? true,
      showComments: json['show_comments'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
      formFields: (json['form_fields'] as List<dynamic>?)
              ?.map((f) => RegistrationFormField.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      hasRegistered: json['has_registered'] as bool? ?? false,
      userSubmissionStatus: json['user_submission_status'] as String?,
      userSubmissionId: json['user_submission_id'] as int?,
      isRegistrationOpen: json['is_registration_open'] as bool? ?? true,
      currentRegistrationCount: json['current_registration_count'] as int? ?? 0,
      spotsRemaining: json['spots_remaining'] as int?,
    );
  }

  String getTitle(String langCode) =>
      langCode == 'fr' && eventTitleFr.isNotEmpty ? eventTitleFr : eventTitle;

  String getDescription(String langCode) =>
      langCode == 'fr' && eventDescriptionFr.isNotEmpty ? eventDescriptionFr : eventDescription;

  String? getCategoryName(String langCode) =>
      langCode == 'fr' && (categoryNameFr ?? '').isNotEmpty ? categoryNameFr : categoryName;

  String getVenue(String langCode) =>
      langCode == 'fr' && venueFr.isNotEmpty ? venueFr : venue;

  String getConfirmationMessage(String langCode) =>
      langCode == 'fr' && confirmationMessageFr.isNotEmpty ? confirmationMessageFr : confirmationMessage;

  Duration? get timeUntilEvent {
    if (eventDate == null) return null;
    final diff = eventDate!.difference(DateTime.now());
    return diff.isNegative ? null : diff;
  }

  bool get isEventPast {
    if (eventDate == null) return false;
    return DateTime.now().isAfter(eventDate!);
  }

  /// Returns the total number of days for multi-day events, or 1 for single-day.
  int get totalDays {
    if (eventDate == null || eventEndDate == null) return 1;
    final days = eventEndDate!.difference(eventDate!).inDays;
    return days > 0 ? days + 1 : 1;
  }

  /// Returns the current day number (1-based) if the event is ongoing, or null.
  int? get currentDayNumber {
    if (eventDate == null || eventEndDate == null) return null;
    if (totalDays <= 1) return null;
    final now = DateTime.now();
    if (now.isBefore(eventDate!)) return null;
    if (now.isAfter(eventEndDate!)) return null;
    return now.difference(eventDate!).inDays + 1;
  }

  /// True if this is a multi-day event.
  bool get isMultiDay => totalDays > 1;
}

class RegistrationFormField {
  final int id;
  final String fieldType;
  final String fieldLabel;
  final String fieldLabelFr;
  final String fieldName;
  final String placeholder;
  final String placeholderFr;
  final bool isRequired;
  final bool isActive;
  final List<dynamic> options;
  final String validationRegex;
  final String helpText;
  final String helpTextFr;
  final int order;

  RegistrationFormField({
    required this.id,
    required this.fieldType,
    required this.fieldLabel,
    this.fieldLabelFr = '',
    required this.fieldName,
    this.placeholder = '',
    this.placeholderFr = '',
    this.isRequired = false,
    this.isActive = true,
    this.options = const [],
    this.validationRegex = '',
    this.helpText = '',
    this.helpTextFr = '',
    this.order = 0,
  });

  factory RegistrationFormField.fromJson(Map<String, dynamic> json) {
    return RegistrationFormField(
      id: json['id'] as int,
      fieldType: json['field_type'] as String? ?? 'text',
      fieldLabel: json['field_label'] as String? ?? '',
      fieldLabelFr: json['field_label_fr'] as String? ?? '',
      fieldName: json['field_name'] as String? ?? '',
      placeholder: json['placeholder'] as String? ?? '',
      placeholderFr: json['placeholder_fr'] as String? ?? '',
      isRequired: json['is_required'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      options: json['options'] as List<dynamic>? ?? [],
      validationRegex: json['validation_regex'] as String? ?? '',
      helpText: json['help_text'] as String? ?? '',
      helpTextFr: json['help_text_fr'] as String? ?? '',
      order: json['order'] as int? ?? 0,
    );
  }

  String getLabel(String langCode) =>
      langCode == 'fr' && fieldLabelFr.isNotEmpty ? fieldLabelFr : fieldLabel;

  String getPlaceholder(String langCode) =>
      langCode == 'fr' && placeholderFr.isNotEmpty ? placeholderFr : placeholder;

  String getHelpText(String langCode) =>
      langCode == 'fr' && helpTextFr.isNotEmpty ? helpTextFr : helpText;
}
