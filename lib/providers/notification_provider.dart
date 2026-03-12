import 'package:flutter/material.dart';
import 'package:academyhub_mobile/model/notification_log_model.dart';
import 'package:academyhub_mobile/services/financial_automation_service.dart';

class FinancialAutomationProvider with ChangeNotifier {
  final FinancialAutomationService _service = FinancialAutomationService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // --- LOGS (Lista Paginada) ---
  List<NotificationLog> _logs = [];
  List<NotificationLog> get logs => _logs;

  int _currentPage = 1;
  int _totalPages = 1;
  int get totalPages => _totalPages;

  // --- CONFIG ---
  Map<String, dynamic> _config = {};
  Map<String, dynamic> get config => _config;

  // --- STATS (Contadores Reais do Dia) ---
  Map<String, dynamic> _stats = {
    'queued': 0,
    'processing': 0,
    'sent': 0,
    'failed': 0,
    'total_today': 0
  };
  Map<String, dynamic> get stats => _stats;

  // --- FORECAST (Previsão do Futuro) ---
  Map<String, dynamic> _forecast = {};
  Map<String, dynamic> get forecast => _forecast;
  bool _isLoadingForecast = false;
  bool get isLoadingForecast => _isLoadingForecast;

  // --- ACTIONS ---

  // [ATUALIZADO] Aceita limit para permitir 'ver tudo'
  // ✅ NOVO: Aceita date para filtrar logs por dia (YYYY-MM-DD)
  Future<void> fetchLogs({
    required String token,
    String? status,
    int page = 1,
    int limit = 20, // Padrão 20
    bool refresh = false,
    String? date, // ✅ NOVO
  }) async {
    if (refresh) {
      _logs = [];
      _currentPage = 1;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Passa o limit e date para o service
      final response = await _service.getLogs(
        token: token,
        status: status,
        page: page,
        limit: limit,
        date: date, // ✅ NOVO
      );

      final List<dynamic> logsJson = response['logs'] ?? [];
      _logs = logsJson.map((json) => NotificationLog.fromJson(json)).toList();
      _totalPages = response['pages'] ?? 1;
      _currentPage = page;
    } catch (e) {
      // ignore: avoid_print
      print("Erro no Provider Automation (Logs): $e");
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // [NOVO] Reenvia todas as falhas do dia
  // ✅ ATUALIZADO: pode reenviar falhas de um dia específico (YYYY-MM-DD)
  Future<bool> retryAllFailed({required String token, String? date}) async {
    try {
      // Chama o serviço
      await _service.retryAllFailed(token: token, date: date); // ✅ NOVO
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Erro ao reenviar falhas em massa: $e");
      return false;
    }
  }

  // ✅ ATUALIZADO: stats por dia (YYYY-MM-DD)
  Future<void> fetchStats({required String token, String? date}) async {
    try {
      final data = await _service.getStats(token: token, date: date); // ✅ NOVO
      _stats = data;
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print("Erro ao buscar stats: $e");
    }
  }

  Future<void> fetchForecast({required String token}) async {
    _isLoadingForecast = true;
    notifyListeners();
    try {
      final data = await _service.getForecast(token: token);
      _forecast = data;
    } catch (e) {
      // ignore: avoid_print
      print("Erro ao buscar forecast: $e");
    } finally {
      _isLoadingForecast = false;
      notifyListeners();
    }
  }

  Future<void> fetchConfig({required String token}) async {
    try {
      final data = await _service.getConfig(token: token);
      _config = data;
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print("Erro ao buscar config: $e");
    }
  }

  Future<bool> saveConfig({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newConfig = await _service.saveConfig(token: token, data: data);
      _config = newConfig;
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Erro ao salvar config: $e");
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> triggerManual({required String token}) async {
    try {
      await _service.triggerManualRun(token: token);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Erro trigger manual: $e");
      return false;
    }
  }

  // ✅ NOVO: Disparo manual de todos os boletos do mês
  Future<bool> triggerMonthInvoices({required String token}) async {
    try {
      final success = await _service.triggerMonthInvoices(token: token);
      return success;
    } catch (e) {
      // ignore: avoid_print
      print("Erro trigger mês: $e");
      return false;
    }
  }
}
