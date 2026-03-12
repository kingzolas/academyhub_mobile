import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Importe seu model de Term
import 'package:academyhub_mobile/model/term_model.dart';
// Importa a sua configuração de API
import 'package:academyhub_mobile/config/api_config.dart'; // <-- Ajuste este caminho se necessário

class TermService {
  final String _apiBaseUrl = ApiConfig.apiUrl;

  /// Busca uma lista de Termos (Períodos/Bimestres)
  ///
  /// [token] O token JWT para autenticação.
  /// [filter] Um Map para filtros de query, ex: {'schoolYearId': '123'}
  Future<List<TermModel>> find(
      String token, Map<String, dynamic> filter) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/terms').replace(
        queryParameters: filter,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        print('[TermService.find] GET ${uri.toString()}');
        print('[TermService.find] Response Code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        print('[TermService.find] Response BODY: ${response.body}');
        final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
        final List<TermModel> terms = body
            .map((dynamic item) =>
                TermModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return terms;
      } else {
        try {
          final dynamic body = json.decode(response.body);
          throw Exception(body['message'] ?? 'Falha ao buscar períodos.');
        } catch (e) {
          throw Exception(
              'Falha ao buscar períodos (código ${response.statusCode})');
        }
      }
    } catch (e) {
      print('Erro em TermService.find: $e');
      throw Exception('Erro de conexão ao buscar períodos: $e');
    }
  }

  /// Cria um novo Termo (Período/Bimestre)
  ///
  /// [token] O token JWT para autenticação.
  /// [data] Um Map com os dados do novo período (schoolYearId, titulo, etc.).
  Future<TermModel> create(String token, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/terms');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (kDebugMode) {
        print('[TermService.create] POST ${uri.toString()}');
        print('[TermService.create] Response Code: ${response.statusCode}');
      }

      final dynamic body = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return TermModel.fromJson(body as Map<String, dynamic>);
      } else {
        throw Exception(body['message'] ?? 'Falha ao criar período.');
      }
    } catch (e) {
      print('Erro em TermService.create: $e');
      throw Exception('Erro de conexão ao criar período: $e');
    }
  }

  /// Atualiza um Termo (Período/Bimestre) existente
  ///
  /// [token] O token JWT para autenticação.
  /// [id] O ID do período a ser atualizado.
  /// [data] Um Map com os dados a serem atualizados.
  Future<TermModel> update(
      String token, String id, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/terms/$id');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (kDebugMode) {
        print('[TermService.update] PUT ${uri.toString()}');
        print('[TermService.update] Response Code: ${response.statusCode}');
      }

      final dynamic body = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return TermModel.fromJson(body as Map<String, dynamic>);
      } else {
        throw Exception(body['message'] ?? 'Falha ao atualizar período.');
      }
    } catch (e) {
      print('Erro em TermService.update: $e');
      throw Exception('Erro de conexão ao atualizar período: $e');
    }
  }

  /// Deleta um Termo (Período/Bimestre)
  ///
  /// [token] O token JWT para autenticação.
  /// [id] O ID do período a ser deletado.
  Future<void> delete(String token, String id) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/terms/$id');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        print('[TermService.delete] DELETE ${uri.toString()}');
        print('[TermService.delete] Response Code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        return; // Sucesso
      } else {
        try {
          final dynamic body = json.decode(response.body);
          throw Exception(body['message'] ?? 'Falha ao deletar período.');
        } catch (e) {
          throw Exception(
              'Falha ao deletar período (código ${response.statusCode})');
        }
      }
    } catch (e) {
      print('Erro em TermService.delete: $e');
      throw Exception('Erro de conexão ao deletar período: $e');
    }
  }
}
