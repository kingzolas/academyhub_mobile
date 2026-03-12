import 'package:flutter/material.dart';
import '../model/expense_model.dart';
import '../services/expense_service.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseService _service = ExpenseService();

  List<Expense> _expenses = [];
  bool _isLoading = false;
  String? _error;

  // Getters para a UI acessar os dados
  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- UX Helpers (Cálculos automáticos para Dashboards) ---

  // Retorna total de despesas pendentes (R$)
  double get totalPendingValue {
    return _expenses
        .where((e) => e.status == 'pending' || e.status == 'late')
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  // Retorna total já pago (R$)
  double get totalPaidValue {
    return _expenses
        .where((e) => e.status == 'paid')
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  // --- Ações ---

  Future<void> fetchExpenses(String token,
      {String? startDate, String? endDate}) async {
    _isLoading = true;
    _error = null;
    // Notifica listeners para mostrar loading na tela
    notifyListeners();

    try {
      _expenses = await _service.getExpenses(token,
          startDate: startDate, endDate: endDate);
    } catch (e) {
      _error = e.toString();
      print('Erro ao buscar despesas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(String token, Expense expense) async {
    try {
      final newExpense = await _service.createExpense(token, expense);
      _expenses.insert(
          0, newExpense); // Adiciona no topo da lista (UX: feedback imediato)
      notifyListeners();
    } catch (e) {
      throw e; // Relança para tratar na UI (ex: mostrar SnackBar de erro)
    }
  }

  Future<void> updateExpense(
      String token, String id, Map<String, dynamic> data) async {
    try {
      final updatedExpense = await _service.updateExpense(token, id, data);
      final index = _expenses.indexWhere((e) => e.id == id);
      if (index != -1) {
        _expenses[index] = updatedExpense;
        notifyListeners();
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> deleteExpense(String token, String id) async {
    try {
      await _service.deleteExpense(token, id);
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      throw e;
    }
  }
}
