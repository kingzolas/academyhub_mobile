import 'package:academyhub_mobile/model/teacher_student_summary_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/teacher_student_summary_service.dart';
import 'package:flutter/foundation.dart';

class TeacherStudentSummaryProvider extends ChangeNotifier {
  final TeacherStudentSummaryService _service = TeacherStudentSummaryService();

  TeacherStudentSummary? _summary;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  TeacherStudentSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  bool get hasSummary => _summary != null;

  String _requireToken(AuthProvider authProvider) {
    final token = authProvider.token;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Usuario nao autenticado.');
    }
    return token;
  }

  Future<void> loadSummary(
    AuthProvider authProvider, {
    required String classId,
    required String studentId,
    bool refresh = false,
  }) async {
    if (refresh && _summary != null) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      _summary = await _service.fetchSummary(
        token: token,
        classId: classId,
        studentId: studentId,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void clear() {
    _summary = null;
    _errorMessage = null;
    _isLoading = false;
    _isRefreshing = false;
    notifyListeners();
  }
}
