import 'dart:convert';
import 'dart:typed_data';

import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/guardian_absence_justification_request_model.dart';
import 'package:academyhub_mobile/services/guardian_session_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GuardianAbsenceJustificationRequestService {
  final String _baseUrl = ApiConfig.apiUrl;

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<GuardianAbsenceJustificationRequest>> getRequests({
    required String token,
    required String studentId,
  }) async {
    final uri =
        Uri.parse('$_baseUrl/absence-justification-requests/guardian/mine')
            .replace(queryParameters: {'studentId': studentId});

    final response = await http.get(uri, headers: _headers(token));
    final decoded = _decodeJson(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final items = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic>
              ? (decoded['data'] ?? decoded['items'] ?? decoded['requests'])
              : null);
      final rawList = items is List ? items : const <dynamic>[];

      return rawList
          .whereType<Map>()
          .map((item) => GuardianAbsenceJustificationRequest.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    }

    _throwIfGuardianSessionExpired(response, decoded);
    throw Exception(_errorMessage(response, decoded));
  }

  Future<GuardianAbsenceJustificationRequest> createRequest({
    required String token,
    required String studentId,
    required DateTime requestedStartDate,
    required DateTime requestedEndDate,
    required String documentType,
    String? notes,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentMimeType,
  }) async {
    final uri = Uri.parse('$_baseUrl/absence-justification-requests/guardian');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['studentId'] = studentId
      ..fields['requestedStartDate'] = _dateOnly(requestedStartDate)
      ..fields['requestedEndDate'] = _dateOnly(requestedEndDate)
      ..fields['documentType'] = documentType
      ..fields['notes'] = (notes ?? '').trim();

    if (attachmentBytes != null && attachmentBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachments',
          attachmentBytes,
          filename: attachmentName ?? 'anexo',
          contentType: _mediaType(attachmentMimeType),
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decodeJson(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final item = decoded is Map<String, dynamic> && decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : decoded;
      if (item is Map<String, dynamic>) {
        return GuardianAbsenceJustificationRequest.fromJson(item);
      }
      throw Exception('Resposta inválida da API.');
    }

    _throwIfGuardianSessionExpired(response, decoded);
    throw Exception(_errorMessage(response, decoded));
  }

  Future<GuardianAbsenceJustificationRequest> cancelRequest({
    required String token,
    required String requestId,
    String? reason,
  }) async {
    return _postAction(
      token: token,
      path: '/absence-justification-requests/guardian/mine/$requestId/cancel',
      body: {
        if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
      },
    );
  }

  Future<GuardianAbsenceJustificationRequest> complementRequest({
    required String token,
    required String requestId,
    String? notes,
    Uint8List? attachmentBytes,
    String? attachmentName,
    String? attachmentMimeType,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/absence-justification-requests/guardian/mine/$requestId/complement',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['notes'] = (notes ?? '').trim();

    if (attachmentBytes != null && attachmentBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachments',
          attachmentBytes,
          filename: attachmentName ?? 'anexo',
          contentType: _mediaType(attachmentMimeType),
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decodeJson(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final item = decoded is Map<String, dynamic> && decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : decoded;
      if (item is Map<String, dynamic>) {
        return GuardianAbsenceJustificationRequest.fromJson(item);
      }
      throw Exception('Resposta inválida da API.');
    }

    _throwIfGuardianSessionExpired(response, decoded);
    throw Exception(_errorMessage(response, decoded));
  }

  Future<GuardianAbsenceJustificationRequest> _postAction({
    required String token,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    final decoded = _decodeJson(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final item = decoded is Map<String, dynamic> && decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : decoded;
      if (item is Map<String, dynamic>) {
        return GuardianAbsenceJustificationRequest.fromJson(item);
      }
      throw Exception('Resposta inválida da API.');
    }

    _throwIfGuardianSessionExpired(response, decoded);
    throw Exception(_errorMessage(response, decoded));
  }

  dynamic _decodeJson(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (body.trim().isEmpty) return null;
    return jsonDecode(body);
  }

  String _errorMessage(http.Response response, dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }
    return 'Não foi possível concluir a solicitação.';
  }

  void _throwIfGuardianSessionExpired(
    http.Response response,
    dynamic decoded,
  ) {
    final sessionException = guardianSessionExceptionFromResponse(
      statusCode: response.statusCode,
      payload: decoded,
    );
    if (sessionException != null) {
      throw sessionException;
    }
  }

  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  MediaType? _mediaType(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty || !normalized.contains('/')) return null;
    final parts = normalized.split('/');
    return MediaType(parts.first, parts.last);
  }
}
