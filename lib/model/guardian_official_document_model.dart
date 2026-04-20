class GuardianOfficialDocumentTypes {
  static const enrollmentDeclaration = 'enrollment_confirmation';
  static const attendanceDeclaration = 'enrollment_status';
  static const noDebtDeclaration = 'nothing_pending';
  static const transferDeclaration = 'transfer_declaration';
  static const incomeTaxDeclaration = 'income_tax';
  static const paymentReceipt = 'payment_receipt';
  static const schoolTranscript = 'school_transcript';
  static const other = 'other';
}

class GuardianOfficialDocumentRequestStatuses {
  static const requested = 'requested';
  static const underReview = 'under_review';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const awaitingSignature = 'awaiting_signature';
  static const signed = 'signed';
  static const published = 'published';
  static const downloaded = 'downloaded';
  static const cancelled = 'cancelled';
}

class GuardianOfficialDocumentStatuses {
  static const draft = 'draft';
  static const signed = 'signed';
  static const published = 'published';
  static const superseded = 'superseded';
  static const cancelled = 'cancelled';
}

class GuardianOfficialDocumentCatalogItem {
  final String type;
  final String title;
  final String purpose;
  final String usedWhen;
  final String schoolExpectation;
  final bool requiresSchoolReview;
  final bool isRecommended;

  const GuardianOfficialDocumentCatalogItem({
    required this.type,
    required this.title,
    required this.purpose,
    required this.usedWhen,
    required this.schoolExpectation,
    this.requiresSchoolReview = true,
    this.isRecommended = false,
  });

  factory GuardianOfficialDocumentCatalogItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return GuardianOfficialDocumentCatalogItem(
      type: guardianOfficialDocumentCanonicalType(
        _stringValue(
          json['type'] ?? json['documentType'] ?? json['key'],
          fallback: GuardianOfficialDocumentTypes.other,
        ),
      ),
      title: _stringValue(json['title'] ?? json['name']),
      purpose: _stringValue(json['purpose'] ?? json['description']),
      usedWhen: _stringValue(json['usedWhen'] ?? json['whenToUse']),
      schoolExpectation:
          _stringValue(json['schoolExpectation'] ?? json['preparationHint']),
      requiresSchoolReview: _boolValue(json['requiresSchoolReview'], true),
      isRecommended: _boolValue(json['isRecommended'], false),
    );
  }

  static const defaults = <GuardianOfficialDocumentCatalogItem>[
    GuardianOfficialDocumentCatalogItem(
      type: GuardianOfficialDocumentTypes.enrollmentDeclaration,
      title: 'Declaração de matrícula',
      purpose: 'Comprova que o aluno possui matrícula ativa na escola.',
      usedWhen:
          'Costuma ser solicitada por planos, benefícios, cursos externos ou cadastros que precisam confirmar o vínculo escolar.',
      schoolExpectation:
          'A escola confere os dados do aluno, emite a declaração e libera o PDF assinado quando estiver pronto.',
      isRecommended: true,
    ),
    GuardianOfficialDocumentCatalogItem(
      type: GuardianOfficialDocumentTypes.attendanceDeclaration,
      title: 'Declaração de aluno cursando',
      purpose: 'Confirma que o aluno está frequentando as aulas regularmente.',
      usedWhen:
          'Use quando a instituição ou empresa pedir comprovação de frequência ou situação escolar atual.',
      schoolExpectation:
          'O pedido passa pela secretaria para validar turma, ano letivo e frequência antes da emissão.',
    ),
    GuardianOfficialDocumentCatalogItem(
      type: GuardianOfficialDocumentTypes.noDebtDeclaration,
      title: 'Declaração de nada consta',
      purpose:
          'Informa que não existem pendências registradas para o aluno ou responsável, conforme regra da escola.',
      usedWhen:
          'Indicada para transferências, encerramento de vínculo ou comprovações administrativas.',
      schoolExpectation:
          'A escola revisa financeiro e documentação antes de aprovar ou orientar sobre alguma pendência.',
    ),
    GuardianOfficialDocumentCatalogItem(
      type: GuardianOfficialDocumentTypes.transferDeclaration,
      title: 'Declaração de transferência',
      purpose:
          'Ajuda no processo de mudança para outra escola ou regularização de matrícula em nova unidade.',
      usedWhen:
          'Use quando outra instituição solicitar um documento formal para iniciar ou concluir a transferência.',
      schoolExpectation:
          'A secretaria valida a situação acadêmica e prepara o documento oficial para assinatura.',
    ),
    GuardianOfficialDocumentCatalogItem(
      type: GuardianOfficialDocumentTypes.incomeTaxDeclaration,
      title: 'Declaração para IRPF',
      purpose:
          'Reúne informações necessárias para declaração de imposto de renda, quando aplicável.',
      usedWhen:
          'Indicada no período de declaração anual ou quando o contador solicitar comprovante escolar.',
      schoolExpectation:
          'A escola confere pagamentos e dados fiscais antes de disponibilizar o documento final.',
    ),
    GuardianOfficialDocumentCatalogItem(
      type: GuardianOfficialDocumentTypes.paymentReceipt,
      title: 'Recibo de pagamento',
      purpose: 'Comprova pagamentos realizados junto à escola.',
      usedWhen:
          'Use quando precisar comprovar uma mensalidade, taxa ou pagamento específico.',
      schoolExpectation:
          'A secretaria/financeiro valida o pagamento e libera o recibo correspondente.',
    ),
    GuardianOfficialDocumentCatalogItem(
      type: GuardianOfficialDocumentTypes.schoolTranscript,
      title: 'Histórico escolar',
      purpose: 'Documento acadêmico formal com registros escolares do aluno.',
      usedWhen:
          'Normalmente solicitado em transferências, processos seletivos ou comprovações acadêmicas oficiais.',
      schoolExpectation:
          'A escola prepara com mais cuidado porque depende de conferência acadêmica e assinatura institucional.',
    ),
  ];
}

class GuardianOfficialDocumentRequest {
  final String id;
  final String studentId;
  final String documentType;
  final String status;
  final String purpose;
  final String notes;
  final String rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? signedAt;
  final DateTime? publishedAt;
  final DateTime? downloadedAt;

  const GuardianOfficialDocumentRequest({
    required this.id,
    required this.studentId,
    required this.documentType,
    required this.status,
    this.purpose = '',
    this.notes = '',
    this.rejectionReason = '',
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.rejectedAt,
    this.signedAt,
    this.publishedAt,
    this.downloadedAt,
  });

  factory GuardianOfficialDocumentRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    return GuardianOfficialDocumentRequest(
      id: _idValue(json),
      studentId: _idFromValue(json['studentId'] ?? json['student']),
      documentType: guardianOfficialDocumentCanonicalType(
        _stringValue(
          json['documentType'],
          fallback: GuardianOfficialDocumentTypes.other,
        ),
      ),
      status: _stringValue(
        json['status'],
        fallback: GuardianOfficialDocumentRequestStatuses.requested,
      ),
      purpose: _stringValue(json['purpose'] ?? json['reason']),
      notes: _stringValue(json['notes']),
      rejectionReason: _stringValue(json['rejectionReason']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
      approvedAt: _dateValue(json['approvedAt']),
      rejectedAt: _dateValue(json['rejectedAt']),
      signedAt: _dateValue(json['signedAt']),
      publishedAt: _dateValue(json['publishedAt']),
      downloadedAt: _dateValue(json['downloadedAt']),
    );
  }

  bool get isRejected =>
      status == GuardianOfficialDocumentRequestStatuses.rejected;

  bool get isCancelled =>
      status == GuardianOfficialDocumentRequestStatuses.cancelled;

  bool get isFinished =>
      isRejected ||
      isCancelled ||
      status == GuardianOfficialDocumentRequestStatuses.published ||
      status == GuardianOfficialDocumentRequestStatuses.downloaded;

  int get progressIndex {
    switch (status) {
      case GuardianOfficialDocumentRequestStatuses.underReview:
        return 1;
      case GuardianOfficialDocumentRequestStatuses.approved:
        return 2;
      case GuardianOfficialDocumentRequestStatuses.awaitingSignature:
        return 4;
      case GuardianOfficialDocumentRequestStatuses.signed:
        return 5;
      case GuardianOfficialDocumentRequestStatuses.published:
        return 6;
      case GuardianOfficialDocumentRequestStatuses.downloaded:
        return 7;
      case GuardianOfficialDocumentRequestStatuses.rejected:
      case GuardianOfficialDocumentRequestStatuses.cancelled:
        return 1;
      case GuardianOfficialDocumentRequestStatuses.requested:
      default:
        return 0;
    }
  }
}

class GuardianOfficialDocument {
  final String id;
  final String studentId;
  final String requestId;
  final String documentType;
  final String status;
  final int version;
  final String fileName;
  final String fileUrl;
  final String mimeType;
  final int fileSize;
  final String fileHash;
  final String certificateSubject;
  final DateTime? generatedAt;
  final DateTime? signedAt;
  final DateTime? publishedAt;
  final DateTime? downloadedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GuardianOfficialDocument({
    required this.id,
    required this.studentId,
    required this.documentType,
    required this.status,
    this.requestId = '',
    this.version = 1,
    this.fileName = '',
    this.fileUrl = '',
    this.mimeType = 'application/pdf',
    this.fileSize = 0,
    this.fileHash = '',
    this.certificateSubject = '',
    this.generatedAt,
    this.signedAt,
    this.publishedAt,
    this.downloadedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory GuardianOfficialDocument.fromJson(Map<String, dynamic> json) {
    return GuardianOfficialDocument(
      id: _idValue(json),
      studentId: _idFromValue(json['studentId'] ?? json['student']),
      requestId: _idFromValue(json['requestId'] ?? json['request']),
      documentType: guardianOfficialDocumentCanonicalType(
        _stringValue(
          json['documentType'],
          fallback: GuardianOfficialDocumentTypes.other,
        ),
      ),
      status: _stringValue(
        json['status'],
        fallback: GuardianOfficialDocumentStatuses.published,
      ),
      version: _intValue(json['version'], 1),
      fileName: _stringValue(json['fileName'] ?? json['name']),
      fileUrl: _stringValue(json['fileUrl'] ?? json['url']),
      mimeType: _stringValue(json['mimeType'], fallback: 'application/pdf'),
      fileSize: _intValue(json['fileSize'], 0),
      fileHash: _stringValue(json['fileHash']),
      certificateSubject: _stringValue(json['certificateSubject']),
      generatedAt: _dateValue(json['generatedAt']),
      signedAt: _dateValue(json['signedAt']),
      publishedAt: _dateValue(json['publishedAt']),
      downloadedAt: _dateValue(json['downloadedAt']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
    );
  }

  bool get isPublished =>
      status == GuardianOfficialDocumentStatuses.published ||
      status == GuardianOfficialDocumentRequestStatuses.downloaded;
}

String guardianOfficialDocumentTitle(String type) {
  final canonicalType = guardianOfficialDocumentCanonicalType(type);
  for (final item in GuardianOfficialDocumentCatalogItem.defaults) {
    if (item.type == canonicalType) return item.title;
  }
  return _humanizeToken(canonicalType);
}

String guardianOfficialDocumentCanonicalType(String type) {
  switch (type.trim()) {
    case 'enrollment_declaration':
    case 'declaration_of_enrollment':
      return GuardianOfficialDocumentTypes.enrollmentDeclaration;
    case 'attendance_declaration':
    case 'student_attendance_declaration':
    case 'enrollment_status_declaration':
      return GuardianOfficialDocumentTypes.attendanceDeclaration;
    case 'no_debt_declaration':
    case 'no_pending_declaration':
    case 'nothing_pending_declaration':
      return GuardianOfficialDocumentTypes.noDebtDeclaration;
    case 'income_tax_declaration':
    case 'irpf_declaration':
      return GuardianOfficialDocumentTypes.incomeTaxDeclaration;
    default:
      return type.trim().isEmpty
          ? GuardianOfficialDocumentTypes.other
          : type.trim();
  }
}

String guardianOfficialDocumentRequestStatusLabel(String status) {
  switch (status) {
    case GuardianOfficialDocumentRequestStatuses.requested:
      return 'Solicitação enviada';
    case GuardianOfficialDocumentRequestStatuses.underReview:
      return 'Em análise pela escola';
    case GuardianOfficialDocumentRequestStatuses.approved:
      return 'Aprovada';
    case GuardianOfficialDocumentRequestStatuses.rejected:
      return 'Recusada';
    case GuardianOfficialDocumentRequestStatuses.awaitingSignature:
      return 'Aguardando assinatura';
    case GuardianOfficialDocumentRequestStatuses.signed:
      return 'Assinada';
    case GuardianOfficialDocumentRequestStatuses.published:
      return 'Disponível';
    case GuardianOfficialDocumentRequestStatuses.downloaded:
      return 'Baixada';
    case GuardianOfficialDocumentRequestStatuses.cancelled:
      return 'Cancelada';
    default:
      return _humanizeToken(status);
  }
}

String guardianOfficialDocumentStatusLabel(String status) {
  switch (status) {
    case GuardianOfficialDocumentStatuses.draft:
      return 'Em preparação';
    case GuardianOfficialDocumentStatuses.signed:
      return 'Assinado';
    case GuardianOfficialDocumentStatuses.published:
      return 'Disponível';
    case GuardianOfficialDocumentStatuses.superseded:
      return 'Substituído';
    case GuardianOfficialDocumentStatuses.cancelled:
      return 'Cancelado';
    default:
      return guardianOfficialDocumentRequestStatusLabel(status);
  }
}

String _idValue(Map<String, dynamic> json) =>
    _stringValue(json['_id'] ?? json['id']);

String _idFromValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map<String, dynamic>) return _idValue(value);
  if (value is Map) {
    return _idValue(Map<String, dynamic>.from(value));
  }
  return value.toString();
}

String _stringValue(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _intValue(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolValue(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value == null) return fallback;
  final normalized = value.toString().toLowerCase().trim();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

DateTime? _dateValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String _humanizeToken(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'Documento escolar';
  return normalized
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
