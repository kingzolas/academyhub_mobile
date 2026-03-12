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

  // Envia a foto da câmera para a API ler o gabarito
  Future<double?> processOmrImage(Uint8List imageBytes, String token) async {
    // Converte os bytes da foto de alta resolução para Base64
    String base64Image = base64Encode(imageBytes);

    // Substitua pela URL base correta do seu backend se necessário
    final response = await http.post(
      Uri.parse(
          '$baseUrl/process-omr'), // Ajustado para evitar duplicação de /exams/exams
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'imageBase64': base64Image,
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

  // 👇 NOVA FUNÇÃO: Busca a lista de alunos de uma prova (Modo Manual)
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

  // 4. Escanear via mobile e lançar nota
  Future<void> scanAndGradeSheet({
    required String qrCodeUuid,
    required double grade,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scan'),
      headers: _headers(token),
      body: jsonEncode({
        'qrCodeUuid': qrCodeUuid,
        'grade': grade,
      }),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['message'] ?? 'Erro ao computar nota';
      throw Exception(error);
    }
  }
}
