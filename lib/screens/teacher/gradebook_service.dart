import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/evaluation_model.dart';
// IMPORTANTE: Importe o novo arquivo
import 'package:academyhub_mobile/model/class_grade_model.dart';

class GradebookService {
  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- AVALIAÇÕES ---
  Future<List<EvaluationModel>> getEvaluations(
      String token, String classId) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/evaluations/class/$classId');
    try {
      final response = await http.get(url, headers: _headers(token));
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((e) => EvaluationModel.fromJson(e)).toList();
      } else {
        throw Exception('Erro ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Falha ao conectar com servidor: $e');
    }
  }

  // --- NOTAS (Usando ClassGradeModel) ---
  Future<List<ClassGradeModel>> getGradesByClass(
      String token, String classId) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/grades/class/$classId');
    try {
      final response = await http.get(url, headers: _headers(token));
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        // Mapeia para o NOVO modelo
        return body.map((e) => ClassGradeModel.fromJson(e)).toList();
      } else {
        throw Exception('Erro ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Falha ao buscar notas: $e');
    }
  }

  // --- SALVAMENTO EM LOTE ---
  Future<void> saveBulkGrades({
    required String token,
    required String classId,
    required EvaluationModel evaluation,
    required List<ClassGradeModel> grades, // Recebe a lista do novo modelo
  }) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/grades/bulk');

    final Map<String, dynamic> payload = {
      'classId': classId,
      'evaluation': evaluation.toJson(),
      'grades': grades.map((g) => g.toBulkJson()).toList(),
    };

    try {
      final response = await http.post(
        url,
        headers: _headers(token),
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Erro ao salvar notas.');
      }
    } catch (e) {
      throw Exception('Falha no envio das notas: $e');
    }
  }
}
