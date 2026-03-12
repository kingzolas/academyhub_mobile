// lib/model/class_model.dart
import 'package:flutter/foundation.dart';

class ClassModel {
  final String id;
  final String name;
  final int schoolYear;
  final String? level;
  final String grade;
  final String shift;
  final String? room;
  final double monthlyFee;
  final int? capacity;
  final String status;
  final int studentCount;
  final Map<String, dynamic>? scheduleSettings;

  // --- [NOVO CAMPO OBRIGATÓRIO] ---
  final String schoolId;
  // ---------------------------------

  ClassModel({
    required this.id,
    required this.name,
    required this.schoolYear,
    this.level,
    required this.grade,
    required this.shift,
    this.room,
    required this.monthlyFee,
    this.capacity,
    required this.status,
    required this.studentCount,
    this.scheduleSettings,

    // --- [NOVO CAMPO OBRIGATÓRIO] ---
    required this.schoolId,
    // ---------------------------------
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['_id'],
      name: json['name'] ?? 'N/A',
      schoolYear: json['schoolYear'] ?? 0,
      level: json['level'],
      grade: json['grade'] ?? 'N/A',
      shift: json['shift'] ?? 'N/A',
      room: json['room'],
      monthlyFee: (json['monthlyFee'] as num?)?.toDouble() ?? 0.0,
      capacity: json['capacity'],
      status: json['status'] ?? 'Planejada',
      studentCount: json['studentCount'] ?? 0,
      scheduleSettings: json['scheduleSettings'] as Map<String, dynamic>?,

      // --- [NOVO CAMPO OBRIGATÓRIO] ---
      // O servidor agora SEMPRE enviará o school_id
      schoolId: json['school_id'],
      // ---------------------------------
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'schoolYear': schoolYear,
      'level': level,
      'grade': grade,
      'shift': shift,
      'room': room,
      'monthlyFee': monthlyFee,
      'capacity': capacity,
      'status': status,
      'scheduleSettings': scheduleSettings,

      // --- [NOVO CAMPO] ---
      // Não enviamos school_id no create, o servidor pega do token.
      // Mas é bom ter no toJson para outros usos.
      'school_id': schoolId,
      // --------------------
    };
  }

  ClassModel copyWith({
    String? id,
    String? name,
    int? schoolYear,
    String? level,
    String? grade,
    String? shift,
    String? room,
    double? monthlyFee,
    int? capacity,
    String? status,
    int? studentCount,
    Map<String, dynamic>? scheduleSettings,

    // --- [NOVO CAMPO] ---
    String? schoolId,
    // --------------------
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      schoolYear: schoolYear ?? this.schoolYear,
      level: level ?? this.level,
      grade: grade ?? this.grade,
      shift: shift ?? this.shift,
      room: room ?? this.room,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      studentCount: studentCount ?? this.studentCount,
      scheduleSettings: scheduleSettings ?? this.scheduleSettings,

      // --- [NOVO CAMPO] ---
      schoolId: schoolId ?? this.schoolId,
      // --------------------
    );
  }
}

// ClassReference (Usada pelo HorarioModel e outros)
class ClassReference {
  final String id;
  final String name;
  final int schoolYear;
  final String grade;
  final String shift;
  final String? level;

  // --- [NOVO CAMPO OBRIGATÓRIO] ---
  final String schoolId;
  // ---------------------------------

  ClassReference({
    required this.id,
    required this.name,
    required this.schoolYear,
    required this.grade,
    required this.shift,
    this.level,

    // --- [NOVO CAMPO OBRIGATÓRIO] ---
    required this.schoolId,
    // ---------------------------------
  });

  factory ClassReference.fromJson(Map<String, dynamic> json) {
    return ClassReference(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'N/A',
      schoolYear: json['schoolYear'] ?? 0,
      grade: json['grade'] ?? 'N/A',
      shift: json['shift'] ?? 'N/A',
      level: json['level'],

      // --- [NOVO CAMPO OBRIGATÓRIO] ---
      // Assume que a API (ex: Horario) vai popular o 'school_id'
      schoolId: json['school_id'] ?? '',
      // ---------------------------------
    );
  }
}
