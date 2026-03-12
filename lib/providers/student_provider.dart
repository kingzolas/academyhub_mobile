import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:academyhub_mobile/model/model_alunos.dart';
import 'package:academyhub_mobile/services/student_service.dart';

class StudentProvider with ChangeNotifier {
  final StudentService _service = StudentService();

  List<Student> _students = [];
  bool _isLoading = false;
  String? _error;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Busca todos os alunos
  Future<void> fetchStudents(String? token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _students = await _service.getStudents(token);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cria aluno (com foto opcional)
  Future<void> addStudent(String? token, Map<String, dynamic> studentData,
      {Uint8List? photoBytes, String? photoName}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final newStudent = await _service.createStudent(studentData, token,
          imageBytes: photoBytes, imageFilename: photoName);
      _students.add(newStudent);
      _students.sort((a, b) => a.fullName.compareTo(b.fullName));
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Atualiza aluno (com foto opcional)
  Future<void> editStudent(
      String? token, String id, Map<String, dynamic> studentData,
      {Uint8List? photoBytes, String? photoName}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updatedStudent = await _service.updateStudent(
          id, token, studentData,
          imageBytes: photoBytes, imageFilename: photoName);

      final index = _students.indexWhere((s) => s.id == id);
      if (index != -1) {
        _students[index] = updatedStudent;
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Método auxiliar para obter foto
  // (Ideal para usar com FutureBuilder nos cards de aluno)
  Future<Uint8List?> getPhoto(String id, String? token) async {
    return await _service.getStudentPhoto(id, token);
  }
}
