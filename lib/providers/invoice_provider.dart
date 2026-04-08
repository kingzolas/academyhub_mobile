import 'dart:typed_data';
import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:academyhub_mobile/services/invoice_service.dart';
import 'package:printing/printing.dart';

class InvoiceProvider extends ChangeNotifier {
  final InvoiceService _invoiceService = InvoiceService();

  List<Invoice> _allInvoices = [];
  List<Invoice> get allInvoices => _allInvoices;

  List<Invoice> _studentInvoices = [];
  List<Invoice> get studentInvoices => _studentInvoices;

  List<Invoice> _guardianInvoices = [];
  List<Invoice> get guardianInvoices => _guardianInvoices;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String? _currentStatusFilter;

  // =========================
  // [NOVO] Listas úteis pro front
  // =========================

  /// Pendentes/vencidas que DEVEM ser cobradas (inadimplência real)
  List<Invoice> get collectablePendingInvoices {
    return _allInvoices.where((inv) {
      final isPendingLike = inv.status == 'pending' || inv.status == 'overdue';
      return isPendingLike && !inv.isCompensationHold;
    }).toList();
  }

  /// Pendentes/vencidas que NÃO devem ser cobradas (compensação ativa)
  List<Invoice> get compensationHoldInvoices {
    return _allInvoices.where((inv) {
      final isPendingLike = inv.status == 'pending' || inv.status == 'overdue';
      return isPendingLike && inv.isCompensationHold;
    }).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? errorMsg) {
    _error = errorMsg;
    notifyListeners();
  }

  // --- MÉTODOS DE API ---

  Future<void> fetchInvoicesByStudent({
    required String studentId,
    required String token,
  }) async {
    _setLoading(true);
    setError(null);
    try {
      _studentInvoices = await _invoiceService.getInvoicesByStudent(
        studentId: studentId,
        token: token,
      );
    } catch (e) {
      setError(e.toString());
    }
    _setLoading(false);
  }

  Future<void> fetchGuardianInvoices({
    required String token,
  }) async {
    _setLoading(true);
    setError(null);
    try {
      _guardianInvoices = await _invoiceService.getGuardianInvoices(
        token: token,
      );
    } catch (e) {
      setError(e.toString().replaceAll('Exception: ', ''));
    }
    _setLoading(false);
  }

  Future<void> fetchAllInvoices({
    required String token,
    String? status,
  }) async {
    _setLoading(true);
    setError(null);
    try {
      _allInvoices = await _invoiceService.getAllInvoices(
        token: token,
        status: status,
      );
      _currentStatusFilter = status;
    } catch (e) {
      setError(e.toString().replaceAll('Exception: ', ''));
    }
    _setLoading(false);
  }

  Future<Invoice?> createInvoice({
    required Map<String, dynamic> data,
    required String token,
  }) async {
    _setLoading(true);
    setError(null);
    try {
      Invoice newInvoice = await _invoiceService.createInvoice(
        invoiceData: data,
        token: token,
      );
      _setLoading(false);
      return newInvoice;
    } catch (e) {
      setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  // --- Cancelar Fatura ---
  Future<bool> cancelInvoice({
    required String invoiceId,
    required String token,
  }) async {
    _setLoading(true);
    setError(null);

    try {
      await _invoiceService.cancelInvoice(invoiceId: invoiceId, token: token);
      _handleLocalCancellation(invoiceId);
      // ignore: avoid_print
      print('✅ Fatura $invoiceId cancelada com sucesso.');
      _setLoading(false);
      return true;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      // ignore: avoid_print
      print('❌ Erro ao cancelar fatura: $errorMsg');
      setError(errorMsg);
      _setLoading(false);
      return false;
    }
  }

  // --- Sync Silencioso ---
  Future<Map<String, dynamic>?> syncPendingInvoices(String token) async {
    try {
      final result = await _invoiceService.syncPendingInvoices(token: token);
      notifyListeners();
      return result;
    } catch (e) {
      // ignore: avoid_print
      print("⚠️ Erro no sync background: $e");
      return null;
    }
  }

  // --- Reenvio WhatsApp ---
  // Retorna String? (null se sucesso, mensagem se erro) para o botão de Retry
  Future<String?> resendWhatsappNotification({
    required String invoiceId,
    required String token,
  }) async {
    try {
      await _invoiceService.resendWhatsapp(invoiceId: invoiceId, token: token);
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  void _handleLocalCancellation(String invoiceId) {
    final indexAll = _allInvoices.indexWhere((inv) => inv.id == invoiceId);
    if (indexAll != -1) {
      if (_currentStatusFilter != null && _currentStatusFilter != 'canceled') {
        _allInvoices.removeAt(indexAll);
      } else {
        _allInvoices[indexAll] =
            _allInvoices[indexAll].copyWith(status: 'canceled');
      }
    }

    final indexStudent =
        _studentInvoices.indexWhere((inv) => inv.id == invoiceId);
    if (indexStudent != -1) {
      _studentInvoices[indexStudent] =
          _studentInvoices[indexStudent].copyWith(status: 'canceled');
    }
    notifyListeners();
  }

  void handleInvoiceCreated(Map<String, dynamic> payload) {
    final newInvoice = Invoice.fromJson(payload);
    if (_currentStatusFilter == null ||
        newInvoice.status == _currentStatusFilter) {
      _allInvoices.insert(0, newInvoice);
    }
    if (_studentInvoices.isNotEmpty &&
        _studentInvoices.first.student?.id == newInvoice.student?.id) {
      _studentInvoices.insert(0, newInvoice);
    }
    notifyListeners();
  }

  void handleInvoiceUpdate(Map<String, dynamic> payload) {
    final updatedInvoice = Invoice.fromJson(payload);
    final indexInAll =
        _allInvoices.indexWhere((inv) => inv.id == updatedInvoice.id);

    if (indexInAll != -1) {
      if (_currentStatusFilter == null ||
          updatedInvoice.status == _currentStatusFilter) {
        _allInvoices[indexInAll] = updatedInvoice;
      } else {
        _allInvoices.removeAt(indexInAll);
      }
    } else {
      if (updatedInvoice.status == _currentStatusFilter) {
        _allInvoices.insert(0, updatedInvoice);
      }
    }

    final indexInStudent =
        _studentInvoices.indexWhere((inv) => inv.id == updatedInvoice.id);
    if (indexInStudent != -1) {
      _studentInvoices[indexInStudent] = updatedInvoice;
    }
    notifyListeners();
  }

  Future<void> generateBatchPdf({
    required List<String> invoiceIds,
    required String token,
  }) async {
    _setLoading(true);
    setError(null);

    try {
      final Uint8List pdfBytes = await _invoiceService.downloadBatchPdf(
        invoiceIds: invoiceIds,
        token: token,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name:
            'Carne_Pagamento_${DateTime.now().day}_${DateTime.now().month}.pdf',
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      // ignore: avoid_print
      print('❌ Erro ao processar impressão: $errorMsg');
      setError(errorMsg);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> generateGuardianBatchPdf({
    required List<String> invoiceIds,
    required String token,
  }) async {
    _setLoading(true);
    setError(null);

    try {
      final Uint8List pdfBytes = await _invoiceService.downloadGuardianBatchPdf(
        invoiceIds: invoiceIds,
        token: token,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name:
            'Boleto_Responsavel_${DateTime.now().day}_${DateTime.now().month}.pdf',
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      setError(errorMsg);
    } finally {
      _setLoading(false);
    }
  }
}
