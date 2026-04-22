import 'dart:convert';

import 'package:academyhub_mobile/config/api_config.dart';
import 'package:academyhub_mobile/model/app_notification_model.dart';
import 'package:http/http.dart' as http;

class AppNotificationService {
  Uri _buildUri(String path) => Uri.parse('${ApiConfig.apiUrl}$path');

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<List<AppNotificationItem>> fetchNotifications({
    required String token,
    int limit = 30,
  }) async {
    final response = await http.get(
      _buildUri('/notifications/app?limit=$limit'),
      headers: _headers(token),
    );

    final payload = json.decode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload is Map && payload['message'] != null
            ? payload['message'].toString()
            : 'Não foi possível buscar notificações.',
      );
    }

    final rawItems =
        payload is Map ? (payload['items'] as List<dynamic>? ?? const []) : [];
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(AppNotificationItem.fromJson)
        .toList();
  }

  Future<void> markAsRead({
    required String token,
    required String notificationId,
  }) async {
    final response = await http.patch(
      _buildUri('/notifications/app/$notificationId/read'),
      headers: _headers(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Não foi possível marcar a notificação como lida.');
    }
  }

  Future<void> markAllAsRead({required String token}) async {
    final response = await http.patch(
      _buildUri('/notifications/app/read-all'),
      headers: _headers(token),
      body: json.encode({'limit': 60}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Não foi possível marcar as notificações como lidas.');
    }
  }
}
