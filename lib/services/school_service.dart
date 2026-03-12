import 'dart:convert';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:academyhub_mobile/model/school_model.dart';

class SchoolService {
  // Buscar dados da escola
  Future<SchoolModel> getSchool(String schoolId, String token) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/schools/$schoolId');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    debugPrint("📩 [API RAW RESPONSE]: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return SchoolModel.fromJson(data);
    } else {
      throw Exception('Falha ao carregar escola: ${response.body}');
    }
  }

  // Atualizar escola (Multipart request por causa da logo)
  Future<void> updateSchool({
    required String schoolId,
    required String token,
    required Map<String, String> fields,
    XFile? logoFile,
  }) async {
    var request = http.MultipartRequest(
        'PATCH', Uri.parse('${ApiConfig.apiUrl}/schools/$schoolId'));

    request.headers['Authorization'] = 'Bearer $token';

    // Adiciona todos os campos de texto
    request.fields.addAll(fields);

    // Se tiver logo nova, anexa
    if (logoFile != null) {
      final bytes = await logoFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'logo',
          bytes,
          filename: logoFile.name,
        ),
      );
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar escola: ${response.body}');
    }
  }
}
