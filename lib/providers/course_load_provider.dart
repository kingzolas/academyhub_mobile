import 'package:flutter/foundation.dart';
import 'package:academyhub_mobile/model/course_load_model.dart';
import 'package:academyhub_mobile/services/course_load_service.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart'; // Para pegar o token

class CourseLoadProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  final CourseLoadService _courseLoadService = CourseLoadService();

  CourseLoadProvider(this._authProvider);

  String? get _token => _authProvider.token;

  List<CourseLoadModel> _courseLoads = [];
  List<CourseLoadModel> get courseLoads => _courseLoads;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void clearError() {
    _error = null;
  }

  /// Busca as metas de horas salvas no banco
  Future<void> fetchCourseLoads(String periodoId, String classId) async {
    if (_token == null) {
      _error = "Usuário não autenticado.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _courseLoads = await _courseLoadService.find(_token!, periodoId, classId);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Salva (Cria/Atualiza) a matriz inteira em lote
  Future<void> batchSave(String periodoId, String classId,
      List<Map<String, dynamic>> loadsData) async {
    if (_token == null) {
      throw Exception("Usuário não autenticado.");
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _courseLoadService.batchSave(
          _token!, periodoId, classId, loadsData);
      // Após salvar, buscamos os dados atualizados
      await fetchCourseLoads(periodoId, classId);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      // Lança o erro para o dialog/tela saber que falhou
      throw Exception('Falha ao salvar: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
