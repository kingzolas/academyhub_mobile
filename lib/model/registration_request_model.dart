import 'package:academyhub_mobile/model/address_model.dart'; // Certifique-se de ter esse model
import 'package:academyhub_mobile/model/model_alunos.dart'; // Para reutilizar HealthInfo e AuthorizedPickup

class RegistrationRequest {
  final String id;
  final String registrationType; // 'ADULT_STUDENT' ou 'MINOR_STUDENT'
  final String status;
  final DateTime createdAt;

  // Dados complexos agora tipados ou Map detalhado
  final Map<String, dynamic> studentData;
  final Map<String, dynamic>? tutorData;

  RegistrationRequest({
    required this.id,
    required this.registrationType,
    required this.status,
    required this.createdAt,
    required this.studentData,
    this.tutorData,
  });

  factory RegistrationRequest.fromJson(Map<String, dynamic> json) {
    return RegistrationRequest(
      id: json['_id'] ?? '',
      registrationType: json['registrationType'] ?? 'MINOR_STUDENT',
      status: json['status'] ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      studentData: json['studentData'] ?? {},
      tutorData: json['tutorData'], // Pode ser null
    );
  }
}
