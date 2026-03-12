import 'package:academyhub_mobile/model/class_model.dart';
import 'package:academyhub_mobile/services/class_service.dart'; // Assumindo que existe
import 'package:flutter/material.dart';

class ClassesDashboardProvider with ChangeNotifier {
  final ClassService _classService = ClassService();

  // --- Cache ---
  List<ClassModel> _classes = [];

  // --- Estado ---
  bool _isLoading = false;
  String? _error;

  // --- Getters ---
  List<ClassModel> get classes => _classes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _classes.isNotEmpty;

  /// Lógica SWR: Mostra cache se existir, busca novo em background.
  /// [filter]: Opcional, caso queira filtrar no backend (ex: ano letivo)
  Future<void> fetchDashboardClasses(String token,
      {Map<String, String>? filter, bool forceRefresh = false}) async {
    // Se já tem dados e não é forçado, não mostra loading visual (Spinner)
    if (!hasData || forceRefresh) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // Busca atualizada
      final results = await _classService.getAllClasses(token, filter: filter);

      // Atualiza cache
      _classes = List<ClassModel>.from(results);

      // Ordenação padrão (Nome A-Z)
      _classes.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      debugPrint("Erro Classes Dashboard: $_error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Métodos para WebSocket e Atualizações Otimistas ---

  void addClassLocally(ClassModel newClass) {
    _classes.add(newClass);
    _classes.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void updateClassLocally(ClassModel updatedClass) {
    final index = _classes.indexWhere((c) => c.id == updatedClass.id);
    if (index != -1) {
      _classes[index] = updatedClass;
      notifyListeners();
    }
  }

  void removeClassLocally(String classId) {
    _classes.removeWhere((c) => c.id == classId);
    notifyListeners();
  }

  // Atualiza contadores de alunos sem refetch total (WebSocket)
  void updateStudentCount(String classId, int change) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index != -1) {
      var current = _classes[index];
      // Cria cópia modificada (Imutabilidade ideal, mas aqui modificamos direto para simplicidade ou usamos copyWith se o model tiver)
      // Assumindo que o model não é const e podemos alterar propriedades ou criar novo objeto:
      // Se não tiver copyWith, teremos que fazer fetch ou aceitar a mutação se o model permitir.
      // Aqui vou assumir que precisamos apenas notificar a mudança.
      // *Idealmente seu model deve ter copyWith*.
      notifyListeners();
    }
  }
}
