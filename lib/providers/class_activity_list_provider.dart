import 'package:academyhub_mobile/model/class_activity_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/class_activity_service.dart';
import 'package:flutter/foundation.dart';

class ClassActivityListProvider extends ChangeNotifier {
  final ClassActivityService _service = ClassActivityService();

  List<ClassActivity> _activities = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isSaving = false;
  String? _errorMessage;

  String? _classId;
  Map<String, String?> _lastFilters = const {};

  List<ClassActivity> get activities => List.unmodifiable(_activities);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  String _requireToken(AuthProvider authProvider) {
    final token = authProvider.token;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Usuario nao autenticado.');
    }
    return token;
  }

  Future<void> loadActivities(
    AuthProvider authProvider, {
    required String classId,
    Map<String, String?> filters = const {},
    bool refresh = false,
  }) async {
    _classId = classId;
    _lastFilters = Map<String, String?>.from(filters);
    _errorMessage = null;

    if (refresh && _activities.isNotEmpty) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      _activities = await _service.listByClass(
        token: token,
        classId: classId,
        filters: filters,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<ClassActivity> createActivity(
    AuthProvider authProvider, {
    required String classId,
    required ClassActivityUpsertInput input,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      final created = await _service.create(
        token: token,
        classId: classId,
        input: input,
      );
      await loadActivities(
        authProvider,
        classId: classId,
        filters: _lastFilters,
        refresh: true,
      );
      return created;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<ClassActivity> updateActivity(
    AuthProvider authProvider, {
    required String activityId,
    required ClassActivityUpsertInput input,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      final updated = await _service.update(
        token: token,
        activityId: activityId,
        input: input,
      );

      if (_classId != null) {
        await loadActivities(
          authProvider,
          classId: _classId!,
          filters: _lastFilters,
          refresh: true,
        );
      }
      return updated;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<ClassActivity> cancelActivity(
    AuthProvider authProvider, {
    required String activityId,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      final cancelled = await _service.cancel(
        token: token,
        activityId: activityId,
      );

      if (_classId != null) {
        await loadActivities(
          authProvider,
          classId: _classId!,
          filters: _lastFilters,
          refresh: true,
        );
      }
      return cancelled;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clear() {
    _activities = [];
    _isLoading = false;
    _isRefreshing = false;
    _isSaving = false;
    _errorMessage = null;
    _classId = null;
    _lastFilters = const {};
    notifyListeners();
  }
}
