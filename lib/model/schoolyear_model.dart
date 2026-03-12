// lib/model/school_year_model.dart
import 'package:flutter/foundation.dart';

class SchoolYearModel {
  final String id;
  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final String? schoolId; // [NOVO] Opcional para leitura

  SchoolYearModel({
    required this.id,
    required this.year,
    required this.startDate,
    required this.endDate,
    this.schoolId,
  });

  factory SchoolYearModel.fromJson(Map<String, dynamic> json) {
    return SchoolYearModel(
      id: json['_id'] ?? '',
      year: json['year'] ?? DateTime.now().year, // Fallback seguro

      // Parse seguro de datas. Se falhar, usa data atual.
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? '') ?? DateTime.now(),

      // Lógica híbrida para o school_id (pode vir string ou objeto populado)
      schoolId: json['school_id'] is Map
          ? json['school_id']['_id']
          : json['school_id'],
    );
  }

  // Usado para ENVIAR dados para a API (Criar/Atualizar)
  Map<String, dynamic> toJson() {
    return {
      'year': year,
      // O Backend espera ISO String (ex: "2025-02-10T00:00:00.000Z")
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),

      // NÃO enviamos 'school_id' aqui.
      // O servidor pega o ID da escola automaticamente do Token.
    };
  }

  // Útil para edição de estado no Provider/Bloc
  SchoolYearModel copyWith({
    String? id,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    String? schoolId,
  }) {
    return SchoolYearModel(
      id: id ?? this.id,
      year: year ?? this.year,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  @override
  String toString() {
    return 'SchoolYearModel(year: $year, start: $startDate, end: $endDate, schoolId: $schoolId)';
  }
}
