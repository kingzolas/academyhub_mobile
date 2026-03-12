import 'package:flutter/material.dart';
import '../model/attendance_model.dart';
import '../services/attendance_service.dart';

class AttendanceProvider with ChangeNotifier {
  final AttendanceService _service = AttendanceService();

  AttendanceSheet? _currentSheet;
  bool _isLoading = false;
  String? _error;

  AttendanceSheet? get currentSheet => _currentSheet;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> get history => _history;

  Future<void> loadHistory(String classId) async {
    try {
      _history = await _service.getClassHistory(classId);
      notifyListeners();
    } catch (e) {
      print("Erro no histórico: $e");
    }
  }

  // Carrega a chamada do dia
  Future<void> loadDailyAttendance(String classId, DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentSheet = await _service.getAttendanceSheet(classId, date);
    } catch (e) {
      _error = e.toString();
      _currentSheet = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Atualiza o status de um aluno LOCALMENTE (para interação rápida na UI)
  void updateStudentStatus(String studentId, String newStatus) {
    if (_currentSheet == null) return;

    final index =
        _currentSheet!.records.indexWhere((r) => r.studentId == studentId);
    if (index != -1) {
      _currentSheet!.records[index].status = newStatus;
      notifyListeners(); // Atualiza a tela instantaneamente
    }
  }

  // Função helper para alternar status (útil para Swipe ou Toque)
  // Ciclo: PRESENT -> ABSENT -> PRESENT
  void toggleStatus(String studentId) {
    if (_currentSheet == null) return;

    final record =
        _currentSheet!.records.firstWhere((r) => r.studentId == studentId);
    final newStatus = record.status == 'PRESENT' ? 'ABSENT' : 'PRESENT';

    updateStudentStatus(studentId, newStatus);
  }

  // Envia tudo para o backend
  Future<bool> submitAttendance() async {
    if (_currentSheet == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _service.saveAttendance(_currentSheet!);
      return true; // Sucesso
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
