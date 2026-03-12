import 'dart:async';
import 'package:flutter/material.dart';
import '../services/whatsapp_service.dart';

enum WhatsappConnectionState {
  loading,
  disconnected,
  pairing,
  connected,
  error
}

class WhatsappProvider with ChangeNotifier {
  final WhatsappService _service = WhatsappService();

  WhatsappConnectionState _state = WhatsappConnectionState.loading;
  String? _qrCodeBase64;
  String? _instanceName;
  Timer? _pollingTimer;

  WhatsappConnectionState get state => _state;
  String? get qrCodeBase64 => _qrCodeBase64;
  String? get instanceName => _instanceName;

  // Verifica o status atual
  Future<void> checkStatus(String token) async {
    try {
      _state = WhatsappConnectionState.loading;
      notifyListeners();

      final data = await _service.getStatus(token);
      final status = data['status']; // 'open', 'close', 'connecting'

      if (status == 'open' || status == 'connected') {
        _state = WhatsappConnectionState.connected;
        _instanceName = data['instanceName'];
        _stopPolling();
      } else {
        _state = WhatsappConnectionState.disconnected;
      }
    } catch (e) {
      _state = WhatsappConnectionState.error;
    }
    notifyListeners();
  }

  // Solicita o QR Code
  Future<void> generateQrCode(String token) async {
    try {
      _state = WhatsappConnectionState.loading;
      notifyListeners();

      final data = await _service.connect(token);

      if (data['status'] == 'open') {
        // Já estava conectado
        _state = WhatsappConnectionState.connected;
        _instanceName = data['instanceName'];
      } else if (data['qrcode'] != null &&
          data['qrcode'].toString().isNotEmpty) {
        // Recebeu QR Code válido
        _qrCodeBase64 = data['qrcode'];
        _state = WhatsappConnectionState.pairing;
        _startPolling(token);
      } else {
        // [CORREÇÃO] Se não veio QR Code e não tá open, deu erro na geração
        print("Erro: Backend não retornou QR Code.");
        _state = WhatsappConnectionState.error;
      }
    } catch (e) {
      print("Erro generateQrCode: $e");
      _state = WhatsappConnectionState.error;
    }
    notifyListeners();
  }

  // Desconecta
  Future<void> logout(String token) async {
    try {
      _state = WhatsappConnectionState.loading;
      notifyListeners();
      await _service.disconnect(token);

      // Força estado desconectado no front
      _state = WhatsappConnectionState.disconnected;
      _qrCodeBase64 = null;
      _stopPolling();
    } catch (e) {
      // Mesmo com erro, vamos considerar desconectado visualmente para permitir nova tentativa
      _state = WhatsappConnectionState.disconnected;
      print("Erro ao desconectar (mas limpando estado local): $e");
    }
    notifyListeners();
  }

  // Polling: Verifica status a cada 3 segundos
  void _startPolling(String token) {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final data = await _service.getStatus(token);
        if (data['status'] == 'open' || data['status'] == 'connected') {
          _state = WhatsappConnectionState.connected;
          _instanceName = data['instanceName'];
          _stopPolling();
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
