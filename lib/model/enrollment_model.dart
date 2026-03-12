import 'package:academyhub_mobile/model/class_model.dart';
// ATENÇÃO: Verifique se este import aponta para o arquivo onde está a classe Student COMPLETA (com cpf, tutors, etc)
// Se o nome do arquivo for diferente de 'model_alunos.dart', ajuste aqui.
import 'package:academyhub_mobile/model/model_alunos.dart';

// Helper para extrair ID de campo possivelmente populado
String? safeExtractId(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data['_id']?.toString();
  }
  return data?.toString();
}

class Enrollment {
  final String id;
  // Agora usamos 'Student' (completo) e não 'StudentReference'
  final Student student;
  final ClassReference classInfo;
  final int academicYear;
  final DateTime enrollmentDate;
  final double agreedFee;
  final String status;
  final String? schoolId;

  Enrollment({
    required this.id,
    required this.student,
    required this.classInfo,
    required this.academicYear,
    required this.enrollmentDate,
    required this.agreedFee,
    required this.status,
    this.schoolId,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    return Enrollment(
      id: json['_id'] ?? '',

      // Mapeamos o JSON completo para a classe Student completa
      // Certifique-se que o backend envia o objeto 'student' populado (populate: true)
      student: Student.fromJson(json['student'] ?? {}),

      classInfo: ClassReference.fromJson(json['class'] ?? {}),
      schoolId: safeExtractId(json['school_id']),
      academicYear: (json['academicYear'] as num?)?.toInt() ?? 0,
      enrollmentDate:
          DateTime.tryParse(json['enrollmentDate'] ?? '') ?? DateTime.now(),
      agreedFee: (json['agreedFee'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Ativa',
    );
  }

  Map<String, dynamic> toJsonForCreate() {
    return {
      'studentId': student.id,
      'classId': classInfo.id,
      'agreedFee': agreedFee,
    };
  }

  // --- MÉTODO COPYWITH ADICIONADO ---
  // Essencial para permitir a atualização de campos específicos (como 'student')
  // mantendo os outros dados inalterados.
  Enrollment copyWith({
    String? id,
    Student? student,
    ClassReference? classInfo,
    int? academicYear,
    DateTime? enrollmentDate,
    double? agreedFee,
    String? status,
    String? schoolId,
  }) {
    return Enrollment(
      id: id ?? this.id,
      student: student ?? this.student,
      classInfo: classInfo ?? this.classInfo,
      academicYear: academicYear ?? this.academicYear,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      agreedFee: agreedFee ?? this.agreedFee,
      status: status ?? this.status,
      schoolId: schoolId ?? this.schoolId,
    );
  }
}
