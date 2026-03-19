import 'dart:convert';
import 'package:academyhub_mobile/model/report_card_model.dart';
import 'package:http/http.dart' as http;

class ReportCardService {
  final String baseUrl;

  ReportCardService({
    required this.baseUrl,
  });

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParams]) {
    final uri = Uri.parse('$baseUrl$path');

    if (queryParams == null || queryParams.isEmpty) return uri;

    return uri.replace(
      queryParameters: queryParams.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    );
  }

  Future<List<ReportCardModel>> generateClassReportCards({
    required String token,
    required String classId,
    required String termId,
    required int schoolYear,
  }) async {
    final response = await http.post(
      _uri('/api/report-cards/generate'),
      headers: _headers(token),
      body: jsonEncode({
        'classId': classId,
        'termId': termId,
        'schoolYear': schoolYear,
      }),
    );

    final data = _decodeResponse(response);

    final list = (data['data'] as List<dynamic>? ?? [])
        .map((e) => ReportCardModel.fromJson(e))
        .toList();

    return list;
  }

  Future<ReportCardModel> getStudentReportCard({
    required String token,
    required String classId,
    required String termId,
    required int schoolYear,
    required String studentId,
  }) async {
    final response = await http.get(
      _uri('/api/report-cards/student', {
        'classId': classId,
        'termId': termId,
        'schoolYear': schoolYear,
        'studentId': studentId,
      }),
      headers: _headers(token),
    );

    final data = _decodeResponse(response);
    return ReportCardModel.fromJson(data['data']);
  }

  Future<ReportCardModel> getReportCardById({
    required String token,
    required String reportCardId,
  }) async {
    final response = await http.get(
      _uri('/api/report-cards/$reportCardId'),
      headers: _headers(token),
    );

    final data = _decodeResponse(response);
    return ReportCardModel.fromJson(data['data']);
  }

  Future<ReportCardModel> updateTeacherSubjectScore({
    required String token,
    required String reportCardId,
    required String subjectId,
    double? score,
    double? testScore,
    double? activityScore,
    double? participationScore,
    String observation = '',
  }) async {
    final bodyData = <String, dynamic>{
      'observation': observation,
    };
    if (score != null) bodyData['score'] = score;
    if (testScore != null) bodyData['testScore'] = testScore;
    if (activityScore != null) bodyData['activityScore'] = activityScore;
    if (participationScore != null)
      bodyData['participationScore'] = participationScore;

    final response = await http.patch(
      _uri('/api/report-cards/$reportCardId/subjects/$subjectId/score'),
      headers: _headers(token),
      body: jsonEncode(bodyData),
    );

    final data = _decodeResponse(response);
    return ReportCardModel.fromJson(data['data']);
  }

  Future<ReportCardModel> recalculateReportCardStatus({
    required String token,
    required String reportCardId,
  }) async {
    final response = await http.patch(
      _uri('/api/report-cards/$reportCardId/recalculate-status'),
      headers: _headers(token),
    );

    final data = _decodeResponse(response);
    return ReportCardModel.fromJson(data['data']);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body as Map<String, dynamic>;
    }

    final message =
        (body is Map<String, dynamic> ? body['message'] : null)?.toString() ??
            'Erro ao processar a requisição.';
    throw Exception(message);
  }
}
