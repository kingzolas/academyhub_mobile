// lib/providers/subject_provider.dart
import 'package:academyhub_mobile/model/subject_model.dart';
import 'package:academyhub_mobile/services/subject_service.dart';
import 'package:flutter/foundation.dart';

class SubjectProvider with ChangeNotifier {
  final SubjectService _subjectService = SubjectService();

  List<SubjectModel> _subjects = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialLoading = true; // Controla apenas o primeiro carregamento

  // Getters públicos (lista imutável para segurança)
  List<SubjectModel> get subjects => List.unmodifiable(_subjects);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialLoading => _isInitialLoading;

  // Setters privados (padrão)
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? errorMsg) {
    _error = errorMsg?.replaceAll('Exception: ', '');
    // Notifica apenas se o erro mudou
    if (_error != null || errorMsg != null) notifyListeners();
  }

  // Ação da UI para limpar erros
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // --- MÉTODOS DE API ---

  Future<void> fetchSubjects(String token,
      {Map<String, String>? filter}) async {
    if (_subjects.isEmpty)
      _isInitialLoading = true; // Se a lista estiver vazia, é o loading inicial
    _setLoading(true);
    _setError(null);

    try {
      _subjects =
          await _subjectService.getAllSubjects(token, filter: filter ?? {});
      _subjects.sort((a, b) => a.name.compareTo(b.name)); // Ordena por nome
    } catch (e) {
      _setError(e.toString());
      _subjects = []; // Limpa a lista em caso de erro
    } finally {
      if (_isInitialLoading)
        _isInitialLoading = false; // Marca que o loading inicial terminou
      _setLoading(false); // Para o loading geral
    }
  }

  Future<void> addSubject(SubjectModel subjectData, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      // Chama o serviço, mas NÃO adiciona localmente
      await _subjectService.createSubject(subjectData, token);
      // O WebSocket (evento 'NEW_SUBJECT') será responsável por adicionar
      _setError(null);
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error); // Re-lança para o dialog saber que falhou
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSubject(
      String id, Map<String, dynamic> updateData, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      await _subjectService.updateSubject(id, updateData, token);
      _setError(null);
      // O WebSocket (evento 'UPDATED_SUBJECT') será responsável por atualizar
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteSubject(String id, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      await _subjectService.deleteSubject(id, token);
      _setError(null);
      // O WebSocket (evento 'DELETED_SUBJECT') será responsável por remover
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  // --- MÉTODOS PARA ATUALIZAÇÃO VIA WEBSOCKET ---

  void addSubjectFromEvent(SubjectModel newSubject) {
    if (!_subjects.any((s) => s.id == newSubject.id)) {
      _subjects.add(newSubject);
      _subjects.sort((a, b) => a.name.compareTo(b.name)); // Re-ordena
      notifyListeners();
      debugPrint(
          "[SubjectProvider] Disciplina ${newSubject.name} adicionada via WebSocket.");
    }
  }

  void updateSubjectFromEvent(SubjectModel updatedSubject) {
    final index = _subjects.indexWhere((s) => s.id == updatedSubject.id);
    if (index != -1) {
      _subjects[index] = updatedSubject;
      _subjects.sort((a, b) => a.name.compareTo(b.name)); // Re-ordena
      notifyListeners();
      debugPrint(
          "[SubjectProvider] Disciplina ${updatedSubject.name} atualizada via WebSocket.");
    } else {
      // Se não encontrou, adiciona (caso de sincronia)
      addSubjectFromEvent(updatedSubject);
    }
  }

  void removeSubjectById(String id) {
    final int removedCount = _subjects.length;
    _subjects.removeWhere((s) => s.id == id);
    if (_subjects.length < removedCount) {
      notifyListeners();
      debugPrint("[SubjectProvider] Disciplina ID $id removida via WebSocket.");
    }
  }
}
