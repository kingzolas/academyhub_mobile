import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../model/assessment_models.dart';

class AssessmentService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    String? staffToken = prefs.getString('authToken');
    String? studentToken = prefs.getString('student_token');
    String? finalToken = staffToken ?? studentToken;

    if (finalToken == null || finalToken.isEmpty || finalToken == "null") {
      throw Exception("Sessão expirada. Por favor, faça login novamente.");
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $finalToken',
    };
  }

  // --- MÉTODOS ---

  Future<Assessment> createDraft({
    required String topic,
    required String difficulty,
    required int quantity,
    required String classId,
    required String subjectId,
    String? description,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/assessments/draft');

    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'topic': topic,
        'difficultyLevel': difficulty,
        'quantity': quantity,
        'classId': classId,
        'subjectId': subjectId,
        'description': description
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 201) {
        return Assessment.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Assessment> publishAssessment(String assessmentId) async {
    final url =
        Uri.parse('${ApiConfig.baseUrl}/api/assessments/$assessmentId/publish');
    try {
      final headers = await _getHeaders();
      final response = await http.patch(url, headers: headers);

      if (response.statusCode == 200) {
        return Assessment.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Assessment>> getByClass(String classId) async {
    final url =
        Uri.parse('${ApiConfig.baseUrl}/api/assessments/class/$classId');
    try {
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Assessment.fromJson(json)).toList();
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Assessment> getById(String assessmentId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/assessments/$assessmentId');
    try {
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return Assessment.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAssessment(String assessmentId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/assessments/$assessmentId');
    try {
      final headers = await _getHeaders();
      final response = await http.delete(url, headers: headers);

      if (response.statusCode != 200) {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      rethrow;
    }
  }

  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['message'] ?? "Erro ${response.statusCode}";
    } catch (_) {
      return "Erro ${response.statusCode}: ${response.body}";
    }
  }
}
