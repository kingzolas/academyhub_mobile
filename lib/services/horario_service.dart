// lib/services/horario_service.dart
import 'dart:convert';
import 'package:academyhub_mobile/model/horario_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class HorarioService {
  final String _baseUrl = '${ApiConfig.apiUrl}/horarios';

  // Helper para criar headers com token
  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Busca horários com base em filtros.
  Future<List<HorarioModel>> getHorarios(String token,
      {Map<String, String>? filter}) async {
    final url = Uri.parse(_baseUrl).replace(queryParameters: filter);
    debugPrint('[HorarioService.get] Buscando em: $url');
    try {
      final response = await http.get(url, headers: _getHeaders(token));
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        List<dynamic> list = responseData;

        // --- [DEBUG ADICIONADO AQUI] ---
        List<HorarioModel> horarios = [];
        for (var jsonItem in list) {
          try {
            horarios.add(HorarioModel.fromJson(jsonItem));
          } catch (e) {
            debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            debugPrint('!!! ERRO AO PARSEAR HorarioModel.fromJson !!!');
            debugPrint('!!! JSON com Erro: $jsonItem');
            debugPrint('!!! Erro: $e');
            debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
          }
        }
        debugPrint(
            '[HorarioService.get] Sucesso. ${horarios.length} horários parseados.');
        return horarios;
        // --- [FIM DO DEBUG] ---
      } else {
        debugPrint(
            '[HorarioService.get] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao buscar horários.');
      }
    } catch (e) {
      debugPrint('[HorarioService.get] Catch Error: $e');
      throw Exception('Falha na comunicação ao buscar horários.');
    }
  }

  /// Cria um novo horário (uma aula na grade)
  Future<HorarioModel> createHorario(HorarioModel horario, String token) async {
    final url = Uri.parse(_baseUrl);
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(token),
        body: json.encode(
            horario.toJson()), // Usa o toJson do model (que envia os IDs)
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return HorarioModel.fromJson(
            responseData); // API retorna o horário populado
      } else {
        // Ex: "Professor não habilitado" ou "Conflito de horário"
        debugPrint(
            '[HorarioService.create] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao criar horário.');
      }
    } catch (e) {
      debugPrint('[HorarioService.create] Catch Error: $e');
      throw Exception(e.toString());
    }
  }

  /// Atualiza um horário (aula)
  Future<HorarioModel> updateHorario(
      String horarioId, Map<String, dynamic> updateData, String token) async {
    final url = Uri.parse('$_baseUrl/$horarioId');
    try {
      final response = await http.patch(
        url,
        headers: _getHeaders(token),
        body: json.encode(updateData),
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return HorarioModel.fromJson(
            responseData); // Retorna o horário atualizado e populado
      } else {
        debugPrint(
            '[HorarioService.update] Erro ${response.statusCode}: ${response.body}');
        throw Exception(
            responseData['message'] ?? 'Erro ao atualizar horário.');
      }
    } catch (e) {
      debugPrint('[HorarioService.update] Catch Error: $e');
      throw Exception(e.toString());
    }
  }

  /// Deleta um horário (uma aula da grade)
  Future<void> deleteHorario(String horarioId, String token) async {
    final url = Uri.parse('$_baseUrl/$horarioId');
    try {
      final response = await http.delete(url, headers: _getHeaders(token));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return; // Sucesso
      } else {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint(
            '[HorarioService.delete] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao deletar horário.');
      }
    } catch (e) {
      debugPrint('[HorarioService.delete] Catch Error: $e');
      throw Exception(e.toString());
    }
  }
}
