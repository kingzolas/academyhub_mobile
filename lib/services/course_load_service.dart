import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:academyhub_mobile/model/course_load_model.dart';
import 'package:academyhub_mobile/config/api_config.dart';

class CourseLoadService {
  final String _apiBaseUrl = ApiConfig.apiUrl;

  /// Busca a Matriz Curricular (metas de horas) para uma turma/período
  Future<List<CourseLoadModel>> find(
      String token, String periodoId, String classId) async {
    final query = {
      'periodoId': periodoId,
      'classId': classId,
    };

    final uri =
        Uri.parse('$_apiBaseUrl/course-loads').replace(queryParameters: query);

    if (kDebugMode) {
      print('[CourseLoadService.find] GET ${uri.toString()}');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (kDebugMode) {
      print('[CourseLoadService.find] Response Code: ${response.statusCode}');
    }

    if (response.statusCode == 200) {
      final List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
      final List<CourseLoadModel> loads = body
          .map((dynamic item) =>
              CourseLoadModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return loads;
    } else {
      throw Exception('Falha ao buscar carga horária.');
    }
  }

  /// Salva (Cria/Atualiza) a Matriz Curricular inteira em lote
  Future<void> batchSave(String token, String periodoId, String classId,
      List<Map<String, dynamic>> loads) async {
    final uri = Uri.parse('$_apiBaseUrl/course-loads/batch');
    final body = json.encode({
      'periodoId': periodoId,
      'classId': classId,
      'loads': loads, // ex: [{'subjectId': '...', 'targetHours': 30.0}, ...]
    });

    if (kDebugMode) {
      print('[CourseLoadService.batchSave] POST ${uri.toString()}');
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (kDebugMode) {
      print(
          '[CourseLoadService.batchSave] Response Code: ${response.statusCode}');
    }

    if (response.statusCode != 200) {
      throw Exception('Falha ao salvar a matriz curricular.');
    }
  }
}
