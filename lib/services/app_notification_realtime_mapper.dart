import 'package:academyhub_mobile/model/app_notification_model.dart';
import 'package:academyhub_mobile/model/guardian_official_document_model.dart';

class AppNotificationRealtimeMapper {
  const AppNotificationRealtimeMapper._();

  static AppNotificationItem? fromWebSocketMessage(
    Map<String, dynamic> message, {
    String? currentStudentId,
    List<String> linkedStudentIds = const [],
  }) {
    final type = message['type']?.toString().trim() ?? '';
    if (type.startsWith('absence_justification_request_')) {
      return _absenceRequestNotification(
        message,
        currentStudentId: currentStudentId,
        linkedStudentIds: linkedStudentIds,
      );
    }

    if (!type.startsWith('official_document_')) return null;

    final payload = _mapValue(message['payload']);
    if (payload == null) return null;

    final payloadStudentId = _stringValue(payload['studentId']) ??
        _stringValue(_mapValue(payload['request'])?['studentId']) ??
        _stringValue(_mapValue(payload['document'])?['studentId']);
    final normalizedStudentId = (currentStudentId ?? '').trim();
    if (!_studentAllowed(
      payloadStudentId,
      currentStudentId: normalizedStudentId,
      linkedStudentIds: linkedStudentIds,
    )) {
      return null;
    }

    final descriptor = _documentDescriptor(type);
    if (descriptor == null) return null;

    final request = _mapValue(payload['request']);
    final document = _mapValue(payload['document']);
    final documentType = guardianOfficialDocumentCanonicalType(
      _stringValue(payload['documentType']) ??
          _stringValue(request?['documentType']) ??
          _stringValue(document?['documentType']) ??
          GuardianOfficialDocumentTypes.other,
    );
    final title = guardianOfficialDocumentTitle(documentType);
    final requestId = _stringValue(payload['requestId']) ??
        _stringValue(request?['_id']) ??
        _stringValue(request?['id']);
    final documentId = _stringValue(payload['documentId']) ??
        _stringValue(document?['_id']) ??
        _stringValue(document?['id']);
    final status = _stringValue(payload['toStatus']) ??
        _stringValue(payload['status']) ??
        _stringValue(request?['status']) ??
        _stringValue(document?['status']) ??
        type;
    final stableId = requestId ?? documentId ?? documentType;

    return AppNotificationItem(
      id: '$type:$stableId:$status',
      threadKey: 'documents:$stableId',
      domain: AppNotificationDomain.documents,
      type: type,
      title: descriptor.title(title),
      summary: descriptor.summary(title),
      createdAt: _dateValue(payload['emittedAt']) ??
          _dateValue(message['emittedAt']) ??
          DateTime.now(),
      priority: descriptor.priority,
      routeKey: 'guardian.documents',
      metadata: {
        'studentId': payloadStudentId,
        'requestId': requestId,
        'documentId': documentId,
        'documentType': documentType,
        'status': status,
        'sourceEvent': type,
      }..removeWhere((_, value) => value == null),
    );
  }

  static AppNotificationItem? _absenceRequestNotification(
    Map<String, dynamic> message, {
    String? currentStudentId,
    List<String> linkedStudentIds = const [],
  }) {
    final type = message['type']?.toString().trim() ?? '';
    final payload = _mapValue(message['payload']);
    if (payload == null) return null;

    final request = _mapValue(payload['request']);
    final payloadStudentId = _stringValue(payload['studentId']) ??
        _stringValue(request?['studentId']);

    if (!_studentAllowed(
      payloadStudentId,
      currentStudentId: currentStudentId,
      linkedStudentIds: linkedStudentIds,
    )) {
      return null;
    }

    final descriptor = _absenceDescriptor(type);
    if (descriptor == null) return null;

    final requestId = _stringValue(payload['requestId']) ??
        _stringValue(request?['_id']) ??
        _stringValue(request?['id']);
    final status = _stringValue(payload['toStatus']) ??
        _stringValue(payload['status']) ??
        _stringValue(request?['status']) ??
        type;
    final studentName = _stringValue(payload['studentName']) ??
        _stringValue(request?['studentName']) ??
        'o aluno';
    final stableId = requestId ?? '$payloadStudentId:$status';

    return AppNotificationItem(
      id: '$type:$stableId:$status',
      threadKey: 'attendance:$stableId',
      domain: AppNotificationDomain.academic,
      type: type,
      title: descriptor.title,
      summary: descriptor.summary(studentName),
      createdAt: _dateValue(payload['emittedAt']) ??
          _dateValue(message['emittedAt']) ??
          DateTime.now(),
      priority: descriptor.priority,
      routeKey: 'guardian.attendance',
      metadata: {
        'studentId': payloadStudentId,
        'requestId': requestId,
        'status': status,
        'sourceEvent': type,
      }..removeWhere((_, value) => value == null),
    );
  }

  static _DocumentNotificationDescriptor? _documentDescriptor(String type) {
    switch (type) {
      case 'official_document_request_created':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Pedido registrado',
          summary: (documentTitle) =>
              'A solicitação de $documentTitle foi enviada para a escola.',
          priority: AppNotificationPriority.info,
        );
      case 'official_document_request_approved':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Solicitação aprovada',
          summary: (documentTitle) =>
              'A escola aprovou o pedido de $documentTitle.',
          priority: AppNotificationPriority.success,
        );
      case 'official_document_request_rejected':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Solicitação recusada',
          summary: (documentTitle) =>
              'A escola respondeu o pedido de $documentTitle.',
          priority: AppNotificationPriority.warning,
        );
      case 'official_document_request_cancelled':
      case 'official_document_cancelled':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Documento cancelado',
          summary: (documentTitle) =>
              'O protocolo de $documentTitle foi encerrado.',
          priority: AppNotificationPriority.warning,
        );
      case 'official_document_preparing':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Documento em preparação',
          summary: (documentTitle) =>
              'A escola está preparando o PDF de $documentTitle.',
          priority: AppNotificationPriority.info,
        );
      case 'official_document_awaiting_signature':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Aguardando assinatura',
          summary: (documentTitle) =>
              'O documento $documentTitle está na etapa de assinatura.',
          priority: AppNotificationPriority.info,
        );
      case 'official_document_signed':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Documento assinado',
          summary: (documentTitle) =>
              'O PDF de $documentTitle foi assinado pela escola.',
          priority: AppNotificationPriority.success,
        );
      case 'official_document_published':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Documento disponível',
          summary: (documentTitle) =>
              'O PDF oficial de $documentTitle já pode ser aberto ou baixado.',
          priority: AppNotificationPriority.success,
        );
      case 'official_document_downloaded':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Download registrado',
          summary: (documentTitle) =>
              'O acesso ao documento $documentTitle foi registrado.',
          priority: AppNotificationPriority.info,
        );
      case 'official_document_replaced':
        return _DocumentNotificationDescriptor(
          title: (documentTitle) => 'Nova versão disponível',
          summary: (documentTitle) =>
              'A escola atualizou a versão do documento $documentTitle.',
          priority: AppNotificationPriority.info,
        );
      default:
        return null;
    }
  }

  static Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _stringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is Map<String, dynamic>) {
      return _stringValue(value['_id']) ?? _stringValue(value['id']);
    }
    if (value is Map) {
      return _stringValue(value['_id']) ?? _stringValue(value['id']);
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _dateValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static bool _studentAllowed(
    String? payloadStudentId, {
    String? currentStudentId,
    List<String> linkedStudentIds = const [],
  }) {
    if (payloadStudentId == null || payloadStudentId.trim().isEmpty) {
      return true;
    }

    final normalizedPayload = payloadStudentId.trim();
    final normalizedCurrent = (currentStudentId ?? '').trim();
    if (normalizedCurrent.isNotEmpty &&
        normalizedPayload == normalizedCurrent) {
      return true;
    }

    final linked = linkedStudentIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();

    return linked.isNotEmpty && linked.contains(normalizedPayload);
  }
}

class _DocumentNotificationDescriptor {
  final String Function(String documentTitle) title;
  final String Function(String documentTitle) summary;
  final AppNotificationPriority priority;

  const _DocumentNotificationDescriptor({
    required this.title,
    required this.summary,
    required this.priority,
  });
}

class _AbsenceNotificationDescriptor {
  final String title;
  final String Function(String studentName) summary;
  final AppNotificationPriority priority;

  const _AbsenceNotificationDescriptor({
    required this.title,
    required this.summary,
    required this.priority,
  });
}

_AbsenceNotificationDescriptor? _absenceDescriptor(String type) {
  switch (type) {
    case 'absence_justification_request_approved':
      return _AbsenceNotificationDescriptor(
        title: 'Abono aprovado',
        summary: (studentName) =>
            'A escola aprovou a solicitação de abono de $studentName.',
        priority: AppNotificationPriority.success,
      );
    case 'absence_justification_request_partially_approved':
      return _AbsenceNotificationDescriptor(
        title: 'Abono aprovado parcialmente',
        summary: (studentName) =>
            'A escola aprovou parte do período solicitado para $studentName.',
        priority: AppNotificationPriority.warning,
      );
    case 'absence_justification_request_rejected':
      return _AbsenceNotificationDescriptor(
        title: 'Abono recusado',
        summary: (studentName) =>
            'A escola respondeu a solicitação de abono de $studentName.',
        priority: AppNotificationPriority.warning,
      );
    case 'absence_justification_request_needs_information':
      return _AbsenceNotificationDescriptor(
        title: 'Complemento solicitado',
        summary: (studentName) =>
            'A escola pediu mais informações sobre o abono de $studentName.',
        priority: AppNotificationPriority.warning,
      );
    case 'absence_justification_request_applied':
      return _AbsenceNotificationDescriptor(
        title: 'Abono aplicado',
        summary: (studentName) =>
            'Uma falta real de $studentName foi coberta pela solicitação aprovada.',
        priority: AppNotificationPriority.success,
      );
    default:
      return null;
  }
}
