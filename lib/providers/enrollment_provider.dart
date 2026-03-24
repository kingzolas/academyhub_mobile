// lib/providers/enrollment_provider.dart

import 'package:flutter/foundation.dart';
import '../model/enrollment_model.dart';
import '../services/enrollment_service.dart';

class EnrollmentProvider with ChangeNotifier {
  final EnrollmentService _service = EnrollmentService();

  List<Enrollment> _enrollments = [];
  bool _isLoading = false;
  String? _error;

  List<Enrollment> get enrollments => List.unmodifiable(_enrollments);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void _setError(String? message) {
    _error = message?.replaceAll('Exception: ', '');
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // --- MÉTODOS DE BUSCA ---

  /// Busca matrículas gerais (pode receber filtros diversos)
  Future<void> fetchEnrollments(String token,
      {Map<String, String>? filter}) async {
    _setLoading(true);
    _setError(null);
    try {
      _enrollments = await _service.getEnrollments(token, filter: filter);
    } catch (e) {
      _setError(e.toString());
      _enrollments = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Método tático para a tela de Gestão de Alunos do Professor
  /// Busca apenas matrículas Ativas de uma turma específica
  /// Método tático para a tela de Gestão de Alunos do Professor
  Future<void> fetchEnrollmentsByClass(String token, String classId) async {
    await fetchEnrollments(token, filter: {
      // CORREÇÃO: O Node.js espera a chave 'class', exatamente como está no Schema do Mongoose!
      'class': classId,

      // E podemos voltar com o status 'Ativa' (com A maiúsculo, que é o seu enum exato)
      // para economizar internet e não baixar alunos inativos à toa.
      'status': 'Ativa',
    });
  }

  // --- MÉTODOS DE ESCRITA ---

  Future<bool> createEnrollment({
    required String studentId,
    required String classId,
    required double agreedFee,
    required String token,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final newEnrollment = await _service.createEnrollment(
        studentId: studentId,
        classId: classId,
        agreedFee: agreedFee,
        token: token,
      );
      _enrollments.insert(0, newEnrollment);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateEnrollment(String enrollmentId,
      Map<String, dynamic> updateData, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      final updated =
          await _service.updateEnrollment(enrollmentId, updateData, token);
      final index = _enrollments.indexWhere((e) => e.id == enrollmentId);
      if (index != -1) {
        _enrollments[index] = updated;
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteEnrollment(String enrollmentId, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      await _service.deleteEnrollment(enrollmentId, token);
      _enrollments.removeWhere((e) => e.id == enrollmentId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
