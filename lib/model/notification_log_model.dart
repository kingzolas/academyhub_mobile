class NotificationLog {
  final String id;
  final String schoolId;
  final String invoiceId; // Pode vir populado ou ID
  final String studentName;
  final String tutorName;
  final String targetPhone;
  final String type; // 'new_invoice', 'reminder', 'overdue'
  final String status; // 'queued', 'processing', 'sent', 'failed'
  final DateTime createdAt;
  final DateTime? sentAt;
  final String? errorMessage;

  // ✅ NOVOS: para exibir mensagem enviada / detalhes do template / erro amigável com granularidade
  final String? messagePreview; // prévia (curta)
  final String? messageText; // texto completo enviado
  final String? templateGroup; // FUTURO/HOJE/ATRASO (ou similar)
  final int? templateIndex; // índice do template sorteado

  // ✅ NOVOS: detalhes técnicos opcionais (não mostrar pro usuário final, mas útil pra suporte)
  final String? errorCode; // ex.: "NUMBER_INVALID", "WHATSAPP_DISCONNECTED"
  final int? errorHttpStatus; // ex.: 400, 404

  NotificationLog({
    required this.id,
    required this.schoolId,
    required this.invoiceId,
    required this.studentName,
    required this.tutorName,
    required this.targetPhone,
    required this.type,
    required this.status,
    required this.createdAt,
    this.sentAt,
    this.errorMessage,
    this.messagePreview,
    this.messageText,
    this.templateGroup,
    this.templateIndex,
    this.errorCode,
    this.errorHttpStatus,
  });

  factory NotificationLog.fromJson(Map<String, dynamic> json) {
    return NotificationLog(
      id: json['_id'] ?? '',
      schoolId: json['school_id'] ?? '',

      // Se invoice_id vier populado (objeto), pega o _id, senão pega a string direta
      invoiceId: json['invoice_id'] is Map
          ? (json['invoice_id']['_id'] ?? '')
          : (json['invoice_id'] ?? ''),

      studentName: json['student_name'] ?? 'Desconhecido',
      tutorName: json['tutor_name'] ?? 'Desconhecido',
      targetPhone: json['target_phone'] ?? '',
      type: json['type'] ?? 'new_invoice',
      status: json['status'] ?? 'queued',

      // createdAt vem do timestamps do Mongoose (createdAt)
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),

      // sent_at vem do seu campo custom (sent_at)
      sentAt:
          json['sent_at'] != null ? DateTime.tryParse(json['sent_at']) : null,

      errorMessage: json['error_message'],

      // ✅ NOVOS CAMPOS (backend precisa enviar)
      messagePreview: json['message_preview'],
      messageText: json['message_text'],
      templateGroup: json['template_group'],
      templateIndex: json['template_index'] is int
          ? json['template_index']
          : int.tryParse((json['template_index'] ?? '').toString()),

      errorCode: json['error_code'],
      errorHttpStatus: json['error_http_status'] is int
          ? json['error_http_status']
          : int.tryParse((json['error_http_status'] ?? '').toString()),
    );
  }
}
