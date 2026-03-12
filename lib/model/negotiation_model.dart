import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart'; // Certifique-se que é o caminho certo

class NegotiationRules {
  final bool allowPixDiscount;
  final double pixDiscountValue;
  final String pixDiscountType;
  final bool allowInstallments;
  final int maxInstallments;
  final String interestPayer;

  NegotiationRules({
    this.allowPixDiscount = false,
    this.pixDiscountValue = 0,
    this.pixDiscountType = 'percentage',
    this.allowInstallments = true,
    this.maxInstallments = 12,
    this.interestPayer = 'student',
  });

  Map<String, dynamic> toJson() {
    return {
      'allowPixDiscount': allowPixDiscount,
      'pixDiscountValue': pixDiscountValue,
      'pixDiscountType': pixDiscountType,
      'allowInstallments': allowInstallments,
      'maxInstallments': maxInstallments,
      'interestPayer': interestPayer,
    };
  }

  factory NegotiationRules.fromJson(Map<String, dynamic> json) {
    return NegotiationRules(
      allowPixDiscount: json['allowPixDiscount'] ?? false,
      pixDiscountValue: (json['pixDiscountValue'] as num?)?.toDouble() ?? 0.0,
      pixDiscountType: json['pixDiscountType'] ?? 'percentage',
      allowInstallments: json['allowInstallments'] ?? true,
      maxInstallments: json['maxInstallments'] ?? 1,
      interestPayer: json['interestPayer'] ?? 'student',
    );
  }
}

class Negotiation {
  final String id;
  final String status;
  final String token;
  final DateTime? expiresAt;
  final DateTime? createdAt; // Adicionado para exibir a data correta
  final double totalOriginalDebt;
  final List<Invoice> invoices;
  final Student? student;
  final NegotiationRules rules;
  final String schoolId; // [NOVO] Adicionado conforme solicitado

  Negotiation({
    required this.id,
    required this.status,
    required this.token,
    required this.expiresAt,
    this.createdAt,
    required this.totalOriginalDebt,
    required this.invoices,
    required this.student,
    required this.rules,
    required this.schoolId,
  });

  factory Negotiation.fromJson(Map<String, dynamic> json) {
    // --- Proteção para Aluno ---
    Student? parsedStudent;
    try {
      if (json['studentId'] != null && json['studentId'] is Map) {
        parsedStudent = Student.fromJson(json['studentId']);
      } else if (json['student'] != null && json['student'] is Map) {
        parsedStudent = Student.fromJson(json['student']);
      }
    } catch (e) {
      print("⚠️ Erro ao converter Student na Negociação: $e");
      // Não quebra a app, apenas deixa o aluno nulo
      parsedStudent = null;
    }

    // --- Proteção para Faturas ---
    List<Invoice> parsedInvoices = [];
    if (json['invoices'] != null && json['invoices'] is List) {
      for (var i in json['invoices']) {
        try {
          parsedInvoices.add(Invoice.fromJson(i));
        } catch (e) {
          print("⚠️ Erro ao converter uma Invoice na Negociação: $e");
        }
      }
    }

    return Negotiation(
      id: json['_id'] ?? '',
      status: json['status'] ?? 'PENDING',
      token: json['token'] ?? '',
      schoolId: json['school_id'] ?? '', // Mapeando o campo do banco

      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,

      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,

      totalOriginalDebt: (json['totalOriginalDebt'] as num?)?.toDouble() ?? 0.0,

      invoices: parsedInvoices,
      student: parsedStudent,

      rules: json['rules'] != null
          ? NegotiationRules.fromJson(json['rules'])
          : NegotiationRules(),
    );
  }
}
