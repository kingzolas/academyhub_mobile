import 'dart:convert';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:academyhub_mobile/model/registration_request_model.dart';
import 'package:flutter/foundation.dart';

class RegistrationRequestService {
  final String baseUrl = ApiConfig.apiUrl;

  // [ALTERADO] Agora busca TUDO (Pendente, Aprovado, Rejeitado)
  // Bate na rota router.get('/list', ...)
  Future<List<RegistrationRequest>> getAllRequests(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/registration-requests/list'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => RegistrationRequest.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar histórico de solicitações');
    }
  }

  // [ADICIONADO] Método de compatibilidade para o Provider antigo.
  // Resolve o erro "method 'getPendingRequests' isn't defined".
  // Ele busca tudo da API e faz o filtro localmente (Front-end), como exigido pelo novo fluxo.
  Future<List<RegistrationRequest>> getPendingRequests(String token) async {
    try {
      final allRequests = await getAllRequests(token);
      // Filtra apenas os pendentes na memória
      return allRequests.where((req) => req.status == 'PENDING').toList();
    } catch (e) {
      debugPrint("Erro getPendingRequests: $e");
      rethrow;
    }
  }

  // Método para Atualizar/Editar os dados da solicitação
  Future<void> updateRequestData(
      String token, String requestId, Map<String, dynamic> updatedData) async {
    final url = Uri.parse('$baseUrl/registration-requests/$requestId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updatedData),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Erro ao atualizar solicitação');
      }
    } catch (e) {
      debugPrint("Erro updateRequestData: $e");
      rethrow;
    }
  }

  Future<void> approveRequest(String token, String requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/registration-requests/$requestId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({}),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Erro ao aprovar');
      }
    } catch (e) {
      debugPrint("Erro approveRequest: $e");
      rethrow;
    }
  }

  Future<void> rejectRequest(
      String token, String requestId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/registration-requests/$requestId/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Erro ao rejeitar solicitação');
      }
    } catch (e) {
      debugPrint("Erro rejectRequest: $e");
      rethrow;
    }
  }
}
