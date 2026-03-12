class AttendanceRecord {
  final String studentId;
  final String studentName;
  final String? studentPhoto;
  String status; // 'PRESENT', 'ABSENT', 'EXCUSED'
  String observation;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    this.studentPhoto,
    required this.status,
    this.observation = '',
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    // Verifica se studentId veio populado como Objeto (Map) ou string
    final studentData = json['studentId'] is Map ? json['studentId'] : {};

    // [CORREÇÃO] Busca 'fullName' (padrão do seu banco) OU 'name'
    String name = 'Aluno Desconhecido';
    if (studentData.isNotEmpty) {
      name = studentData['fullName'] ?? studentData['name'] ?? 'Sem Nome';
    }

    return AttendanceRecord(
      studentId: studentData['_id'] ??
          (json['studentId'] is String ? json['studentId'] : ''),
      studentName: name,
      studentPhoto: studentData['photoUrl'],
      status: json['status'] ?? 'PRESENT',
      observation: json['observation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'status': status,
      'observation': observation,
    };
  }
}

class AttendanceSheet {
  final String? id;
  final String classId;
  final DateTime date;
  final List<AttendanceRecord> records;

  AttendanceSheet({
    this.id,
    required this.classId,
    required this.date,
    required this.records,
  });

  factory AttendanceSheet.fromJson(Map<String, dynamic> json) {
    var list = json['records'] as List;
    List<AttendanceRecord> recordsList =
        list.map((i) => AttendanceRecord.fromJson(i)).toList();

    return AttendanceSheet(
      id: json['_id'],
      classId: json['classId'].toString(),
      date: DateTime.parse(json['date']),
      records: recordsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'classId': classId,
      'date': date.toIso8601String(),
      'records': records.map((r) => r.toJson()).toList(),
    };
  }
}
