// lib/providers/student_note_provider.dart

import 'package:flutter/foundation.dart';
import '../model/student_note_model.dart';
import '../services/student_note_service.dart';
import 'auth_provider.dart';

class StudentNoteProvider extends ChangeNotifier {
  final StudentNoteService _service = StudentNoteService();

  List<StudentNoteModel> _notes = [];
  bool _isLoading = false;
  bool _isOperationLoading = false;
  String? _errorMessage;

  List<StudentNoteModel> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;
  bool get isOperationLoading => _isOperationLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearNotes() {
    _notes.clear();
    notifyListeners();
  }

  String _requireToken(AuthProvider authProvider) {
    final token = authProvider.token;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Usuário não autenticado.');
    }
    return token;
  }

  // Carrega a lista de notas do aluno
  Future<void> loadNotes(AuthProvider authProvider, String studentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      _notes = await _service.fetchNotesByStudent(token, studentId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cria nota e adiciona na lista atual
  Future<bool> createNote({
    required AuthProvider authProvider,
    required String studentId,
    required String title,
    required String description,
    required String type,
  }) async {
    _isOperationLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      final newNote = await _service.createNote(
        token: token,
        studentId: studentId,
        title: title,
        description: description,
        type: type,
      );

      // Insere no topo da lista
      _notes.insert(0, newNote);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isOperationLoading = false;
      notifyListeners();
    }
  }

  // Exclui a nota e remove da lista local
  Future<bool> deleteNote({
    required AuthProvider authProvider,
    required String noteId,
  }) async {
    _isOperationLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      await _service.deleteNote(token, noteId);

      _notes.removeWhere((n) => n.id == noteId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isOperationLoading = false;
      notifyListeners();
    }
  }
}
