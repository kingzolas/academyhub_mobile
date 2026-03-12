import 'dart:convert';
import 'package:academyhub_mobile/model/address_model.dart';

// Helper
String tutorToJson(Tutor data) => json.encode(data.toJson());

class Tutor {
  final String id;
  final String fullName;
  final DateTime birthDate;
  final String gender;
  final String nationality;
  final String phoneNumber;
  final String? rg;
  final String? cpf;
  final String? email;
  final Address address;
  final String schoolId;

  // [NOVO] Profissão
  final String? profession;

  Tutor({
    required this.id,
    required this.fullName,
    required this.birthDate,
    required this.gender,
    required this.nationality,
    required this.phoneNumber,
    this.rg,
    this.cpf,
    this.email,
    required this.address,
    required this.schoolId,
    this.profession, // Opcional no construtor
  });

  factory Tutor.fromJson(Map<String, dynamic> json) {
    return Tutor(
      id: json["_id"] ?? "",
      fullName: json["fullName"] ?? "",
      birthDate: json["birthDate"] != null
          ? DateTime.parse(json["birthDate"])
          : DateTime.now(),
      gender: json["gender"] ?? "",
      nationality: json["nationality"] ?? "",
      phoneNumber: json["phoneNumber"] ?? "",
      rg: json["rg"],
      cpf: json["cpf"],
      email: json["email"],
      address: Address.fromJson(json["address"] ?? {}),
      schoolId: json["school_id"] ?? "",

      // [NOVO] Mapeamento do JSON
      profession: json["profession"],
    );
  }

  Map<String, dynamic> toJson() => {
        "_id": id,
        "fullName": fullName,
        "birthDate": birthDate.toIso8601String(),
        "gender": gender,
        "nationality": nationality,
        "phoneNumber": phoneNumber,
        "rg": rg,
        "cpf": cpf,
        "email": email,
        "address": address.toJson(),
        "school_id": schoolId,

        // [NOVO] Envio para JSON
        "profession": profession,
      };
}

// Classe 2: Representa a "relação" dentro do array do Aluno (Inalterada, mas herda o Tutor atualizado)
class TutorInStudent {
  final Tutor tutorInfo;
  final String relationship;

  TutorInStudent({
    required this.tutorInfo,
    required this.relationship,
  });

  factory TutorInStudent.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('tutorId') && json['tutorId'] is Map) {
      return TutorInStudent(
        tutorInfo: Tutor.fromJson(json['tutorId']),
        relationship: json['relationship'] ?? 'Responsável',
      );
    }
    return TutorInStudent(
      tutorInfo: Tutor.fromJson(json),
      relationship: json['relationship'] ?? 'Responsável',
    );
  }

  Map<String, dynamic> toJson() => {
        "relationship": relationship,
        ...tutorInfo.toJson(),
      };
}
