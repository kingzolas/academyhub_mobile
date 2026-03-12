// lib/services/class_service.dart
import 'dart:convert';
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ClassService {
  final String _baseUrl =
      '${ApiConfig.apiUrl}/classes'; // Rota base para turmas

  // --- [CORREÇÃO APLICADA AQUI] ---
  Map<String, String> _getHeaders(String? token) {
    // 1. O token agora é anulável (String?)

    // 2. Verificação de segurança ANTES de criar o header
    if (token == null) {
      debugPrint('❌ [_getHeaders] Tentativa de chamada de API sem token.');
      // Lança um erro que será pego pelo 'catch' da função chamadora
      throw Exception('Usuário não autenticado (token nulo).');
    }

    // 3. Se passou, cria o header válido
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- Criar Turma ---
  // [MODIFICADO] Aceita token anulável
  Future<ClassModel> createClass(ClassModel classData, String? token) async {
    final url = Uri.parse(_baseUrl);
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(token), // Agora é seguro
        body: json.encode(classData.toJson()),
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return ClassModel.fromJson(responseData);
      } else {
        debugPrint(
            '[ClassService.create] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao criar turma.');
      }
    } catch (error) {
      debugPrint('[ClassService.create] Catch Error: $error');
      // Relança o erro (seja do _getHeaders ou do http)
      throw Exception(error.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- Buscar Todas as Turmas (com Filtros) ---
  // [MODIFICADO] Aceita token anulável
  Future<List<ClassModel>> getAllClasses(String? token,
      {Map<String, String>? filter}) async {
    final url = Uri.parse(_baseUrl).replace(queryParameters: filter);
    debugPrint('[ClassService.getAll] Buscando em: $url');
    try {
      final response =
          await http.get(url, headers: _getHeaders(token)); // Agora é seguro
      final responseBody = utf8.decode(response.bodyBytes);
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200) {
        List<dynamic> classList = responseData;
        return classList.map((json) => ClassModel.fromJson(json)).toList();
      } else {
        debugPrint(
            '[ClassService.getAll] Erro ${response.statusCode}: $responseBody');
        throw Exception(responseData['message'] ?? 'Erro ao buscar turmas.');
      }
    } catch (error) {
      debugPrint('[ClassService.getAll] Catch Error: $error');
      throw Exception(error.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- Atualizar Turma ---
  // [MODIFICADO] Aceita token anulável
  Future<ClassModel> updateClass(
      String classId, Map<String, dynamic> updateData, String? token) async {
    final url = Uri.parse('$_baseUrl/$classId');
    try {
      final response = await http.patch(
        url,
        headers: _getHeaders(token), // Agora é seguro
        body: json.encode(updateData),
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return ClassModel.fromJson(responseData);
      } else {
        debugPrint(
            '[ClassService.update] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao atualizar turma.');
      }
    } catch (error) {
      debugPrint('[ClassService.update] Catch Error: $error');
      throw Exception(error.toString().replaceAll('Exception: ', ''));
    }
  }

  // --- Deletar Turma ---
  // [MODIFICADO] Aceita token anulável
  Future<void> deleteClass(String classId, String? token) async {
    final url = Uri.parse('$_baseUrl/$classId');
    try {
      final response =
          await http.delete(url, headers: _getHeaders(token)); // Agora é seguro

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        debugPrint(
            '[ClassService.delete] Erro ${response.statusCode}: ${response.body}');
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(responseData['message'] ?? 'Erro ao deletar turma.');
      }
    } catch (error) {
      debugPrint('[ClassService.delete] Catch Error: $error');
      throw Exception(error.toString().replaceAll('Exception: ', ''));
    }
  }
}
