import 'package:academyhub_mobile/model/user_model.dart';
import 'package:academyhub_mobile/services/user_service.dart';
import 'package:flutter/foundation.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();

  List<User> _users = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialLoading = true;

  List<User> get users => List.unmodifiable(_users);
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
    if (_error != null || errorMsg != null) notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void clear() {
    _users = [];
    _isLoading = false;
    _error = null;
    _isInitialLoading = true;
    notifyListeners();
    debugPrint('🧹 [UserProvider] Provider state cleared.');
  }

  // --- MÉTODOS DE API ---

  Future<void> fetchUsers(String token) async {
    if (_users.isEmpty) _isInitialLoading = true;
    _setLoading(true);
    _setError(null);

    try {
      _users = await _userService.getAllUsers(token);
      _users.sort((a, b) => a.fullName.compareTo(b.fullName));
    } catch (e) {
      _setError(e.toString());
      _users = [];
    } finally {
      if (_isInitialLoading) _isInitialLoading = false;
      _setLoading(false);
    }
  }

  Future<void> addStaff(Map<String, dynamic> staffData, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      await _userService.createStaff(staffData, token);
      _setError(null);
      // Não adiciona localmente, espera WebSocket (lógica original mantida)
    } catch (e) {
      _setError(e.toString());
      // [IMPORTANTE] Relança o erro para que a UI (Dialog) possa capturá-lo
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateStaff(
      String id, Map<String, dynamic> updateData, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      await _userService.updateStaff(id, updateData, token);
      _setError(null);
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reactivateUser(String id, String token) async {
    _setLoading(true);
    _setError(null);

    try {
      final updatedUser = await _userService.reactivateUser(id, token);

      if (updatedUser != null) {
        updateUserFromEvent(updatedUser);
      } else {
        // fallback: deixa WS atualizar ou apenas refetch
      }

      _setError(null);
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> inactivateUser(String id, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      final updatedUser = await _userService.inactivateUser(id, token);

      if (updatedUser != null) {
        updateUserFromEvent(updatedUser);
      } else {
        // fallback — remove local ou deixa WebSocket atualizar
        removeUserById(id);
      }

      _setError(null);
    } catch (e) {
      _setError(e.toString());
      throw Exception(_error);
    } finally {
      _setLoading(false);
    }
  }

  // --- MÉTODOS WEBSOCKET (Mantidos) ---

  void addUserFromEvent(User newUser) {
    if (!_users.any((u) => u.id == newUser.id)) {
      _users.add(newUser);
      _users.sort((a, b) => a.fullName.compareTo(b.fullName));
      notifyListeners();
      debugPrint(
          "[UserProvider] Usuário ${newUser.fullName} adicionado via WebSocket.");
    }
  }

  void updateUserFromEvent(User updatedUser) {
    final index = _users.indexWhere((u) => u.id == updatedUser.id);
    if (index != -1) {
      _users[index] = updatedUser;
      _users.sort((a, b) => a.fullName.compareTo(b.fullName));
      notifyListeners();
      debugPrint(
          "[UserProvider] Usuário ${updatedUser.fullName} atualizado via WebSocket.");
    } else {
      addUserFromEvent(updatedUser);
    }
  }

  void removeUserById(String id) {
    final int removedCount = _users.length;
    _users.removeWhere((u) => u.id == id);
    if (_users.length < removedCount) {
      notifyListeners();
      debugPrint("[UserProvider] Usuário ID $id removido via WebSocket.");
    }
  }
}
