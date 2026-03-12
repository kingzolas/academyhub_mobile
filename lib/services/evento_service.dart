// lib/services/evento_service.dart
import 'dart:convert';
import 'package:academyhub_mobile/model/evento_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class EventoService {
  final String _baseUrl = '${ApiConfig.apiUrl}/eventos';

  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Busca eventos (Provas, Feriados, etc.) com base em filtros.
  Future<List<EventoModel>> getEventos(String token,
      {Map<String, String>? filter}) async {
    final url = Uri.parse(_baseUrl).replace(queryParameters: filter);
    debugPrint('[EventoService.get] Buscando em: $url');
    try {
      final response = await http.get(url, headers: _getHeaders(token));
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        List<dynamic> list = responseData;

        // --- [DEBUG ADICIONADO AQUI] ---
        List<EventoModel> eventos = [];
        for (var jsonItem in list) {
          try {
            eventos.add(EventoModel.fromJson(jsonItem));
          } catch (e) {
            debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            debugPrint('!!! ERRO AO PARSEAR EventoModel.fromJson !!!');
            debugPrint('!!! JSON com Erro: $jsonItem');
            debugPrint('!!! Erro: $e');
            debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
          }
        }
        debugPrint(
            '[EventoService.get] Sucesso. ${eventos.length} eventos parseados.');
        return eventos;
        // --- [FIM DO DEBUG] ---
      } else {
        debugPrint(
            '[EventoService.get] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao buscar eventos.');
      }
    } catch (e) {
      debugPrint('[EventoService.get] Catch Error: $e');
      throw Exception('Falha na comunicação ao buscar eventos.');
    }
  }

  /// Cria um novo evento (Prova, Feriado, etc.)
  Future<EventoModel> createEvento(EventoModel evento, String token) async {
    final url = Uri.parse(_baseUrl);
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(token),
        body: json.encode(evento.toJson()), // Usa o toJson do model
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return EventoModel.fromJson(responseData); // Retorna o evento criado
      } else {
        debugPrint(
            '[EventoService.create] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao criar evento.');
      }
    } catch (e) {
      debugPrint('[EventoService.create] Catch Error: $e');
      throw Exception(e.toString());
    }
  }

  /// Atualiza um evento
  Future<EventoModel> updateEvento(
      String eventoId, Map<String, dynamic> updateData, String token) async {
    final url = Uri.parse('$_baseUrl/$eventoId');
    try {
      final response = await http.patch(
        url,
        headers: _getHeaders(token),
        body: json.encode(updateData),
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return EventoModel.fromJson(responseData);
      } else {
        debugPrint(
            '[EventoService.update] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao atualizar evento.');
      }
    } catch (e) {
      debugPrint('[EventoService.update] Catch Error: $e');
      throw Exception(e.toString());
    }
  }

  /// Deleta um evento
  Future<void> deleteEvento(String eventoId, String token) async {
    final url = Uri.parse('$_baseUrl/$eventoId');
    try {
      final response = await http.delete(url, headers: _getHeaders(token));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return; // Sucesso
      } else {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint(
            '[EventoService.delete] Erro ${response.statusCode}: ${response.body}');
        throw Exception(responseData['message'] ?? 'Erro ao deletar evento.');
      }
    } catch (e) {
      debugPrint('[EventoService.delete] Catch Error: $e');
      throw Exception(e.toString());
    }
  }
}
