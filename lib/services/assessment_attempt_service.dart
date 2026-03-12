import 'dart:convert';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../model/assessment_models.dart';

class AssessmentAttemptService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('student_token') ??
        prefs.getString('authToken'); // Tenta token de aluno ou staff
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // [ADICIONADO] Buscar avaliações do aluno logado
  Future<List<dynamic>> getStudentAssessments() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/attempts/my-assessments');
    debugPrint('🚀 [AttemptService] Buscando avaliações do aluno: $url');

    try {
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        String errorMsg;
        try {
          final err = jsonDecode(response.body);
          errorMsg = err['message'] ?? 'Erro desconhecido.';
        } catch (_) {
          errorMsg = 'Erro (${response.statusCode}) ao buscar avaliações.';
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ [AttemptService] Erro em getStudentAssessments: $e');
      rethrow;
    }
  }

  // Iniciar Prova
  Future<Map<String, dynamic>> startAttempt(String assessmentId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/attempts/start');
    debugPrint('🚀 [AttemptService] Iniciando prova: $url');

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'assessmentId': assessmentId}),
      );

      debugPrint('📡 [AttemptService] Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<')) {
        debugPrint('❌ [AttemptService] Erro Crítico: Servidor retornou HTML.');
        throw Exception(
            'Erro de conexão (${response.statusCode}): Rota da API inválida.');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'attemptId': data['attemptId'],
          'assessment': Assessment.fromJson(data['assessment']),
        };
      } else {
        String errorMsg;
        try {
          final err = jsonDecode(response.body);
          errorMsg = err['message'] ?? 'Erro desconhecido.';
        } catch (_) {
          errorMsg = "Erro (${response.statusCode}) ao iniciar prova.";
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ [AttemptService] Exception: $e');
      rethrow;
    }
  }

  // Enviar Prova Finalizada
  Future<AssessmentAttempt> submitAttempt(
      String attemptId, AssessmentAttempt attemptData) async {
    final url =
        Uri.parse('${ApiConfig.baseUrl}/api/attempts/$attemptId/submit');

    try {
      final headers = await _getHeaders();
      final body = jsonEncode(attemptData.toSubmissionJson());

      final response = await http.post(url, headers: headers, body: body);

      if (response.body.trim().startsWith('<')) {
        throw Exception(
            'Erro de conexão (${response.statusCode}): Servidor retornou HTML.');
      }

      if (response.statusCode == 200) {
        return AssessmentAttempt.fromJson(jsonDecode(response.body));
      } else {
        String errorMsg;
        try {
          final err = jsonDecode(response.body);
          errorMsg = err['message'] ?? 'Erro ao enviar.';
        } catch (_) {
          errorMsg = "Erro (${response.statusCode}) ao enviar.";
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Método Adicionado para o Professor ver resultados
  Future<List<AssessmentAttempt>> getResultsByAssessment(
      String assessmentId) async {
    final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/attempts/assessment/$assessmentId/results');

    try {
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AssessmentAttempt.fromJson(json)).toList();
      } else {
        throw Exception('Erro ao buscar resultados (${response.statusCode}).');
      }
    } catch (e) {
      rethrow;
    }
  }
}
