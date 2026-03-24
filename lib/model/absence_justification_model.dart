import 'dart:convert';
import 'dart:typed_data';

enum AbsenceJustificationStatus {
  pending,
  approved,
  rejected,
  expired,
  unknown,
}

enum AbsenceDocumentType {
  medicalCertificate,
  declaration,
  courtOrder,
  other,
}

class AbsenceJustificationModel {
  final String id;
  final String schoolId;
  final String classId;
  final String className;
  final String studentId;
  final String studentName;
  final String? studentPhotoUrl;
  final AbsenceDocumentType documentType;
  final String notes;
  final AbsenceJustificationStatus status;
  final DateTime coverageStartDate;
  final DateTime coverageEndDate;
  final List<DateTime> absenceDates;
  final List<AttendanceReferenceModel> attendanceRefs;
  final JustificationDocumentMetaModel? document;
  final JustificationRulesSnapshotModel? rulesSnapshot;
  final JustificationSubmissionModel? submission;
  final JustificationReviewModel? review;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AbsenceJustificationModel({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.studentId,
    required this.studentName,
    required this.studentPhotoUrl,
    required this.documentType,
    required this.notes,
    required this.status,
    required this.coverageStartDate,
    required this.coverageEndDate,
    required this.absenceDates,
    required this.attendanceRefs,
    required this.document,
    required this.rulesSnapshot,
    required this.submission,
    required this.review,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == AbsenceJustificationStatus.pending;
  bool get isApproved => status == AbsenceJustificationStatus.approved;
  bool get isRejected => status == AbsenceJustificationStatus.rejected;
  bool get isExpired => status == AbsenceJustificationStatus.expired;

  bool get isActive =>
      status == AbsenceJustificationStatus.pending ||
      status == AbsenceJustificationStatus.approved;

  String get statusApiValue {
    switch (status) {
      case AbsenceJustificationStatus.pending:
        return 'PENDING';
      case AbsenceJustificationStatus.approved:
        return 'APPROVED';
      case AbsenceJustificationStatus.rejected:
        return 'REJECTED';
      case AbsenceJustificationStatus.expired:
        return 'EXPIRED';
      case AbsenceJustificationStatus.unknown:
        return 'UNKNOWN';
    }
  }

  String get statusLabel {
    switch (status) {
      case AbsenceJustificationStatus.pending:
        return 'Pendente';
      case AbsenceJustificationStatus.approved:
        return 'Abonada';
      case AbsenceJustificationStatus.rejected:
        return 'Recusada';
      case AbsenceJustificationStatus.expired:
        return 'Prazo expirado';
      case AbsenceJustificationStatus.unknown:
        return 'Desconhecido';
    }
  }

  String get documentTypeApiValue {
    switch (documentType) {
      case AbsenceDocumentType.medicalCertificate:
        return 'MEDICAL_CERTIFICATE';
      case AbsenceDocumentType.declaration:
        return 'DECLARATION';
      case AbsenceDocumentType.courtOrder:
        return 'COURT_ORDER';
      case AbsenceDocumentType.other:
        return 'OTHER';
    }
  }

  String get documentTypeLabel {
    switch (documentType) {
      case AbsenceDocumentType.medicalCertificate:
        return 'Atestado médico';
      case AbsenceDocumentType.declaration:
        return 'Declaração';
      case AbsenceDocumentType.courtOrder:
        return 'Ordem judicial';
      case AbsenceDocumentType.other:
        return 'Outro';
    }
  }

  bool coversDate(DateTime date) {
    final target = _dateOnly(date);
    final start = _dateOnly(coverageStartDate);
    final end = _dateOnly(coverageEndDate);

    if (absenceDates.isNotEmpty) {
      return absenceDates.any((d) => _isSameDate(d, target));
    }

    return !target.isBefore(start) && !target.isAfter(end);
  }

  AbsenceJustificationModel copyWith({
    String? id,
    String? schoolId,
    String? classId,
    String? className,
    String? studentId,
    String? studentName,
    String? studentPhotoUrl,
    AbsenceDocumentType? documentType,
    String? notes,
    AbsenceJustificationStatus? status,
    DateTime? coverageStartDate,
    DateTime? coverageEndDate,
    List<DateTime>? absenceDates,
    List<AttendanceReferenceModel>? attendanceRefs,
    JustificationDocumentMetaModel? document,
    JustificationRulesSnapshotModel? rulesSnapshot,
    JustificationSubmissionModel? submission,
    JustificationReviewModel? review,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AbsenceJustificationModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhotoUrl: studentPhotoUrl ?? this.studentPhotoUrl,
      documentType: documentType ?? this.documentType,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      coverageStartDate: coverageStartDate ?? this.coverageStartDate,
      coverageEndDate: coverageEndDate ?? this.coverageEndDate,
      absenceDates: absenceDates ?? this.absenceDates,
      attendanceRefs: attendanceRefs ?? this.attendanceRefs,
      document: document ?? this.document,
      rulesSnapshot: rulesSnapshot ?? this.rulesSnapshot,
      submission: submission ?? this.submission,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AbsenceJustificationModel.fromJson(Map<String, dynamic> json) {
    return AbsenceJustificationModel(
      id: _extractId(json['_id']),
      schoolId: _extractId(json['schoolId']),
      classId: _extractId(json['classId']),
      className: _extractClassName(json['classId']),
      studentId: _extractId(json['studentId']),
      studentName: _extractStudentName(json['studentId']),
      studentPhotoUrl: _extractStudentPhoto(json['studentId']),
      documentType: _parseDocumentType(json['documentType']),
      notes: (json['notes'] ?? '').toString(),
      status: _parseStatus(json['status']),
      coverageStartDate:
          DateTime.tryParse((json['coverageStartDate'] ?? '').toString()) ??
              DateTime.now(),
      coverageEndDate:
          DateTime.tryParse((json['coverageEndDate'] ?? '').toString()) ??
              DateTime.now(),
      absenceDates: ((json['absenceDates'] as List?) ?? [])
          .map((e) => DateTime.tryParse(e.toString()))
          .whereType<DateTime>()
          .toList(),
      attendanceRefs: ((json['attendanceRefs'] as List?) ?? [])
          .whereType<Map>()
          .map(
            (e) => AttendanceReferenceModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      document: json['document'] is Map<String, dynamic>
          ? JustificationDocumentMetaModel.fromJson(json['document'])
          : null,
      rulesSnapshot: json['rulesSnapshot'] is Map<String, dynamic>
          ? JustificationRulesSnapshotModel.fromJson(json['rulesSnapshot'])
          : null,
      submission: json['submission'] is Map<String, dynamic>
          ? JustificationSubmissionModel.fromJson(json['submission'])
          : null,
      review: json['review'] is Map<String, dynamic>
          ? JustificationReviewModel.fromJson(json['review'])
          : null,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'schoolId': schoolId,
      'classId': classId,
      'studentId': studentId,
      'documentType': documentTypeApiValue,
      'notes': notes,
      'status': statusApiValue,
      'coverageStartDate': coverageStartDate.toIso8601String(),
      'coverageEndDate': coverageEndDate.toIso8601String(),
      'absenceDates': absenceDates.map((e) => e.toIso8601String()).toList(),
      'attendanceRefs': attendanceRefs.map((e) => e.toJson()).toList(),
      'document': document?.toJson(),
      'rulesSnapshot': rulesSnapshot?.toJson(),
      'submission': submission?.toJson(),
      'review': review?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static AbsenceJustificationStatus _parseStatus(dynamic value) {
    final normalized = (value ?? '').toString().toUpperCase();
    switch (normalized) {
      case 'PENDING':
        return AbsenceJustificationStatus.pending;
      case 'APPROVED':
        return AbsenceJustificationStatus.approved;
      case 'REJECTED':
        return AbsenceJustificationStatus.rejected;
      case 'EXPIRED':
        return AbsenceJustificationStatus.expired;
      default:
        return AbsenceJustificationStatus.unknown;
    }
  }

  static AbsenceDocumentType _parseDocumentType(dynamic value) {
    final normalized = (value ?? '').toString().toUpperCase();
    switch (normalized) {
      case 'MEDICAL_CERTIFICATE':
        return AbsenceDocumentType.medicalCertificate;
      case 'DECLARATION':
        return AbsenceDocumentType.declaration;
      case 'COURT_ORDER':
        return AbsenceDocumentType.courtOrder;
      case 'OTHER':
      default:
        return AbsenceDocumentType.other;
    }
  }

  static String _extractId(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map<String, dynamic>) {
      return (value['_id'] ?? '').toString();
    }
    return value.toString();
  }

  static String _extractClassName(dynamic value) {
    if (value is Map<String, dynamic>) {
      return (value['name'] ?? '').toString();
    }
    return '';
  }

  static String _extractStudentName(dynamic value) {
    if (value is Map<String, dynamic>) {
      return (value['fullName'] ?? '').toString();
    }
    return '';
  }

  static String? _extractStudentPhoto(dynamic value) {
    if (value is Map<String, dynamic>) {
      final photo = value['photoUrl'];
      if (photo == null || photo.toString().trim().isEmpty) return null;
      return photo.toString();
    }
    return null;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class AttendanceReferenceModel {
  final String attendanceId;
  final DateTime date;

  const AttendanceReferenceModel({
    required this.attendanceId,
    required this.date,
  });

  factory AttendanceReferenceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceReferenceModel(
      attendanceId: (json['attendanceId'] ?? '').toString(),
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendanceId': attendanceId,
      'date': date.toIso8601String(),
    };
  }
}

class JustificationDocumentMetaModel {
  final String? fileName;
  final String? mimeType;
  final int size;

  const JustificationDocumentMetaModel({
    required this.fileName,
    required this.mimeType,
    required this.size,
  });

  factory JustificationDocumentMetaModel.fromJson(Map<String, dynamic> json) {
    return JustificationDocumentMetaModel(
      fileName: json['fileName']?.toString(),
      mimeType: json['mimeType']?.toString(),
      size: (json['size'] is num) ? (json['size'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'mimeType': mimeType,
      'size': size,
    };
  }
}

class JustificationRulesSnapshotModel {
  final int deadlineDays;
  final String deadlineType;
  final bool submittedWithinDeadline;
  final bool lateOverrideUsed;

  const JustificationRulesSnapshotModel({
    required this.deadlineDays,
    required this.deadlineType,
    required this.submittedWithinDeadline,
    required this.lateOverrideUsed,
  });

  factory JustificationRulesSnapshotModel.fromJson(Map<String, dynamic> json) {
    return JustificationRulesSnapshotModel(
      deadlineDays: (json['deadlineDays'] is num)
          ? (json['deadlineDays'] as num).toInt()
          : 0,
      deadlineType: (json['deadlineType'] ?? '').toString(),
      submittedWithinDeadline: json['submittedWithinDeadline'] == true,
      lateOverrideUsed: json['lateOverrideUsed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deadlineDays': deadlineDays,
      'deadlineType': deadlineType,
      'submittedWithinDeadline': submittedWithinDeadline,
      'lateOverrideUsed': lateOverrideUsed,
    };
  }
}

class JustificationSubmissionModel {
  final String submittedById;
  final String submittedByName;
  final DateTime? submittedAt;

  const JustificationSubmissionModel({
    required this.submittedById,
    required this.submittedByName,
    required this.submittedAt,
  });

  factory JustificationSubmissionModel.fromJson(Map<String, dynamic> json) {
    final submittedBy = json['submittedById'];
    return JustificationSubmissionModel(
      submittedById: _extractNestedId(submittedBy),
      submittedByName: _extractNestedName(submittedBy),
      submittedAt: DateTime.tryParse((json['submittedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'submittedById': submittedById,
      'submittedAt': submittedAt?.toIso8601String(),
    };
  }
}

class JustificationReviewModel {
  final String reviewedById;
  final String reviewedByName;
  final DateTime? reviewedAt;
  final String decisionNote;

  const JustificationReviewModel({
    required this.reviewedById,
    required this.reviewedByName,
    required this.reviewedAt,
    required this.decisionNote,
  });

  factory JustificationReviewModel.fromJson(Map<String, dynamic> json) {
    final reviewedBy = json['reviewedById'];
    return JustificationReviewModel(
      reviewedById: _extractNestedId(reviewedBy),
      reviewedByName: _extractNestedName(reviewedBy),
      reviewedAt: DateTime.tryParse((json['reviewedAt'] ?? '').toString()),
      decisionNote: (json['decisionNote'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewedById': reviewedById,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'decisionNote': decisionNote,
    };
  }
}

class AbsenceJustificationCreatePayload {
  final String classId;
  final String studentId;
  final AbsenceDocumentType documentType;
  final String notes;
  final List<DateTime> absenceDates;
  final DateTime? coverageStartDate;
  final DateTime? coverageEndDate;
  final bool approveNow;
  final bool forceLateOverride;
  final String reviewNote;

  const AbsenceJustificationCreatePayload({
    required this.classId,
    required this.studentId,
    required this.documentType,
    required this.notes,
    this.absenceDates = const [],
    this.coverageStartDate,
    this.coverageEndDate,
    this.approveNow = false,
    this.forceLateOverride = false,
    this.reviewNote = '',
  });

  bool get hasSpecificDates => absenceDates.isNotEmpty;

  bool get hasDateRange => coverageStartDate != null && coverageEndDate != null;

  bool get isValid =>
      classId.trim().isNotEmpty &&
      studentId.trim().isNotEmpty &&
      (hasSpecificDates || hasDateRange);

  DateTime? get resolvedCoverageStartDate {
    if (coverageStartDate != null) return coverageStartDate;
    if (absenceDates.isEmpty) return null;
    final sorted = [...absenceDates]..sort((a, b) => a.compareTo(b));
    return sorted.first;
  }

  DateTime? get resolvedCoverageEndDate {
    if (coverageEndDate != null) return coverageEndDate;
    if (absenceDates.isEmpty) return null;
    final sorted = [...absenceDates]..sort((a, b) => a.compareTo(b));
    return sorted.last;
  }

  String get documentTypeApiValue {
    switch (documentType) {
      case AbsenceDocumentType.medicalCertificate:
        return 'MEDICAL_CERTIFICATE';
      case AbsenceDocumentType.declaration:
        return 'DECLARATION';
      case AbsenceDocumentType.courtOrder:
        return 'COURT_ORDER';
      case AbsenceDocumentType.other:
        return 'OTHER';
    }
  }

  Map<String, String> toFormFields() {
    final fields = <String, String>{
      'classId': classId,
      'studentId': studentId,
      'documentType': documentTypeApiValue,
      'notes': notes,
      'approveNow': approveNow.toString(),
      'forceLateOverride': forceLateOverride.toString(),
      'reviewNote': reviewNote,
    };

    final start = resolvedCoverageStartDate;
    final end = resolvedCoverageEndDate;

    if (start != null) {
      fields['coverageStartDate'] = _apiDate(start);
    }

    if (end != null) {
      fields['coverageEndDate'] = _apiDate(end);
    }

    return fields;
  }
}

class AbsenceJustificationReviewPayload {
  final AbsenceJustificationStatus status;
  final String reviewNote;

  const AbsenceJustificationReviewPayload({
    required this.status,
    this.reviewNote = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'status': _statusToApi(status),
      'reviewNote': reviewNote,
    };
  }

  static String _statusToApi(AbsenceJustificationStatus status) {
    switch (status) {
      case AbsenceJustificationStatus.approved:
        return 'APPROVED';
      case AbsenceJustificationStatus.rejected:
        return 'REJECTED';
      case AbsenceJustificationStatus.pending:
        return 'PENDING';
      case AbsenceJustificationStatus.expired:
        return 'EXPIRED';
      case AbsenceJustificationStatus.unknown:
        return 'UNKNOWN';
    }
  }
}

class DownloadedJustificationDocument {
  final Uint8List bytes;
  final String fileName;
  final String? mimeType;

  const DownloadedJustificationDocument({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  String get base64 => base64Encode(bytes);
}

String _extractNestedId(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map<String, dynamic>) {
    return (value['_id'] ?? '').toString();
  }
  return value.toString();
}

String _extractNestedName(dynamic value) {
  if (value is Map<String, dynamic>) {
    return (value['fullName'] ?? '').toString();
  }
  return '';
}

String _apiDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final y = normalized.year.toString().padLeft(4, '0');
  final m = normalized.month.toString().padLeft(2, '0');
  final d = normalized.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
