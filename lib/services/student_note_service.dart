import 'dart:convert';

import 'package:academyhub_mobile/config/api_client.dart';

import '../config/api_config.dart';
import '../model/student_note_model.dart';

class StudentNoteService {
  String get _baseUrl => ApiConfig.apiUrl.endsWith('/')
      ? ApiConfig.apiUrl.substring(0, ApiConfig.apiUrl.length - 1)
      : ApiConfig.apiUrl;

  Future<List<StudentNoteModel>> fetchNotesByStudent(
    String token,
    String studentId,
  ) async {
    final url = Uri.parse('$_baseUrl/students/$studentId/notes');

    final response = await ApiClient.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final bodyText = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(bodyText);
      final data = body['data'] as List?;
      if (data == null) return [];

      return data.map((json) => StudentNoteModel.fromJson(json)).toList();
    }

    throw Exception(
      _extractErrorMessage(bodyText, 'Erro ao carregar anotacoes.'),
    );
  }

  Future<StudentNoteModel> createNote({
    required String token,
    required String studentId,
    required String title,
    required String description,
    required String type,
  }) async {
    final url = Uri.parse('$_baseUrl/students/$studentId/notes');

    final response = await ApiClient.post(
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
    final bodyText = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(bodyText);
      return StudentNoteModel.fromJson(body['data']);
    }

    throw Exception(
      _extractErrorMessage(bodyText, 'Erro ao criar anotacao.'),
    );
  }

  Future<void> deleteNote(String token, String noteId) async {
    final url = Uri.parse('$_baseUrl/students/notes/$noteId');

    final response = await ApiClient.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final bodyText = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      _extractErrorMessage(bodyText, 'Erro ao excluir anotacao.'),
    );
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
