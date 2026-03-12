import 'dart:convert';
import 'dart:developer'; // Importante para ver logs longos
import 'package:http/http.dart' as http;
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/dashboard_model.dart';

class DashboardService {
  Future<DashboardData> getDashboardMetrics(String token) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/dashboard');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // --- ÁREA DE DEBUG ---
        // Isso vai imprimir o JSON exato que o backend mandou.
        // Procure aqui dentro se "pix" ou "boleto" estão com valores > 0.
        log("🔍 JSON RECEBIDO DO BACKEND: ${response.body}");
        // ---------------------

        final data = jsonDecode(response.body);
        return DashboardData.fromJson(data);
      } else {
        log("❌ ERRO API: ${response.statusCode} - ${response.body}");
        throw Exception('Falha ao carregar dashboard: ${response.statusCode}');
      }
    } catch (e) {
      log("❌ ERRO CONEXÃO: $e");
      throw Exception('Erro de conexão: $e');
    }
  }
}
