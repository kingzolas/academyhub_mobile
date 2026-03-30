String _extractId(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map) {
    final map = Map<String, dynamic>.from(value as Map);
    return map['_id']?.toString() ?? map['id']?.toString() ?? '';
  }
  return value.toString();
}

String _stringOrFallback(dynamic value, String fallback) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  try {
    return DateTime.parse(text).toLocal();
  } catch (_) {
    return null;
  }
}

DateTime _parseAttendanceDay(dynamic value) {
  if (value == null) return DateTime.now();

  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }

  final text = value.toString().trim();
  if (text.isEmpty) return DateTime.now();

  final onlyDate = text.split('T').first;
  final parts = onlyDate.split('-');
  if (parts.length == 3) {
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  try {
    final parsed = DateTime.parse(text);
    return DateTime(parsed.year, parsed.month, parsed.day);
  } catch (_) {
    return DateTime.now();
  }
}

String _normalizeStatus(dynamic value) {
  return _stringOrFallback(value, 'PRESENT').toUpperCase() == 'ABSENT'
      ? 'ABSENT'
      : 'PRESENT';
}

String _normalizeAbsenceState(dynamic value) {
  return _stringOrFallback(value, 'NONE').toUpperCase();
}

class AttendanceRecord {
  final String studentId;
  final String studentName;
  final String? studentPhoto;
  String status; // 'PRESENT' or 'ABSENT'
  String observation;
  final String absenceState;
  final String? justificationId;
  final DateTime? justificationDeadlineAt;
  final DateTime? justificationUpdatedAt;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    this.studentPhoto,
    required this.status,
    this.observation = '',
    this.absenceState = 'NONE',
    this.justificationId,
    this.justificationDeadlineAt,
    this.justificationUpdatedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final rawStudent = json['studentId'];
    final studentData = rawStudent is Map
        ? Map<String, dynamic>.from(rawStudent)
        : <String, dynamic>{};

    final studentId = _extractId(rawStudent);
    final studentName = studentData.isNotEmpty
        ? _stringOrFallback(
            studentData['fullName'] ??
                studentData['name'] ??
                studentData['studentName'],
            'Sem nome',
          )
        : _stringOrFallback(json['studentName'], 'Aluno desconhecido');

    final studentPhoto = studentData.isNotEmpty
        ? _stringOrFallback(
                studentData['photoUrl'] ??
                    studentData['profilePictureUrl'] ??
                    studentData['profilePicture'] ??
                    studentData['avatar'],
                '')
            .trim()
        : _stringOrFallback(json['studentPhoto'], '').trim();

    return AttendanceRecord(
      studentId: studentId,
      studentName: studentName,
      studentPhoto: studentPhoto.isEmpty ? null : studentPhoto,
      status: _normalizeStatus(json['status']),
      observation: _stringOrFallback(json['observation'], ''),
      absenceState: _normalizeAbsenceState(json['absenceState']),
      justificationId: _extractId(json['justificationId']).isEmpty
          ? null
          : _extractId(json['justificationId']),
      justificationDeadlineAt: _parseDateTime(json['justificationDeadlineAt']),
      justificationUpdatedAt: _parseDateTime(json['justificationUpdatedAt']),
    );
  }

  bool get isPresent => status.toUpperCase() == 'PRESENT';
  bool get isAbsent => status.toUpperCase() == 'ABSENT';
  bool get hasObservation => observation.trim().isNotEmpty;

  String get absenceLabel {
    switch (absenceState.toUpperCase()) {
      case 'APPROVED':
        return 'Justificada';
      case 'PENDING':
        return 'Pendente';
      case 'REJECTED':
        return 'Rejeitada';
      case 'EXPIRED':
        return 'Expirada';
      default:
        return isAbsent ? 'Ausente' : 'Presente';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'status': status.toUpperCase(),
      'observation': observation,
    };
  }
}

class AttendanceSheet {
  final String? id;
  final String classId;
  final DateTime date;
  final DateTime? updatedAt;
  final List<AttendanceRecord> records;

  AttendanceSheet({
    this.id,
    required this.classId,
    required this.date,
    this.updatedAt,
    required this.records,
  });

  factory AttendanceSheet.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'];
    final recordsList = rawRecords is List
        ? rawRecords
            .whereType<dynamic>()
            .map((item) {
              if (item is Map<String, dynamic>) {
                return AttendanceRecord.fromJson(item);
              }
              if (item is Map) {
                return AttendanceRecord.fromJson(
                    Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<AttendanceRecord>()
            .toList()
        : <AttendanceRecord>[];

    return AttendanceSheet(
      id: _extractId(json['_id']).isEmpty ? null : _extractId(json['_id']),
      classId: _extractId(json['classId']),
      date: _parseAttendanceDay(json['date']),
      updatedAt: _parseDateTime(json['updatedAt']),
      records: recordsList,
    );
  }

  int get totalStudents => records.length;
  int get presentCount => records.where((r) => r.isPresent).length;
  int get absentCount => records.where((r) => r.isAbsent).length;
  double get presenceRate =>
      totalStudents == 0 ? 0 : presentCount / totalStudents;
  List<AttendanceRecord> get presentRecords =>
      records.where((r) => r.isPresent).toList(growable: false);
  List<AttendanceRecord> get absentRecords =>
      records.where((r) => r.isAbsent).toList(growable: false);

  AttendanceRecord? recordForStudent(String studentId) {
    try {
      return records.firstWhere((r) => r.studentId == studentId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return {
      if (id != null) '_id': id,
      'classId': classId,
      'date': '$y-$m-$d',
      'records': records.map((r) => r.toJson()).toList(),
    };
  }
}
