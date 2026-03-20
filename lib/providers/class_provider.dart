// lib/providers/class_provider.dart
import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/services/class_service.dart';
import 'package:flutter/foundation.dart';

class ClassProvider with ChangeNotifier {
  final ClassService _classService = ClassService();

  List<ClassModel> _classes = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialLoading = true;

  List<ClassModel> get classes => List.unmodifiable(_classes);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialLoading => _isInitialLoading;

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? errorMsg) {
    _error = errorMsg?.replaceAll('Exception: ', '');
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // --- MÉTODOS DE API ---

  Future<void> fetchClasses(String token, {Map<String, String>? filter}) async {
    if (_classes.isEmpty) _isInitialLoading = true;
    _setLoading(true);
    _setError(null);
    try {
      _classes = await _classService.getAllClasses(token, filter: filter);
    } catch (e) {
      _setError(e.toString());
      _classes = [];
    } finally {
      if (_isInitialLoading)
        _isInitialLoading = false; // Só muda na primeira vez
      _setLoading(false);
    }
  }

  Future<List<ClassModel>> fetchActiveClassesByYear(
      String token, int year) async {
    try {
      // [CORREÇÃO] Não usa o service getAllClasses, mas sim ele mesmo
      // Esta função deve chamar o service, não o provider.
      return await _classService.getAllClasses(token, filter: {
        'schoolYear': year.toString(),
        'status': 'Ativa',
      });
    } catch (e) {
      print("Erro ao buscar turmas ativas por ano: $e");
      return [];
    }
  }

  Future<void> addClass(ClassModel classData, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      // O service agora retorna o objeto sem a contagem (é 0)
      final newClass = await _classService.createClass(classData, token);
      // O evento WebSocket (NEW_CLASS) vai lidar com a adição na lista
      // Não precisamos adicionar manualmente aqui para evitar duplicatas se o WS for rápido
      // _classes.insert(0, newClass);
      _setError(null);
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error); // Re-lança para o dialog
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateClass(
      String classId, Map<String, dynamic> updateData, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      // O service agora retorna o objeto atualizado e com contagem
      final updatedClass =
          await _classService.updateClass(classId, updateData, token);
      // O evento WebSocket (UPDATED_CLASS) vai lidar com a atualização
      // Não precisamos atualizar manualmente aqui
      // final index = _classes.indexWhere((c) => c.id == classId);
      // if (index != -1) _classes[index] = updatedClass;
      _setError(null);
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteClass(String classId, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      await _classService.deleteClass(classId, token);
      // O evento WebSocket (DELETED_CLASS) vai lidar com a remoção
      // _classes.removeWhere((c) => c.id == classId);
      _setError(null);
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  // --- MÉTODOS PARA ATUALIZAÇÃO VIA WEBSOCKET ---

  void addClassFromEvent(ClassModel newClass) {
    if (!_classes.any((c) => c.id == newClass.id)) {
      _classes.insert(
          0, newClass); // Adiciona a nova turma (já virá com studentCount=0)
      notifyListeners();
    }
  }

  void updateClassFromEvent(ClassModel updatedClass) {
    final index = _classes.indexWhere((c) => c.id == updatedClass.id);
    if (index != -1) {
      // Mantém a contagem de alunos que o evento WS pode não ter (se a API update não calcular)
      // Usando o copyWith para garantir
      _classes[index] =
          updatedClass.copyWith(studentCount: updatedClass.studentCount);
      notifyListeners();
    } else {
      // Se não encontrou, adiciona
      addClassFromEvent(updatedClass);
    }
  }

  void removeClassById(String classId) {
    final int removedCount = _classes.length;
    _classes.removeWhere((c) => c.id == classId);
    if (_classes.length < removedCount) {
      notifyListeners();
    }
  }

  // --- [NOVOS MÉTODOS] Para atualizar contagem via WS ---

  /// Incrementa a contagem de alunos de uma turma específica
  void incrementStudentCount(String classId) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      final currentClass = _classes[index];
      _classes[index] =
          currentClass.copyWith(studentCount: currentClass.studentCount + 1);
      notifyListeners();
      debugPrint(
          "[ClassProvider] Contagem incrementada para turma ${currentClass.name}");
    }
  }

  /// Decrementa a contagem de alunos de uma turma específica
  void decrementStudentCount(String classId) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      final currentClass = _classes[index];
      _classes[index] = currentClass.copyWith(
          studentCount: (currentClass.studentCount > 0)
              ? currentClass.studentCount - 1
              : 0 // Evita negativo
          );
      notifyListeners();
      debugPrint(
          "[ClassProvider] Contagem decrementada para turma ${currentClass.name}");
    }
  }

  void clear() {
    _classes = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
