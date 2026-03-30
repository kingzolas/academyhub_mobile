import 'package:flutter/material.dart';
import '../model/attendance_model.dart';
import '../services/attendance_service.dart';

class AttendanceProvider with ChangeNotifier {
  final AttendanceService _service = AttendanceService();

  AttendanceSheet? _currentSheet;
  bool _isLoading = false;
  String? _error;

  List<AttendanceSheet> _history = [];
  bool _isHistoryLoading = false;
  String? _historyError;

  AttendanceSheet? get currentSheet => _currentSheet;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<AttendanceSheet> get history => List.unmodifiable(_history);
  bool get isHistoryLoading => _isHistoryLoading;
  String? get historyError => _historyError;

  Future<void> loadHistory(String classId) async {
    _isHistoryLoading = true;
    _historyError = null;
    notifyListeners();

    try {
      _history = await _service.getClassHistory(classId);
    } catch (e) {
      _historyError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDailyAttendance(String classId, DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentSheet = await _service.getAttendanceSheet(classId, date);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _currentSheet = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateStudentStatus(String studentId, String newStatus) {
    if (_currentSheet == null) return;

    final index =
        _currentSheet!.records.indexWhere((r) => r.studentId == studentId);
    if (index != -1) {
      _currentSheet!.records[index].status = newStatus;
      notifyListeners();
    }
  }

  void toggleStatus(String studentId) {
    if (_currentSheet == null) return;

    final record =
        _currentSheet!.records.firstWhere((r) => r.studentId == studentId);
    final newStatus = record.status == 'PRESENT' ? 'ABSENT' : 'PRESENT';

    updateStudentStatus(studentId, newStatus);
  }

  Future<bool> submitAttendance() async {
    if (_currentSheet == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _service.saveAttendance(_currentSheet!);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _currentSheet = null;
    _isLoading = false;
    _error = null;
    _history = [];
    _isHistoryLoading = false;
    _historyError = null;
    notifyListeners();
  }
}
