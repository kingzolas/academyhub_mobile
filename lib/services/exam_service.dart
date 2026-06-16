import 'dart:convert';
import 'dart:typed_data';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/exam_model.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

const bool kOmrPerformanceDebug =
    bool.fromEnvironment('OMR_PERFORMANCE_DEBUG', defaultValue: false);

void _logOmrPerformance(String event, Map<String, Object?> data) {
  if (!kOmrPerformanceDebug) return;
  debugPrint('[OMR PERF MOBILE API] $event ${jsonEncode(data)}');
}

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
    if (exam.id == null) {
      throw Exception("ID da prova não encontrado para atualização.");
    }

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

  // 👇 ATUALIZADO: Agora retorna um Map inteiro e envia examId
  Future<Map<String, dynamic>> processOmrImage({
    required Uint8List imageBytes,
    required String token,
    required String correctionType,
    String? examId,
    String? correlationId,
  }) async {
    final encodeStopwatch = Stopwatch()..start();
    String base64Image = base64Encode(imageBytes);
    encodeStopwatch.stop();

    final endpoint = Uri.parse('$baseUrl/process-omr');
    final bodyMap = {
      'imageBase64': base64Image,
      'correctionType': correctionType,
      'examId': examId,
      if (correlationId != null) 'correlationId': correlationId,
    };
    final bodyString = jsonEncode(bodyMap);

    _logOmrPerformance('process_omr_request', {
      'correlationId': correlationId,
      'endpoint': endpoint.toString(),
      'usingLocalhost': ApiConfig.baseUrl.contains('localhost'),
      'imageBytes': imageBytes.length,
      'base64Chars': base64Image.length,
      'payloadBytes': utf8.encode(bodyString).length,
      'base64EncodeMs': encodeStopwatch.elapsedMilliseconds,
      'correctionType': correctionType,
      'examId': examId,
    });

    final requestStopwatch = Stopwatch()..start();
    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        if (correlationId != null) 'x-correlation-id': correlationId,
      },
      body: bodyString,
    );
    requestStopwatch.stop();

    _logOmrPerformance('process_omr_response', {
      'correlationId': correlationId,
      'statusCode': response.statusCode,
      'httpMs': requestStopwatch.elapsedMilliseconds,
      'responseBytes': response.bodyBytes.length,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Retorna o objeto inteiro em vez de tentar forçar a conversão de "grade"
        return data;
      } else {
        final hints = data['captureHints'];
        final firstHint =
            hints is List && hints.isNotEmpty ? hints.first.toString() : null;
        throw Exception(data['userMessage'] ??
            firstHint ??
            data['message'] ??
            data['error'] ??
            'A IA não conseguiu ler este formato.');
      }
    } else {
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = null;
      }

      final hints = data?['captureHints'];
      final firstHint =
          hints is List && hints.isNotEmpty ? hints.first.toString() : null;
      throw Exception(data?['userMessage'] ??
          firstHint ??
          data?['message'] ??
          data?['error'] ??
          'Falha de comunicação com o servidor. Status: ${response.statusCode}');
    }
  }

  // Método para buscar os dados do aluno ANTES de dar a nota
  Future<Map<String, dynamic>> verifySheetData(
      {required String qrCodeUuid,
      required String token,
      String? correlationId}) async {
    final endpoint = Uri.parse('$baseUrl/sheet/$qrCodeUuid/verify');
    _logOmrPerformance('verify_qr_request', {
      'correlationId': correlationId,
      'endpoint': endpoint.toString(),
      'usingLocalhost': ApiConfig.baseUrl.contains('localhost'),
    });

    final requestStopwatch = Stopwatch()..start();
    final response = await http.get(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        if (correlationId != null) 'x-correlation-id': correlationId,
      },
    );
    requestStopwatch.stop();

    _logOmrPerformance('verify_qr_response', {
      'correlationId': correlationId,
      'statusCode': response.statusCode,
      'httpMs': requestStopwatch.elapsedMilliseconds,
      'responseBytes': response.bodyBytes.length,
    });

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
    Map<String, dynamic>? correctionDetails,
    int? totalQuestions,
    int? correctCount,
    int? wrongCount,
    int? blankCount,
    int? multipleCount,
    int? uncertainCount,
    int? notDetectedCount,
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
        if (correctionDetails != null) 'correctionDetails': correctionDetails,
        if (totalQuestions != null) 'totalQuestions': totalQuestions,
        if (correctCount != null) 'correctCount': correctCount,
        if (wrongCount != null) 'wrongCount': wrongCount,
        if (blankCount != null) 'blankCount': blankCount,
        if (multipleCount != null) 'multipleCount': multipleCount,
        if (uncertainCount != null) 'uncertainCount': uncertainCount,
        if (notDetectedCount != null) 'notDetectedCount': notDetectedCount,
      }),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['message'] ?? 'Erro ao computar nota';
      throw Exception(error);
    }
  }
}
