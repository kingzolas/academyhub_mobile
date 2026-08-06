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
  final String evaluationMode;
  final double minimumAverage;
  final String status;
  final String responsibleNameSnapshot;
  final String generalObservation;
  final List<ReportCardSubjectModel> subjects;
  final List<DevelopmentalSubjectAssessmentModel> developmentalAssessments;
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
    this.evaluationMode = 'numeric',
    required this.minimumAverage,
    required this.status,
    required this.responsibleNameSnapshot,
    required this.generalObservation,
    required this.subjects,
    this.developmentalAssessments = const [],
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
      evaluationMode: json['evaluationMode']?.toString() ??
          json['evaluation_mode']?.toString() ??
          json['gradingType']?.toString() ??
          'numeric',
      minimumAverage: (json['minimumAverage'] as num?)?.toDouble() ?? 7.0,
      status: json['status']?.toString() ?? '',
      responsibleNameSnapshot:
          json['responsibleNameSnapshot']?.toString() ?? '',
      generalObservation: json['generalObservation']?.toString() ?? '',
      subjects: (json['subjects'] as List<dynamic>? ?? [])
          .map((e) => ReportCardSubjectModel.fromJson(e))
          .toList(),
      developmentalAssessments: ((json['developmentalAssessments'] ??
                  json['developmental_assessments']) as List<dynamic>? ??
              [])
          .whereType<Map>()
          .map((e) => DevelopmentalSubjectAssessmentModel.fromJson(
              Map<String, dynamic>.from(e)))
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
      'evaluationMode': evaluationMode,
      'minimumAverage': minimumAverage,
      'status': status,
      'responsibleNameSnapshot': responsibleNameSnapshot,
      'generalObservation': generalObservation,
      'subjects': subjects.map((e) => e.toJson()).toList(),
      'developmentalAssessments':
          developmentalAssessments.map((e) => e.toJson()).toList(),
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
    String? evaluationMode,
    double? minimumAverage,
    String? status,
    String? responsibleNameSnapshot,
    String? generalObservation,
    List<ReportCardSubjectModel>? subjects,
    List<DevelopmentalSubjectAssessmentModel>? developmentalAssessments,
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
      evaluationMode: evaluationMode ?? this.evaluationMode,
      minimumAverage: minimumAverage ?? this.minimumAverage,
      status: status ?? this.status,
      responsibleNameSnapshot:
          responsibleNameSnapshot ?? this.responsibleNameSnapshot,
      generalObservation: generalObservation ?? this.generalObservation,
      subjects: subjects ?? this.subjects,
      developmentalAssessments:
          developmentalAssessments ?? this.developmentalAssessments,
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
  final String areaId;
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
  final ReportCardTestScoreSourceModel? testScoreSource;

  ReportCardSubjectModel({
    required this.subjectId,
    this.areaId = '',
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
    this.testScoreSource,
  });

  factory ReportCardSubjectModel.fromJson(Map<String, dynamic> json) {
    return ReportCardSubjectModel(
      subjectId: ReportCardModel._extractId(json['subjectId']),
      areaId: (json['areaId'] ?? json['area_id'])?.toString() ?? '',
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
      testScoreSource: json['testScoreSource'] is Map<String, dynamic>
          ? ReportCardTestScoreSourceModel.fromJson(json['testScoreSource'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subjectId': subjectId,
      'areaId': areaId,
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
      'testScoreSource': testScoreSource?.toJson(),
    };
  }

  ReportCardSubjectModel copyWith({
    String? subjectId,
    String? areaId,
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
    ReportCardTestScoreSourceModel? testScoreSource,
  }) {
    return ReportCardSubjectModel(
      subjectId: subjectId ?? this.subjectId,
      areaId: areaId ?? this.areaId,
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
      testScoreSource: testScoreSource ?? this.testScoreSource,
    );
  }

  bool get isFilled => score != null;
  String get developmentalKey => areaId.trim().isNotEmpty ? areaId : subjectId;
  bool get isBelowAverage =>
      status.toLowerCase().contains('abaixo') ||
      status.toLowerCase().contains('below');
  bool get isAboveAverage =>
      status.toLowerCase().contains('acima') ||
      status.toLowerCase().contains('above');
}

class DevelopmentalSubjectAssessmentModel {
  final String subjectId;
  final String areaId;
  final String subjectName;
  final String teacherId;
  final String teacherName;
  final List<DevelopmentalCriterionAssessmentModel> criteria;
  final String generalObservation;
  final String completionStatus;

  const DevelopmentalSubjectAssessmentModel({
    required this.subjectId,
    this.areaId = '',
    required this.subjectName,
    this.teacherId = '',
    required this.teacherName,
    required this.criteria,
    this.generalObservation = '',
    String? completionStatus,
  }) : completionStatus = completionStatus ?? '';

  factory DevelopmentalSubjectAssessmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return DevelopmentalSubjectAssessmentModel(
      subjectId:
          ReportCardModel._extractId(json['subjectId'] ?? json['subject_id']),
      areaId: (json['areaId'] ?? json['area_id'])?.toString() ?? '',
      subjectName: json['subjectName']?.toString() ??
          json['subject_name']?.toString() ??
          '',
      teacherId:
          ReportCardModel._extractId(json['teacherId'] ?? json['teacher_id']),
      teacherName: json['teacherName']?.toString() ??
          json['teacher_name']?.toString() ??
          '',
      criteria:
          ((json['criteria'] ?? json['criterias']) as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((e) => DevelopmentalCriterionAssessmentModel.fromJson(
                  Map<String, dynamic>.from(e)))
              .toList(),
      generalObservation: json['generalObservation']?.toString() ??
          json['general_observation']?.toString() ??
          '',
      completionStatus: json['completionStatus']?.toString() ??
          json['completion_status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subjectId': subjectId,
      'areaId': areaId,
      'subjectName': subjectName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'criteria': criteria.map((e) => e.toJson()).toList(),
      'generalObservation': generalObservation,
      'completionStatus': completionStatusLabel,
    };
  }

  DevelopmentalSubjectAssessmentModel copyWith({
    String? subjectId,
    String? areaId,
    String? subjectName,
    String? teacherId,
    String? teacherName,
    List<DevelopmentalCriterionAssessmentModel>? criteria,
    String? generalObservation,
    String? completionStatus,
  }) {
    return DevelopmentalSubjectAssessmentModel(
      subjectId: subjectId ?? this.subjectId,
      areaId: areaId ?? this.areaId,
      subjectName: subjectName ?? this.subjectName,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      criteria: criteria ?? this.criteria,
      generalObservation: generalObservation ?? this.generalObservation,
      completionStatus: completionStatus ?? this.completionStatus,
    );
  }

  DevelopmentalSubjectAssessmentModel normalizedWithSubject(
    ReportCardSubjectModel subject,
  ) {
    return copyWith(
      subjectName: subjectName.trim().isNotEmpty
          ? subjectName
          : subject.subjectNameSnapshot,
      teacherId: teacherId.trim().isNotEmpty ? teacherId : subject.teacherId,
      teacherName: teacherName.trim().isNotEmpty
          ? teacherName
          : subject.teacherNameSnapshot,
      generalObservation: generalObservation.trim().isNotEmpty
          ? generalObservation
          : subject.observation,
    );
  }

  int get totalCriteriaCount => criteria.length;
  String get developmentalKey => areaId.trim().isNotEmpty ? areaId : subjectId;

  int get filledCriteriaCount =>
      criteria.where((criterion) => criterion.status.trim().isNotEmpty).length;

  bool get isStarted => filledCriteriaCount > 0;

  bool get isComplete =>
      criteria.isNotEmpty && filledCriteriaCount == totalCriteriaCount;

  String get completionStatusLabel {
    if (!isStarted) return 'Pendente';
    if (!isComplete) return 'Em preenchimento';
    return 'Concluído';
  }
}

class DevelopmentalCriterionAssessmentModel {
  final String criterionId;
  final String description;
  final String status;
  final String observation;
  final DateTime? updatedAt;

  const DevelopmentalCriterionAssessmentModel({
    required this.criterionId,
    required this.description,
    required this.status,
    this.observation = '',
    this.updatedAt,
  });

  factory DevelopmentalCriterionAssessmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return DevelopmentalCriterionAssessmentModel(
      criterionId: json['criterionId']?.toString() ??
          json['criterion_id']?.toString() ??
          '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      observation: json['observation']?.toString() ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'criterionId': criterionId,
      'description': description,
      'status': status,
      'observation': observation,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  DevelopmentalCriterionAssessmentModel copyWith({
    String? criterionId,
    String? description,
    String? status,
    String? observation,
    DateTime? updatedAt,
  }) {
    return DevelopmentalCriterionAssessmentModel(
      criterionId: criterionId ?? this.criterionId,
      description: description ?? this.description,
      status: status ?? this.status,
      observation: observation ?? this.observation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ReportCardTestScoreSourceModel {
  final String? type;
  final String? examId;
  final String? examTitle;
  final String? sheetId;
  final String? importBatchId;
  final String? importedBy;
  final DateTime? importedAt;
  final double? originalGrade;
  final double? originalMaxGrade;
  final String? scoreMode;

  const ReportCardTestScoreSourceModel({
    this.type,
    this.examId,
    this.examTitle,
    this.sheetId,
    this.importBatchId,
    this.importedBy,
    this.importedAt,
    this.originalGrade,
    this.originalMaxGrade,
    this.scoreMode,
  });

  bool get hasSource =>
      type == 'exam_result_import' && (examTitle?.trim().isNotEmpty ?? false);

  factory ReportCardTestScoreSourceModel.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic value) {
      if (value == null || value == '') return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    String? asId(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value['_id']?.toString();
      return value.toString();
    }

    return ReportCardTestScoreSourceModel(
      type: json['type']?.toString(),
      examId: asId(json['examId']),
      examTitle: json['examTitle']?.toString(),
      sheetId: asId(json['sheetId']),
      importBatchId: asId(json['importBatchId']),
      importedBy: asId(json['importedBy']),
      importedAt: json['importedAt'] != null
          ? DateTime.tryParse(json['importedAt'].toString())
          : null,
      originalGrade: asDouble(json['originalGrade']),
      originalMaxGrade: asDouble(json['originalMaxGrade']),
      scoreMode: json['scoreMode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'examId': examId,
      'examTitle': examTitle,
      'sheetId': sheetId,
      'importBatchId': importBatchId,
      'importedBy': importedBy,
      'importedAt': importedAt?.toIso8601String(),
      'originalGrade': originalGrade,
      'originalMaxGrade': originalMaxGrade,
      'scoreMode': scoreMode,
    };
  }
}
