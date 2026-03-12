import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Importe seu model de SchoolYear
import 'package:academyhub_mobile/model/schoolyear_model.dart';
// Importa a sua configuração de API
import 'package:academyhub_mobile/config/api_config.dart'; // <-- Ajuste este caminho se necessário

class SchoolYearService {
  final String _apiBaseUrl = ApiConfig.apiUrl;

  /// Busca uma lista de Anos Letivos
  ///
  /// [token] O token JWT para autenticação.
  /// [filter] Um Map para filtros de query, ex: {'schoolId': '123'}
  Future<List<SchoolYearModel>> find(
      String token, Map<String, dynamic> filter) async {
    try {
      // Constrói a URI com os parâmetros de query
      // Ex: http://localhost:3000/api/school-years?schoolId=123
      final uri = Uri.parse('$_apiBaseUrl/school-years').replace(
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
        print('[SchoolYearService.find] GET ${uri.toString()}');
        print('[SchoolYearService.find] Response Code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        // Decodifica o corpo da resposta (que é uma Lista de objetos)
        final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));

        // Mapeia a lista de JSON para uma lista de SchoolYearModel
        final List<SchoolYearModel> schoolYears = body
            .map((dynamic item) =>
                SchoolYearModel.fromJson(item as Map<String, dynamic>))
            .toList();

        return schoolYears;
      } else {
        // Tenta decodificar a mensagem de erro do backend
        try {
          final dynamic body = json.decode(response.body);
          throw Exception(body['message'] ?? 'Falha ao buscar anos letivos.');
        } catch (e) {
          throw Exception(
              'Falha ao buscar anos letivos (código ${response.statusCode})');
        }
      }
    } catch (e) {
      print('Erro em SchoolYearService.find: $e');
      throw Exception('Erro de conexão ao buscar anos letivos: $e');
    }
  }

  /// Cria um novo Ano Letivo
  ///
  /// [token] O token JWT para autenticação.
  /// [data] Um Map com os dados do novo ano letivo (year, startDate, endDate, schoolId).
  Future<SchoolYearModel> create(
      String token, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/school-years');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (kDebugMode) {
        print('[SchoolYearService.create] POST ${uri.toString()}');
        print(
            '[SchoolYearService.create] Response Code: ${response.statusCode}');
      }

      final dynamic body = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return SchoolYearModel.fromJson(body as Map<String, dynamic>);
      } else {
        throw Exception(body['message'] ?? 'Falha ao criar ano letivo.');
      }
    } catch (e) {
      print('Erro em SchoolYearService.create: $e');
      throw Exception('Erro de conexão ao criar ano letivo: $e');
    }
  }

  /// Atualiza um Ano Letivo existente
  ///
  /// [token] O token JWT para autenticação.
  /// [id] O ID do ano letivo a ser atualizado.
  /// [data] Um Map com os dados a serem atualizados.
  Future<SchoolYearModel> update(
      String token, String id, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/school-years/$id');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      if (kDebugMode) {
        print('[SchoolYearService.update] PUT ${uri.toString()}');
        print(
            '[SchoolYearService.update] Response Code: ${response.statusCode}');
      }

      final dynamic body = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return SchoolYearModel.fromJson(body as Map<String, dynamic>);
      } else {
        throw Exception(body['message'] ?? 'Falha ao atualizar ano letivo.');
      }
    } catch (e) {
      print('Erro em SchoolYearService.update: $e');
      throw Exception('Erro de conexão ao atualizar ano letivo: $e');
    }
  }

  /// Deleta um Ano Letivo
  ///
  /// [token] O token JWT para autenticação.
  /// [id] O ID do ano letivo a ser deletado.
  Future<void> delete(String token, String id) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/school-years/$id');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        print('[SchoolYearService.delete] DELETE ${uri.toString()}');
        print(
            '[SchoolYearService.delete] Response Code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        return; // Sucesso
      } else {
        try {
          final dynamic body = json.decode(response.body);
          throw Exception(body['message'] ?? 'Falha ao deletar ano letivo.');
        } catch (e) {
          throw Exception(
              'Falha ao deletar ano letivo (código ${response.statusCode})');
        }
      }
    } catch (e) {
      print('Erro em SchoolYearService.delete: $e');
      throw Exception('Erro de conexão ao deletar ano letivo: $e');
    }
  }
}
