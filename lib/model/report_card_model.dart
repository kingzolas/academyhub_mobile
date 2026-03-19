import 'dart:convert';

ReportCardModel reportCardModelFromJson(String str) =>
    ReportCardModel.fromJson(json.decode(str));

String reportCardModelToJson(ReportCardModel data) =>
    json.encode(data.toJson());

class ReportCardModel {
  final String id;
  final String schoolId;
  final int schoolYear;
  final String termId;
  final String classId;
  final String studentId;
  final String studentNameSnapshot; // NOVO: Nome que vem populado da API
  final String enrollmentId;
  final String gradingType;
  final double minimumAverage;
  final String status;
  final String responsibleNameSnapshot;
  final String generalObservation;
  final List<ReportCardSubjectModel> subjects;
  final bool releasedForPrint;
  final DateTime? releasedAt;
  final String? releasedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReportCardModel({
    required this.id,
    required this.schoolId,
    required this.schoolYear,
    required this.termId,
    required this.classId,
    required this.studentId,
    this.studentNameSnapshot = '',
    required this.enrollmentId,
    required this.gradingType,
    required this.minimumAverage,
    required this.status,
    required this.responsibleNameSnapshot,
    required this.generalObservation,
    required this.subjects,
    required this.releasedForPrint,
    this.releasedAt,
    this.releasedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ReportCardModel.fromJson(Map<String, dynamic> json) {
    return ReportCardModel(
      id: json['_id']?.toString() ?? '',
      schoolId: _extractId(json['school_id']),
      schoolYear: (json['schoolYear'] as num?)?.toInt() ?? 0,
      termId: _extractId(json['termId']),
      classId: _extractId(json['classId']),
      studentId: _extractId(json['studentId']),
      studentNameSnapshot:
          _extractPopulatedName(json['studentId']) ?? '', // Lê o nome populado
      enrollmentId: _extractId(json['enrollmentId']),
      gradingType: json['gradingType']?.toString() ?? 'numeric',
      minimumAverage: (json['minimumAverage'] as num?)?.toDouble() ?? 7.0,
      status: json['status']?.toString() ?? '',
      responsibleNameSnapshot:
          json['responsibleNameSnapshot']?.toString() ?? '',
      generalObservation: json['generalObservation']?.toString() ?? '',
      subjects: (json['subjects'] as List<dynamic>? ?? [])
          .map((e) => ReportCardSubjectModel.fromJson(e))
          .toList(),
      releasedForPrint: json['releasedForPrint'] == true,
      releasedAt: json['releasedAt'] != null
          ? DateTime.tryParse(json['releasedAt'].toString())
          : null,
      releasedBy:
          json['releasedBy'] != null ? _extractId(json['releasedBy']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'school_id': schoolId,
      'schoolYear': schoolYear,
      'termId': termId,
      'classId': classId,
      'studentId': studentId,
      'enrollmentId': enrollmentId,
      'gradingType': gradingType,
      'minimumAverage': minimumAverage,
      'status': status,
      'responsibleNameSnapshot': responsibleNameSnapshot,
      'generalObservation': generalObservation,
      'subjects': subjects.map((e) => e.toJson()).toList(),
      'releasedForPrint': releasedForPrint,
      'releasedAt': releasedAt?.toIso8601String(),
      'releasedBy': releasedBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  ReportCardModel copyWith({
    String? id,
    String? schoolId,
    int? schoolYear,
    String? termId,
    String? classId,
    String? studentId,
    String? studentNameSnapshot,
    String? enrollmentId,
    String? gradingType,
    double? minimumAverage,
    String? status,
    String? responsibleNameSnapshot,
    String? generalObservation,
    List<ReportCardSubjectModel>? subjects,
    bool? releasedForPrint,
    DateTime? releasedAt,
    String? releasedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportCardModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      schoolYear: schoolYear ?? this.schoolYear,
      termId: termId ?? this.termId,
      classId: classId ?? this.classId,
      studentId: studentId ?? this.studentId,
      studentNameSnapshot: studentNameSnapshot ?? this.studentNameSnapshot,
      enrollmentId: enrollmentId ?? this.enrollmentId,
      gradingType: gradingType ?? this.gradingType,
      minimumAverage: minimumAverage ?? this.minimumAverage,
      status: status ?? this.status,
      responsibleNameSnapshot:
          responsibleNameSnapshot ?? this.responsibleNameSnapshot,
      generalObservation: generalObservation ?? this.generalObservation,
      subjects: subjects ?? this.subjects,
      releasedForPrint: releasedForPrint ?? this.releasedForPrint,
      releasedAt: releasedAt ?? this.releasedAt,
      releasedBy: releasedBy ?? this.releasedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _extractId(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map<String, dynamic>) {
      return value['_id']?.toString() ?? '';
    }
    return '';
  }

  // Tenta extrair o nome do aluno caso a API tenha populado o objeto
  static String? _extractPopulatedName(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value['name']?.toString() ??
          value['fullName']?.toString() ??
          value['full_name']?.toString();
    }
    return null;
  }

  int get totalSubjectsCount => subjects.length;

  int get filledSubjectsCount =>
      subjects.where((subject) => subject.isFilled).length;

  int get pendingSubjectsCount => totalSubjectsCount - filledSubjectsCount;

  double? get averageScore {
    final filledScores =
        subjects.where((subject) => subject.score != null).map((subject) {
      return subject.score!;
    }).toList();

    if (filledScores.isEmpty) return null;

    final total = filledScores.fold<double>(0, (sum, value) => sum + value);
    return total / filledScores.length;
  }

  bool get hasPendingSubjects => pendingSubjectsCount > 0;
}

class ReportCardSubjectModel {
  final String subjectId;
  final String subjectNameSnapshot;
  final String teacherId;
  final String teacherNameSnapshot;
  final double? testScore;
  final double? activityScore;
  final double? participationScore;
  final double? score;
  final String status;
  final String observation;
  final String? filledBy;
  final DateTime? filledAt;

  ReportCardSubjectModel({
    required this.subjectId,
    required this.subjectNameSnapshot,
    required this.teacherId,
    required this.teacherNameSnapshot,
    this.testScore,
    this.activityScore,
    this.participationScore,
    required this.score,
    required this.status,
    required this.observation,
    this.filledBy,
    this.filledAt,
  });

  factory ReportCardSubjectModel.fromJson(Map<String, dynamic> json) {
    return ReportCardSubjectModel(
      subjectId: ReportCardModel._extractId(json['subjectId']),
      subjectNameSnapshot: json['subjectNameSnapshot']?.toString() ?? '',
      teacherId: ReportCardModel._extractId(json['teacherId']),
      teacherNameSnapshot: json['teacherNameSnapshot']?.toString() ?? '',
      testScore: (json['testScore'] as num?)?.toDouble(),
      activityScore: (json['activityScore'] as num?)?.toDouble(),
      participationScore: (json['participationScore'] as num?)?.toDouble(),
      score: (json['score'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'Pendente',
      observation: json['observation']?.toString() ?? '',
      filledBy: json['filledBy'] != null
          ? ReportCardModel._extractId(json['filledBy'])
          : null,
      filledAt: json['filledAt'] != null
          ? DateTime.tryParse(json['filledAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subjectId': subjectId,
      'subjectNameSnapshot': subjectNameSnapshot,
      'teacherId': teacherId,
      'teacherNameSnapshot': teacherNameSnapshot,
      'testScore': testScore,
      'activityScore': activityScore,
      'participationScore': participationScore,
      'score': score,
      'status': status,
      'observation': observation,
      'filledBy': filledBy,
      'filledAt': filledAt?.toIso8601String(),
    };
  }

  ReportCardSubjectModel copyWith({
    String? subjectId,
    String? subjectNameSnapshot,
    String? teacherId,
    String? teacherNameSnapshot,
    double? testScore,
    double? activityScore,
    double? participationScore,
    double? score,
    String? status,
    String? observation,
    String? filledBy,
    DateTime? filledAt,
  }) {
    return ReportCardSubjectModel(
      subjectId: subjectId ?? this.subjectId,
      subjectNameSnapshot: subjectNameSnapshot ?? this.subjectNameSnapshot,
      teacherId: teacherId ?? this.teacherId,
      teacherNameSnapshot: teacherNameSnapshot ?? this.teacherNameSnapshot,
      testScore: testScore ?? this.testScore,
      activityScore: activityScore ?? this.activityScore,
      participationScore: participationScore ?? this.participationScore,
      score: score ?? this.score,
      status: status ?? this.status,
      observation: observation ?? this.observation,
      filledBy: filledBy ?? this.filledBy,
      filledAt: filledAt ?? this.filledAt,
    );
  }

  bool get isFilled => score != null;
  bool get isBelowAverage =>
      status.toLowerCase().contains('abaixo') ||
      status.toLowerCase().contains('below');
  bool get isAboveAverage =>
      status.toLowerCase().contains('acima') ||
      status.toLowerCase().contains('above');
}
