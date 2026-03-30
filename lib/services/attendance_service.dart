import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../model/attendance_model.dart';

class AttendanceService {
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      debugPrint(
          'â›” [AttendanceService] Token não encontrado no SharedPreferences.');
      throw Exception('Não autenticado. Faça login novamente.');
    }
    return token;
  }

  Future<List<AttendanceSheet>> getClassHistory(String classId) async {
    final token = await _getToken();
    final url = Uri.parse('${ApiConfig.apiUrl}/attendance/history/$classId');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final dynamic rawHistory = decoded is Map
          ? (decoded['data'] is List
              ? decoded['data']
              : decoded['data'] is Map
                  ? [decoded['data']]
                  : decoded['records'] is List
                      ? decoded['records']
                      : <dynamic>[])
          : decoded;
      final rawList = rawHistory is List ? rawHistory : <dynamic>[];

      final history = rawList
          .whereType<dynamic>()
          .map((item) {
            if (item is Map<String, dynamic>) {
              return AttendanceSheet.fromJson(item);
            }
            if (item is Map) {
              return AttendanceSheet.fromJson(Map<String, dynamic>.from(item));
            }
            return null;
          })
          .whereType<AttendanceSheet>()
          .toList();

      history.sort((a, b) => b.date.compareTo(a.date));
      return history;
    }

    throw Exception(
      _readErrorMessage(response.body, 'Erro ao carregar histórico.'),
    );
  }

  Future<AttendanceSheet> getAttendanceSheet(
      String classId, DateTime date) async {
    final token = await _getToken();
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body['data'] != null) {
        return AttendanceSheet.fromJson(
            Map<String, dynamic>.from(body['data']));
      }

      throw Exception('Formato de resposta inválido: campo data ausente.');
    }

    debugPrint('❌ [AttendanceService] Erro: ${response.body}');
    throw Exception(
      _readErrorMessage(
        response.body,
        'Falha ao carregar lista de chamada: ${response.statusCode}',
      ),
    );
  }

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
      return;
    }

    debugPrint('❌ [AttendanceService] Erro ao salvar: ${response.body}');
    throw Exception(
      _readErrorMessage(response.body, 'Erro ao salvar chamada.'),
    );
  }

  String _readErrorMessage(String rawBody, String fallback) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {
      // Fallback below.
    }
    return fallback;
  }
}
