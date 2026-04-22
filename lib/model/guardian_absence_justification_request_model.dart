class GuardianAbsenceJustificationRequestStatuses {
  static const pending = 'PENDING';
  static const underReview = 'UNDER_REVIEW';
  static const approved = 'APPROVED';
  static const partiallyApproved = 'PARTIALLY_APPROVED';
  static const rejected = 'REJECTED';
  static const needsInformation = 'NEEDS_INFORMATION';
  static const cancelled = 'CANCELLED';

  static String label(String status) {
    switch (status.toUpperCase()) {
      case pending:
        return 'Aguardando análise';
      case underReview:
        return 'Em análise';
      case approved:
        return 'Aprovada';
      case partiallyApproved:
        return 'Aprovada parcialmente';
      case rejected:
        return 'Recusada';
      case needsInformation:
        return 'Complemento solicitado';
      case cancelled:
        return 'Cancelada';
      default:
        return 'Solicitação';
    }
  }
}

class GuardianAbsenceDocumentTypes {
  static const medicalCertificate = 'MEDICAL_CERTIFICATE';
  static const declaration = 'DECLARATION';
  static const courtOrder = 'COURT_ORDER';
  static const other = 'OTHER';

  static const values = [
    medicalCertificate,
    declaration,
    courtOrder,
    other,
  ];

  static String label(String type) {
    switch (type.toUpperCase()) {
      case medicalCertificate:
        return 'Atestado médico';
      case declaration:
        return 'Declaração';
      case courtOrder:
        return 'Determinação judicial';
      case other:
      default:
        return 'Outro documento';
    }
  }

  static bool requiresAttachment(String type) {
    final normalized = type.toUpperCase();
    return normalized == medicalCertificate || normalized == courtOrder;
  }
}

class GuardianAbsenceJustificationAttachment {
  final String id;
  final String fileName;
  final String mimeType;
  final int size;

  const GuardianAbsenceJustificationAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.size,
  });

  factory GuardianAbsenceJustificationAttachment.fromJson(
    Map<String, dynamic> json,
  ) {
    return GuardianAbsenceJustificationAttachment(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      fileName: (json['fileName'] ?? 'anexo').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      size: int.tryParse('${json['size'] ?? 0}') ?? 0,
    );
  }
}

class GuardianAbsenceJustificationRequest {
  final String id;
  final String studentId;
  final String classId;
  final String studentName;
  final String className;
  final DateTime? requestedStartDate;
  final DateTime? requestedEndDate;
  final List<DateTime> approvedDates;
  final String documentType;
  final String notes;
  final String status;
  final String decisionReason;
  final DateTime? reviewedAt;
  final DateTime? appliedAt;
  final DateTime? createdAt;
  final List<GuardianAbsenceJustificationAttachment> attachments;

  const GuardianAbsenceJustificationRequest({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.studentName,
    required this.className,
    required this.requestedStartDate,
    required this.requestedEndDate,
    required this.approvedDates,
    required this.documentType,
    required this.notes,
    required this.status,
    required this.decisionReason,
    required this.reviewedAt,
    required this.appliedAt,
    required this.createdAt,
    required this.attachments,
  });

  bool get isOpen {
    return status == GuardianAbsenceJustificationRequestStatuses.pending ||
        status == GuardianAbsenceJustificationRequestStatuses.underReview ||
        status == GuardianAbsenceJustificationRequestStatuses.needsInformation;
  }

  factory GuardianAbsenceJustificationRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawAttachments = json['attachments'] as List<dynamic>? ?? const [];
    final rawApprovedDates =
        json['approvedDates'] as List<dynamic>? ?? const [];

    return GuardianAbsenceJustificationRequest(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      studentId: _idValue(json['studentId']),
      classId: _idValue(json['classId']),
      studentName: (json['studentName'] ?? '').toString(),
      className: (json['className'] ?? '').toString(),
      requestedStartDate:
          DateTime.tryParse('${json['requestedStartDate'] ?? ''}'),
      requestedEndDate: DateTime.tryParse('${json['requestedEndDate'] ?? ''}'),
      approvedDates: rawApprovedDates
          .map((item) => DateTime.tryParse(item.toString()))
          .whereType<DateTime>()
          .toList(),
      documentType: (json['documentType'] ?? GuardianAbsenceDocumentTypes.other)
          .toString()
          .toUpperCase(),
      notes: (json['notes'] ?? '').toString(),
      status: (json['status'] ??
              GuardianAbsenceJustificationRequestStatuses.pending)
          .toString()
          .toUpperCase(),
      decisionReason: (json['decisionReason'] ?? '').toString(),
      reviewedAt: DateTime.tryParse('${json['reviewedAt'] ?? ''}'),
      appliedAt: DateTime.tryParse('${json['appliedAt'] ?? ''}'),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      attachments: rawAttachments
          .whereType<Map>()
          .map((item) => GuardianAbsenceJustificationAttachment.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }

  static String _idValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map<String, dynamic>) {
      return (value['_id'] ?? value['id'] ?? '').toString();
    }
    if (value is Map) {
      return (value['_id'] ?? value['id'] ?? '').toString();
    }
    return value.toString();
  }
}
