import 'package:academyhub_mobile/model/student_note_model.dart';

String _summaryString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text;
}

String? _summaryNullableString(dynamic value) {
  final text = _summaryString(value);
  return text.isEmpty ? null : text;
}

int? _summaryInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double _summaryDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _summaryBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().toLowerCase().trim();
  return normalized == 'true' || normalized == '1';
}

DateTime? _summaryDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _summaryMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _summaryMapList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => _summaryMap(item)).toList();
}

class TeacherStudentSummary {
  final TeacherClassInfo classInfo;
  final TeacherStudentIdentity student;
  final TeacherEnrollmentSnapshot enrollment;
  final TeacherGuardiansSummary guardians;
  final TeacherHealthSummary health;
  final TeacherAttendanceSummaryBlock recentAttendance;
  final List<StudentNoteModel> notes;

  const TeacherStudentSummary({
    required this.classInfo,
    required this.student,
    required this.enrollment,
    required this.guardians,
    required this.health,
    required this.recentAttendance,
    required this.notes,
  });

  factory TeacherStudentSummary.fromJson(Map<String, dynamic> json) {
    return TeacherStudentSummary(
      classInfo: TeacherClassInfo.fromJson(_summaryMap(json['class'])),
      student: TeacherStudentIdentity.fromJson(_summaryMap(json['student'])),
      enrollment:
          TeacherEnrollmentSnapshot.fromJson(_summaryMap(json['enrollment'])),
      guardians:
          TeacherGuardiansSummary.fromJson(_summaryMap(json['guardians'])),
      health: TeacherHealthSummary.fromJson(_summaryMap(json['health'])),
      recentAttendance: TeacherAttendanceSummaryBlock.fromJson(
        _summaryMap(json['recentAttendance']),
      ),
      notes: _summaryMapList(json['notes'])
          .map(StudentNoteModel.fromJson)
          .toList(),
    );
  }
}

class TeacherClassInfo {
  final String id;
  final String name;
  final String grade;
  final String shift;
  final int? schoolYear;

  const TeacherClassInfo({
    required this.id,
    required this.name,
    required this.grade,
    required this.shift,
    required this.schoolYear,
  });

  factory TeacherClassInfo.fromJson(Map<String, dynamic> json) {
    return TeacherClassInfo(
      id: _summaryString(json['id']),
      name: _summaryString(json['name']),
      grade: _summaryString(json['grade']),
      shift: _summaryString(json['shift']),
      schoolYear: _summaryInt(json['schoolYear']),
    );
  }
}

class TeacherStudentIdentity {
  final String id;
  final String fullName;
  final String? enrollmentNumber;
  final DateTime? birthDate;
  final int? age;
  final TeacherBirthdayInfo birthday;
  final String? gender;

  const TeacherStudentIdentity({
    required this.id,
    required this.fullName,
    required this.enrollmentNumber,
    required this.birthDate,
    required this.age,
    required this.birthday,
    required this.gender,
  });

  String get initials {
    final parts = fullName
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory TeacherStudentIdentity.fromJson(Map<String, dynamic> json) {
    return TeacherStudentIdentity(
      id: _summaryString(json['id']),
      fullName: _summaryString(json['fullName']),
      enrollmentNumber: _summaryNullableString(json['enrollmentNumber']),
      birthDate: _summaryDate(json['birthDate']),
      age: _summaryInt(json['age']),
      birthday: TeacherBirthdayInfo.fromJson(_summaryMap(json['birthday'])),
      gender: _summaryNullableString(json['gender']),
    );
  }
}

class TeacherBirthdayInfo {
  final int? day;
  final int? month;
  final String? label;
  final bool isToday;

  const TeacherBirthdayInfo({
    required this.day,
    required this.month,
    required this.label,
    required this.isToday,
  });

  factory TeacherBirthdayInfo.fromJson(Map<String, dynamic> json) {
    return TeacherBirthdayInfo(
      day: _summaryInt(json['day']),
      month: _summaryInt(json['month']),
      label: _summaryNullableString(json['label']),
      isToday: _summaryBool(json['isToday']),
    );
  }
}

class TeacherEnrollmentSnapshot {
  final String id;
  final String? status;
  final DateTime? enrollmentDate;
  final int? academicYear;

  const TeacherEnrollmentSnapshot({
    required this.id,
    required this.status,
    required this.enrollmentDate,
    required this.academicYear,
  });

  factory TeacherEnrollmentSnapshot.fromJson(Map<String, dynamic> json) {
    return TeacherEnrollmentSnapshot(
      id: _summaryString(json['id']),
      status: _summaryNullableString(json['status']),
      enrollmentDate: _summaryDate(json['enrollmentDate']),
      academicYear: _summaryInt(json['academicYear']),
    );
  }
}

class TeacherGuardiansSummary {
  final TeacherGuardianContact? father;
  final TeacherGuardianContact? mother;
  final List<TeacherGuardianContact> contacts;

  const TeacherGuardiansSummary({
    required this.father,
    required this.mother,
    required this.contacts,
  });

  factory TeacherGuardiansSummary.fromJson(Map<String, dynamic> json) {
    TeacherGuardianContact? parseContact(dynamic value) {
      final map = _summaryMap(value);
      if (map.isEmpty) return null;
      final contact = TeacherGuardianContact.fromJson(map);
      return contact.name.isEmpty ? null : contact;
    }

    return TeacherGuardiansSummary(
      father: parseContact(json['father']),
      mother: parseContact(json['mother']),
      contacts: _summaryMapList(json['contacts'])
          .map(TeacherGuardianContact.fromJson)
          .where((contact) => contact.name.isNotEmpty)
          .toList(),
    );
  }
}

class TeacherGuardianContact {
  final String id;
  final String name;
  final String relationship;
  final String? phoneNumber;

  const TeacherGuardianContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phoneNumber,
  });

  factory TeacherGuardianContact.fromJson(Map<String, dynamic> json) {
    return TeacherGuardianContact(
      id: _summaryString(json['id']),
      name: _summaryString(json['name']),
      relationship: _summaryString(json['relationship']),
      phoneNumber: _summaryNullableString(json['phoneNumber']),
    );
  }
}

class TeacherHealthSummary {
  final bool hasAlerts;
  final String? allergies;
  final String? medicationAllergies;
  final String? continuousMedication;
  final String? healthCondition;
  final String? disability;
  final String? visionProblem;
  final String? feverGuidance;
  final String? foodObservations;
  final List<TeacherHealthAlert> alerts;

  const TeacherHealthSummary({
    required this.hasAlerts,
    required this.allergies,
    required this.medicationAllergies,
    required this.continuousMedication,
    required this.healthCondition,
    required this.disability,
    required this.visionProblem,
    required this.feverGuidance,
    required this.foodObservations,
    required this.alerts,
  });

  List<TeacherHealthDetail> get details {
    final items = <TeacherHealthDetail>[
      TeacherHealthDetail(
        label: 'Alergias',
        value: allergies,
        tone: TeacherHealthTone.critical,
      ),
      TeacherHealthDetail(
        label: 'Alergia a medicacao',
        value: medicationAllergies,
        tone: TeacherHealthTone.warning,
      ),
      TeacherHealthDetail(
        label: 'Medicacao continua',
        value: continuousMedication,
        tone: TeacherHealthTone.warning,
      ),
      TeacherHealthDetail(
        label: 'Condicao de saude',
        value: healthCondition,
        tone: TeacherHealthTone.warning,
      ),
      TeacherHealthDetail(
        label: 'Deficiencia ou adaptacao',
        value: disability,
        tone: TeacherHealthTone.info,
      ),
      TeacherHealthDetail(
        label: 'Visao',
        value: visionProblem,
        tone: TeacherHealthTone.info,
      ),
      TeacherHealthDetail(
        label: 'Orientacao para febre',
        value: feverGuidance,
        tone: TeacherHealthTone.info,
      ),
      TeacherHealthDetail(
        label: 'Observacao alimentar',
        value: foodObservations,
        tone: TeacherHealthTone.info,
      ),
    ];

    return items.where((item) => (item.value ?? '').trim().isNotEmpty).toList();
  }

  factory TeacherHealthSummary.fromJson(Map<String, dynamic> json) {
    return TeacherHealthSummary(
      hasAlerts: _summaryBool(json['hasAlerts']),
      allergies: _summaryNullableString(json['allergies']),
      medicationAllergies: _summaryNullableString(json['medicationAllergies']),
      continuousMedication: _summaryNullableString(json['continuousMedication']),
      healthCondition: _summaryNullableString(json['healthCondition']),
      disability: _summaryNullableString(json['disability']),
      visionProblem: _summaryNullableString(json['visionProblem']),
      feverGuidance: _summaryNullableString(json['feverGuidance']),
      foodObservations: _summaryNullableString(json['foodObservations']),
      alerts: _summaryMapList(json['alerts'])
          .map(TeacherHealthAlert.fromJson)
          .toList(),
    );
  }
}

enum TeacherHealthTone { critical, warning, info }

class TeacherHealthDetail {
  final String label;
  final String? value;
  final TeacherHealthTone tone;

  const TeacherHealthDetail({
    required this.label,
    required this.value,
    required this.tone,
  });
}

class TeacherHealthAlert {
  final String key;
  final String label;
  final String description;

  const TeacherHealthAlert({
    required this.key,
    required this.label,
    required this.description,
  });

  factory TeacherHealthAlert.fromJson(Map<String, dynamic> json) {
    return TeacherHealthAlert(
      key: _summaryString(json['key']),
      label: _summaryString(json['label']),
      description: _summaryString(json['description']),
    );
  }
}

class TeacherAttendanceSummaryBlock {
  final TeacherAttendanceWindow window;
  final TeacherAttendanceStats summary;
  final List<TeacherAttendanceRecord> records;

  const TeacherAttendanceSummaryBlock({
    required this.window,
    required this.summary,
    required this.records,
  });

  factory TeacherAttendanceSummaryBlock.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceSummaryBlock(
      window: TeacherAttendanceWindow.fromJson(_summaryMap(json['window'])),
      summary: TeacherAttendanceStats.fromJson(_summaryMap(json['summary'])),
      records: _summaryMapList(json['records'])
          .map(TeacherAttendanceRecord.fromJson)
          .toList(),
    );
  }
}

class TeacherAttendanceWindow {
  final String type;
  final int requestedSize;
  final int returnedRecords;

  const TeacherAttendanceWindow({
    required this.type,
    required this.requestedSize,
    required this.returnedRecords,
  });

  factory TeacherAttendanceWindow.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceWindow(
      type: _summaryString(json['type']),
      requestedSize: _summaryInt(json['requestedSize']) ?? 0,
      returnedRecords: _summaryInt(json['returnedRecords']) ?? 0,
    );
  }
}

class TeacherAttendanceStats {
  final int totalRecords;
  final int presentCount;
  final int absentCount;
  final int justifiedAbsences;
  final int pendingJustifications;
  final int rejectedJustifications;
  final int expiredJustifications;
  final double presenceRate;
  final DateTime? lastRecordedAt;

  const TeacherAttendanceStats({
    required this.totalRecords,
    required this.presentCount,
    required this.absentCount,
    required this.justifiedAbsences,
    required this.pendingJustifications,
    required this.rejectedJustifications,
    required this.expiredJustifications,
    required this.presenceRate,
    required this.lastRecordedAt,
  });

  factory TeacherAttendanceStats.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceStats(
      totalRecords: _summaryInt(json['totalRecords']) ?? 0,
      presentCount: _summaryInt(json['presentCount']) ?? 0,
      absentCount: _summaryInt(json['absentCount']) ?? 0,
      justifiedAbsences: _summaryInt(json['justifiedAbsences']) ?? 0,
      pendingJustifications: _summaryInt(json['pendingJustifications']) ?? 0,
      rejectedJustifications: _summaryInt(json['rejectedJustifications']) ?? 0,
      expiredJustifications: _summaryInt(json['expiredJustifications']) ?? 0,
      presenceRate: _summaryDouble(json['presenceRate']),
      lastRecordedAt: _summaryDate(json['lastRecordedAt']),
    );
  }
}

class TeacherAttendanceRecord {
  final DateTime? date;
  final String status;
  final String absenceState;
  final String label;
  final String observation;
  final DateTime? updatedAt;

  const TeacherAttendanceRecord({
    required this.date,
    required this.status,
    required this.absenceState,
    required this.label,
    required this.observation,
    required this.updatedAt,
  });

  bool get isPresent => status.toUpperCase() == 'PRESENT';

  factory TeacherAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceRecord(
      date: _summaryDate(json['date']),
      status: _summaryString(json['status']),
      absenceState: _summaryString(json['absenceState']),
      label: _summaryString(json['label']),
      observation: _summaryString(json['observation']),
      updatedAt: _summaryDate(json['updatedAt']),
    );
  }
}
