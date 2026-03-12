// lib/services/enrollment_service.dart
import 'dart:convert';
import 'package:academyhub_mobile/model/enrollment_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class EnrollmentService {
  final String _baseUrl = '${ApiConfig.apiUrl}/enrollments'; // Rota base

  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- Matricular Aluno ---
  Future<Enrollment> createEnrollment({
    required String studentId,
    required String classId,
    required double agreedFee,
    required String token,
  }) async {
    final url = Uri.parse(_baseUrl);
    final body = json.encode({
      'studentId': studentId,
      'classId': classId,
      'agreedFee': agreedFee,
    });
    debugPrint('[EnrollmentService.create] Enviando: $body');
    try {
      final response =
          await http.post(url, headers: _getHeaders(token), body: body);
      // Tratamento de erro específico para UTF-8
      final String responseBody = utf8.decode(response.bodyBytes);
      final responseData = json.decode(responseBody);

      if (response.statusCode == 201) {
        return Enrollment.fromJson(
            responseData); // API retorna a matrícula populada
      } else {
        debugPrint(
            '[EnrollmentService.create] Erro ${response.statusCode}: $responseBody');
        throw Exception(responseData['message'] ?? 'Erro ao criar matrícula.');
      }
    } catch (error, stackTrace) {
      debugPrint('[EnrollmentService.create] Catch Error: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Falha na comunicação ao criar matrícula.');
    }
  }

  // --- Buscar Matrículas (com Filtros) ---
  Future<List<Enrollment>> getEnrollments(String token,
      {Map<String, String>? filter}) async {
    final url = Uri.parse(_baseUrl).replace(queryParameters: filter);
    debugPrint('[EnrollmentService.get] Buscando em: $url');
    try {
      final response = await http.get(url, headers: _getHeaders(token));
      // Tratamento de erro específico para UTF-8
      final String responseBody = utf8.decode(response.bodyBytes);
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200) {
        List<dynamic> enrollmentList = responseData;
        return enrollmentList.map((json) => Enrollment.fromJson(json)).toList();
      } else {
        debugPrint(
            '[EnrollmentService.get] Erro ${response.statusCode}: $responseBody');
        throw Exception(
            responseData['message'] ?? 'Erro ao buscar matrículas.');
      }
    } catch (error, stackTrace) {
      debugPrint('[EnrollmentService.get] Catch Error: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Falha na comunicação ao buscar matrículas.');
    }
  }

  // --- Atualizar Status/Fee da Matrícula ---
  Future<Enrollment> updateEnrollment(String enrollmentId,
      Map<String, dynamic> updateData, String token) async {
    final url = Uri.parse('$_baseUrl/$enrollmentId');
    try {
      final response = await http.patch(
        url,
        headers: _getHeaders(token),
        body: json.encode(updateData),
      );
      final String responseBody = utf8.decode(response.bodyBytes);
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200) {
        return Enrollment.fromJson(responseData);
      } else {
        debugPrint(
            '[EnrollmentService.update] Erro ${response.statusCode}: $responseBody');
        throw Exception(
            responseData['message'] ?? 'Erro ao atualizar matrícula.');
      }
    } catch (error, stackTrace) {
      debugPrint('[EnrollmentService.update] Catch Error: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Falha na comunicação ao atualizar matrícula.');
    }
  }

  // --- Deletar Matrícula ---
  Future<void> deleteEnrollment(String enrollmentId, String token) async {
    final url = Uri.parse('$_baseUrl/$enrollmentId');
    try {
      final response = await http.delete(url, headers: _getHeaders(token));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return; // Sucesso
      } else {
        debugPrint(
            '[EnrollmentService.delete] Erro ${response.statusCode}: ${response.body}');
        try {
          // Tenta decodificar erro, mas pode não ter corpo
          final responseData = json.decode(utf8.decode(response.bodyBytes));
          throw Exception(
              responseData['message'] ?? 'Erro ao deletar matrícula.');
        } catch (_) {
          // Se não conseguir decodificar, lança erro genérico
          throw Exception('Erro ${response.statusCode} ao deletar matrícula.');
        }
      }
    } catch (error, stackTrace) {
      debugPrint('[EnrollmentService.delete] Catch Error: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Falha na comunicação ao deletar matrícula.');
    }
  }
}
