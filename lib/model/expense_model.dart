class Expense {
  String? id;
  String? schoolId;
  String description;
  double amount;
  DateTime date;
  String category;
  String status; // 'pending', 'paid', 'late'
  String paymentMethod;
  String? relatedStaff; // <--- NOVO CAMPO (ID do funcionário)
  bool isRecurring;
  String? attachmentUrl;
  DateTime? createdAt;

  Expense({
    this.id,
    this.schoolId,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.status = 'pending',
    this.paymentMethod = 'Outros',
    this.relatedStaff,
    this.isRecurring = false,
    this.attachmentUrl,
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['_id'],
      schoolId: json['schoolId'],
      description: json['description'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      category: json['category'] ?? 'Outros',
      status: json['status'] ?? 'pending',
      paymentMethod: json['paymentMethod'] ?? 'Outros',
      relatedStaff: json['relatedStaff'], // <--- Mapeamento
      isRecurring: json['isRecurring'] ?? false,
      attachmentUrl: json['attachmentUrl'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'status': status,
      'paymentMethod': paymentMethod,
      if (relatedStaff != null) 'relatedStaff': relatedStaff, // <--- Envio
      'isRecurring': isRecurring,
      'attachmentUrl': attachmentUrl,
    };
  }
}
