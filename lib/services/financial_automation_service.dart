import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:academyhub_mobile/config/api_config.dart';

class FinancialAutomationService {
  // Helper de cabeçalhos
  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- [MÉTODOS EXISTENTES ATUALIZADOS] ---

  // GET Logs (Agora suporta LIMIT para trazer tudo)
  // ✅ ATUALIZADO: suporta date para filtrar por dia (YYYY-MM-DD)
  Future<Map<String, dynamic>> getLogs({
    required String token,
    String? status,
    int page = 1,
    int limit = 20, // [NOVO] Padrão 20, mas permite mudar
    String? date, // ✅ NOVO
  }) async {
    // Monta a query string
    String query = 'page=$page&limit=$limit';

    if (status != null && status.isNotEmpty && status != 'Todos') {
      query += '&status=$status';
    }

    // ✅ NOVO: filtro por data (dia específico)
    if (date != null && date.isNotEmpty) {
      query += '&date=$date';
    }

    final url = Uri.parse('${ApiConfig.apiUrl}/notifications/logs?$query');
    final response = await http.get(url, headers: _headers(token));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erro ao buscar logs: ${response.body}');
    }
  }

  // [NOVO] Retry All Failed (Reenvia falhas do dia)
  // ✅ ATUALIZADO: pode reenviar falhas de um dia específico (YYYY-MM-DD)
  Future<Map<String, dynamic>> retryAllFailed({
    required String token,
    String? date, // ✅ NOVO
  }) async {
    String urlStr = '${ApiConfig.apiUrl}/notifications/retry-all';

    // ✅ NOVO: enviar date via query
    if (date != null && date.isNotEmpty) {
      urlStr += '?date=$date';
    }

    final url = Uri.parse(urlStr);
    final response = await http.post(url, headers: _headers(token));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erro ao reenviar falhas: ${response.body}');
    }
  }

  // GET Config
  Future<Map<String, dynamic>> getConfig({required String token}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/notifications/config');
    final response = await http.get(url, headers: _headers(token));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 404) {
      return {};
    } else {
      throw Exception('Erro ao buscar configurações: ${response.body}');
    }
  }

  // POST Config
  Future<Map<String, dynamic>> saveConfig({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/notifications/config');
    final response = await http.post(
      url,
      headers: _headers(token),
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erro ao salvar configurações: ${response.body}');
    }
  }

  // POST Trigger
  Future<void> triggerManualRun({required String token}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/notifications/trigger');
    final response = await http.post(url, headers: _headers(token));

    if (response.statusCode != 200) {
      throw Exception('Erro ao disparar automação: ${response.body}');
    }
  }

  // ✅ NOVO: POST Trigger Month (Envia todos os boletos do mês de uma vez)
  Future<bool> triggerMonthInvoices({required String token}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/notifications/trigger-month');
    final response = await http.post(url, headers: _headers(token));

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Erro ao disparar faturas do mês: ${response.body}');
    }
  }

  // GET Stats
  // ✅ ATUALIZADO: suporta date para stats por dia (YYYY-MM-DD)
  Future<Map<String, dynamic>> getStats({
    required String token,
    String? date, // ✅ NOVO
  }) async {
    String urlStr = '${ApiConfig.apiUrl}/notifications/stats';

    // ✅ NOVO: enviar date via query
    if (date != null && date.isNotEmpty) {
      urlStr += '?date=$date';
    }

    final url = Uri.parse(urlStr);
    final response = await http.get(url, headers: _headers(token));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erro ao buscar estatísticas: ${response.body}');
    }
  }

  // GET Forecast
  Future<Map<String, dynamic>> getForecast(
      {required String token, String? date}) async {
    String urlStr = '${ApiConfig.apiUrl}/notifications/forecast';
    if (date != null) {
      urlStr += '?date=$date';
    }

    final url = Uri.parse(urlStr);
    final response = await http.get(url, headers: _headers(token));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erro ao buscar previsão: ${response.body}');
    }
  }
}
