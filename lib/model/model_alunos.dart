import 'dart:convert';
import 'package:academyhub_mobile/model/academic_record_model.dart';
import 'package:academyhub_mobile/model/address_model.dart';
import 'package:academyhub_mobile/model/tutor_model.dart';

// Funções helper para parse rápido
List<Student> studentFromJson(String str) =>
    List<Student>.from(json.decode(str).map((x) => Student.fromJson(x)));

String studentToJson(Student data) => json.encode(data.toJson());

class Student {
  final String id;
  // Campo de matrícula
  final String? enrollmentNumber;

  // [NOVO] Série Pretendida (Vinda da solicitação)
  final String? intendedGrade;

  final String fullName;
  final List<AcademicRecord> academicHistory;
  final DateTime birthDate;
  final String gender;
  final String? race;
  // profilePictureUrl removido (agora é via endpoint de foto)

  final HealthInfo healthInfo;
  final List<AuthorizedPickup> authorizedPickups;
  final String nationality;
  final String? phoneNumber;
  final String? email;
  final String? rg;
  final String? cpf;
  final Address address;

  // Lista de tutores
  final List<TutorInStudent> tutors;

  // --- NOVOS CAMPOS FINANCEIROS ---
  final String financialResp; // 'STUDENT' ou 'TUTOR'
  final String? financialTutorId;
  // --------------------------------

  final bool isActive;
  final String? classId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String schoolId;

  Student({
    required this.id,
    this.enrollmentNumber,
    this.intendedGrade, // [NOVO]
    required this.fullName,
    required this.academicHistory,
    required this.birthDate,
    required this.gender,
    required this.nationality,
    this.race,
    required this.healthInfo,
    required this.authorizedPickups,
    this.phoneNumber,
    this.email,
    this.rg,
    this.cpf,
    required this.address,
    required this.tutors,
    required this.financialResp,
    this.financialTutorId,
    required this.isActive,
    this.classId,
    required this.createdAt,
    required this.updatedAt,
    required this.schoolId,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json["_id"] ?? "",
      enrollmentNumber: json["enrollmentNumber"],

      // [NOVO] Mapeamento
      intendedGrade: json["intendedGrade"],

      fullName: json["fullName"] ?? "Sem Nome",

      academicHistory: json['academicHistory'] != null
          ? List<AcademicRecord>.from(
              json['academicHistory'].map((x) => AcademicRecord.fromJson(x)))
          : [],

      birthDate: json["birthDate"] != null
          ? DateTime.tryParse(json["birthDate"]) ?? DateTime.now()
          : DateTime.now(),

      gender: json["gender"] ?? "Não informado",
      nationality: json["nationality"] ?? "Brasileira",
      race: json["race"],

      // Garante que HealthInfo nunca seja null
      healthInfo: HealthInfo.fromJson(json["healthInfo"] ?? {}),

      authorizedPickups: json["authorizedPickups"] != null
          ? List<AuthorizedPickup>.from(json["authorizedPickups"]
              .map((x) => AuthorizedPickup.fromJson(x)))
          : [],

      phoneNumber: json["phoneNumber"],
      email: json["email"],
      rg: json["rg"],
      cpf: json["cpf"],

      // Garante que Address nunca seja null
      address: Address.fromJson(json["address"] ?? {}),

      tutors: json["tutors"] != null
          ? List<TutorInStudent>.from(
              json["tutors"].map((x) => TutorInStudent.fromJson(x)))
          : [],

      // --- TRATAMENTO DOS NOVOS CAMPOS ---
      financialResp: json["financialResp"] ?? "TUTOR",

      // O campo pode vir como string ID ou objeto populado. Tratamos os dois casos.
      financialTutorId: json["financialTutorId"] is Map
          ? json["financialTutorId"]["_id"] // Se veio populate
          : json["financialTutorId"], // Se veio só ID string

      isActive: json["isActive"] ?? true,

      // ClassID pode vir populado ou string, pegamos o ID se for objeto
      classId:
          json["classId"] is Map ? json["classId"]["_id"] : json["classId"],

      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"]) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json["updatedAt"] != null
          ? DateTime.tryParse(json["updatedAt"]) ?? DateTime.now()
          : DateTime.now(),

      schoolId: json["school_id"] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "_id": id,
        "enrollmentNumber": enrollmentNumber,
        // [NOVO] Serialização
        "intendedGrade": intendedGrade,
        "fullName": fullName,
        "academicHistory":
            List<dynamic>.from(academicHistory.map((x) => x.toJson())),
        "birthDate": birthDate.toIso8601String(),
        "gender": gender,
        "race": race,
        "healthInfo": healthInfo.toJson(),
        "authorizedPickups":
            List<dynamic>.from(authorizedPickups.map((x) => x.toJson())),
        "nationality": nationality,
        "phoneNumber": phoneNumber,
        "email": email,
        "rg": rg,
        "cpf": cpf,
        "address": address.toJson(),
        "tutors": List<dynamic>.from(tutors.map((x) => x.toJson())),

        // Novos campos no payload de envio
        "financialResp": financialResp,
        "financialTutorId": financialTutorId,

        "isActive": isActive,
        "classId": classId,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": updatedAt.toIso8601String(),
        "school_id": schoolId,
      };

  // Método copyWith atualizado
  Student copyWith({
    String? id,
    String? enrollmentNumber,
    String? intendedGrade, // [NOVO]
    String? fullName,
    List<AcademicRecord>? academicHistory,
    DateTime? birthDate,
    String? gender,
    String? race,
    HealthInfo? healthInfo,
    List<AuthorizedPickup>? authorizedPickups,
    String? nationality,
    String? phoneNumber,
    String? email,
    String? rg,
    String? cpf,
    Address? address,
    List<TutorInStudent>? tutors,
    String? financialResp,
    String? financialTutorId,
    bool? isActive,
    String? classId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? schoolId,
  }) {
    return Student(
      id: id ?? this.id,
      enrollmentNumber: enrollmentNumber ?? this.enrollmentNumber,
      intendedGrade: intendedGrade ?? this.intendedGrade, // [NOVO]
      fullName: fullName ?? this.fullName,
      academicHistory: academicHistory ?? this.academicHistory,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      race: race ?? this.race,
      healthInfo: healthInfo ?? this.healthInfo,
      authorizedPickups: authorizedPickups ?? this.authorizedPickups,
      nationality: nationality ?? this.nationality,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      rg: rg ?? this.rg,
      cpf: cpf ?? this.cpf,
      address: address ?? this.address,
      tutors: tutors ?? this.tutors,
      financialResp: financialResp ?? this.financialResp,
      financialTutorId: financialTutorId ?? this.financialTutorId,
      isActive: isActive ?? this.isActive,
      classId: classId ?? this.classId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schoolId: schoolId ?? this.schoolId,
    );
  }
}

// --- SUB-CLASSES AUXILIARES ---

class AuthorizedPickup {
  final String fullName;
  final String relationship;
  final String phoneNumber;

  AuthorizedPickup({
    required this.fullName,
    required this.relationship,
    required this.phoneNumber,
  });

  factory AuthorizedPickup.fromJson(Map<String, dynamic> json) =>
      AuthorizedPickup(
        fullName: json["fullName"] ?? "",
        relationship: json["relationship"] ?? "",
        phoneNumber: json["phoneNumber"] ?? "",
      );

  Map<String, dynamic> toJson() => {
        "fullName": fullName,
        "relationship": relationship,
        "phoneNumber": phoneNumber,
      };
}

class HealthInfo {
  final bool hasHealthProblem;
  final String healthProblemDetails;
  final bool takesMedication;
  final String medicationDetails;
  final bool hasDisability;
  final String disabilityDetails;
  final bool hasAllergy;
  final String allergyDetails;
  final bool hasMedicationAllergy;
  final String medicationAllergyDetails;
  final bool hasVisionProblem;
  final String visionProblemDetails;
  final String feverMedication;
  final String foodObservations;

  HealthInfo({
    required this.hasHealthProblem,
    required this.healthProblemDetails,
    required this.takesMedication,
    required this.medicationDetails,
    required this.hasDisability,
    required this.disabilityDetails,
    required this.hasAllergy,
    required this.allergyDetails,
    required this.hasMedicationAllergy,
    required this.medicationAllergyDetails,
    required this.hasVisionProblem,
    required this.visionProblemDetails,
    required this.feverMedication,
    required this.foodObservations,
  });

  factory HealthInfo.fromJson(Map<String, dynamic> json) {
    return HealthInfo(
      hasHealthProblem: json["hasHealthProblem"] ?? false,
      healthProblemDetails: json["healthProblemDetails"] ?? "",
      takesMedication: json["takesMedication"] ?? false,
      medicationDetails: json["medicationDetails"] ?? "",
      hasDisability: json["hasDisability"] ?? false,
      disabilityDetails: json["disabilityDetails"] ?? "",
      hasAllergy: json["hasAllergy"] ?? false,
      allergyDetails: json["allergyDetails"] ?? "",
      hasMedicationAllergy: json["hasMedicationAllergy"] ?? false,
      medicationAllergyDetails: json["medicationAllergyDetails"] ?? "",
      hasVisionProblem: json["hasVisionProblem"] ?? false,
      visionProblemDetails: json["visionProblemDetails"] ?? "",
      feverMedication: json["feverMedication"] ?? "",
      foodObservations: json["foodObservations"] ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
        "hasHealthProblem": hasHealthProblem,
        "healthProblemDetails": healthProblemDetails,
        "takesMedication": takesMedication,
        "medicationDetails": medicationDetails,
        "hasDisability": hasDisability,
        "disabilityDetails": disabilityDetails,
        "hasAllergy": hasAllergy,
        "allergyDetails": allergyDetails,
        "hasMedicationAllergy": hasMedicationAllergy,
        "medicationAllergyDetails": medicationAllergyDetails,
        "hasVisionProblem": hasVisionProblem,
        "visionProblemDetails": visionProblemDetails,
        "feverMedication": feverMedication,
        "foodObservations": foodObservations,
      };
}
