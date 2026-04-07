import 'dart:convert';

import 'package:academyhub_mobile/config/api_client.dart';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/teacher_student_summary_model.dart';
import 'package:flutter/foundation.dart';

class TeacherStudentSummaryService {
  String get _baseUrl => ApiConfig.apiUrl.endsWith('/')
      ? ApiConfig.apiUrl.substring(0, ApiConfig.apiUrl.length - 1)
      : ApiConfig.apiUrl;

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<TeacherStudentSummary> fetchSummary({
    required String token,
    required String classId,
    required String studentId,
  }) async {
    final url =
        Uri.parse('$_baseUrl/classes/$classId/students/$studentId/teacher-summary');
    debugPrint('[TeacherStudentSummaryService] GET $url');

    final response = await ApiClient.get(url, headers: _headers(token));
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      return TeacherStudentSummary.fromJson(payload);
    }

    throw Exception(
      _extractErrorMessage(body, 'Erro ao carregar o resumo do aluno.'),
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
      // ignore parse error and use fallback
    }
    return fallback;
  }
}
