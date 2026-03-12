// lib/model/subject_model.dart
class SubjectModel {
  final String id;
  final String name;
  final String level;
  final String? schoolId; // [NOVO] Campo opcional para mapear o retorno do back

  SubjectModel({
    required this.id,
    required this.name,
    required this.level,
    this.schoolId,
  });

  /// ✅ Novo: cria um Subject apenas com ID (fallback quando backend manda só string)
  factory SubjectModel.fromId(String id) {
    return SubjectModel(
      id: id,
      name: 'Matéria (ID)',
      level: 'Geral',
      schoolId: null,
    );
  }

  /// ✅ Novo: aceita tanto Map (populate) quanto String (id cru)
  factory SubjectModel.fromAny(dynamic value) {
    if (value is Map<String, dynamic>) return SubjectModel.fromJson(value);
    if (value is String) return SubjectModel.fromId(value);
    return SubjectModel(
      id: '',
      name: 'Matéria Inválida',
      level: 'Geral',
      schoolId: null,
    );
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Matéria Inválida').toString(),
      level: (json['level'] ?? 'Geral').toString(),
      // Mapeia o school_id se ele vier populado (objeto) ou string direta
      schoolId: json['school_id'] is Map
          ? (json['school_id']['_id'] ?? '').toString()
          : (json['school_id']?.toString()),
    );
  }

  // Usado para ENVIAR dados para a API (Criar/Atualizar)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
      // NÃO enviamos 'school_id' aqui.
    };
  }

  SubjectModel copyWith({
    String? id,
    String? name,
    String? level,
    String? schoolId,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  // --- CORREÇÃO CRÍTICA PARA O DROPDOWN ---
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
