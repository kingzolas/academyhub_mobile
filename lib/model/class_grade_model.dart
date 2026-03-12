class ClassGradeModel {
  final String? id;
  final String? evaluationId; // Link com a Avaliação (Prova, Trabalho)
  final String studentId; // Link com o Aluno
  final String enrollmentId; // Link com a Matrícula (Obrigatório)
  double value; // O valor numérico (double) para cálculo de média
  String? feedback;

  ClassGradeModel({
    this.id,
    this.evaluationId,
    required this.studentId,
    required this.enrollmentId,
    required this.value,
    this.feedback,
  });

  // Factory inteligente para lidar com o JSON do Backend
  factory ClassGradeModel.fromJson(Map<String, dynamic> json) {
    // Extração segura de IDs caso venham populados (Objetos) ou puros (Strings)
    String extractId(dynamic data) {
      if (data == null) return '';
      if (data is Map) return data['_id'] ?? '';
      return data.toString();
    }

    return ClassGradeModel(
      id: json['_id'],
      evaluationId: extractId(json['evaluation']),
      studentId: extractId(json['student']),
      enrollmentId: extractId(json['enrollment']),
      // Garante conversão segura de int/string para double
      value: (json['value'] is num)
          ? (json['value'] as num).toDouble()
          : double.tryParse(json['value'].toString()) ?? 0.0,
      feedback: json['feedback'],
    );
  }

  // JSON simplificado para envio em Lote (Bulk) para a rota nova
  Map<String, dynamic> toBulkJson() {
    return {
      'studentId': studentId,
      'enrollmentId': enrollmentId,
      'value': value,
      'feedback': feedback,
    };
  }
}
