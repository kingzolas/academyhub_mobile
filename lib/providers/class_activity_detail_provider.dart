import 'package:academyhub_mobile/model/class_activity_model.dart';
import 'package:academyhub_mobile/providers/auth_provider.dart';
import 'package:academyhub_mobile/services/class_activity_service.dart';
import 'package:flutter/foundation.dart';

class ClassActivityDetailProvider extends ChangeNotifier {
  final ClassActivityService _service = ClassActivityService();

  ClassActivity? _activity;
  List<ClassActivitySubmission> _students = [];
  final Map<String, ClassActivitySubmission> _originalBySubmissionId = {};
  final Set<String> _expandedSubmissionIds = {};
  final Set<String> _dirtySubmissionIds = {};

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isSaving = false;
  String? _errorMessage;

  String? _activityId;

  ClassActivity? get activity => _activity;
  List<ClassActivitySubmission> get students => List.unmodifiable(_students);
  Set<String> get expandedSubmissionIds => Set.unmodifiable(_expandedSubmissionIds);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get hasPendingChanges => _dirtySubmissionIds.isNotEmpty;
  int get pendingChangeCount => _dirtySubmissionIds.length;

  String _requireToken(AuthProvider authProvider) {
    final token = authProvider.token;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Usuario nao autenticado.');
    }
    return token;
  }

  Future<void> load(
    AuthProvider authProvider, {
    required String activityId,
    bool refresh = false,
  }) async {
    _activityId = activityId;
    _errorMessage = null;

    if (refresh && (_activity != null || _students.isNotEmpty)) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      final results = await Future.wait([
        _service.getById(token: token, activityId: activityId),
        _service.getSubmissions(token: token, activityId: activityId),
      ]);

      final detail = results[0] as ClassActivity;
      final submissions = results[1] as ClassActivitySubmissionsResponse;

      _activity = detail.copyWith(
        summary: submissions.activity.summary,
        status: submissions.activity.status,
        workflowState: submissions.activity.workflowState,
        updatedAt: submissions.activity.updatedAt ?? detail.updatedAt,
      );
      _replaceStudents(submissions.students);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void toggleExpanded(String submissionId) {
    if (_expandedSubmissionIds.contains(submissionId)) {
      _expandedSubmissionIds.remove(submissionId);
    } else {
      _expandedSubmissionIds.add(submissionId);
    }
    notifyListeners();
  }

  void applyDeliveryStatus(String submissionId, ClassActivityDeliveryStatus status) {
    final index = _students.indexWhere((item) => item.id == submissionId);
    if (index == -1) return;

    final current = _students[index];
    final shouldResetCorrection = !status.allowsCorrection;

    final updated = current.copyWith(
      deliveryStatus: status,
      submittedAt: status.allowsCorrection
          ? (current.submittedAt ?? DateTime.now())
          : null,
      isCorrected: shouldResetCorrection ? false : current.isCorrected,
      correctedAt: shouldResetCorrection ? null : current.correctedAt,
      score: shouldResetCorrection ? null : current.score,
    );

    _students[index] = updated;
    _trackDirty(updated);
    notifyListeners();
  }

  void applyBulkStatus(ClassActivityDeliveryStatus status) {
    for (var index = 0; index < _students.length; index++) {
      final student = _students[index];
      if (!student.isCurrentClassMember) continue;

      final shouldResetCorrection = !status.allowsCorrection;
      final updated = student.copyWith(
        deliveryStatus: status,
        submittedAt: status.allowsCorrection
            ? (student.submittedAt ?? DateTime.now())
            : null,
        isCorrected: shouldResetCorrection ? false : student.isCorrected,
        correctedAt: shouldResetCorrection ? null : student.correctedAt,
        score: shouldResetCorrection ? null : student.score,
      );

      _students[index] = updated;
      _trackDirty(updated);
    }
    notifyListeners();
  }

  void applyCorrected(String submissionId, bool value) {
    final index = _students.indexWhere((item) => item.id == submissionId);
    if (index == -1) return;

    final current = _students[index];
    final updated = current.copyWith(
      isCorrected: value,
      correctedAt: value ? (current.correctedAt ?? DateTime.now()) : null,
      score: value ? current.score : null,
    );

    _students[index] = updated;
    _trackDirty(updated);
    notifyListeners();
  }

  void applyScore(String submissionId, double? score) {
    final index = _students.indexWhere((item) => item.id == submissionId);
    if (index == -1) return;

    final current = _students[index];
    final updated = current.copyWith(
      isCorrected: score != null ? true : current.isCorrected,
      correctedAt: score != null ? (current.correctedAt ?? DateTime.now()) : current.correctedAt,
      score: score,
    );

    _students[index] = updated;
    _trackDirty(updated);
    notifyListeners();
  }

  void applyTeacherNote(String submissionId, String value) {
    final index = _students.indexWhere((item) => item.id == submissionId);
    if (index == -1) return;

    final current = _students[index];
    final updated = current.copyWith(teacherNote: value);
    _students[index] = updated;
    _trackDirty(updated);
    notifyListeners();
  }

  Future<ClassActivitySubmissionsResponse> saveChanges(
    AuthProvider authProvider,
  ) async {
    if (_activityId == null) {
      throw Exception('Atividade nao carregada.');
    }

    final updates = _students
        .where((submission) => _dirtySubmissionIds.contains(submission.id))
        .map(ClassActivitySubmissionUpdateInput.fromSubmission)
        .toList();

    if (updates.isEmpty) {
      throw Exception('Nenhuma alteracao pendente.');
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      final result = await _service.bulkUpdateSubmissions(
        token: token,
        activityId: _activityId!,
        updates: updates,
      );
      _activity = result.activity;
      _replaceStudents(result.students);
      return result;
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
    required ClassActivityUpsertInput input,
  }) async {
    if (_activityId == null) {
      throw Exception('Atividade nao carregada.');
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      final updated = await _service.update(
        token: token,
        activityId: _activityId!,
        input: input,
      );
      _activity = updated;
      return updated;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<ClassActivity> cancelActivity(AuthProvider authProvider) async {
    if (_activityId == null) {
      throw Exception('Atividade nao carregada.');
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = _requireToken(authProvider);
      final cancelled = await _service.cancel(
        token: token,
        activityId: _activityId!,
      );
      _activity = cancelled;
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
    _activity = null;
    _students = [];
    _originalBySubmissionId.clear();
    _expandedSubmissionIds.clear();
    _dirtySubmissionIds.clear();
    _isLoading = false;
    _isRefreshing = false;
    _isSaving = false;
    _errorMessage = null;
    _activityId = null;
    notifyListeners();
  }

  void _replaceStudents(List<ClassActivitySubmission> items) {
    _students = List<ClassActivitySubmission>.from(items);
    _originalBySubmissionId
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.id, item)));
    _dirtySubmissionIds.clear();
  }

  void _trackDirty(ClassActivitySubmission submission) {
    final original = _originalBySubmissionId[submission.id];
    if (original == null) {
      _dirtySubmissionIds.add(submission.id);
      return;
    }

    if (submission.isEquivalentTo(original)) {
      _dirtySubmissionIds.remove(submission.id);
    } else {
      _dirtySubmissionIds.add(submission.id);
    }
  }
}
