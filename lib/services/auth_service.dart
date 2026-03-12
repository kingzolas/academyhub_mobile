import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identifier': identifier,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Erro ao fazer login.');
      }
    } on Exception catch (_) {
      // [CORREÇÃO] Se a Exception foi lançada por nós ali em cima (Status != 200),
      // nós a repassamos para a tela não perder a mensagem (ex: "Senha incorreta").
      rethrow;
    } catch (error) {
      // Só entra aqui se for um erro físico (ex: servidor caiu, internet sem sinal)
      throw Exception('Não foi possível conectar ao servidor.');
    }
  }

  // --- [NOVO MÉTODO] Envia o Token do Firebase para o Backend ---
  Future<void> updateFcmToken(String fcmToken, String userJwtToken) async {
    // Atenção: A rota que criamos no backend é /users/refresh-token
    final url = Uri.parse('${ApiConfig.apiUrl}/users/refresh-token');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userJwtToken', // [IMPORTANTE] Autenticação
        },
        body: json.encode({
          'fcmToken': fcmToken, // O corpo que o controller espera
        }),
      );

      if (response.statusCode != 200) {
        // Apenas logamos o erro, não precisamos travar o app se isso falhar
        print("⚠️ Falha ao atualizar token FCM: ${response.body}");
      } else {
        print("✅ Token FCM sincronizado com sucesso!");
      }
    } catch (error) {
      print("❌ Erro de conexão ao enviar FCM: $error");
    }
  }
}
