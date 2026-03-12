import 'dart:convert';
import 'package:flutter/foundation.dart'; // Para usar debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Essencial para pegar o token
import '../config/api_config.dart';
import '../model/attendance_model.dart';

class AttendanceService {
  // Helper privado para pegar o token salvo no SharedPreferences
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      debugPrint(
          '⛔ [AttendanceService] Token não encontrado no SharedPreferences.');
      throw Exception('Não autenticado. Faça login novamente.');
    }
    return token;
  }

  Future<List<Map<String, dynamic>>> getClassHistory(String classId) async {
    final token = await _getToken();
    final url = Uri.parse('${ApiConfig.apiUrl}/attendance/history/$classId');

    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Erro ao carregar histórico.');
    }
  }

  // Busca a lista (seja salva ou proposta pelo backend)
  Future<AttendanceSheet> getAttendanceSheet(
      String classId, DateTime date) async {
    final token = await _getToken();
    final dateStr = date.toIso8601String().split('T')[0]; // Formato YYYY-MM-DD

    // Ajustado para usar apiUrl (padrão do seu projeto)
    final url = Uri.parse(
        '${ApiConfig.apiUrl}/attendance/class/$classId?date=$dateStr');

    debugPrint('🔄 [AttendanceService] Buscando chamada: $url');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    debugPrint('CODE: ${response.statusCode}');
    debugPrint('BODY: ${response.body}');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // O backend retorna: { type: 'saved'/'proposed', data: {...} }
      if (body['data'] != null) {
        return AttendanceSheet.fromJson(body['data']);
      } else {
        throw Exception('Formato de resposta inválido: campo data ausente.');
      }
    } else {
      debugPrint('❌ [AttendanceService] Erro: ${response.body}');
      throw Exception(
          'Falha ao carregar lista de chamada: ${response.statusCode}');
    }
  }

  // Salva ou Atualiza a chamada
  Future<void> saveAttendance(AttendanceSheet sheet) async {
    final token = await _getToken();
    final url = Uri.parse('${ApiConfig.apiUrl}/attendance');

    debugPrint('💾 [AttendanceService] Salvando chamada...');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(sheet.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      debugPrint('✅ [AttendanceService] Chamada salva com sucesso!');
    } else {
      debugPrint('❌ [AttendanceService] Erro ao salvar: ${response.body}');
      throw Exception('Erro ao salvar chamada: ${response.body}');
    }
  }
}
