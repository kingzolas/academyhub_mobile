// lib/services/student_note_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../model/student_note_model.dart';

class StudentNoteService {
  String get _baseUrl => ApiConfig.apiUrl.endsWith('/')
      ? ApiConfig.apiUrl.substring(0, ApiConfig.apiUrl.length - 1)
      : ApiConfig.apiUrl;

  // Busca todas as anotações do aluno
  Future<List<StudentNoteModel>> fetchNotesByStudent(
      String token, String studentId) async {
    final url = Uri.parse('$_baseUrl/students/$studentId/notes');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      final data = body['data'] as List?;
      if (data == null) return [];

      return data.map((json) => StudentNoteModel.fromJson(json)).toList();
    } else {
      throw Exception(
          _extractErrorMessage(response.body, 'Erro ao carregar anotações.'));
    }
  }

  // Cria uma nova anotação
  Future<StudentNoteModel> createNote({
    required String token,
    required String studentId,
    required String title,
    required String description,
    required String type, // 'PRIVATE', 'ATTENTION', 'WARNING'
  }) async {
    final url = Uri.parse('$_baseUrl/students/$studentId/notes');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'type': type,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      return StudentNoteModel.fromJson(body['data']);
    } else {
      throw Exception(
          _extractErrorMessage(response.body, 'Erro ao criar anotação.'));
    }
  }

  // Exclui uma anotação
  Future<void> deleteNote(String token, String noteId) async {
    final url = Uri.parse('$_baseUrl/notes/$noteId');

    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      throw Exception(
          _extractErrorMessage(response.body, 'Erro ao excluir anotação.'));
    }
  }

  String _extractErrorMessage(String responseBody, String fallback) {
    try {
      final decoded = jsonDecode(responseBody);
      return decoded['message'] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
