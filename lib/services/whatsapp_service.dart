import 'dart:convert';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
// import '../utils/constants.dart'; // Assumindo que você tenha uma constante BASE_URL, senão ajuste a URL abaixo

class WhatsappService {
  // Ajuste para a URL do seu backend (ex: http://localhost:3000/api)
  // Se estiver rodando no emulador Android use 10.0.2.2, se for Web/Desktop use localhost
  final String baseUrl = '${ApiConfig.baseUrl}/api';

  Future<Map<String, dynamic>> getStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/whatsapp/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Falha ao buscar status');
      }
    } catch (e) {
      debugPrint('Erro WhatsApp Service (Status): $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> connect(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/whatsapp/connect'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Falha ao gerar conexão');
      }
    } catch (e) {
      debugPrint('Erro WhatsApp Service (Connect): $e');
      rethrow;
    }
  }

  Future<void> disconnect(String token) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/whatsapp/disconnect'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      debugPrint('Erro WhatsApp Service (Disconnect): $e');
      rethrow;
    }
  }
}
