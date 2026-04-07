enum ClassActivityType {
  homework,
  classwork,
  project,
  reading,
  practice,
  custom,
}

enum ClassActivitySourceType {
  book,
  notebook,
  worksheet,
  project,
  free,
  other,
}

enum ClassActivityStatus {
  planned,
  active,
  inReview,
  completed,
  cancelled,
}

enum ClassActivityDeliveryStatus {
  pending,
  delivered,
  partial,
  notDelivered,
  excused,
}

extension ClassActivityTypeX on ClassActivityType {
  String get apiValue {
    switch (this) {
      case ClassActivityType.homework:
        return 'HOMEWORK';
      case ClassActivityType.classwork:
        return 'CLASSWORK';
      case ClassActivityType.project:
        return 'PROJECT';
      case ClassActivityType.reading:
        return 'READING';
      case ClassActivityType.practice:
        return 'PRACTICE';
      case ClassActivityType.custom:
        return 'CUSTOM';
    }
  }

  String get label {
    switch (this) {
      case ClassActivityType.homework:
        return 'Tarefa';
      case ClassActivityType.classwork:
        return 'Sala';
      case ClassActivityType.project:
        return 'Projeto';
      case ClassActivityType.reading:
        return 'Leitura';
      case ClassActivityType.practice:
        return 'Pratica';
      case ClassActivityType.custom:
        return 'Livre';
    }
  }

  static ClassActivityType fromApi(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'CLASSWORK':
        return ClassActivityType.classwork;
      case 'PROJECT':
        return ClassActivityType.project;
      case 'READING':
        return ClassActivityType.reading;
      case 'PRACTICE':
        return ClassActivityType.practice;
      case 'CUSTOM':
        return ClassActivityType.custom;
      case 'HOMEWORK':
      default:
        return ClassActivityType.homework;
    }
  }
}

extension ClassActivitySourceTypeX on ClassActivitySourceType {
  String get apiValue {
    switch (this) {
      case ClassActivitySourceType.book:
        return 'BOOK';
      case ClassActivitySourceType.notebook:
        return 'NOTEBOOK';
      case ClassActivitySourceType.worksheet:
        return 'WORKSHEET';
      case ClassActivitySourceType.project:
        return 'PROJECT';
      case ClassActivitySourceType.free:
        return 'FREE';
      case ClassActivitySourceType.other:
        return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case ClassActivitySourceType.book:
        return 'Livro';
      case ClassActivitySourceType.notebook:
        return 'Caderno';
      case ClassActivitySourceType.worksheet:
        return 'Folha';
      case ClassActivitySourceType.project:
        return 'Projeto';
      case ClassActivitySourceType.free:
        return 'Livre';
      case ClassActivitySourceType.other:
        return 'Outro';
    }
  }

  static ClassActivitySourceType fromApi(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'BOOK':
        return ClassActivitySourceType.book;
      case 'NOTEBOOK':
        return ClassActivitySourceType.notebook;
      case 'WORKSHEET':
        return ClassActivitySourceType.worksheet;
      case 'PROJECT':
        return ClassActivitySourceType.project;
      case 'OTHER':
        return ClassActivitySourceType.other;
      case 'FREE':
      default:
        return ClassActivitySourceType.free;
    }
  }
}

extension ClassActivityStatusX on ClassActivityStatus {
  String get apiValue {
    switch (this) {
      case ClassActivityStatus.planned:
        return 'PLANNED';
      case ClassActivityStatus.active:
        return 'ACTIVE';
      case ClassActivityStatus.inReview:
        return 'IN_REVIEW';
      case ClassActivityStatus.completed:
        return 'COMPLETED';
      case ClassActivityStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get label {
    switch (this) {
      case ClassActivityStatus.planned:
        return 'Planejada';
      case ClassActivityStatus.active:
        return 'Ativa';
      case ClassActivityStatus.inReview:
        return 'Em correcao';
      case ClassActivityStatus.completed:
        return 'Concluida';
      case ClassActivityStatus.cancelled:
        return 'Cancelada';
    }
  }

  bool get isHistory {
    return this == ClassActivityStatus.completed ||
        this == ClassActivityStatus.cancelled;
  }

  static ClassActivityStatus fromApi(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'PLANNED':
        return ClassActivityStatus.planned;
      case 'IN_REVIEW':
        return ClassActivityStatus.inReview;
      case 'COMPLETED':
        return ClassActivityStatus.completed;
      case 'CANCELLED':
        return ClassActivityStatus.cancelled;
      case 'ACTIVE':
      default:
        return ClassActivityStatus.active;
    }
  }
}

extension ClassActivityDeliveryStatusX on ClassActivityDeliveryStatus {
  String get apiValue {
    switch (this) {
      case ClassActivityDeliveryStatus.pending:
        return 'PENDING';
      case ClassActivityDeliveryStatus.delivered:
        return 'DELIVERED';
      case ClassActivityDeliveryStatus.partial:
        return 'PARTIAL';
      case ClassActivityDeliveryStatus.notDelivered:
        return 'NOT_DELIVERED';
      case ClassActivityDeliveryStatus.excused:
        return 'EXCUSED';
    }
  }

  String get label {
    switch (this) {
      case ClassActivityDeliveryStatus.pending:
        return 'Pendente';
      case ClassActivityDeliveryStatus.delivered:
        return 'Entregou';
      case ClassActivityDeliveryStatus.partial:
        return 'Parcial';
      case ClassActivityDeliveryStatus.notDelivered:
        return 'Nao entregou';
      case ClassActivityDeliveryStatus.excused:
        return 'Dispensado';
    }
  }

  String get shortLabel {
    switch (this) {
      case ClassActivityDeliveryStatus.pending:
        return 'Pendente';
      case ClassActivityDeliveryStatus.delivered:
        return 'Entregou';
      case ClassActivityDeliveryStatus.partial:
        return 'Parcial';
      case ClassActivityDeliveryStatus.notDelivered:
        return 'Nao';
      case ClassActivityDeliveryStatus.excused:
        return 'Disp.';
    }
  }

  bool get allowsCorrection {
    return this == ClassActivityDeliveryStatus.delivered ||
        this == ClassActivityDeliveryStatus.partial;
  }

  static ClassActivityDeliveryStatus fromApi(String? value) {
    switch ((value ?? '').trim().toUpperCase()) {
      case 'DELIVERED':
        return ClassActivityDeliveryStatus.delivered;
      case 'PARTIAL':
        return ClassActivityDeliveryStatus.partial;
      case 'NOT_DELIVERED':
        return ClassActivityDeliveryStatus.notDelivered;
      case 'EXCUSED':
        return ClassActivityDeliveryStatus.excused;
      case 'PENDING':
      default:
        return ClassActivityDeliveryStatus.pending;
    }
  }
}

String _readString(Map<String, dynamic> json, String key, {String fallback = ''}) {
  final value = json[key];
  if (value == null) return fallback;
  return value.toString();
}

DateTime? _readDate(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

int _readInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double? _readDoubleNullable(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _readBool(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

class ClassActivitySummary {
  final int totalStudents;
  final int deliveredCount;
  final int partialCount;
  final int notDeliveredCount;
  final int excusedCount;
  final int pendingCount;
  final int correctedCount;
  final int pendingCorrectionCount;
  final int gradedCount;
  final double? averageScore;

  const ClassActivitySummary({
    required this.totalStudents,
    required this.deliveredCount,
    required this.partialCount,
    required this.notDeliveredCount,
    required this.excusedCount,
    required this.pendingCount,
    required this.correctedCount,
    required this.pendingCorrectionCount,
    required this.gradedCount,
    required this.averageScore,
  });

  factory ClassActivitySummary.fromJson(Map<String, dynamic> json) {
    return ClassActivitySummary(
      totalStudents: _readInt(json, 'totalStudents'),
      deliveredCount: _readInt(json, 'deliveredCount'),
      partialCount: _readInt(json, 'partialCount'),
      notDeliveredCount: _readInt(json, 'notDeliveredCount'),
      excusedCount: _readInt(json, 'excusedCount'),
      pendingCount: _readInt(json, 'pendingCount'),
      correctedCount: _readInt(json, 'correctedCount'),
      pendingCorrectionCount: _readInt(json, 'pendingCorrectionCount'),
      gradedCount: _readInt(json, 'gradedCount'),
      averageScore: _readDoubleNullable(json, 'averageScore'),
    );
  }

  const ClassActivitySummary.empty()
      : totalStudents = 0,
        deliveredCount = 0,
        partialCount = 0,
        notDeliveredCount = 0,
        excusedCount = 0,
        pendingCount = 0,
        correctedCount = 0,
        pendingCorrectionCount = 0,
        gradedCount = 0,
        averageScore = null;
}

class ClassActivityClassInfo {
  final String id;
  final String name;
  final String grade;
  final String shift;
  final int? schoolYear;

  const ClassActivityClassInfo({
    required this.id,
    required this.name,
    required this.grade,
    required this.shift,
    required this.schoolYear,
  });

  factory ClassActivityClassInfo.fromJson(Map<String, dynamic> json) {
    return ClassActivityClassInfo(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      grade: _readString(json, 'grade'),
      shift: _readString(json, 'shift'),
      schoolYear: json['schoolYear'] == null ? null : _readInt(json, 'schoolYear'),
    );
  }
}

class ClassActivityTeacherInfo {
  final String id;
  final String fullName;
  final String? profilePictureUrl;

  const ClassActivityTeacherInfo({
    required this.id,
    required this.fullName,
    required this.profilePictureUrl,
  });

  factory ClassActivityTeacherInfo.fromJson(Map<String, dynamic> json) {
    final picture = _readString(json, 'profilePictureUrl');
    return ClassActivityTeacherInfo(
      id: _readString(json, 'id'),
      fullName: _readString(json, 'fullName'),
      profilePictureUrl: picture.isEmpty ? null : picture,
    );
  }
}

class ClassActivitySubjectInfo {
  final String id;
  final String name;
  final String level;

  const ClassActivitySubjectInfo({
    required this.id,
    required this.name,
    required this.level,
  });

  factory ClassActivitySubjectInfo.fromJson(Map<String, dynamic> json) {
    return ClassActivitySubjectInfo(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      level: _readString(json, 'level'),
    );
  }
}

class ClassActivity {
  final String id;
  final String title;
  final String description;
  final ClassActivityType activityType;
  final ClassActivitySourceType sourceType;
  final String sourceReference;
  final bool isGraded;
  final double? maxScore;
  final DateTime? assignedAt;
  final DateTime? dueDate;
  final DateTime? correctionDate;
  final ClassActivityStatus status;
  final ClassActivityStatus workflowState;
  final bool visibilityToGuardians;
  final ClassActivitySummary summary;
  final ClassActivityClassInfo classInfo;
  final ClassActivityTeacherInfo teacher;
  final ClassActivitySubjectInfo? subject;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClassActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.activityType,
    required this.sourceType,
    required this.sourceReference,
    required this.isGraded,
    required this.maxScore,
    required this.assignedAt,
    required this.dueDate,
    required this.correctionDate,
    required this.status,
    required this.workflowState,
    required this.visibilityToGuardians,
    required this.summary,
    required this.classInfo,
    required this.teacher,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClassActivity.fromJson(Map<String, dynamic> json) {
    return ClassActivity(
      id: _readString(json, 'id'),
      title: _readString(json, 'title'),
      description: _readString(json, 'description'),
      activityType: ClassActivityTypeX.fromApi(json['activityType']?.toString()),
      sourceType: ClassActivitySourceTypeX.fromApi(json['sourceType']?.toString()),
      sourceReference: _readString(json, 'sourceReference'),
      isGraded: _readBool(json, 'isGraded'),
      maxScore: _readDoubleNullable(json, 'maxScore'),
      assignedAt: _readDate(json, 'assignedAt'),
      dueDate: _readDate(json, 'dueDate'),
      correctionDate: _readDate(json, 'correctionDate'),
      status: ClassActivityStatusX.fromApi(json['status']?.toString()),
      workflowState:
          ClassActivityStatusX.fromApi(json['workflowState']?.toString()),
      visibilityToGuardians: _readBool(json, 'visibilityToGuardians'),
      summary: json['summary'] is Map<String, dynamic>
          ? ClassActivitySummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const ClassActivitySummary.empty(),
      classInfo: json['class'] is Map<String, dynamic>
          ? ClassActivityClassInfo.fromJson(json['class'] as Map<String, dynamic>)
          : const ClassActivityClassInfo(
              id: '',
              name: '',
              grade: '',
              shift: '',
              schoolYear: null,
            ),
      teacher: json['teacher'] is Map<String, dynamic>
          ? ClassActivityTeacherInfo.fromJson(
              json['teacher'] as Map<String, dynamic>,
            )
          : const ClassActivityTeacherInfo(
              id: '',
              fullName: '',
              profilePictureUrl: null,
            ),
      subject: json['subject'] is Map<String, dynamic>
          ? ClassActivitySubjectInfo.fromJson(json['subject'] as Map<String, dynamic>)
          : null,
      createdAt: _readDate(json, 'createdAt'),
      updatedAt: _readDate(json, 'updatedAt'),
    );
  }

  bool get isCancelled => status == ClassActivityStatus.cancelled;
  bool get isCompleted => workflowState == ClassActivityStatus.completed;

  ClassActivity copyWith({
    String? id,
    String? title,
    String? description,
    ClassActivityType? activityType,
    ClassActivitySourceType? sourceType,
    String? sourceReference,
    bool? isGraded,
    double? maxScore,
    DateTime? assignedAt,
    DateTime? dueDate,
    DateTime? correctionDate,
    ClassActivityStatus? status,
    ClassActivityStatus? workflowState,
    bool? visibilityToGuardians,
    ClassActivitySummary? summary,
    ClassActivityClassInfo? classInfo,
    ClassActivityTeacherInfo? teacher,
    ClassActivitySubjectInfo? subject,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassActivity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      activityType: activityType ?? this.activityType,
      sourceType: sourceType ?? this.sourceType,
      sourceReference: sourceReference ?? this.sourceReference,
      isGraded: isGraded ?? this.isGraded,
      maxScore: maxScore ?? this.maxScore,
      assignedAt: assignedAt ?? this.assignedAt,
      dueDate: dueDate ?? this.dueDate,
      correctionDate: correctionDate ?? this.correctionDate,
      status: status ?? this.status,
      workflowState: workflowState ?? this.workflowState,
      visibilityToGuardians:
          visibilityToGuardians ?? this.visibilityToGuardians,
      summary: summary ?? this.summary,
      classInfo: classInfo ?? this.classInfo,
      teacher: teacher ?? this.teacher,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ClassActivityStudentInfo {
  final String id;
  final String fullName;
  final String enrollmentNumber;
  final String? profilePictureUrl;

  const ClassActivityStudentInfo({
    required this.id,
    required this.fullName,
    required this.enrollmentNumber,
    required this.profilePictureUrl,
  });

  factory ClassActivityStudentInfo.fromJson(Map<String, dynamic> json) {
    final picture = _readString(json, 'profilePictureUrl');
    return ClassActivityStudentInfo(
      id: _readString(json, 'id'),
      fullName: _readString(json, 'fullName'),
      enrollmentNumber: _readString(json, 'enrollmentNumber'),
      profilePictureUrl: picture.isEmpty ? null : picture,
    );
  }
}

class ClassActivityEnrollmentInfo {
  final String id;
  final int? academicYear;
  final DateTime? enrollmentDate;
  final String status;

  const ClassActivityEnrollmentInfo({
    required this.id,
    required this.academicYear,
    required this.enrollmentDate,
    required this.status,
  });

  factory ClassActivityEnrollmentInfo.fromJson(Map<String, dynamic> json) {
    return ClassActivityEnrollmentInfo(
      id: _readString(json, 'id'),
      academicYear: json['academicYear'] == null
          ? null
          : _readInt(json, 'academicYear'),
      enrollmentDate: _readDate(json, 'enrollmentDate'),
      status: _readString(json, 'status'),
    );
  }
}

class ClassActivitySubmission {
  final String id;
  final ClassActivityStudentInfo student;
  final ClassActivityEnrollmentInfo? enrollment;
  final ClassActivityDeliveryStatus deliveryStatus;
  final DateTime? submittedAt;
  final bool isCorrected;
  final DateTime? correctedAt;
  final double? score;
  final String teacherNote;
  final bool isCurrentClassMember;

  const ClassActivitySubmission({
    required this.id,
    required this.student,
    required this.enrollment,
    required this.deliveryStatus,
    required this.submittedAt,
    required this.isCorrected,
    required this.correctedAt,
    required this.score,
    required this.teacherNote,
    required this.isCurrentClassMember,
  });

  factory ClassActivitySubmission.fromJson(Map<String, dynamic> json) {
    return ClassActivitySubmission(
      id: _readString(json, 'id'),
      student: json['student'] is Map<String, dynamic>
          ? ClassActivityStudentInfo.fromJson(json['student'] as Map<String, dynamic>)
          : const ClassActivityStudentInfo(
              id: '',
              fullName: '',
              enrollmentNumber: '',
              profilePictureUrl: null,
            ),
      enrollment: json['enrollment'] is Map<String, dynamic>
          ? ClassActivityEnrollmentInfo.fromJson(
              json['enrollment'] as Map<String, dynamic>,
            )
          : null,
      deliveryStatus:
          ClassActivityDeliveryStatusX.fromApi(json['deliveryStatus']?.toString()),
      submittedAt: _readDate(json, 'submittedAt'),
      isCorrected: _readBool(json, 'isCorrected'),
      correctedAt: _readDate(json, 'correctedAt'),
      score: _readDoubleNullable(json, 'score'),
      teacherNote: _readString(json, 'teacherNote'),
      isCurrentClassMember: _readBool(json, 'isCurrentClassMember', fallback: true),
    );
  }

  static const Object _sentinel = Object();

  ClassActivitySubmission copyWith({
    String? id,
    ClassActivityStudentInfo? student,
    ClassActivityEnrollmentInfo? enrollment,
    ClassActivityDeliveryStatus? deliveryStatus,
    Object? submittedAt = _sentinel,
    bool? isCorrected,
    Object? correctedAt = _sentinel,
    Object? score = _sentinel,
    String? teacherNote,
    bool? isCurrentClassMember,
  }) {
    return ClassActivitySubmission(
      id: id ?? this.id,
      student: student ?? this.student,
      enrollment: enrollment ?? this.enrollment,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      submittedAt: identical(submittedAt, _sentinel)
          ? this.submittedAt
          : submittedAt as DateTime?,
      isCorrected: isCorrected ?? this.isCorrected,
      correctedAt: identical(correctedAt, _sentinel)
          ? this.correctedAt
          : correctedAt as DateTime?,
      score: identical(score, _sentinel) ? this.score : score as double?,
      teacherNote: teacherNote ?? this.teacherNote,
      isCurrentClassMember: isCurrentClassMember ?? this.isCurrentClassMember,
    );
  }

  bool isEquivalentTo(ClassActivitySubmission other) {
    return deliveryStatus == other.deliveryStatus &&
        _sameMoment(submittedAt, other.submittedAt) &&
        isCorrected == other.isCorrected &&
        _sameMoment(correctedAt, other.correctedAt) &&
        score == other.score &&
        teacherNote.trim() == other.teacherNote.trim();
  }

  static bool _sameMoment(DateTime? left, DateTime? right) {
    if (left == null && right == null) return true;
    if (left == null || right == null) return false;
    return left.toIso8601String() == right.toIso8601String();
  }
}

class ClassActivitySubmissionsResponse {
  final ClassActivity activity;
  final int totalStudents;
  final List<ClassActivitySubmission> students;

  const ClassActivitySubmissionsResponse({
    required this.activity,
    required this.totalStudents,
    required this.students,
  });

  factory ClassActivitySubmissionsResponse.fromJson(Map<String, dynamic> json) {
    final items = json['students'] as List<dynamic>? ?? const [];
    return ClassActivitySubmissionsResponse(
      activity: ClassActivity.fromJson(json['activity'] as Map<String, dynamic>),
      totalStudents: _readInt(json, 'totalStudents'),
      students: items
          .whereType<Map<String, dynamic>>()
          .map(ClassActivitySubmission.fromJson)
          .toList(),
    );
  }
}

class ClassActivityUpsertInput {
  final String title;
  final String description;
  final ClassActivityType activityType;
  final ClassActivitySourceType sourceType;
  final String sourceReference;
  final bool isGraded;
  final double? maxScore;
  final DateTime assignedAt;
  final DateTime dueDate;
  final DateTime? correctionDate;
  final String? subjectId;
  final bool visibilityToGuardians;
  final ClassActivityStatus? status;

  const ClassActivityUpsertInput({
    required this.title,
    required this.description,
    required this.activityType,
    required this.sourceType,
    required this.sourceReference,
    required this.isGraded,
    required this.maxScore,
    required this.assignedAt,
    required this.dueDate,
    required this.correctionDate,
    required this.subjectId,
    required this.visibilityToGuardians,
    required this.status,
  });

  factory ClassActivityUpsertInput.fromActivity(ClassActivity activity) {
    return ClassActivityUpsertInput(
      title: activity.title,
      description: activity.description,
      activityType: activity.activityType,
      sourceType: activity.sourceType,
      sourceReference: activity.sourceReference,
      isGraded: activity.isGraded,
      maxScore: activity.maxScore,
      assignedAt: activity.assignedAt ?? DateTime.now(),
      dueDate: activity.dueDate ?? DateTime.now(),
      correctionDate: activity.correctionDate,
      subjectId: activity.subject?.id,
      visibilityToGuardians: activity.visibilityToGuardians,
      status: activity.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'activityType': activityType.apiValue,
      'sourceType': sourceType.apiValue,
      'sourceReference': sourceReference.trim(),
      'isGraded': isGraded,
      'maxScore': isGraded ? maxScore : null,
      'assignedAt': assignedAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'correctionDate': correctionDate?.toIso8601String(),
      'subjectId': (subjectId ?? '').trim().isEmpty ? null : subjectId,
      'visibilityToGuardians': visibilityToGuardians,
      if (status != null) 'status': status!.apiValue,
    };
  }
}

class ClassActivitySubmissionUpdateInput {
  final String studentId;
  final String? enrollmentId;
  final ClassActivityDeliveryStatus deliveryStatus;
  final DateTime? submittedAt;
  final bool isCorrected;
  final DateTime? correctedAt;
  final double? score;
  final String teacherNote;

  const ClassActivitySubmissionUpdateInput({
    required this.studentId,
    required this.enrollmentId,
    required this.deliveryStatus,
    required this.submittedAt,
    required this.isCorrected,
    required this.correctedAt,
    required this.score,
    required this.teacherNote,
  });

  factory ClassActivitySubmissionUpdateInput.fromSubmission(
    ClassActivitySubmission submission,
  ) {
    return ClassActivitySubmissionUpdateInput(
      studentId: submission.student.id,
      enrollmentId: submission.enrollment?.id,
      deliveryStatus: submission.deliveryStatus,
      submittedAt: submission.submittedAt,
      isCorrected: submission.isCorrected,
      correctedAt: submission.correctedAt,
      score: submission.score,
      teacherNote: submission.teacherNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      if ((enrollmentId ?? '').trim().isNotEmpty) 'enrollmentId': enrollmentId,
      'deliveryStatus': deliveryStatus.apiValue,
      'submittedAt': submittedAt?.toIso8601String(),
      'isCorrected': isCorrected,
      'correctedAt': correctedAt?.toIso8601String(),
      'score': score,
      'teacherNote': teacherNote.trim(),
    };
  }
}
