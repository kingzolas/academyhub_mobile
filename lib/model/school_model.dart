import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class SchoolModel {
  String id;
  String name;
  String legalName;
  String? cnpj;
  String? stateRegistration;
  String? municipalRegistration;

  // [NOVO] Campo para Portaria/Ato Autorizativo
  String? authorizationProtocol;

  String? contactPhone;
  String? contactEmail;
  AddressModel? address;
  String? logoUrl;
  Uint8List? logoBytes;

  MercadoPagoConfigModel? mercadoPagoConfig;
  CoraConfigModel? coraConfig;
  String? preferredGateway;

  SchoolModel({
    required this.id,
    required this.name,
    required this.legalName,
    this.cnpj,
    this.stateRegistration,
    this.municipalRegistration,
    this.authorizationProtocol, // Novo
    this.contactPhone,
    this.contactEmail,
    this.address,
    this.logoUrl,
    this.logoBytes,
    this.mercadoPagoConfig,
    this.coraConfig,
    this.preferredGateway,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    Uint8List? decodedLogo;

    try {
      if (json['logo'] != null) {
        final logoRaw = json['logo'];
        if (logoRaw is String && logoRaw.isNotEmpty) {
          String cleanBase64 = logoRaw;
          if (logoRaw.contains(',')) {
            cleanBase64 = logoRaw.split(',').last;
          }
          decodedLogo = base64Decode(cleanBase64);
        } else if (logoRaw is Map && logoRaw.containsKey('data')) {
          // Lógica para buffer do mongo
          final dataContent = logoRaw['data'];
          if (dataContent is List) {
            decodedLogo = Uint8List.fromList(List<int>.from(dataContent));
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Erro ao converter logo da escola: $e");
    }

    return SchoolModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      legalName: json['legalName'] ?? '',
      cnpj: json['cnpj'],
      stateRegistration: json['stateRegistration'],
      municipalRegistration: json['municipalRegistration'],
      authorizationProtocol:
          json['authorizationProtocol'], // Mapeamento do novo campo
      contactPhone: json['contactPhone'],
      contactEmail: json['contactEmail'],
      address: json['address'] != null
          ? AddressModel.fromJson(json['address'])
          : null,
      logoUrl: json['logoUrl'],
      logoBytes: decodedLogo,
      mercadoPagoConfig: json['mercadoPagoConfig'] != null
          ? MercadoPagoConfigModel.fromJson(json['mercadoPagoConfig'])
          : null,
      coraConfig: json['coraConfig'] != null
          ? CoraConfigModel.fromJson(json['coraConfig'])
          : null,
      preferredGateway: json['preferredGateway'],
    );
  }
}

// --- MERCADO PAGO ---
class MercadoPagoConfigModel {
  String? prodPublicKey;
  bool isConfigured;
  MercadoPagoConfigModel({this.prodPublicKey, this.isConfigured = false});
  factory MercadoPagoConfigModel.fromJson(Map<String, dynamic> json) {
    return MercadoPagoConfigModel(
      prodPublicKey: json['prodPublicKey'],
      isConfigured: json['isConfigured'] ?? false,
    );
  }
}

// --- CORA ATUALIZADO (Juros e Multa) ---
class CoraConfigModel {
  bool isSandbox;
  bool isConfigured;
  CoraEnvironmentConfig? sandbox;
  CoraEnvironmentConfig? production;

  // Configurações de Cobrança Padrão
  ChargeConfig? defaultInterest; // Juros
  ChargeConfig? defaultFine; // Multa
  double? defaultDiscount; // Desconto

  CoraConfigModel({
    this.isSandbox = false,
    this.isConfigured = false,
    this.sandbox,
    this.production,
    this.defaultInterest,
    this.defaultFine,
    this.defaultDiscount,
  });

  factory CoraConfigModel.fromJson(Map<String, dynamic> json) {
    return CoraConfigModel(
      isSandbox: json['isSandbox'] ?? false,
      isConfigured: json['isConfigured'] ?? false,
      sandbox: json['sandbox'] != null
          ? CoraEnvironmentConfig.fromJson(json['sandbox'])
          : null,
      production: json['production'] != null
          ? CoraEnvironmentConfig.fromJson(json['production'])
          : null,
      defaultInterest: json['defaultInterest'] != null
          ? ChargeConfig.fromJson(json['defaultInterest'])
          : null,
      defaultFine: json['defaultFine'] != null
          ? ChargeConfig.fromJson(json['defaultFine'])
          : null,
      defaultDiscount: json['defaultDiscount'] != null
          ? (json['defaultDiscount'] as num).toDouble()
          : null,
    );
  }
}

// Classe auxiliar para Juros e Multa (amount ou percentage)
class ChargeConfig {
  double? amount;
  double? percentage;

  ChargeConfig({this.amount, this.percentage});

  factory ChargeConfig.fromJson(Map<String, dynamic> json) {
    return ChargeConfig(
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : 0.0,
      percentage: json['percentage'] != null
          ? (json['percentage'] as num).toDouble()
          : 0.0,
    );
  }
}

class CoraEnvironmentConfig {
  String? clientId;
  CoraEnvironmentConfig({this.clientId});
  factory CoraEnvironmentConfig.fromJson(Map<String, dynamic> json) {
    return CoraEnvironmentConfig(clientId: json['clientId']);
  }
}

class AddressModel {
  String street;
  String number;
  String district;
  String city;
  String state;
  String zipCode;

  AddressModel({
    this.street = '',
    this.number = '',
    this.district = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      street: json['street'] ?? '',
      number: json['number'] ?? '',
      district: json['neighborhood'] ?? json['district'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zipCode'] ?? json['cep'] ?? '',
    );
  }
}
