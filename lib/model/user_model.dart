import 'dart:convert';
import 'package:academyhub_mobile/model/address_model.dart';
import 'package:academyhub_mobile/model/staff_profile_model.dart';

List<User> userFromJson(String str) =>
    List<User>.from(json.decode(str).map((x) => User.fromJson(x)));

String userToJson(User data) => json.encode(data.toJson());

class User {
  final String id;
  final String fullName;
  final String email;
  final String username;
  final List<String> roles;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String schoolId;

  final String? profilePictureUrl;
  final String? cpf;
  final DateTime? birthDate;
  final String? gender;
  final String? phoneNumber;
  final String? phoneFixed;
  final Address? address;
  final List<StaffProfile> staffProfiles;
  final List<String> fcmToken;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.roles,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.schoolId,
    this.profilePictureUrl,
    this.cpf,
    this.birthDate,
    this.gender,
    this.phoneNumber,
    this.phoneFixed,
    this.address,
    required this.staffProfiles,
    this.fcmToken = const [],
  });

  // --- [SOLUÇÃO BLINDADA] Função auxiliar para tratar campos que vêm como String ---
  static Map<String, dynamic> _parseMap(dynamic data) {
    if (data == null) return {};

    // Se já for um Map (o cenário ideal), retorna direto
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    // Se for String (o cenário do erro), faz o decode
    if (data is String) {
      try {
        if (data.isEmpty || data == "null") return {};
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        print("⚠️ Erro ao converter JSON String no User Model: $data");
        return {};
      }
    }

    return {};
  }
  // -------------------------------------------------------------------------------

  factory User.fromJson(Map<String, dynamic> json) {
    List<String> rolesList = [];
    if (json['roles'] != null && json['roles'] is List) {
      rolesList = List<String>.from(json['roles']);
    } else if (json['role'] != null) {
      rolesList = [json['role'] as String];
    }

    String statusString = 'Inativo';
    if (json['status'] != null) {
      statusString = json['status'];
    } else if (json['isActive'] == true) {
      statusString = 'Ativo';
    }

    // Tratamento seguro para Address (JÁ ESTAVA OK)
    Address? addressObj;
    if (json["address"] != null) {
      Map<String, dynamic> addressMap = _parseMap(json["address"]);
      if (addressMap.isNotEmpty) {
        addressObj = Address.fromJson(addressMap);
      }
    }

    return User(
      id: json["_id"] ?? "",
      fullName: json["fullName"] ?? "",
      email: json["email"] ?? "",
      username: json["username"] ?? "",
      roles: rolesList,
      status: statusString,
      createdAt: json["createdAt"] != null
          ? DateTime.parse(json["createdAt"])
          : DateTime.now(),
      updatedAt: json["updatedAt"] != null
          ? DateTime.parse(json["updatedAt"])
          : DateTime.now(),
      schoolId: json["school_id"] ?? "",
      profilePictureUrl: json["profilePictureUrl"],
      cpf: json["cpf"],
      birthDate:
          json["birthDate"] != null ? DateTime.parse(json["birthDate"]) : null,
      gender: json["gender"],
      phoneNumber: json["phoneNumber"],
      phoneFixed: json["phoneFixed"],

      address: addressObj,

      // ==========================================================
      // CORREÇÃO AQUI: BLINDAGEM DO STAFF PROFILES
      // ==========================================================
      staffProfiles: (json['staffProfiles'] as List<dynamic>?)
              ?.where((element) =>
                  element is Map) // 1. Filtra: Só aceita se for MAP (Objeto)
              .map((profileJson) => StaffProfile.fromJson(
                  profileJson as Map<String, dynamic>)) // 2. Converte
              .toList() ??
          [], // 3. Se vier null ou lista de Strings, retorna lista vazia []
      // ==========================================================

      fcmToken:
          json["fcmToken"] != null ? List<String>.from(json["fcmToken"]) : [],
    );
  }

  Map<String, dynamic> toJson() => {
        "_id": id,
        "fullName": fullName,
        "email": email,
        "username": username,
        "roles": List<dynamic>.from(roles.map((x) => x)),
        "status": status,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": updatedAt.toIso8601String(),
        "school_id": schoolId,
        "profilePictureUrl": profilePictureUrl,
        "cpf": cpf,
        "birthDate": birthDate?.toIso8601String(),
        "gender": gender,
        "phoneNumber": phoneNumber,
        "phoneFixed": phoneFixed,
        "address": address?.toJson(),
        "staffProfiles": List<dynamic>.from(staffProfiles.map((x) => x.id)),
        "fcmToken": List<dynamic>.from(fcmToken.map((x) => x)),
      };
}
