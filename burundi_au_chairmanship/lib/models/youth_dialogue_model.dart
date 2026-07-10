class YouthDialogueApplication {
  final int id;
  final String? referenceId;
  final String status;
  final String title;
  final String firstName;
  final String lastName;
  final String email;
  final String nationality;
  final String organization;
  final String position;
  final String? rejectionReason;
  final String? documentsRejectionNotes;
  final String? participantCode;
  final bool hasCredential;
  final List<YouthDialogueDocument> documents;
  final DateTime? createdAt;
  final bool isRevoked;
  final String? revokedReason;
  final DateTime? revokedAt;
  final bool allowReapply;

  YouthDialogueApplication({
    required this.id,
    this.referenceId,
    required this.status,
    this.title = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.nationality = '',
    this.organization = '',
    this.position = '',
    this.rejectionReason,
    this.documentsRejectionNotes,
    this.participantCode,
    this.hasCredential = false,
    this.documents = const [],
    this.createdAt,
    this.isRevoked = false,
    this.revokedReason,
    this.revokedAt,
    this.allowReapply = true,
  });

  factory YouthDialogueApplication.fromJson(Map<String, dynamic> json) {
    return YouthDialogueApplication(
      id: json['id'] ?? 0,
      referenceId: json['reference_id'],
      status: json['status'] ?? '',
      title: json['title'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      nationality: json['nationality'] ?? '',
      organization: json['organization'] ?? '',
      position: json['position'] ?? '',
      rejectionReason: json['rejection_reason'],
      documentsRejectionNotes: json['documents_rejection_notes'],
      participantCode: json['participant_code'],
      hasCredential: json['has_credential'] ?? false,
      documents: (json['documents'] as List<dynamic>?)
              ?.map((d) => YouthDialogueDocument.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      isRevoked: json['is_revoked'] ?? false,
      revokedReason: json['revoked_reason'],
      revokedAt: json['revoked_at'] != null ? DateTime.tryParse(json['revoked_at']) : null,
      allowReapply: json['allow_reapply'] ?? true,
    );
  }
}

class YouthDialogueDocument {
  final int id;
  final String documentType;
  final String? file;
  final String originalFilename;
  final int fileSize;
  final String status;
  final String? rejectionReason;
  final bool isResubmission;
  final DateTime? uploadedAt;

  YouthDialogueDocument({
    required this.id,
    required this.documentType,
    this.file,
    this.originalFilename = '',
    this.fileSize = 0,
    this.status = 'pending',
    this.rejectionReason,
    this.isResubmission = false,
    this.uploadedAt,
  });

  factory YouthDialogueDocument.fromJson(Map<String, dynamic> json) {
    return YouthDialogueDocument(
      id: json['id'] ?? 0,
      documentType: json['document_type'] ?? '',
      file: json['file'],
      originalFilename: json['original_filename'] ?? '',
      fileSize: json['file_size'] ?? 0,
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      isResubmission: json['is_resubmission'] ?? false,
      uploadedAt: json['uploaded_at'] != null ? DateTime.tryParse(json['uploaded_at']) : null,
    );
  }
}

class YouthDialogueSideEvent {
  final int id;
  final String name;
  final String nameFr;
  final String description;
  final String descriptionFr;
  final String? eventDate;
  final String? eventTime;
  final int order;

  YouthDialogueSideEvent({
    required this.id,
    this.name = '',
    this.nameFr = '',
    this.description = '',
    this.descriptionFr = '',
    this.eventDate,
    this.eventTime,
    this.order = 0,
  });

  factory YouthDialogueSideEvent.fromJson(Map<String, dynamic> json) {
    return YouthDialogueSideEvent(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameFr: json['name_fr'] ?? '',
      description: json['description'] ?? '',
      descriptionFr: json['description_fr'] ?? '',
      eventDate: json['event_date'],
      eventTime: json['event_time'],
      order: json['order'] ?? 0,
    );
  }

  String getName(String langCode) {
    if (langCode == 'fr' && nameFr.isNotEmpty) return nameFr;
    return name;
  }

  String getDescription(String langCode) {
    if (langCode == 'fr' && descriptionFr.isNotEmpty) return descriptionFr;
    return description;
  }
}


class YouthDialogueRole {
  final int id;
  final String name;
  final String nameFr;
  final String color;
  final int order;

  YouthDialogueRole({
    required this.id,
    this.name = '',
    this.nameFr = '',
    this.color = '#4CAF50',
    this.order = 0,
  });

  factory YouthDialogueRole.fromJson(Map<String, dynamic> json) {
    return YouthDialogueRole(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameFr: json['name_fr'] ?? '',
      color: json['color'] ?? '#4CAF50',
      order: json['order'] ?? 0,
    );
  }
}

class YouthDialogueMedia {
  final int id;
  final String mediaType;
  final String title;
  final String titleFr;
  final String caption;
  final String captionFr;
  final String editionTag;
  final String fileUrl;
  final String externalUrl;
  final String thumbnailUrl;
  final bool isPromotional;
  final int displayOrder;

  YouthDialogueMedia({
    required this.id,
    this.mediaType = 'photo',
    this.title = '',
    this.titleFr = '',
    this.caption = '',
    this.captionFr = '',
    this.editionTag = '',
    this.fileUrl = '',
    this.externalUrl = '',
    this.thumbnailUrl = '',
    this.isPromotional = false,
    this.displayOrder = 0,
  });

  factory YouthDialogueMedia.fromJson(Map<String, dynamic> json) {
    return YouthDialogueMedia(
      id: json['id'] ?? 0,
      mediaType: json['media_type'] ?? 'photo',
      title: json['title'] ?? '',
      titleFr: json['title_fr'] ?? '',
      caption: json['caption'] ?? '',
      captionFr: json['caption_fr'] ?? '',
      editionTag: json['edition_tag'] ?? '',
      fileUrl: json['file_url'] ?? '',
      externalUrl: json['external_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      isPromotional: json['is_promotional'] ?? false,
      displayOrder: json['display_order'] ?? 0,
    );
  }
}

class YouthDialogueCredential {
  final String firstName;
  final String lastName;
  final String email;
  final String nationality;
  final String nationalityDisplay;
  final String nationalityFlag;
  final String organization;
  final String position;
  final String role;
  final String roleColor;
  final String participantCode;
  final String qrData;
  final String idPhotoUrl;
  final DateTime? credentialIssuedAt;
  final DateTime? eventStartDate;
  final DateTime? eventEndDate;
  final bool isRevoked;
  final bool allowPdfDownload;

  /// Extra fields from admin (list of {label, value} maps)
  final List<Map<String, String>> extraFields;

  /// Extra logo URLs from admin
  final List<String> extraLogos;

  /// Visible fields on the ID card (empty = all visible)
  final List<String> idCardVisibleFields;

  /// Selected side event name (null if none)
  final String sideEvent;

  YouthDialogueCredential({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.nationality = '',
    this.nationalityDisplay = '',
    this.nationalityFlag = '',
    this.organization = '',
    this.position = '',
    this.role = 'Participant',
    this.roleColor = '#4CAF50',
    this.participantCode = '',
    this.qrData = '',
    this.idPhotoUrl = '',
    this.credentialIssuedAt,
    this.eventStartDate,
    this.eventEndDate,
    this.isRevoked = false,
    this.allowPdfDownload = false,
    this.extraFields = const [],
    this.extraLogos = const [],
    this.idCardVisibleFields = const [],
    this.sideEvent = '',
  });

  factory YouthDialogueCredential.fromJson(Map<String, dynamic> json) {
    // Parse extra_fields: [{label, value}, ...]
    final rawExtra = json['extra_fields'] as List<dynamic>?;
    final extraFields = rawExtra
        ?.map((e) {
          final m = e as Map<String, dynamic>;
          return {
            'label': (m['label'] ?? '').toString(),
            'value': (m['value'] ?? '').toString(),
          };
        })
        .where((m) => m['label']!.isNotEmpty && m['value']!.isNotEmpty)
        .toList() ?? [];

    // Parse extra_logos: [url, ...]
    final rawLogos = json['extra_logos'] as List<dynamic>?;
    final extraLogos = rawLogos
        ?.map((e) => e.toString())
        .where((u) => u.isNotEmpty)
        .toList() ?? [];

    return YouthDialogueCredential(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      nationality: json['nationality'] ?? '',
      nationalityDisplay: json['nationality_display'] ?? '',
      nationalityFlag: json['nationality_flag'] ?? '',
      organization: json['organization'] ?? '',
      position: json['position'] ?? '',
      role: json['role'] ?? 'Participant',
      roleColor: json['role_color'] ?? '#4CAF50',
      participantCode: json['participant_code'] ?? '',
      qrData: json['qr_data'] ?? '',
      idPhotoUrl: json['id_photo_url'] ?? '',
      credentialIssuedAt: json['credential_issued_at'] != null
          ? DateTime.tryParse(json['credential_issued_at'])
          : null,
      eventStartDate: json['event_start_date'] != null
          ? DateTime.tryParse(json['event_start_date'])
          : null,
      eventEndDate: json['event_end_date'] != null
          ? DateTime.tryParse(json['event_end_date'])
          : null,
      isRevoked: json['is_revoked'] ?? false,
      allowPdfDownload: json['allow_pdf_download'] ?? false,
      extraFields: extraFields,
      extraLogos: extraLogos,
      idCardVisibleFields: (json['id_card_visible_fields'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      sideEvent: json['side_event'] is Map
          ? (json['side_event']['name'] ?? '').toString()
          : (json['side_event'] ?? '').toString(),
    );
  }

  /// Returns true if the given field should be visible on the ID card.
  /// Empty list means all fields are visible (backward compatible).
  bool isIdCardFieldVisible(String key) {
    return idCardVisibleFields.isEmpty || idCardVisibleFields.contains(key);
  }
}
