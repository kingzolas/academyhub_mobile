import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:academyhub_mobile/config/api_config.dart';

enum WebSocketStatus { connected, disconnected, connecting, error }

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;

  final StreamController<Map<String, dynamic>> _streamController =
      StreamController<Map<String, dynamic>>.broadcast();

  final ValueNotifier<WebSocketStatus> connectionStatus =
      ValueNotifier(WebSocketStatus.disconnected);

  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  String? _currentSchoolId;

  Map<String, dynamic>? _tryParseToMap(dynamic message) {
    try {
      if (message is Map<String, dynamic>) return message;

      if (message is String) {
        final trimmed = message.trim();
        if (trimmed.isEmpty) return null;

        final decoded = json.decode(trimmed);

        if (decoded is Map<String, dynamic>) return decoded;

        debugPrint(
            '[WebSocketService] Ignorado: JSON não é Map (${decoded.runtimeType}). Conteúdo: $decoded');
        return null;
      }

      debugPrint(
          '[WebSocketService] Ignorado: payload tipo ${message.runtimeType}. Conteúdo: $message');
      return null;
    } catch (e) {
      debugPrint('[WebSocketService] Erro ao decodificar: $e | msg=$message');
      return null;
    }
  }

  void connect(String schoolId) {
    if (_currentSchoolId == schoolId &&
        (connectionStatus.value == WebSocketStatus.connected ||
            connectionStatus.value == WebSocketStatus.connecting)) {
      debugPrint(
          "WebSocket já está conectado ou conectando na escola $schoolId.");
      return;
    }

    _currentSchoolId = schoolId;

    if (_channel != null) {
      disconnect();
    }

    try {
      debugPrint("Tentando conectar ao WebSocket na escola: $schoolId...");
      connectionStatus.value = WebSocketStatus.connecting;

      final String baseUrl = ApiConfig.wsUrl;
      final String separator = baseUrl.contains('?') ? '&' : '?';
      final String finalUrl = '$baseUrl${separator}schoolId=$schoolId';

      debugPrint("URL WS: $finalUrl");

      _channel = WebSocketChannel.connect(Uri.parse(finalUrl));

      connectionStatus.value = WebSocketStatus.connected;
      debugPrint("✅ Conectado ao WebSocket Server!");

      _channel!.stream.listen(
        (message) {
          final map = _tryParseToMap(message);
          if (map == null) return;

          // (Opcional) valida formato esperado
          if (!map.containsKey('type')) {
            debugPrint(
                '[WebSocketService] Ignorado: Map sem "type": ${jsonEncode(map)}');
            return;
          }

          _streamController.add(map);
        },
        onDone: () {
          debugPrint("🔌 Conexão WebSocket fechada pelo servidor.");
          connectionStatus.value = WebSocketStatus.disconnected;
          _reconnect();
        },
        onError: (error) {
          debugPrint("❌ Erro no WebSocket: $error.");
          connectionStatus.value = WebSocketStatus.error;
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint("Falha ao conectar ao WebSocket: $e");
      connectionStatus.value = WebSocketStatus.error;
      _reconnect();
    }
  }

  void _reconnect() {
    _channel = null;

    if (_currentSchoolId != null) {
      Future.delayed(const Duration(seconds: 5), () {
        debugPrint("Reconectando na escola $_currentSchoolId...");
        connect(_currentSchoolId!);
      });
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    connectionStatus.value = WebSocketStatus.disconnected;
    debugPrint("Desconectado do WebSocket.");
  }
}
