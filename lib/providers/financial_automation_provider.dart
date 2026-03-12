import 'package:academyhub_mobile/model/invoice_model.dart';
import 'package:academyhub_mobile/model/negotiation_model.dart'; // Certifique-se de ter este model
import 'package:flutter/material.dart';
import 'package:academyhub_mobile/services/negotiation_service.dart';

class NegotiationProvider with ChangeNotifier {
  final NegotiationService _negotiationService = NegotiationService();

  bool _isLoading = false;
  String? _error;

  // [NOVO] Lista para armazenar o histórico
  List<Negotiation> _studentNegotiations = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Negotiation> get studentNegotiations => _studentNegotiations;

  void _setState(bool loading, String? error) {
    _isLoading = loading;
    _error = error;
    notifyListeners();
  }

  // MUDANÇA AQUI: Retorna Future<String?> (O Token ou null)
  Future<String?> createAndSendNegotiation({
    required String token,
    required String studentId,
    required List<Invoice> selectedInvoices,
    required NegotiationRules rules,
  }) async {
    _setState(true, null);

    try {
      final invoiceIds = selectedInvoices.map((inv) => inv.id).toList();

      final String negotiationToken =
          await _negotiationService.createNegotiation(
        token: token,
        studentId: studentId,
        invoiceIds: invoiceIds,
        rules: rules,
      );

      _setState(false, null);
      return negotiationToken;
    } catch (e) {
      _setState(false, e.toString());
      return null;
    }
  }

  // [NOVO] Método para buscar o histórico
  Future<void> fetchNegotiationsByStudent(
      String studentId, String token) async {
    // Define loading apenas localmente para não travar a UI inteira se não quiser
    _isLoading = true;
    _error = null;
    // Limpa a lista anterior para não mostrar dados de outro aluno
    _studentNegotiations = [];
    notifyListeners();

    try {
      final result = await _negotiationService.listByStudent(
        token: token,
        studentId: studentId,
      );
      _studentNegotiations = result;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
