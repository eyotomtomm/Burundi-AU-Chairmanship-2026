class YouthDialogueApplication {
  final int id;
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

class YouthDialogueCredential {
  final String firstName;
  final String lastName;
  final String email;
  final String nationality;
  final String organization;
  final String position;
  final String participantCode;
  final String qrData;
  final String idPhotoUrl;
  final DateTime? credentialIssuedAt;

  YouthDialogueCredential({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.nationality = '',
    this.organization = '',
    this.position = '',
    this.participantCode = '',
    this.qrData = '',
    this.idPhotoUrl = '',
    this.credentialIssuedAt,
  });

  factory YouthDialogueCredential.fromJson(Map<String, dynamic> json) {
    return YouthDialogueCredential(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      nationality: json['nationality'] ?? '',
      organization: json['organization'] ?? '',
      position: json['position'] ?? '',
      participantCode: json['participant_code'] ?? '',
      qrData: json['qr_data'] ?? '',
      idPhotoUrl: json['id_photo_url'] ?? '',
      credentialIssuedAt: json['credential_issued_at'] != null
          ? DateTime.tryParse(json['credential_issued_at'])
          : null,
    );
  }
}
