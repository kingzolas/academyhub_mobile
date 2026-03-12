// lib/services/subject_service.dart
import 'dart:convert';
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SubjectService {
  final String _baseUrl = '${ApiConfig.apiUrl}/subjects';

  // Helper para criar headers com token
  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- Criar Disciplina ---
  Future<SubjectModel> createSubject(SubjectModel subject, String token) async {
    final url = Uri.parse(_baseUrl);
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(token),
        body: json.encode(subject.toJson()), // Usa o toJson do model
      );
      // Decodifica usando utf8 para garantir acentuação correta
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return SubjectModel.fromJson(responseData);
      } else {
        debugPrint(
            '[SubjectService.create] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao criar disciplina.');
      }
    } catch (e) {
      debugPrint('[SubjectService.create] Catch Error: $e');
      throw Exception('Falha na comunicação ao criar disciplina.');
    }
  }

  // --- Buscar Todas as Disciplinas (com Filtros) ---
  Future<List<SubjectModel>> getAllSubjects(String token,
      {Map<String, String>? filter}) async {
    final url = Uri.parse(_baseUrl).replace(queryParameters: filter);
    debugPrint('[SubjectService.getAll] Buscando em: $url');
    try {
      final response = await http.get(url, headers: _getHeaders(token));
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        List<dynamic> list = responseData;
        return list.map((json) => SubjectModel.fromJson(json)).toList();
      } else {
        debugPrint(
            '[SubjectService.getAll] Erro ${response.statusCode}: ${response.body}');
        throw Exception(
            responseData['message'] ?? 'Erro ao buscar disciplinas.');
      }
    } catch (e) {
      debugPrint('[SubjectService.getAll] Catch Error: $e');
      throw Exception('Falha na comunicação ao buscar disciplinas.');
    }
  }

  // --- Atualizar Disciplina ---
  Future<SubjectModel> updateSubject(
      String id, Map<String, dynamic> updateData, String token) async {
    final url = Uri.parse('$_baseUrl/$id');
    try {
      final response = await http.patch(
        url,
        headers: _getHeaders(token),
        body: json.encode(updateData),
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return SubjectModel.fromJson(responseData);
      } else {
        debugPrint(
            '[SubjectService.update] Erro ${response.statusCode}: ${response.body}');
        throw Exception(
            responseData['message'] ?? 'Erro ao atualizar disciplina.');
      }
    } catch (e) {
      debugPrint('[SubjectService.update] Catch Error: $e');
      throw Exception('Falha na comunicação ao atualizar disciplina.');
    }
  }

  // --- Deletar Disciplina ---
  Future<void> deleteSubject(String id, String token) async {
    final url = Uri.parse('$_baseUrl/$id');
    try {
      final response = await http.delete(url, headers: _getHeaders(token));

      // Sucesso
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }

      // Se a API retornar um erro (ex: disciplina em uso)
      else {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint(
            '[SubjectService.delete] Erro ${response.statusCode}: ${response.body}');
        // Lança o erro vindo da API
        throw Exception(
            responseData['message'] ?? 'Erro ao deletar disciplina.');
      }
    } catch (e) {
      debugPrint('[SubjectService.delete] Catch Error: $e');
      throw Exception(e.toString()); // Re-lança o erro
    }
  }
}
