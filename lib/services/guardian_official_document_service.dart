import 'dart:convert';
import 'dart:typed_data';

import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/guardian_official_document_model.dart';
import 'package:academyhub_mobile/services/guardian_session_exception.dart';
import 'package:http/http.dart' as http;

class GuardianOfficialDocumentService {
  final String _baseUrl = ApiConfig.apiUrl;

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<GuardianOfficialDocumentCatalogItem>> getCatalog({
    required String token,
  }) async {
    // The API does not expose a guardian catalog endpoint yet. Falling back to
    // /official-documents/catalog sends a guardian token to a staff-only route
    // and turns its expected 401 into a false session expiration.
    return GuardianOfficialDocumentCatalogItem.defaults;
  }

  Future<List<GuardianOfficialDocumentRequest>> getRequests({
    required String token,
    required String studentId,
  }) async {
    final queryParameters = {'studentId': studentId};
    final data = await _jsonWithFallback(
      method: 'GET',
      token: token,
      queryParameters: queryParameters,
      paths: const [
        '/official-document-requests/guardian/mine',
      ],
    );

    final rawRequests = _extractList(data, const [
      'requests',
      'documentRequests',
      'items',
      'data',
    ]);

    return rawRequests
        .whereType<Map<String, dynamic>>()
        .map(GuardianOfficialDocumentRequest.fromJson)
        .toList();
  }

  Future<GuardianOfficialDocumentRequest> createRequest({
    required String token,
    required String studentId,
    required String documentType,
    required String purpose,
    String? notes,
  }) async {
    final body = {
      'studentId': studentId,
      'requesterType': 'guardian',
      'documentType': documentType,
      'purpose': purpose,
      'reason': purpose,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };

    final data = await _jsonWithFallback(
      method: 'POST',
      token: token,
      body: body,
      paths: const [
        '/official-document-requests/guardian',
      ],
    );

    final requestJson = _extractObject(data, const [
      'request',
      'documentRequest',
      'item',
      'data',
    ]);

    return GuardianOfficialDocumentRequest.fromJson(requestJson);
  }

  Future<List<GuardianOfficialDocument>> getPublishedDocuments({
    required String token,
    required String studentId,
  }) async {
    final queryParameters = {'studentId': studentId};
    final data = await _jsonWithFallback(
      method: 'GET',
      token: token,
      queryParameters: queryParameters,
      paths: const [
        '/official-documents/guardian/mine',
      ],
    );

    final rawDocuments = _extractList(data, const [
      'documents',
      'officialDocuments',
      'items',
      'data',
    ]);

    return rawDocuments
        .whereType<Map<String, dynamic>>()
        .map(GuardianOfficialDocument.fromJson)
        .where((document) => document.isPublished)
        .toList();
  }

  Future<Uint8List> downloadPublishedDocument({
    required String token,
    required String documentId,
    String? fileUrl,
  }) async {
    final normalizedFileUrl = (fileUrl ?? '').trim();
    final paths = [
      '/official-documents/guardian/mine/$documentId/file',
    ];

    Object? lastError;
    for (final path in paths) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl$path'),
          headers: _headers(token),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.bodyBytes;
        }

        final sessionException = guardianSessionExceptionFromResponse(
          statusCode: response.statusCode,
          payload: _safeDecodeJson(response),
        );
        if (sessionException != null) {
          throw sessionException;
        }

        if (response.statusCode != 404 && response.statusCode != 405) {
          throw Exception(_errorMessage(response));
        }
      } on GuardianSessionExpiredException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    if (normalizedFileUrl.startsWith('http')) {
      final response = await http.get(
        Uri.parse(normalizedFileUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      final sessionException = guardianSessionExceptionFromResponse(
        statusCode: response.statusCode,
        payload: _safeDecodeJson(response),
      );
      if (sessionException != null) {
        throw sessionException;
      }
      throw Exception(_errorMessage(response));
    }

    if (lastError != null) {
      throw Exception(
        lastError.toString().replaceFirst('Exception: ', ''),
      );
    }
    throw Exception('Não foi possível baixar o documento.');
  }

  Future<void> markDownloaded({
    required String token,
    required String documentId,
  }) async {
    final paths = [
      '/official-documents/guardian/mine/$documentId/downloaded',
    ];

    for (final path in paths) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers(token),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }
        final sessionException = guardianSessionExceptionFromResponse(
          statusCode: response.statusCode,
          payload: _safeDecodeJson(response),
        );
        if (sessionException != null) {
          throw sessionException;
        }

        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }
        return;
      } on GuardianSessionExpiredException {
        rethrow;
      } catch (_) {
        return;
      }
    }
  }

  Future<dynamic> _jsonWithFallback({
    required String method,
    required String token,
    required List<String> paths,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    Object? lastError;

    for (final path in paths) {
      try {
        final uri = Uri.parse('$_baseUrl$path').replace(
          queryParameters: queryParameters,
        );
        final response = method == 'POST'
            ? await http.post(
                uri,
                headers: _headers(token),
                body: jsonEncode(body ?? const {}),
              )
            : await http.get(uri, headers: _headers(token));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _decodeJson(response);
        }

        final sessionException = guardianSessionExceptionFromResponse(
          statusCode: response.statusCode,
          payload: _safeDecodeJson(response),
        );
        if (sessionException != null) {
          throw sessionException;
        }

        if (response.statusCode == 404 || response.statusCode == 405) {
          lastError = Exception(_errorMessage(response));
          continue;
        }

        throw Exception(_errorMessage(response));
      } catch (e) {
        lastError = e;
        if (!e.toString().contains('404') && !e.toString().contains('405')) {
          rethrow;
        }
      }
    }

    throw Exception(
      lastError?.toString().replaceFirst('Exception: ', '') ??
          'Não foi possível concluir a operação.',
    );
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  dynamic _safeDecodeJson(http.Response response) {
    try {
      return _decodeJson(response);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = _decodeJson(response);
      if (decoded is Map<String, dynamic>) {
        return (decoded['message'] ??
                decoded['error'] ??
                'Não foi possível concluir a operação.')
            .toString();
      }
    } catch (_) {}
    return 'Não foi possível concluir a operação.';
  }

  Map<String, dynamic> _extractObject(dynamic data, List<String> keys) {
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is Map<String, dynamic>) return value;
      }
      return data;
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  List<dynamic> _extractList(dynamic data, List<String> keys) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is List) return value;
        if (value is Map<String, dynamic>) {
          final nested = _extractList(value, keys);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return const [];
  }
}
