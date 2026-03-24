// lib/services/api_client.dart
import 'dart:convert';
import 'package:academyhub_mobile/main.dart' as NavigationService;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// import 'navigation_service.dart';
import '../providers/auth_provider.dart';

class ApiClient {
  // O PULO DO GATO: O validador central!
  static void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint(
          '🚨 [ApiClient] Erro 401 interceptado! Token inválido ou expirado.');

      final context = NavigationService.navigatorKey.currentContext;
      if (context != null) {
        // Dispara o logout global que fizemos no AuthProvider
        Provider.of<AuthProvider>(context, listen: false).logout();
      }

      throw Exception('Sua sessão expirou. Faça login novamente.');
    }
  }

  // --- Wrappers para os métodos HTTP ---

  static Future<http.Response> get(Uri url,
      {Map<String, String>? headers}) async {
    final response = await http.get(url, headers: headers);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response =
        await http.post(url, headers: headers, body: body, encoding: encoding);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response =
        await http.put(url, headers: headers, body: body, encoding: encoding);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> patch(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response =
        await http.patch(url, headers: headers, body: body, encoding: encoding);
    _checkUnauthorized(response);
    return response;
  }

  static Future<http.Response> delete(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await http.delete(url,
        headers: headers, body: body, encoding: encoding);
    _checkUnauthorized(response);
    return response;
  }
}
