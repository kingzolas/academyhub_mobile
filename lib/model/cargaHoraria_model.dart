import 'package:flutter/foundation.dart';
import 'package:academyhub_mobile/model/subject_model.dart'; // Importa o SubjectModel

class CargaHorariaModel {
  final String id;
  final String termId;
  final String classId;
  final SubjectModel subject; // Usamos o SubjectModel completo
  final double horasNecessarias; // Usando double para horas (ex: 30.5)

  CargaHorariaModel({
    required this.id,
    required this.termId,
    required this.classId,
    required this.subject,
    required this.horasNecessarias,
  });

  factory CargaHorariaModel.fromJson(Map<String, dynamic> json) {
    return CargaHorariaModel(
      id: json['_id'],
      termId: json['termId'],
      classId: json['classId'],
      // Assume que a API popula o 'subjectId' com o objeto Subject
      subject: SubjectModel.fromJson(json['subjectId']),
      horasNecessarias: (json['horasNecessarias'] as num).toDouble(),
    );
  }
}
