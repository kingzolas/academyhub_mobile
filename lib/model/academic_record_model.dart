// lib/model/academic_record_model.dart
import 'dart:convert';
import 'package:academyhub_mobile/model/grade_model.dart'; // Importa o model que acabamos de criar

class AcademicRecord {
  final String id; // O _id do Mongoose
  final String gradeLevel;
  final int schoolYear;
  final String schoolName;
  final String city;
  final String state;
  final List<Grade> grades;
  final String? annualWorkload;
  final String finalResult;

  AcademicRecord({
    required this.id,
    required this.gradeLevel,
    required this.schoolYear,
    required this.schoolName,
    required this.city,
    required this.state,
    required this.grades,
    this.annualWorkload,
    required this.finalResult,
  });

  factory AcademicRecord.fromJson(Map<String, dynamic> json) {
    return AcademicRecord(
      id: json['_id'],
      gradeLevel: json['gradeLevel'] ?? 'N/A',
      schoolYear: json['schoolYear'] ?? 0,
      schoolName: json['schoolName'] ?? 'N/A',
      city: json['city'] ?? 'N/A',
      state: json['state'] ?? 'N/A',
      grades: json['grades'] != null
          ? List<Grade>.from(json['grades'].map((x) => Grade.fromJson(x)))
          : [],
      annualWorkload: json['annualWorkload'],
      finalResult: json['finalResult'] ?? 'N/A',
    );
  }

  // toJson para CRIAR ou ATUALIZAR (não precisa do ID, ele vai na URL)
  Map<String, dynamic> toJson() {
    return {
      'gradeLevel': gradeLevel,
      'schoolYear': schoolYear,
      'schoolName': schoolName,
      'city': city,
      'state': state,
      'grades': grades.map((x) => x.toJson()).toList(),
      'annualWorkload': annualWorkload,
      'finalResult': finalResult,
    };
  }
}
