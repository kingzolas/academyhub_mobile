import 'package:academyhub_mobile/model/user_model.dart';
import 'package:academyhub_mobile/services/user_service.dart'; // Assumindo que seu UserProvider usa este service
import 'package:flutter/material.dart';

class StaffDashboardProvider with ChangeNotifier {
  // Se você não tiver um UserService separado e a lógica estiver toda no UserProvider,
  // você pode instanciar o UserProvider ou extrair a lógica.
  // Vou assumir que existe um UserService padrão.
  final UserService _userService = UserService();

  // --- Cache ---
  List<User> _users = [];

  // --- Estado ---
  bool _isLoading = false;
  String? _error;

  // --- Getters ---
  List<User> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _users.isNotEmpty;

  /// Lógica SWR:
  /// 1. Se já tem dados em memória, mostra eles imediatamente.
  /// 2. Busca dados novos em background.
  /// 3. Atualiza a tela silenciosamente.
  Future<void> fetchDashboardUsers(String token,
      {bool forceRefresh = false}) async {
    // Se não for forçado e já tiver dados, não mostra loading visual (Spinner)
    if (!hasData || forceRefresh) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // Busca atualizada do backend
      final results = await _userService.getAllUsers(token);

      // Atualiza cache
      _users = List<User>.from(results);

      // Ordenação padrão (Ex: Nome A-Z)
      _users.sort((a, b) => a.fullName.compareTo(b.fullName));
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      debugPrint("Erro Staff Dashboard: $_error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Atualizações Locais (Otimistic UI Update) ---

  // Se quiser remover localmente sem refetch total ao inativar
  void updateUserStatusLocally(String userId, String newStatus) {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      // Como User geralmente é imutável ou complexo, o ideal seria copyWith.
      // Se não tiver, forçamos um fetch rápido ou aceitamos a mutação se o model permitir.
      // Aqui, vou assumir que vamos fazer um fetch silencioso após a ação na tela,
      // mas deixo o método pronto caso queira implementar manipulação de lista.
      notifyListeners();
    }
  }
}
