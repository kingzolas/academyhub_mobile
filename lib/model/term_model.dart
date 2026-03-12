// lib/model/term_model.dart
import 'package:flutter/foundation.dart';

class TermModel {
  final String id;
  final String schoolYearId; // No Backend é 'anoLetivoId'
  final String titulo;
  final DateTime startDate; // No Backend é 'dataInicio'
  final DateTime endDate; // No Backend é 'dataFim'
  final String tipo; // 'Letivo' ou 'NaoLetivo'
  final String? schoolId; // Opcional, apenas para leitura

  TermModel({
    required this.id,
    required this.schoolYearId,
    required this.titulo,
    required this.startDate,
    required this.endDate,
    required this.tipo,
    this.schoolId,
  });

  factory TermModel.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      // print('[TermModel.fromJson] Processando: $json'); // Comentado para limpar log se quiser
    }

    return TermModel(
      id: json['_id'] ?? '',

      // [SEGURANÇA] Verifica se 'anoLetivoId' veio como Objeto (populado) ou String
      schoolYearId: json['anoLetivoId'] is Map
          ? json['anoLetivoId']['_id']
          : json['anoLetivoId'] ?? '',

      titulo: json['titulo'] ?? '',

      // [SEGURANÇA] Parse seguro de datas (usa data atual se falhar)
      startDate: DateTime.tryParse(json['dataInicio'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['dataFim'] ?? '') ?? DateTime.now(),

      tipo: json['tipo'] ?? 'Letivo',

      // [SEGURANÇA] Verifica se 'school_id' veio como Objeto ou String
      schoolId: json['school_id'] is Map
          ? json['school_id']['_id']
          : json['school_id'],
    );
  }

  // Usado para ENVIAR dados para a API
  // AQUI FAZEMOS A TRADUÇÃO DE VOLTA PARA O PORTUGUÊS (Backend)
  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'tipo': tipo,
      'dataInicio': startDate.toIso8601String(), // Backend espera ISO8601
      'dataFim': endDate.toIso8601String(), // Backend espera ISO8601
      'anoLetivoId': schoolYearId, // Nome exato do campo no Schema

      // NÃO enviamos 'school_id'. O token cuida disso.
    };
  }

  TermModel copyWith({
    String? id,
    String? schoolYearId,
    String? titulo,
    DateTime? startDate,
    DateTime? endDate,
    String? tipo,
    String? schoolId,
  }) {
    return TermModel(
      id: id ?? this.id,
      schoolYearId: schoolYearId ?? this.schoolYearId,
      titulo: titulo ?? this.titulo,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      tipo: tipo ?? this.tipo,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  @override
  String toString() {
    return 'TermModel(titulo: $titulo, start: $startDate, end: $endDate, tipo: $tipo)';
  }

  // ====================================================================
  // [CORREÇÃO CRÍTICA PARA O DROPDOWN]
  // Permite que o Flutter saiba que dois objetos com o mesmo ID são iguais
  // ====================================================================
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TermModel && other.id == id; // Compara pelo ID único
  }

  @override
  int get hashCode => id.hashCode;
}
