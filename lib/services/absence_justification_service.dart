import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../model/absence_justification_model.dart';

class AbsenceJustificationService {
  static const String _resource = '/absence-justifications';

  Future<List<AbsenceJustificationModel>> fetchJustifications({
    required String token,
    String? classId,
    String? studentId,
    String? status,
    DateTime? date,
  }) async {
    final query = <String, String>{};

    if (classId != null && classId.trim().isNotEmpty) {
      query['classId'] = classId.trim();
    }

    if (studentId != null && studentId.trim().isNotEmpty) {
      query['studentId'] = studentId.trim();
    }

    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim().toUpperCase();
    }

    if (date != null) {
      query['date'] = _apiDate(date);
    }

    final uri = _buildUri(
      path: _resource,
      queryParameters: query.isEmpty ? null : query,
    );

    final response = await http.get(uri, headers: _jsonHeaders(token));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AbsenceJustificationApiException(
        _extractApiMessage(
          response.body,
          fallback: 'Erro ao listar justificativas.',
        ),
      );
    }

    final decoded = _decodeBody(response.body);
    final rawList = decoded is List ? decoded : <dynamic>[];

    return rawList
        .whereType<Map>()
        .map(
          (item) => AbsenceJustificationModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<AbsenceJustificationModel> getById({
    required String token,
    required String justificationId,
  }) async {
    final uri = _buildUri(path: '$_resource/$justificationId');

    final response = await http.get(uri, headers: _jsonHeaders(token));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AbsenceJustificationApiException(
        _extractApiMessage(
          response.body,
          fallback: 'Erro ao buscar justificativa.',
        ),
      );
    }

    final decoded = _decodeBody(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AbsenceJustificationApiException(
        'Resposta inválida ao buscar justificativa.',
      );
    }

    return AbsenceJustificationModel.fromJson(decoded);
  }

  Future<DownloadedJustificationDocument> downloadDocument({
    required String token,
    required String justificationId,
  }) async {
    final uri = _buildUri(path: '$_resource/$justificationId/document');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': '*/*',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AbsenceJustificationApiException(
        _extractApiMessage(
          response.body,
          fallback: 'Erro ao baixar documento.',
        ),
      );
    }

    final contentDisposition = response.headers['content-disposition'];
    final fileName = _extractFileName(contentDisposition) ?? 'documento';
    final mimeType = response.headers['content-type'];

    return DownloadedJustificationDocument(
      bytes: response.bodyBytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  Future<AbsenceJustificationModel> createJustification({
    required String token,
    required AbsenceJustificationCreatePayload payload,
    required List<int> documentBytes,
    required String fileName,
  }) async {
    if (!payload.isValid) {
      throw const AbsenceJustificationApiException(
        'Payload de justificativa inválido.',
      );
    }

    if (documentBytes.isEmpty) {
      throw const AbsenceJustificationApiException(
        'O documento da justificativa é obrigatório.',
      );
    }

    final uri = _buildUri(path: _resource);

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      })
      ..fields.addAll(payload.toFormFields())
      ..files.add(
        http.MultipartFile.fromBytes(
          'document',
          documentBytes,
          filename: fileName,
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AbsenceJustificationApiException(
        _extractApiMessage(
          response.body,
          fallback: 'Erro ao criar justificativa.',
        ),
      );
    }

    final decoded = _decodeBody(response.body);
    final data = _extractWrappedData(decoded);

    if (data is! Map<String, dynamic>) {
      throw const AbsenceJustificationApiException(
        'Resposta inválida ao criar justificativa.',
      );
    }

    return AbsenceJustificationModel.fromJson(data);
  }

  Future<AbsenceJustificationModel> reviewJustification({
    required String token,
    required String justificationId,
    required AbsenceJustificationReviewPayload payload,
  }) async {
    final uri = _buildUri(path: '$_resource/$justificationId/review');

    final response = await http.patch(
      uri,
      headers: _jsonHeaders(token),
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AbsenceJustificationApiException(
        _extractApiMessage(
          response.body,
          fallback: 'Erro ao revisar justificativa.',
        ),
      );
    }

    final decoded = _decodeBody(response.body);
    final data = _extractWrappedData(decoded);

    if (data is! Map<String, dynamic>) {
      throw const AbsenceJustificationApiException(
        'Resposta inválida ao revisar justificativa.',
      );
    }

    return AbsenceJustificationModel.fromJson(data);
  }

  Uri _buildUri({
    required String path,
    Map<String, String>? queryParameters,
  }) {
    final base = ApiConfig.apiUrl.endsWith('/')
        ? ApiConfig.apiUrl.substring(0, ApiConfig.apiUrl.length - 1)
        : ApiConfig.apiUrl;

    return Uri.parse('$base$path').replace(
      queryParameters: queryParameters,
    );
  }

  Map<String, String> _jsonHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return null;
    return jsonDecode(body);
  }

  dynamic _extractWrappedData(dynamic decoded) {
    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }

  String _extractApiMessage(String body, {required String fallback}) {
    try {
      final decoded = _decodeBody(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  String? _extractFileName(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.trim().isEmpty) {
      return null;
    }

    final utf8Regex = RegExp(r"filename\*=UTF-8''([^;]+)");
    final classicRegex = RegExp(r'filename="?([^"]+)"?');

    final utf8Match = utf8Regex.firstMatch(contentDisposition);
    if (utf8Match != null && utf8Match.groupCount >= 1) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final classicMatch = classicRegex.firstMatch(contentDisposition);
    if (classicMatch != null && classicMatch.groupCount >= 1) {
      return classicMatch.group(1);
    }

    return null;
  }
}

class AbsenceJustificationApiException implements Exception {
  final String message;

  const AbsenceJustificationApiException(this.message);

  @override
  String toString() => message;
}

String _apiDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final y = normalized.year.toString().padLeft(4, '0');
  final m = normalized.month.toString().padLeft(2, '0');
  final d = normalized.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
