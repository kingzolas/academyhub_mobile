// lib/model/course_load_model.dart

import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:flutter/foundation.dart';

class CourseLoadModel {
  final String id;
  final String periodoId;
  final String classId;
  final String? schoolId; // [NOVO] Adicionado para leitura
  final SubjectModel subject;
  final double targetHours;

  CourseLoadModel({
    required this.id,
    required this.periodoId,
    required this.classId,
    this.schoolId, // [NOVO]
    required this.subject,
    required this.targetHours,
  });

  // Helper para extrair ID de campo possivelmente populado (Map ou String)
  static String? safeExtractId(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['_id']?.toString();
    }
    return data?.toString();
  }

  factory CourseLoadModel.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('[CourseLoadModel.fromJson] JSON Recebido: $json');
    }

    return CourseLoadModel(
      id: json['_id'] ?? '',

      periodoId: json['periodoId'] ?? '',
      classId: json['classId'] ?? '',

      schoolId: safeExtractId(json['school_id']), // [NOVO] Mapeamento seguro

      // Assumimos que subjectId vem populado ou é um Map vazio
      subject: SubjectModel.fromJson(json['subjectId'] ?? {}),

      targetHours: (json['targetHours'] as num? ?? 0.0).toDouble(),
    );
  }

  // Modelo para enviar no batch save
  Map<String, dynamic> toJsonForBatch() {
    return {
      // Nota: periodoId e classId são enviados no body da requisição batch,
      // então este toJson precisa apenas dos detalhes da carga.
      'subjectId': subject.id,
      'targetHours': targetHours,
    };
  }

  // copyWith para imutabilidade (opcional, mas boa prática)
  CourseLoadModel copyWith({
    String? id,
    String? periodoId,
    String? classId,
    String? schoolId,
    SubjectModel? subject,
    double? targetHours,
  }) {
    return CourseLoadModel(
      id: id ?? this.id,
      periodoId: periodoId ?? this.periodoId,
      classId: classId ?? this.classId,
      schoolId: schoolId ?? this.schoolId,
      subject: subject ?? this.subject,
      targetHours: targetHours ?? this.targetHours,
    );
  }
}
