import 'dart:convert';
import 'dart:typed_data';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/exam_model.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ExamApiService {
  final String baseUrl = '${ApiConfig.apiUrl}/exams';

  // Helper para headers
  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 1. Criar uma nova Prova
  Future<ExamModel> createExam(ExamModel exam, String token) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: _headers(token),
      body: jsonEncode(exam.toJson()),
    );

    if (response.statusCode == 201) {
      return ExamModel.fromJson(jsonDecode(response.body));
    } else {
      final error =
          jsonDecode(response.body)['message'] ?? 'Erro ao criar prova';
      throw Exception(error);
    }
  }

  // 👇 NOVO: Atualizar Prova (Se não estiver bloqueada)
  Future<ExamModel> updateExam(ExamModel exam, String token) async {
    if (exam.id == null)
      throw Exception("ID da prova não encontrado para atualização.");

    final response = await http.put(
      Uri.parse('$baseUrl/${exam.id}'),
      headers: _headers(token),
      body: jsonEncode(exam.toJson()),
    );

    if (response.statusCode == 200) {
      return ExamModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 403) {
      throw Exception(
          "Esta prova já foi impressa/corrigida e não pode ser alterada.");
    } else {
      final error =
          jsonDecode(response.body)['message'] ?? 'Erro ao atualizar prova';
      throw Exception(error);
    }
  }

  // 👇 NOVO: Duplicar Prova
  Future<ExamModel> duplicateExam(String examId, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$examId/duplicate'),
      headers: _headers(token),
    );

    if (response.statusCode == 201) {
      return ExamModel.fromJson(jsonDecode(response.body));
    } else {
      final error =
          jsonDecode(response.body)['message'] ?? 'Erro ao duplicar prova';
      throw Exception(error);
    }
  }

  // Envia a foto da câmera para a API ler o gabarito
  Future<double?> processOmrImage({
    required Uint8List imageBytes,
    required String token,
    required String correctionType, // 👇 Agora passamos para a API
  }) async {
    String base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse('$baseUrl/process-omr'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'imageBase64': base64Image,
        'correctionType':
            correctionType // O servidor vai pegar essa string e avisar o Python
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Pega a nota processada pelo Python. Usa num para evitar erros de casting entre int/double
        return (data['grade'] as num).toDouble();
      } else {
        throw Exception(
            data['message'] ?? 'Erro desconhecido ao processar a imagem na IA');
      }
    } else {
      throw Exception(
          'Falha de comunicação com o servidor. Status: ${response.statusCode}');
    }
  }

  // Método para buscar os dados do aluno ANTES de dar a nota
  Future<Map<String, dynamic>> verifySheetData(
      {required String qrCodeUuid, required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sheet/$qrCodeUuid/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ??
          'Erro ao ler dados da prova.');
    }
  }

  // 2. Buscar todas as provas da escola (com filtros opcionais)
  Future<List<ExamModel>> getExams(String token, {String? classId}) async {
    String url = baseUrl;
    if (classId != null) {
      url += '?class_id=$classId';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => ExamModel.fromJson(item)).toList();
    } else {
      throw Exception('Falha ao carregar provas.');
    }
  }

  // Busca a lista de alunos de uma prova (Modo Manual)
  Future<Map<String, dynamic>> getExamSheetsByExamId(
      String examId, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$examId/sheets'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Falha ao carregar lista de alunos.');
    }
  }

  // 3. Gerar o Lote de PDF
  Future<ExamSheetResponse> generateExamSheets({
    required String examId,
    required String token,
    List<String>? specificStudentIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$examId/generate-sheets'),
      headers: _headers(token),
      body: jsonEncode({
        if (specificStudentIds != null && specificStudentIds.isNotEmpty)
          'studentIds': specificStudentIds
      }),
    );

    if (response.statusCode == 200) {
      return ExamSheetResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body)['message'] ??
          'Erro ao gerar folhas da prova';
      throw Exception(error);
    }
  }

  // ATUALIZADO: Agora suporta enviar gabarito e notas divididas
  Future<void> scanAndGradeSheet({
    required String qrCodeUuid,
    required double grade,
    double? objectiveGrade,
    double? dissertativeGrade,
    List<Map<String, dynamic>>? answers,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scan'),
      headers: _headers(token),
      body: jsonEncode({
        'qrCodeUuid': qrCodeUuid,
        'grade': grade,
        if (objectiveGrade != null) 'objectiveGrade': objectiveGrade,
        if (dissertativeGrade != null) 'dissertativeGrade': dissertativeGrade,
        if (answers != null && answers.isNotEmpty) 'answers': answers,
      }),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['message'] ?? 'Erro ao computar nota';
      throw Exception(error);
    }
  }
}
