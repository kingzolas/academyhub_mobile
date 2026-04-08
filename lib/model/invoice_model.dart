import 'dart:convert';

List<Invoice> invoiceFromJson(String str) =>
    List<Invoice>.from(json.decode(str).map((x) => Invoice.fromJson(x)));

String invoiceToJson(List<Invoice> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

enum CollectionStatus { collectable, compensationHold }

CollectionStatus _parseCollectionStatus(dynamic v) {
  final s = (v ?? 'collectable').toString();
  if (s == 'compensation_hold') return CollectionStatus.compensationHold;
  return CollectionStatus.collectable;
}

String _collectionStatusToJson(CollectionStatus v) {
  switch (v) {
    case CollectionStatus.compensationHold:
      return 'compensation_hold';
    case CollectionStatus.collectable:
      return 'collectable';
  }
}

/// ✅ Modelo mínimo da compensação (para o gestor entender e o app renderizar)
class InvoiceCompensation {
  final String id;
  final String reason;
  final String? notes;
  final DateTime createdAt;

  /// Invoice paga por engano (ex: Julho) que compensou a target (ex: Fevereiro)
  final SourceInvoiceMini? sourceInvoice;

  InvoiceCompensation({
    required this.id,
    required this.reason,
    this.notes,
    required this.createdAt,
    this.sourceInvoice,
  });

  factory InvoiceCompensation.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return InvoiceCompensation(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      sourceInvoice: json['source_invoice'] != null &&
              json['source_invoice'] is Map<String, dynamic>
          ? SourceInvoiceMini.fromJson(
              json['source_invoice'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reason': reason,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'source_invoice': sourceInvoice?.toJson(),
    };
  }
}

class SourceInvoiceMini {
  final String id;
  final String description;
  final int value; // centavos
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? status;

  SourceInvoiceMini({
    required this.id,
    required this.description,
    required this.value,
    this.dueDate,
    this.paidAt,
    this.status,
  });

  factory SourceInvoiceMini.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return SourceInvoiceMini(
      id: (json['_id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      value: (json['value'] is int)
          ? (json['value'] as int)
          : (json['value'] as num?)?.toInt() ?? 0,
      dueDate: parseDate(json['dueDate']),
      paidAt: parseDate(json['paidAt']),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'description': description,
      'value': value,
      'dueDate': dueDate?.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'status': status,
    };
  }
}

class Invoice {
  final String id;
  final InvoiceStudent? student;
  final InvoiceTutor? tutor;
  final String? schoolYear;
  final String? schoolId;
  final String description;
  final int value; // EM CENTAVOS
  final DateTime dueDate;
  final String status;

  /// Data que o backend marca como pago (pode vir null em alguns fluxos)
  final DateTime? paidAt;

  // --- CAMPOS DE PAGAMENTO GENÉRICOS ---
  final String? paymentMethod; // 'pix', 'boleto', etc.
  final String? gateway; // 'mercadopago', 'cora'
  final String? externalId; // ID da transação no banco

  // Dados para Boleto (Cora ou MP Boleto)
  final String? boletoUrl; // URL do PDF
  final String? boletoBarcode; // Linha digitável
  final String? boletoDigitableLine; // Linha digitável oficial (47 dígitos)

  // Dados para Pix (Cora ou MP Pix)
  final String? pixCode; // Copia e Cola
  final String? pixQrBase64; // Imagem Base64

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // =========================
  // [NOVO] Controle de cobrança
  // =========================
  final CollectionStatus collectionStatus;
  final InvoiceCompensation? compensation;

  Invoice({
    required this.id,
    this.student,
    this.tutor,
    this.schoolYear,
    this.schoolId,
    required this.description,
    required this.value,
    required this.dueDate,
    required this.status,
    this.paidAt,
    this.paymentMethod,
    this.gateway,
    this.externalId,
    this.boletoUrl,
    this.boletoBarcode,
    this.boletoDigitableLine,
    this.pixCode,
    this.pixQrBase64,
    this.createdAt,
    this.updatedAt,
    required this.collectionStatus,
    this.compensation,
  });

  bool get isCompensationHold =>
      collectionStatus == CollectionStatus.compensationHold;

  /// ✅ Resolve o problema: "status == paid" mas sem paidAt vindo do backend.
  /// Estratégia:
  /// - 1) paidAt (se existir)
  /// - 2) updatedAt (normalmente é quando o status virou "paid")
  /// - 3) createdAt (último fallback)
  DateTime? get effectivePaidAt {
    if (status != 'paid') return null;
    return paidAt ?? updatedAt ?? createdAt;
  }

  Invoice copyWith({
    String? id,
    InvoiceStudent? student,
    InvoiceTutor? tutor,
    String? schoolYear,
    String? schoolId,
    String? description,
    int? value,
    DateTime? dueDate,
    String? status,
    DateTime? paidAt,
    String? paymentMethod,
    String? gateway,
    String? externalId,
    String? boletoUrl,
    String? boletoBarcode,
    String? boletoDigitableLine,
    String? pixCode,
    String? pixQrBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
    CollectionStatus? collectionStatus,
    InvoiceCompensation? compensation,
  }) {
    return Invoice(
      id: id ?? this.id,
      student: student ?? this.student,
      tutor: tutor ?? this.tutor,
      schoolYear: schoolYear ?? this.schoolYear,
      schoolId: schoolId ?? this.schoolId,
      description: description ?? this.description,
      value: value ?? this.value,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      gateway: gateway ?? this.gateway,
      externalId: externalId ?? this.externalId,
      boletoUrl: boletoUrl ?? this.boletoUrl,
      boletoBarcode: boletoBarcode ?? this.boletoBarcode,
      boletoDigitableLine: boletoDigitableLine ?? this.boletoDigitableLine,
      pixCode: pixCode ?? this.pixCode,
      pixQrBase64: pixQrBase64 ?? this.pixQrBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,

      // NOVO
      collectionStatus: collectionStatus ?? this.collectionStatus,
      compensation: compensation ?? this.compensation,
    );
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    String? extractId(dynamic data) {
      if (data == null) return null;
      if (data is Map) return data['_id']?.toString();
      return data.toString();
    }

    InvoiceStudent? parseStudent(dynamic data) {
      if (data == null) return null;
      if (data is Map<String, dynamic>) return InvoiceStudent.fromJson(data);
      if (data is String) {
        return InvoiceStudent(id: data, fullName: 'Carregando...');
      }
      return null;
    }

    InvoiceTutor? parseTutor(dynamic data) {
      if (data == null) return null;
      if (data is Map<String, dynamic>) return InvoiceTutor.fromJson(data);
      if (data is String) {
        return InvoiceTutor(id: data, fullName: 'Carregando...');
      }
      return null;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    // ✅ paidAt pode vir com nomes diferentes dependendo do gateway / versão do backend
    final paidAtParsed = parseDate(json['paidAt']) ??
        parseDate(json['paid_at']) ??
        parseDate(json['paymentDate']) ??
        parseDate(json['payment_date']) ??
        parseDate(json['paid_date']);

    final createdAtParsed =
        parseDate(json['createdAt']) ?? parseDate(json['created_at']);
    final updatedAtParsed =
        parseDate(json['updatedAt']) ?? parseDate(json['updated_at']);

    // [NOVO]
    final cs = _parseCollectionStatus(json['collection_status']);
    final comp = (json['compensation'] != null &&
            json['compensation'] is Map<String, dynamic>)
        ? InvoiceCompensation.fromJson(
            json['compensation'] as Map<String, dynamic>)
        : null;

    return Invoice(
      id: (json['_id'] ?? '').toString(),
      student: parseStudent(json['student']),
      tutor: parseTutor(json['tutor']),
      schoolYear: extractId(json['schoolYear']),
      schoolId: extractId(json['school_id']),
      description: (json['description'] ?? '').toString(),
      value: (json['value'] is int)
          ? (json['value'] as int)
          : (json['value'] as num?)?.toInt() ?? 0,
      dueDate: DateTime.tryParse((json['dueDate'] ?? '').toString()) ??
          DateTime.now(),
      status: (json['status'] ?? 'pending').toString(),
      paidAt: paidAtParsed,

      // --- MAPEAMENTO INTELIGENTE (Backend Novo) ---
      paymentMethod: json['paymentMethod'] ?? json['payment_method'],
      gateway: json['gateway']?.toString(),
      externalId:
          (json['external_id'] ?? json['externalId'] ?? json['mp_payment_id'])
              ?.toString(),

      boletoUrl: (json['boleto_url'] ?? json['mp_ticket_url'])?.toString(),
      boletoBarcode: json['boleto_barcode']?.toString(),
      boletoDigitableLine: json['boleto_digitable_line']?.toString(),
      pixCode: (json['pix_code'] ?? json['mp_pix_copia_e_cola'])?.toString(),
      pixQrBase64:
          (json['pix_qr_base64'] ?? json['mp_pix_qr_base64'])?.toString(),

      createdAt: createdAtParsed,
      updatedAt: updatedAtParsed,

      // NOVO
      collectionStatus: cs,
      compensation: comp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'student': student?.id,
      'tutor': tutor?.id,
      'school_id': schoolId,
      'description': description,
      'value': value,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'paidAt': paidAt?.toIso8601String(),
      'paymentMethod': paymentMethod,
      'gateway': gateway,
      'external_id': externalId,
      'boleto_url': boletoUrl,
      'boleto_barcode': boletoBarcode,
      'boleto_digitable_line': boletoDigitableLine,
      'pix_code': pixCode,
      'pix_qr_base64': pixQrBase64,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),

      // NOVO (se precisar enviar pra algum lugar)
      'collection_status': _collectionStatusToJson(collectionStatus),
      'compensation': compensation?.toJson(),
    };
  }
}

class InvoiceStudent {
  final String id;
  final String fullName;
  InvoiceStudent({required this.id, required this.fullName});
  factory InvoiceStudent.fromJson(Map<String, dynamic> json) => InvoiceStudent(
        id: (json['_id'] ?? '').toString(),
        fullName: (json['fullName'] ?? 'Aluno').toString(),
      );
}

class InvoiceTutor {
  final String id;
  final String fullName;
  InvoiceTutor({required this.id, required this.fullName});
  factory InvoiceTutor.fromJson(Map<String, dynamic> json) => InvoiceTutor(
        id: (json['_id'] ?? '').toString(),
        fullName: (json['fullName'] ?? 'Responsável').toString(),
      );
}
