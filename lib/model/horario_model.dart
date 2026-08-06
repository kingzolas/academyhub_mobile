// lib/model/horario_model.dart
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/model/evento_model.dart'; // Contém TeacherReference

// Helper para extrair ID de campo possivelmente populado
String? safeExtractId(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data['_id']?.toString();
  }
  return data?.toString();
}

class HorarioModel {
  final String id;
  final String termId;
  final String? schoolId;
  final ClassReference classInfo;
  final SubjectModel subject;
  final TeacherReference teacher;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? room;
  final bool isInherited;
  final String? resolvedFromTermId;
  final String? resolvedFromTermName;
  final String? targetTermId;
  final String? targetTermName;
  final String? sourceTermId;
  final String? sourceHorarioId;

  HorarioModel({
    required this.id,
    required this.termId,
    this.schoolId,
    required this.classInfo,
    required this.subject,
    required this.teacher,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.isInherited = false,
    this.resolvedFromTermId,
    this.resolvedFromTermName,
    this.targetTermId,
    this.targetTermName,
    this.sourceTermId,
    this.sourceHorarioId,
  });

  // Getters para facilitar acesso na UI
  String get subjectId => subject.id;
  String get teacherId => teacher.id;
  String get classId => classInfo.id;

  factory HorarioModel.fromJson(Map<String, dynamic> json) {
    final schoolIdValue =
        json['school_id'] is Map ? json['school_id']['_id'] : json['school_id'];
    final schoolIdStr = safeExtractId(schoolIdValue) ?? '';

    // 1. Subject (Matéria)
    SubjectModel subjectObj;
    if (json['subjectId'] is Map<String, dynamic>) {
      subjectObj = SubjectModel.fromJson(json['subjectId']);
    } else {
      subjectObj = SubjectModel(
        id: json['subjectId']?.toString() ?? '',
        name: 'Carregando...',
        level: 'Geral',
        schoolId: schoolIdStr,
      );
    }

    // 2. Teacher (Professor)
    TeacherReference teacherObj;
    if (json['teacherId'] is Map<String, dynamic>) {
      teacherObj = TeacherReference.fromJson(json['teacherId']);
    } else {
      // CORREÇÃO: Adicionado o campo obrigatório 'fullName'
      teacherObj = TeacherReference(
        id: json['teacherId']?.toString() ?? '',
        fullName: 'Professor',
      );
    }

    // 3. ClassInfo (Turma)
    ClassReference classObj;
    if (json['classId'] is Map<String, dynamic>) {
      classObj = ClassReference.fromJson(json['classId']);
    } else {
      // CORREÇÃO: Adicionados campos obrigatórios com valores padrão
      classObj = ClassReference(
        id: json['classId']?.toString() ?? '',
        name: 'Turma',
        schoolYear: DateTime.now().year, // Valor padrão
        grade: '-', // Valor padrão
        shift: '-', // Valor padrão
        schoolId: schoolIdStr, // Valor padrão
      );
    }

    return HorarioModel(
      id: json['_id'] ?? '',
      termId: safeExtractId(json['termId']) ?? '',
      schoolId: schoolIdStr,
      classInfo: classObj,
      subject: subjectObj,
      teacher: teacherObj,
      dayOfWeek: (json['dayOfWeek'] as int?) ?? 1,
      startTime: json['startTime'] ?? '00:00',
      endTime: json['endTime'] ?? '00:00',
      room: json['room'],
      isInherited: json['isInherited'] == true,
      resolvedFromTermId: safeExtractId(json['resolvedFromTermId']),
      resolvedFromTermName: json['resolvedFromTermName']?.toString(),
      targetTermId: safeExtractId(json['targetTermId']),
      targetTermName: json['targetTermName']?.toString(),
      sourceTermId: safeExtractId(json['sourceTermId']),
      sourceHorarioId: safeExtractId(json['sourceHorarioId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classInfo.id,
      'termId': termId,
      'subjectId': subject.id,
      'teacherId': teacher.id,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
    };
  }

  HorarioModel copyWith({
    String? id,
    String? termId,
    String? schoolId,
    ClassReference? classInfo,
    SubjectModel? subject,
    TeacherReference? teacher,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    bool? isInherited,
    String? resolvedFromTermId,
    String? resolvedFromTermName,
    String? targetTermId,
    String? targetTermName,
    String? sourceTermId,
    String? sourceHorarioId,
  }) {
    return HorarioModel(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      schoolId: schoolId ?? this.schoolId,
      classInfo: classInfo ?? this.classInfo,
      subject: subject ?? this.subject,
      teacher: teacher ?? this.teacher,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      isInherited: isInherited ?? this.isInherited,
      resolvedFromTermId: resolvedFromTermId ?? this.resolvedFromTermId,
      resolvedFromTermName: resolvedFromTermName ?? this.resolvedFromTermName,
      targetTermId: targetTermId ?? this.targetTermId,
      targetTermName: targetTermName ?? this.targetTermName,
      sourceTermId: sourceTermId ?? this.sourceTermId,
      sourceHorarioId: sourceHorarioId ?? this.sourceHorarioId,
    );
  }
}
