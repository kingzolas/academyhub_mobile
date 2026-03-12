class InvoiceCompensationModel {
  final String id;
  final String reason;
  final String? notes;
  final DateTime createdAt;

  final TargetInvoiceMini? targetInvoice;
  final SourceInvoiceMini? sourceInvoice;

  InvoiceCompensationModel({
    required this.id,
    required this.reason,
    this.notes,
    required this.createdAt,
    this.targetInvoice,
    this.sourceInvoice,
  });

  factory InvoiceCompensationModel.fromJson(Map<String, dynamic> json) {
    return InvoiceCompensationModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      reason: (json['reason'] ?? '').toString(),
      notes: json['notes']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      targetInvoice: json['target_invoice'] != null
          ? TargetInvoiceMini.fromJson(json['target_invoice'])
          : null,
      sourceInvoice: json['source_invoice'] != null
          ? SourceInvoiceMini.fromJson(json['source_invoice'])
          : null,
    );
  }
}

class TargetInvoiceMini {
  final String id;
  final String description;
  final int value; // centavos
  final DateTime? dueDate;
  final String? status;

  TargetInvoiceMini({
    required this.id,
    required this.description,
    required this.value,
    this.dueDate,
    this.status,
  });

  factory TargetInvoiceMini.fromJson(Map<String, dynamic> json) {
    return TargetInvoiceMini(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      description: (json['description'] ?? '').toString(),
      value: (json['value'] ?? 0) is int
          ? json['value']
          : int.tryParse(json['value'].toString()) ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString())
          : null,
      status: json['status']?.toString(),
    );
  }
}

class SourceInvoiceMini {
  final String id;
  final String description;
  final int value; // centavos
  final DateTime? dueDate;
  final DateTime? paidAt;

  SourceInvoiceMini({
    required this.id,
    required this.description,
    required this.value,
    this.dueDate,
    this.paidAt,
  });

  factory SourceInvoiceMini.fromJson(Map<String, dynamic> json) {
    return SourceInvoiceMini(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      description: (json['description'] ?? '').toString(),
      value: (json['value'] ?? 0) is int
          ? json['value']
          : int.tryParse(json['value'].toString()) ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString())
          : null,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
    );
  }
}
