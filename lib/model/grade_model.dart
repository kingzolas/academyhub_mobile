// lib/model/grade_model.dart
import 'dart:convert';

class Grade {
  final String subjectName;
  final String gradeValue;

  Grade({
    required this.subjectName,
    required this.gradeValue,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      subjectName: json['subjectName'] ?? 'N/A',
      gradeValue: json['gradeValue'] ?? '--',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subjectName': subjectName,
      'gradeValue': gradeValue,
    };
  }
}
