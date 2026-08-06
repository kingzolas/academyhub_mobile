double? _asDouble(dynamic value) {
  if (value == null || value == '') return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _asInt(dynamic value) {
  if (value == null || value == '') return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _asString(dynamic value) => value?.toString() ?? '';

class ImportableExamModel {
  final String examId;
  final String title;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String teacherName;
  final String? termId;
  final String? termName;
  final DateTime? applicationDate;
  final String status;
  final String correctionType;
  final double? totalValue;
  final int totalSheets;
  final int correctedSheets;
  final int pendingSheets;
  final int alreadyImportedCount;
  final int conflictCount;
  final int importableCount;
  final bool hasConflicts;
  final int blockedCount;
  final int noopCount;
  final int pendingCount;
  final bool importBlocked;
  final String? importSummaryError;
  final String scoreMode;

  const ImportableExamModel({
    required this.examId,
    required this.title,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.teacherName,
    this.termId,
    this.termName,
    this.applicationDate,
    required this.status,
    required this.correctionType,
    this.totalValue,
    required this.totalSheets,
    required this.correctedSheets,
    required this.pendingSheets,
    required this.alreadyImportedCount,
    required this.conflictCount,
    required this.importableCount,
    required this.hasConflicts,
    required this.blockedCount,
    required this.noopCount,
    required this.pendingCount,
    required this.importBlocked,
    this.importSummaryError,
    required this.scoreMode,
  });

  factory ImportableExamModel.fromJson(Map<String, dynamic> json) {
    return ImportableExamModel(
      examId: _asString(json['examId'] ?? json['_id']),
      title: _asString(json['title']),
      classId: _asString(json['classId']),
      className: _asString(json['className']),
      subjectId: _asString(json['subjectId']),
      subjectName: _asString(json['subjectName']),
      teacherName: _asString(json['teacherName']),
      termId:
          _asString(json['termId']).isEmpty ? null : _asString(json['termId']),
      termName: _asString(json['termName']).isEmpty
          ? null
          : _asString(json['termName']),
      applicationDate: _asDate(json['applicationDate']),
      status: _asString(json['status']),
      correctionType: _asString(json['correctionType']),
      totalValue: _asDouble(json['totalValue']),
      totalSheets: _asInt(json['totalSheets']),
      correctedSheets: _asInt(json['correctedSheets']),
      pendingSheets: _asInt(json['pendingSheets']),
      alreadyImportedCount: _asInt(json['alreadyImportedCount']),
      conflictCount: _asInt(json['conflictCount']),
      importableCount: _asInt(json['importableCount']),
      hasConflicts: json['hasConflicts'] == true,
      blockedCount: _asInt(json['blockedCount']),
      noopCount: _asInt(json['noopCount']),
      pendingCount: _asInt(json['pendingCount']),
      importBlocked: json['importBlocked'] == true,
      importSummaryError: json['importSummaryError']?.toString(),
      scoreMode: _asString(json['scoreMode']).isEmpty
          ? 'raw'
          : _asString(json['scoreMode']),
    );
  }
}

class ExamResultsMobileData {
  final ExamResultsMobileExam exam;
  final ExamResultsMobileSummary summary;
  final List<ExamStudentResultMobile> students;

  const ExamResultsMobileData({
    required this.exam,
    required this.summary,
    required this.students,
  });

  factory ExamResultsMobileData.fromJson(Map<String, dynamic> json) {
    return ExamResultsMobileData(
      exam: ExamResultsMobileExam.fromJson(
        Map<String, dynamic>.from(json['exam'] as Map? ?? const {}),
      ),
      summary: ExamResultsMobileSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      ),
      students: (json['students'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => ExamStudentResultMobile.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class ExamResultsMobileExam {
  final String id;
  final String title;
  final String subjectId;
  final String subjectName;
  final String classId;
  final String className;
  final String? termId;
  final String? termName;
  final DateTime? applicationDate;
  final double? totalValue;
  final String status;
  final String correctionType;

  const ExamResultsMobileExam({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.subjectName,
    required this.classId,
    required this.className,
    this.termId,
    this.termName,
    this.applicationDate,
    this.totalValue,
    required this.status,
    required this.correctionType,
  });

  factory ExamResultsMobileExam.fromJson(Map<String, dynamic> json) {
    return ExamResultsMobileExam(
      id: _asString(json['id'] ?? json['examId']),
      title: _asString(json['title']),
      subjectId: _asString(json['subjectId']),
      subjectName: _asString(json['subject']),
      classId: _asString(json['classId']),
      className: _asString(json['className']),
      termId:
          _asString(json['termId']).isEmpty ? null : _asString(json['termId']),
      termName: _asString(json['termName']).isEmpty
          ? null
          : _asString(json['termName']),
      applicationDate: _asDate(json['applicationDate']),
      totalValue: _asDouble(json['totalValue'] ?? json['totalPoints']),
      status: _asString(json['status']),
      correctionType: _asString(json['correctionType']),
    );
  }
}

class ExamResultsMobileSummary {
  final int totalStudents;
  final int corrected;
  final int pending;
  final double? averageScore;
  final double? highestScore;
  final double? lowestScore;

  const ExamResultsMobileSummary({
    required this.totalStudents,
    required this.corrected,
    required this.pending,
    this.averageScore,
    this.highestScore,
    this.lowestScore,
  });

  factory ExamResultsMobileSummary.fromJson(Map<String, dynamic> json) {
    return ExamResultsMobileSummary(
      totalStudents: _asInt(json['totalStudents']),
      corrected: _asInt(json['corrected']),
      pending: _asInt(json['pending']),
      averageScore: _asDouble(json['averageScore']),
      highestScore: _asDouble(json['highestScore']),
      lowestScore: _asDouble(json['lowestScore']),
    );
  }
}

class ExamStudentResultMobile {
  final String studentId;
  final String studentName;
  final String status;
  final String? sheetId;
  final String? sheetStatus;
  final double? score;
  final double? maxScore;
  final double? percentage;
  final DateTime? correctedAt;

  const ExamStudentResultMobile({
    required this.studentId,
    required this.studentName,
    required this.status,
    this.sheetId,
    this.sheetStatus,
    this.score,
    this.maxScore,
    this.percentage,
    this.correctedAt,
  });

  bool get isCorrected => status == 'corrected';

  factory ExamStudentResultMobile.fromJson(Map<String, dynamic> json) {
    return ExamStudentResultMobile(
      studentId: _asString(json['studentId']),
      studentName: _asString(json['studentName']).isEmpty
          ? 'Aluno sem nome'
          : _asString(json['studentName']),
      status: _asString(json['status']).isEmpty
          ? 'pending'
          : _asString(json['status']),
      sheetId: json['sheetId']?.toString(),
      sheetStatus: json['sheetStatus']?.toString(),
      score: _asDouble(json['score'] ?? json['grade']),
      maxScore: _asDouble(json['maxScore'] ?? json['maxGrade']),
      percentage: _asDouble(json['percentage']),
      correctedAt: _asDate(json['correctedAt']),
    );
  }
}

class ReportCardExamImportPreview {
  final ImportPreviewExam exam;
  final ImportPreviewTarget target;
  final ImportPreviewSummary summary;
  final bool canCommit;
  final bool termBlocked;
  final List<ImportPreviewItem> items;

  const ReportCardExamImportPreview({
    required this.exam,
    required this.target,
    required this.summary,
    required this.canCommit,
    required this.termBlocked,
    required this.items,
  });

  factory ReportCardExamImportPreview.fromJson(Map<String, dynamic> json) {
    return ReportCardExamImportPreview(
      exam: ImportPreviewExam.fromJson(
        Map<String, dynamic>.from(json['exam'] as Map? ?? const {}),
      ),
      target: ImportPreviewTarget.fromJson(
        Map<String, dynamic>.from(json['target'] as Map? ?? const {}),
      ),
      summary: ImportPreviewSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      ),
      canCommit: json['canCommit'] == true,
      termBlocked: json['termBlocked'] == true,
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => ImportPreviewItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class ImportPreviewExam {
  final String examId;
  final String title;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String? termId;
  final String? termName;
  final double? totalValue;

  const ImportPreviewExam({
    required this.examId,
    required this.title,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    this.termId,
    this.termName,
    this.totalValue,
  });

  factory ImportPreviewExam.fromJson(Map<String, dynamic> json) {
    return ImportPreviewExam(
      examId: _asString(json['examId']),
      title: _asString(json['title']),
      classId: _asString(json['classId']),
      className: _asString(json['className']),
      subjectId: _asString(json['subjectId']),
      subjectName: _asString(json['subjectName']),
      termId: json['termId']?.toString(),
      termName: json['termName']?.toString(),
      totalValue: _asDouble(json['totalValue']),
    );
  }
}

class ImportPreviewTarget {
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String termId;
  final String termName;
  final String? academicYearId;
  final int? academicYear;
  final String scoreMode;

  const ImportPreviewTarget({
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.termId,
    required this.termName,
    this.academicYearId,
    this.academicYear,
    required this.scoreMode,
  });

  factory ImportPreviewTarget.fromJson(Map<String, dynamic> json) {
    return ImportPreviewTarget(
      classId: _asString(json['classId']),
      className: _asString(json['className']),
      subjectId: _asString(json['subjectId']),
      subjectName: _asString(json['subjectName']),
      termId: _asString(json['termId']),
      termName: _asString(json['termName']),
      academicYearId: _asString(json['academicYearId']).isEmpty
          ? null
          : _asString(json['academicYearId']),
      academicYear:
          json['academicYear'] == null ? null : _asInt(json['academicYear']),
      scoreMode: _asString(json['scoreMode']).isEmpty
          ? 'raw'
          : _asString(json['scoreMode']),
    );
  }
}

class ImportPreviewSummary {
  final int totalStudents;
  final int importableCount;
  final int noopCount;
  final int conflictCount;
  final int pendingCount;
  final int blockedCount;

  const ImportPreviewSummary({
    required this.totalStudents,
    required this.importableCount,
    required this.noopCount,
    required this.conflictCount,
    required this.pendingCount,
    required this.blockedCount,
  });

  factory ImportPreviewSummary.fromJson(Map<String, dynamic> json) {
    return ImportPreviewSummary(
      totalStudents: _asInt(json['totalStudents']),
      importableCount: _asInt(json['importableCount']),
      noopCount: _asInt(json['noopCount']),
      conflictCount: _asInt(json['conflictCount']),
      pendingCount: _asInt(json['pendingCount']),
      blockedCount: _asInt(json['blockedCount']),
    );
  }
}

class ImportPreviewItem {
  final String studentId;
  final String studentName;
  final String? reportCardId;
  final String? sheetId;
  final String correctionStatus;
  final double? examGrade;
  final double? examMaxGrade;
  final double? proposedTestScore;
  final double? currentTestScore;
  final double? activityScore;
  final double? participationScore;
  final double? predictedFinalScore;
  final String scaleStatus;
  final bool blocked;
  final String status;
  final String suggestedAction;
  final String? message;
  final String? missingReportCardDiagnosis;

  const ImportPreviewItem({
    required this.studentId,
    required this.studentName,
    this.reportCardId,
    this.sheetId,
    required this.correctionStatus,
    this.examGrade,
    this.examMaxGrade,
    this.proposedTestScore,
    this.currentTestScore,
    this.activityScore,
    this.participationScore,
    this.predictedFinalScore,
    required this.scaleStatus,
    required this.blocked,
    required this.status,
    required this.suggestedAction,
    this.message,
    this.missingReportCardDiagnosis,
  });

  bool get isImportable => status == 'will_fill';
  bool get isConflict => status == 'conflict_existing_test_score';
  bool get isAlreadyImported =>
      status == 'already_imported' || status == 'already_same';
  bool get isBlocked => blocked;
  String get blockReason =>
      message?.trim().isNotEmpty == true ? message!.trim() : status;

  factory ImportPreviewItem.fromJson(Map<String, dynamic> json) {
    return ImportPreviewItem(
      studentId: _asString(json['studentId']),
      studentName: _asString(json['studentName']),
      reportCardId: json['reportCardId']?.toString(),
      sheetId: json['sheetId']?.toString(),
      correctionStatus: _asString(json['correctionStatus']),
      examGrade: _asDouble(json['examGrade']),
      examMaxGrade: _asDouble(json['examMaxGrade']),
      proposedTestScore: _asDouble(json['proposedTestScore']),
      currentTestScore: _asDouble(json['currentTestScore']),
      activityScore: _asDouble(json['activityScore']),
      participationScore: _asDouble(json['participationScore']),
      predictedFinalScore: _asDouble(json['predictedFinalScore']),
      scaleStatus: _asString(json['scaleStatus']),
      blocked: json['blocked'] == true,
      status: _asString(json['status']),
      suggestedAction: _asString(json['suggestedAction']),
      message: json['message']?.toString(),
      missingReportCardDiagnosis:
          json['missingReportCardDiagnosis']?.toString(),
    );
  }
}

class ReportCardExamImportCommitResult {
  final bool reused;
  final String batchId;
  final String status;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> items;

  const ReportCardExamImportCommitResult({
    required this.reused,
    required this.batchId,
    required this.status,
    required this.summary,
    required this.items,
  });

  factory ReportCardExamImportCommitResult.fromJson(Map<String, dynamic> json) {
    return ReportCardExamImportCommitResult(
      reused: json['reused'] == true,
      batchId: _asString(json['batchId']),
      status: _asString(json['status']),
      summary: Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }
}
