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
  });

  factory YouthDialogueCredential.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
