import 'package:flutter/material.dart';
import '../services/invoice_compensation_service.dart';

class InvoiceCompensationProvider extends ChangeNotifier {
  final InvoiceCompensationService _service;

  InvoiceCompensationProvider({required InvoiceCompensationService service})
      : _service = service;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<dynamic> _active = [];
  List<dynamic> get active => _active;

  List<dynamic> _history = [];
  List<dynamic> get history => _history;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  Future<void> fetchAll({
    required String token,
    String? studentId,
  }) async {
    _setLoading(true);
    setError(null);
    try {
      _active = await _service.listCompensations(
        token: token,
        status: 'active',
        studentId: studentId,
      );
      _history = await _service.listCompensations(
        token: token,
        status: null,
        studentId: studentId,
      );
    } catch (e) {
      setError(e.toString().replaceAll('Exception: ', ''));
    }
    _setLoading(false);
  }

  Future<Map<String, dynamic>?> create({
    required String token,
    required String studentId,
    required String targetInvoiceId,
    required String sourceInvoiceId,
    required String reason,
    String? notes,
  }) async {
    print('🟡 [Provider] Iniciando create() de compensação...');
    print(
        '🟡 [Provider] Aluno: $studentId | Target: $targetInvoiceId | Source: $sourceInvoiceId');

    _setLoading(true);
    setError(null);
    try {
      final res = await _service.createCompensation(
        token: token,
        studentId: studentId,
        targetInvoiceId: targetInvoiceId,
        sourceInvoiceId: sourceInvoiceId,
        reason: reason,
        notes: notes,
      );

      print('🟡 [Provider] Sucesso! Compensação criada.');
      _setLoading(false);
      return res;
    } catch (e, stackTrace) {
      print('🔴 [Provider] ERRO CAPTURADO no create(): $e');
      // Descomente a linha abaixo se quiser ver a árvore de erro completa:
      // print(stackTrace);

      setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return null;
    }
  }

  Future<bool> resolve({
    required String token,
    required String compensationId,
  }) async {
    _setLoading(true);
    setError(null);
    try {
      await _service.resolveCompensation(
        token: token,
        compensationId: compensationId,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> cancel({
    required String token,
    required String compensationId,
  }) async {
    _setLoading(true);
    setError(null);
    try {
      await _service.cancelCompensation(
        token: token,
        compensationId: compensationId,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }
}
