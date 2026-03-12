import 'dart:convert';
import 'package:academyhub_mobile/model/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class UserService {
  final String _baseUrl = '${ApiConfig.apiUrl}/users';

  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<User> createStaff(Map<String, dynamic> staffData, String token) async {
    final url = Uri.parse('${ApiConfig.apiUrl}/users/staff');

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(token),
        body: json.encode(staffData),
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return User.fromJson(responseData);
      } else {
        // [AJUSTE] Lê a mensagem amigável do backend
        debugPrint(
            '[UserService.createStaff] Erro ${response.statusCode}: ${response.body}');
        throw Exception(
            responseData['message'] ?? 'Erro ao criar funcionário.');
      }
    } catch (e) {
      debugPrint('[UserService.createStaff] Catch Error: $e');
      throw e; // Relança o erro original (contendo a mensagem da API)
    }
  }

  Future<List<User>> getAllUsers(String token) async {
    final url = Uri.parse(_baseUrl);
    try {
      final response = await http.get(url, headers: _getHeaders(token));
      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        return userFromJson(responseBody);
      } else {
        final responseData = json.decode(responseBody);
        throw Exception(responseData['message'] ?? 'Erro ao buscar usuários.');
      }
    } catch (e) {
      debugPrint('[UserService.getAllUsers] Catch Error: $e');
      throw Exception('Falha na comunicação ao buscar usuários.');
    }
  }

  Future<User> getUserById(String id, String token) async {
    final url = Uri.parse('$_baseUrl/$id');
    try {
      final response = await http.get(url, headers: _getHeaders(token));
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return User.fromJson(responseData);
      } else {
        throw Exception(responseData['message'] ?? 'Usuário não encontrado.');
      }
    } catch (e) {
      debugPrint('[UserService.getUserById] Catch Error: $e');
      throw Exception('Falha na comunicação ao buscar usuário.');
    }
  }

  Future<User> updateStaff(
      String id, Map<String, dynamic> updateData, String token) async {
    final url = Uri.parse('$_baseUrl/$id');
    try {
      final response = await http.patch(
        url,
        headers: _getHeaders(token),
        body: json.encode(updateData),
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return User.fromJson(responseData);
      } else {
        // [AJUSTE] Lê mensagem de erro específica
        debugPrint(
            '[UserService.updateStaff] Erro ${response.statusCode}: ${response.body}');
        throw Exception(
            responseData['message'] ?? 'Erro ao atualizar usuário.');
      }
    } catch (e) {
      debugPrint('[UserService.updateStaff] Catch Error: $e');
      throw e; // Relança para o provider
    }
  }

  Future<User?> inactivateUser(String id, String token) async {
    final url = Uri.parse('$_baseUrl/$id/inactivate');

    try {
      final response = await http.patch(
        url,
        headers: _getHeaders(token),
      );

      final raw = utf8.decode(response.bodyBytes);

      debugPrint('[UserService.inactivateUser] RAW RESPONSE: $raw');

      dynamic decoded;

      try {
        decoded = json.decode(raw);
      } catch (_) {
        // resposta não é JSON (ex: "OK")
        decoded = raw;
      }

      if (response.statusCode == 200) {
        // ✅ Caso ideal: { user: {...} }
        if (decoded is Map<String, dynamic> && decoded['user'] != null) {
          return User.fromJson(decoded['user']);
        }

        // ✅ Caso backend retornou o próprio usuário direto
        if (decoded is Map<String, dynamic> && decoded['id'] != null) {
          return User.fromJson(decoded);
        }

        // ✅ Caso backend só retornou mensagem
        debugPrint(
            '[UserService.inactivateUser] Backend retornou apenas mensagem. Ignorando parse de usuário.');

        return null;
      } else {
        if (decoded is Map<String, dynamic>) {
          throw Exception(decoded['message'] ?? 'Erro ao inativar usuário.');
        }

        throw Exception('Erro ao inativar usuário.');
      }
    } catch (e) {
      debugPrint('[UserService.inactivateUser] Catch Error: $e');
      throw e;
    }
  }

  Future<User?> reactivateUser(String id, String token) async {
    final url = Uri.parse('$_baseUrl/$id/reactivate');

    final response = await http.patch(url, headers: _getHeaders(token));
    final raw = utf8.decode(response.bodyBytes);

    dynamic decoded;
    try {
      decoded = json.decode(raw);
    } catch (_) {
      decoded = raw;
    }

    if (response.statusCode == 200) {
      if (decoded is Map<String, dynamic> &&
          decoded['user'] is Map<String, dynamic>) {
        return User.fromJson(decoded['user']);
      }
      return null;
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(decoded['message'] ?? 'Erro ao reativar usuário.');
    }
    throw Exception('Erro ao reativar usuário.');
  }
}
