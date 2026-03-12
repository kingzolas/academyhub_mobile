import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Ajuste o import abaixo para onde fica sua config de API
import '../config/api_config.dart';

class AuthStudentService {
  // Login do Aluno
  Future<Map<String, dynamic>> login(
      String enrollmentNumber, String password) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/auth/student/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'enrollmentNumber': enrollmentNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Salvar Token e Dados localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('student_token', data['token']);
        await prefs.setString('student_data', jsonEncode(data['student']));
        await prefs.setString(
            'user_role', 'student'); // Importante para o app saber quem é

        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erro ao fazer login.');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_token');
    await prefs.remove('student_data');
    await prefs.remove('user_role');
  }
}
