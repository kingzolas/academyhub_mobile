class GuardianSessionExpiredException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;

  const GuardianSessionExpiredException({
    required this.message,
    this.statusCode,
    this.code,
  });

  bool get isGuardianAuthFailure => true;

  @override
  String toString() => message;
}

GuardianSessionExpiredException? guardianSessionExceptionFromResponse({
  required int statusCode,
  required dynamic payload,
  String fallbackMessage = 'Sessao do responsavel expirada.',
}) {
  final message = guardianResponseMessage(payload) ?? fallbackMessage;
  final code = guardianResponseCode(payload);

  if (!isGuardianSessionFailure(
    statusCode: statusCode,
    message: message,
    code: code,
  )) {
    return null;
  }

  return GuardianSessionExpiredException(
    statusCode: statusCode,
    message: message,
    code: code,
  );
}

String? guardianResponseMessage(dynamic payload) {
  if (payload is Map<String, dynamic>) {
    final value = payload['message'] ?? payload['error'];
    return value?.toString();
  }
  if (payload is Map) {
    final value = payload['message'] ?? payload['error'];
    return value?.toString();
  }
  if (payload is String && payload.trim().isNotEmpty) {
    return payload.trim();
  }
  return null;
}

String? guardianResponseCode(dynamic payload) {
  if (payload is Map<String, dynamic>) {
    final value = payload['code'] ?? payload['reason'];
    return value?.toString();
  }
  if (payload is Map) {
    final value = payload['code'] ?? payload['reason'];
    return value?.toString();
  }
  return null;
}

bool isGuardianSessionFailure({
  required int statusCode,
  String? message,
  String? code,
}) {
  if (statusCode == 401) return true;

  final normalizedCode = _normalizeGuardianAuthText(code ?? '');
  const authCodes = {
    'guardian_token_missing',
    'guardian_token_invalid',
    'guardian_token_expired',
    'guardian_account_not_found',
    'guardian_account_unavailable',
    'guardian_session_expired',
    'guardian_session_invalid',
  };

  if (authCodes.contains(normalizedCode)) return true;

  if (statusCode != 403 && statusCode != 423) return false;

  final text = _normalizeGuardianAuthText(message ?? '');
  if (text.isEmpty) return false;

  if (text.contains('nenhum token')) return true;
  if (text.contains('token nao fornecido')) return true;
  if (text.contains('token invalido')) return true;
  if (text.contains('token expirado')) return true;
  if (text.contains('token de responsavel')) return true;
  if (text.contains('conta de responsavel nao encontrada')) return true;
  if (text.contains('conta de responsavel indisponivel')) return true;
  if (text.contains('conta de responsavel temporariamente bloqueada')) {
    return true;
  }
  if (text.contains('sessao') &&
      (text.contains('expir') || text.contains('inval'))) {
    return true;
  }

  return false;
}

String _normalizeGuardianAuthText(String value) {
  var text = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'ê': 'e',
    'è': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'õ': 'o',
    'ô': 'o',
    'ò': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };

  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });

  return text;
}
