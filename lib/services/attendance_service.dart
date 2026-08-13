import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_client.dart';
import '../config/api_config.dart';
import '../model/attendance_model.dart';
import 'offline_attendance_store.dart';

class AttendanceConflictException implements Exception {
  final String message;
  const AttendanceConflictException(this.message);
  @override
  String toString() => message;
}

class AttendanceService {
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) {
      throw Exception('Nao autenticado. Faca login novamente.');
    }
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<AttendanceSheet>> getClassHistory(String classId) async {
    final token = await _getToken();
    final response = await ApiClient.get(
      Uri.parse('${ApiConfig.apiUrl}/attendance/history/$classId'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      throw Exception(
          _readErrorMessage(response.body, 'Erro ao carregar historico.'));
    }
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
    final history = (rawHistory is List ? rawHistory : <dynamic>[])
        .whereType<Map>()
        .map(
            (item) => AttendanceSheet.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return history;
  }

  Future<AttendanceSheet> getAttendanceSheet(
      String classId, DateTime date) async {
    try {
      final token = await _getToken();
      final dateStr = _dateKey(date);
      final response = await ApiClient.get(
        Uri.parse(
            '${ApiConfig.apiUrl}/attendance/class/$classId?date=$dateStr'),
        headers: _headers(token),
      );
      if (response.statusCode != 200) {
        throw Exception(_readErrorMessage(
          response.body,
          'Falha ao carregar lista de chamada: ${response.statusCode}',
        ));
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body['data'] is! Map) {
        throw Exception('Resposta de chamada invalida.');
      }
      final sheet =
          AttendanceSheet.fromJson(Map<String, dynamic>.from(body['data']));
      await OfflineAttendanceStore.instance.saveSheet(sheet);
      return sheet;
    } catch (_) {
      final cached =
          await OfflineAttendanceStore.instance.loadSheet(classId, date);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<bool> saveAttendance(AttendanceSheet sheet) async {
    await OfflineAttendanceStore.instance.enqueue(sheet);
    return true;
  }

  Future<AttendanceSheet> syncOperation(
      PendingAttendanceOperation operation) async {
    final token = await _getToken();
    final response = await ApiClient.post(
      Uri.parse('${ApiConfig.apiUrl}/attendance'),
      headers: _headers(token),
      body: jsonEncode({
        'operationId': operation.operationId,
        'baseVersion': operation.baseVersion,
        'clientUpdatedAt': operation.createdAt.toUtc().toIso8601String(),
        'classId': operation.classId,
        'date': operation.date,
        'records': operation.records,
        'metadata': {'device': 'mobile_offline_queue'},
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
      return AttendanceSheet.fromJson(
          Map<String, dynamic>.from(body['data'] as Map));
    }
    if (response.statusCode == 409) {
      throw AttendanceConflictException(
        _readErrorMessage(
            response.body, 'Conflito com uma chamada mais recente.'),
      );
    }
    throw Exception(
        _readErrorMessage(response.body, 'Erro ao salvar chamada.'));
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _readErrorMessage(String rawBody, String fallback) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}
