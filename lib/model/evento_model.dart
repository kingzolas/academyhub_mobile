// lib/model/evento_model.dart
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/model/user_model.dart';

// --- Referência Simplificada do Professor (User) ---
class TeacherReference {
  final String id;
  final String fullName;

  TeacherReference({required this.id, required this.fullName});

  factory TeacherReference.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return TeacherReference(id: '', fullName: 'N/A');
    return TeacherReference(
      id: json['_id'] ?? '',
      fullName: json['fullName'] ?? 'N/A',
    );
  }
}
// --- Fim da Referência ---

// Helper para extrair ID de campo possivelmente populado (Map ou String)
String? safeExtractId(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data['_id']?.toString();
  }
  return data?.toString();
}

class EventoModel {
  final String id;
  final String title;
  final String eventType;
  final String? description;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final bool isSchoolWide;

  final String? schoolId; // [NOVO] Campo para leitura

  // Vínculos (podem ser nulos ou populados)
  final ClassReference? classInfo;
  final SubjectModel? subject;
  final TeacherReference? teacher;

  EventoModel({
    required this.id,
    required this.title,
    required this.eventType,
    this.description,
    required this.date,
    this.startTime,
    this.endTime,
    required this.isSchoolWide,
    this.schoolId, // [NOVO] Adicionado ao construtor
    this.classInfo,
    this.subject,
    this.teacher,
  });

  factory EventoModel.fromJson(Map<String, dynamic> json) {
    return EventoModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? 'Sem Título',
      eventType: json['eventType'] ?? 'Outro',
      description: json['description'],

      // [NOVO] Mapeamento do schoolId
      schoolId: safeExtractId(json['school_id']),

      date: DateTime.tryParse(json['date'] ?? '') ??
          DateTime.now(), // Uso de tryParse
      startTime: json['startTime'],
      endTime: json['endTime'],
      isSchoolWide: json['isSchoolWide'] ?? false,

      // Mapeamento de objetos populados (se for Map, chama fromJson)
      classInfo: json['classId'] is Map
          ? ClassReference.fromJson(json['classId'])
          : null,
      subject: json['subjectId'] is Map
          ? SubjectModel.fromJson(json['subjectId'])
          : null,
      teacher: json['teacherId'] is Map
          ? TeacherReference.fromJson(json['teacherId'])
          : null,
    );
  }

  // toJson para CRIAR um evento (envia apenas os IDs)
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'eventType': eventType,
      'description': description,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'isSchoolWide': isSchoolWide,
      // Envia apenas os IDs, se existirem
      if (classInfo != null) 'classId': classInfo!.id,
      if (subject != null) 'subjectId': subject!.id,
      if (teacher != null) 'teacherId': teacher!.id,

      // schoolId NÃO é enviado
    };
  }
}
