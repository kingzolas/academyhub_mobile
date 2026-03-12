import 'dart:convert';
import 'dart:typed_data';
import 'package:academyhub_mobile/model/academic_record_model.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

class StudentService {
  Map<String, String> _getHeaders(String? token) {
    if (token == null) {
      debugPrint('❌ [_getHeaders] ERRO: O token recebido é NULO.');
      throw Exception('Usuário não autenticado (token nulo).');
    }
    return {
      'Authorization': 'Bearer $token',
    };
  }

  // --- CREATE (COM FOTO OPCIONAL) ---
  Future<Student> createStudent(Map<String, dynamic> studentData, String? token,
      {Uint8List? imageBytes, String? imageFilename}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/students');
    debugPrint('--- [DEBUG] Criando aluno (Multipart) em: $url ---');

    try {
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(_getHeaders(token));

      // Adiciona campos de texto e JSONs complexos
      studentData.forEach((key, value) {
        if (value != null) {
          if (value is Map || value is List) {
            request.fields[key] = json.encode(value);
          } else {
            request.fields[key] = value.toString();
          }
        }
      });

      // Adiciona arquivo se existir
      if (imageBytes != null && imageFilename != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'photo', // Nome do campo esperado pelo Multer no backend
          imageBytes,
          filename: imageFilename,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      final responseBody = utf8.decode(response.bodyBytes);
      debugPrint('[DEBUG] Create Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        return Student.fromJson(json.decode(responseBody));
      } else {
        final errorData = json.decode(responseBody);
        throw Exception(errorData['message'] ?? 'Erro ao cadastrar aluno.');
      }
    } catch (e) {
      debugPrint('[StudentService.create] Erro: $e');
      throw Exception('Falha na criação: $e');
    }
  }

  // --- UPDATE (COM FOTO OPCIONAL) ---
  Future<Student> updateStudent(
      String studentId, String? token, Map<String, dynamic> studentData,
      {Uint8List? imageBytes, String? imageFilename}) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/students/$studentId');
    debugPrint('--- [DEBUG] Atualizando aluno em: $url ---');

    try {
      http.Response response;

      // Se tiver imagem, usamos Multipart
      if (imageBytes != null) {
        var request = http.MultipartRequest('PUT', url);
        request.headers.addAll(_getHeaders(token));

        studentData.forEach((key, value) {
          if (value != null) {
            if (value is Map || value is List) {
              request.fields[key] = json.encode(value);
            } else {
              request.fields[key] = value.toString();
            }
          }
        });

        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          imageBytes,
          filename: imageFilename ?? 'photo.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));

        var streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // Se NÃO tiver imagem, usamos JSON padrão (headers manuais)
        response = await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(studentData),
        );
      }

      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        return Student.fromJson(json.decode(responseBody));
      } else {
        final errorData = json.decode(responseBody);
        throw Exception(errorData['message'] ?? 'Erro ao atualizar aluno.');
      }
    } catch (e) {
      debugPrint('[StudentService.update] Erro: $e');
      throw Exception('Falha na atualização: $e');
    }
  }

  // --- GET PHOTO (NOVO) ---
  Future<Uint8List?> getStudentPhoto(String studentId, String? token) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/students/$studentId/photo');
    try {
      final response = await http.get(
        url,
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Erro ao buscar foto: $e');
      return null;
    }
  }

  // --- GET ALL ---
  Future<List<Student>> getStudents(String? token) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/students');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        return studentFromJson(responseBody);
      } else {
        final responseData = json.decode(responseBody);
        throw Exception(responseData['message'] ?? 'Erro ao buscar alunos.');
      }
    } catch (error) {
      debugPrint('--- [DEBUG] ERRO (getStudents) ---');
      debugPrint('Erro: $error');
      throw Exception(error.toString());
    }
  }

  // --- GET BY ID ---
  Future<Student> getStudentById(String studentId, String? token) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/students/$studentId');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        return Student.fromJson(json.decode(responseBody));
      } else {
        final responseData = json.decode(responseBody);
        throw Exception(responseData['message'] ?? 'Erro ao buscar aluno.');
      }
    } catch (error) {
      throw Exception(error.toString());
    }
  }

  // --- GET BIRTHDAYS ---
  Future<List<Student>> getUpcomingBirthdays(String? token) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/students/birthdays');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        return studentFromJson(responseBody);
      } else {
        final responseData = json.decode(responseBody);
        throw Exception(
            responseData['message'] ?? 'Erro ao buscar aniversariantes.');
      }
    } catch (error) {
      throw Exception(error.toString());
    }
  }

  // --- ADD HISTORY ---
  Future<List<AcademicRecord>> addHistoryRecord(
      String? token, String studentId, AcademicRecord recordData) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/students/$studentId/history');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(recordData.toJson()),
      );
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode == 201) {
        Iterable list = json.decode(responseBody);
        return List<AcademicRecord>.from(
            list.map((x) => AcademicRecord.fromJson(x)));
      } else {
        throw Exception('Falha ao adicionar registro: $responseBody');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- UPDATE HISTORY ---
  Future<List<AcademicRecord>> updateHistoryRecord(String? token,
      String studentId, String recordId, AcademicRecord recordData) async {
    final url =
        Uri.parse('${ApiConfig.apiUrl}/students/$studentId/history/$recordId');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(recordData.toJson()),
      );
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        Iterable list = json.decode(responseBody);
        return List<AcademicRecord>.from(
            list.map((x) => AcademicRecord.fromJson(x)));
      } else {
        throw Exception('Falha ao atualizar registro: $responseBody');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- DELETE HISTORY ---
  Future<List<AcademicRecord>> deleteHistoryRecord(
      String? token, String studentId, String recordId) async {
    final url =
        Uri.parse('${ApiConfig.apiUrl}/students/$studentId/history/$recordId');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        Iterable list = json.decode(responseBody);
        return List<AcademicRecord>.from(
            list.map((x) => AcademicRecord.fromJson(x)));
      } else {
        throw Exception('Falha ao deletar registro: $responseBody');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
