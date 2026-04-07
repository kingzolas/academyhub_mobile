import 'dart:convert';

import 'package:academyhub_mobile/config/api_client.dart';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/class_activity_model.dart';
import 'package:flutter/foundation.dart';

class ClassActivityService {
  String get _baseUrl => ApiConfig.apiUrl.endsWith('/')
      ? ApiConfig.apiUrl.substring(0, ApiConfig.apiUrl.length - 1)
      : ApiConfig.apiUrl;

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<List<ClassActivity>> listByClass({
    required String token,
    required String classId,
    Map<String, String?> filters = const {},
  }) async {
    final query = <String, String>{};
    for (final entry in filters.entries) {
      final value = entry.value?.trim();
      if (value != null && value.isNotEmpty) {
        query[entry.key] = value;
      }
    }

    final url = Uri.parse('$_baseUrl/classes/$classId/activities')
        .replace(queryParameters: query.isEmpty ? null : query);
    debugPrint('[ClassActivityService] GET $url');

    final response = await ApiClient.get(url, headers: _headers(token));
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final items = payload['items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(ClassActivity.fromJson)
          .toList();
    }

    throw Exception(
      _extractErrorMessage(body, 'Erro ao carregar as atividades da turma.'),
    );
  }

  Future<ClassActivity> create({
    required String token,
    required String classId,
    required ClassActivityUpsertInput input,
  }) async {
    final url = Uri.parse('$_baseUrl/classes/$classId/activities');
    debugPrint('[ClassActivityService] POST $url');

    final response = await ApiClient.post(
      url,
      headers: _headers(token),
      body: jsonEncode(input.toJson()),
    );
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ClassActivity.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }

    throw Exception(
      _extractErrorMessage(body, 'Erro ao criar a atividade.'),
    );
  }

  Future<ClassActivity> getById({
    required String token,
    required String activityId,
  }) async {
    final url = Uri.parse('$_baseUrl/activities/$activityId');
    debugPrint('[ClassActivityService] GET $url');

    final response = await ApiClient.get(url, headers: _headers(token));
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ClassActivity.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }

    throw Exception(
      _extractErrorMessage(body, 'Erro ao carregar a atividade.'),
    );
  }

  Future<ClassActivity> update({
    required String token,
    required String activityId,
    required ClassActivityUpsertInput input,
  }) async {
    final url = Uri.parse('$_baseUrl/activities/$activityId');
    debugPrint('[ClassActivityService] PATCH $url');

    final response = await ApiClient.patch(
      url,
      headers: _headers(token),
      body: jsonEncode(input.toJson()),
    );
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ClassActivity.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }

    throw Exception(
      _extractErrorMessage(body, 'Erro ao atualizar a atividade.'),
    );
  }

  Future<ClassActivity> cancel({
    required String token,
    required String activityId,
  }) async {
    final url = Uri.parse('$_baseUrl/activities/$activityId');
    debugPrint('[ClassActivityService] DELETE $url');

    final response = await ApiClient.delete(url, headers: _headers(token));
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final activity = payload['activity'];
      if (activity is Map<String, dynamic>) {
        return ClassActivity.fromJson(activity);
      }
    }

    throw Exception(
      _extractErrorMessage(body, 'Erro ao cancelar a atividade.'),
    );
  }

  Future<ClassActivitySubmissionsResponse> getSubmissions({
    required String token,
    required String activityId,
  }) async {
    final url = Uri.parse('$_baseUrl/activities/$activityId/submissions');
    debugPrint('[ClassActivityService] GET $url');

    final response = await ApiClient.get(url, headers: _headers(token));
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ClassActivitySubmissionsResponse.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    }

    throw Exception(
      _extractErrorMessage(body, 'Erro ao carregar as entregas da atividade.'),
    );
  }

  Future<ClassActivitySubmissionsResponse> bulkUpdateSubmissions({
    required String token,
    required String activityId,
    required List<ClassActivitySubmissionUpdateInput> updates,
  }) async {
    final url = Uri.parse('$_baseUrl/activities/$activityId/submissions/bulk');
    debugPrint('[ClassActivityService] PUT $url');

    final response = await ApiClient.put(
      url,
      headers: _headers(token),
      body: jsonEncode({
        'updates': updates.map((item) => item.toJson()).toList(),
      }),
    );
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ClassActivitySubmissionsResponse.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    }

    throw Exception(
      _extractErrorMessage(body, 'Erro ao salvar as entregas da atividade.'),
    );
  }

  String _extractErrorMessage(String responseBody, String fallback) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // ignore decode errors and fallback below
    }
    return fallback;
  }
}
