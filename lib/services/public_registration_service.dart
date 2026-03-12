import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:academyhub_mobile/config/api_config.dart'; // Sua config de URL base

class PublicRegistrationService {
  // Substitua pela sua URL base se não estiver usando o arquivo de config
  // Ex: const String baseUrl = "https://sua-api.onrender.com/api";

  Future<void> submitRegistrationRequest(Map<String, dynamic> data) async {
    final url =
        Uri.parse('${ApiConfig.apiUrl}/registration-requests/public/submit');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(data),
    );

    if (response.statusCode != 201) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Erro ao enviar solicitação.');
    }
  }
}
