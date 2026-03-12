import 'package:intl/intl.dart';

class EvaluationModel {
  final String? id;
  final String classId;
  final String? teacherId;
  final String title;
  final String type; // EXAM, WORK, ACTIVITY, PARTICIPATION
  final DateTime date;
  final double maxScore;
  final String? term;
  final String? schoolYear;

  // --- NOVOS CAMPOS ADICIONADOS ---
  final String? subjectId; // ID da disciplina
  final String? startTime; // Ex: "08:00"
  final String? endTime; // Ex: "10:00"

  EvaluationModel({
    this.id,
    required this.classId,
    this.teacherId,
    required this.title,
    required this.type,
    required this.date,
    required this.maxScore,
    this.term,
    this.schoolYear,
    // Novos parâmetros no construtor
    this.subjectId,
    this.startTime,
    this.endTime,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    return EvaluationModel(
      id: json['_id'] ?? json['id'],
      classId: json['classInfo'] is Map
          ? json['classInfo']['_id']
          : (json['classInfo'] ?? ''),
      teacherId:
          json['teacher'] is Map ? json['teacher']['_id'] : json['teacher'],
      title: json['title'] ?? 'Sem título',
      type: json['type'] ?? 'ACTIVITY',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      maxScore: (json['maxScore'] ?? 0).toDouble(),
      term: json['term'],
      schoolYear: json['schoolYear'],

      // Mapeamento dos novos campos
      // Nota: O backend pode retornar o objeto populado ou apenas o ID
      subjectId:
          json['subject'] is Map ? json['subject']['_id'] : json['subject'],
      startTime: json['startTime'],
      endTime: json['endTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'classInfo': classId,
      'teacher': teacherId,
      'title': title,
      'type': type,
      'date': date.toIso8601String(),
      'maxScore': maxScore,
      'term': term,
      'schoolYear': schoolYear,

      // Envio dos novos campos para o backend
      'subject':
          subjectId, // O backend provavelmente espera 'subject' como referência
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}
