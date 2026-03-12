// lib/services/tutor_service.dart
import 'dart:convert';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/model/tutor_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class TutorService {
  // --- [NOVO HELPER] ---
  // Adicionado para padronizar e previnir o erro "Bearer null"
  Map<String, String> _getHeaders(String? token) {
    if (token == null) {
      debugPrint('❌ [_getHeaders] Tentativa de chamada de API sem token.');
      throw Exception('Usuário não autenticado (token nulo).');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  // --- [FIM DO HELPER] ---

  /// Rota: PUT /api/tutors/:id
  /// Atualiza os dados de um tutor específico.
  Future<Tutor> updateTutor(
      String tutorId, String? token, Map<String, dynamic> tutorData) async {
    // Aceita nulo
    final url = Uri.parse('${ApiConfig.apiUrl}/tutors/$tutorId');
    debugPrint('--- [DEBUG] Atualizando tutor em: $url ---');
    debugPrint('--- [DEBUG] Dados enviados: ${json.encode(tutorData)} ---');

    try {
      final response = await http.put(
        url,
        headers: _getHeaders(token), // Usa o helper
        body: json.encode(tutorData),
      );

      final responseBody = utf8.decode(response.bodyBytes); // Usa utf8
      debugPrint(
          '[DEBUG] Resposta da API (Update Tutor - Status ${response.statusCode}): $responseBody');

      if (response.statusCode == 200) {
        return Tutor.fromJson(json.decode(responseBody));
      } else {
        final responseData = json.decode(responseBody);
        throw Exception(
            responseData['message'] ?? 'Erro ao atualizar dados do tutor.');
      }
    } catch (error) {
      debugPrint('--- [DEBUG] ERRO DE CONEXÃO (updateTutor) ---');
      debugPrint('Erro: $error');
      throw Exception(error.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Rota: PUT /api/students/:studentId/tutors/:tutorId
  Future<TutorInStudent> updateTutorRelationship(String studentId,
      String tutorId, String relationship, String? token) async {
    // Aceita nulo

    final url =
        Uri.parse('${ApiConfig.apiUrl}/students/$studentId/tutors/$tutorId');
    debugPrint('--- [DEBUG] Atualizando relacionamento em: $url ---');

    try {
      final response = await http.put(
        url,
        headers: _getHeaders(token), // Usa o helper
        body: json.encode({'relationship': relationship}),
      );

      final responseBody = utf8.decode(response.bodyBytes); // Usa utf8
      debugPrint(
          '[DEBUG] Resposta da API (Update Relationship - Status ${response.statusCode}): $responseBody');

      if (response.statusCode == 200) {
        return TutorInStudent.fromJson(json.decode(responseBody));
      } else {
        final responseData = json.decode(responseBody);
        throw Exception(
            responseData['message'] ?? 'Erro ao atualizar relacionamento.');
      }
    } catch (error) {
      debugPrint('--- [DEBUG] ERRO DE CONEXÃO (updateTutorRelationship) ---');
      debugPrint('Erro: $error');
      throw Exception(error.toString().replaceAll('Exception: ', ''));
    }
  }
}
