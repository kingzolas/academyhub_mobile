import 'dart:convert';
import 'package:academyhub_mobile/config/api_config.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  // AJUSTE 1: A rota no backend agora é /query
  final String _baseUrl = '${ApiConfig.baseUrl}/api/assistant/chat';

  Future<String> sendMessage({
    required String token,
    required String question, // Renomeado para clareza
    required List<dynamic> history,
  }) async {
    try {
      print('🛰️ Enviando pergunta para o RAG Agent...');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'question': question, // AJUSTE 2: O Backend espera 'question'
          'history': history,
        }),
      );

      print('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // AJUSTE 3: O Backend retorna { success: true, data: "texto..." }
        return data['data'] ?? 'Sem resposta da IA.';
      } else {
        final errorData = jsonDecode(response.body);
        // Tenta pegar a mensagem de erro ou usa o corpo bruto
        final errorMessage =
            errorData['message'] ?? errorData['error'] ?? response.body;
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('🚨 Erro no AssistantService: $e');
      rethrow; // Repassa o erro para o Provider tratar o retry
    }
  }
}
