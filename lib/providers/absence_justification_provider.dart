import 'package:flutter/foundation.dart';

import '../model/absence_justification_model.dart';
import '../services/absence_justification_service.dart';
import 'auth_provider.dart';

class AbsenceJustificationProvider extends ChangeNotifier {
  final AbsenceJustificationService _service = AbsenceJustificationService();

  final List<AbsenceJustificationModel> _items = [];
  final Map<String, DownloadedJustificationDocument> _documentCache = {};

  AbsenceJustificationModel? _selected;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isReviewing = false;
  bool _isDownloadingDocument = false;
  String? _errorMessage;
  DateTime? _lastFetchedAt;

  List<AbsenceJustificationModel> get items => List.unmodifiable(_items);
  AbsenceJustificationModel? get selected => _selected;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isReviewing => _isReviewing;
  bool get isDownloadingDocument => _isDownloadingDocument;
  String? get errorMessage => _errorMessage;
  DateTime? get lastFetchedAt => _lastFetchedAt;

  int get totalCount => _items.length;
  int get pendingCount => _items
      .where((e) => e.status == AbsenceJustificationStatus.pending)
      .length;
  int get approvedCount => _items
      .where((e) => e.status == AbsenceJustificationStatus.approved)
      .length;
  int get rejectedCount => _items
      .where((e) => e.status == AbsenceJustificationStatus.rejected)
      .length;
  int get expiredCount => _items
      .where((e) => e.status == AbsenceJustificationStatus.expired)
      .length;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSelection() {
    _selected = null;
    notifyListeners();
  }

  void clearAll() {
    _items.clear();
    _documentCache.clear();
    _selected = null;
    _errorMessage = null;
    _lastFetchedAt = null;
    notifyListeners();
  }

  List<AbsenceJustificationModel> getForStudent(String studentId) {
    return _items.where((item) => item.studentId == studentId).toList()
      ..sort((a, b) {
        final aDate = a.coverageStartDate;
        final bDate = b.coverageStartDate;
        return bDate.compareTo(aDate);
      });
  }

  AbsenceJustificationModel? findForStudentOnDate(
    String studentId,
    DateTime date,
  ) {
    final matches = _items.where((item) {
      return item.studentId == studentId && item.coversDate(date);
    }).toList();

    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final priorityA = _statusPriority(a.status);
      final priorityB = _statusPriority(b.status);
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      final aDate = a.createdAt ?? a.coverageStartDate;
      final bDate = b.createdAt ?? b.coverageStartDate;
      return bDate.compareTo(aDate);
    });

    return matches.first;
  }

  bool hasAnyForStudentOnDate(String studentId, DateTime date) {
    return findForStudentOnDate(studentId, date) != null;
  }

  bool hasApprovedForStudentOnDate(String studentId, DateTime date) {
    final item = findForStudentOnDate(studentId, date);
    return item?.status == AbsenceJustificationStatus.approved;
  }

  bool hasPendingForStudentOnDate(String studentId, DateTime date) {
    final item = findForStudentOnDate(studentId, date);
    return item?.status == AbsenceJustificationStatus.pending;
  }

  Future<bool> loadJustifications({
    required AuthProvider authProvider,
    String? classId,
    String? studentId,
    String? status,
    DateTime? date,
    bool silent = false,
  }) async {
    final token = _requireToken(authProvider);

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final result = await _service.fetchJustifications(
        token: token,
        classId: classId,
        studentId: studentId,
        status: status,
        date: date,
      );

      _items
        ..clear()
        ..addAll(result);

      _lastFetchedAt = DateTime.now();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<AbsenceJustificationModel?> fetchById({
    required AuthProvider authProvider,
    required String justificationId,
    bool selectAfterFetch = true,
  }) async {
    final token = _requireToken(authProvider);

    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _service.getById(
        token: token,
        justificationId: justificationId,
      );

      _upsert(result);

      if (selectAfterFetch) {
        _selected = result;
      }

      return result;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DownloadedJustificationDocument?> downloadDocument({
    required AuthProvider authProvider,
    required String justificationId,
    bool useCache = true,
  }) async {
    final token = _requireToken(authProvider);

    _errorMessage = null;

    if (useCache && _documentCache.containsKey(justificationId)) {
      return _documentCache[justificationId];
    }

    _isDownloadingDocument = true;
    notifyListeners();

    try {
      final result = await _service.downloadDocument(
        token: token,
        justificationId: justificationId,
      );

      _documentCache[justificationId] = result;
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isDownloadingDocument = false;
      notifyListeners();
    }
  }

  Future<AbsenceJustificationModel?> createJustification({
    required AuthProvider authProvider,
    required AbsenceJustificationCreatePayload payload,
    required List<int> documentBytes,
    required String fileName,
    bool addToList = true,
  }) async {
    final token = _requireToken(authProvider);

    _errorMessage = null;
    _isSubmitting = true;
    notifyListeners();

    try {
      final result = await _service.createJustification(
        token: token,
        payload: payload,
        documentBytes: documentBytes,
        fileName: fileName,
      );

      if (addToList) {
        _upsert(result);
      }

      _selected = result;
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<AbsenceJustificationModel?> reviewJustification({
    required AuthProvider authProvider,
    required String justificationId,
    required AbsenceJustificationReviewPayload payload,
  }) async {
    final token = _requireToken(authProvider);

    _errorMessage = null;
    _isReviewing = true;
    notifyListeners();

    try {
      final result = await _service.reviewJustification(
        token: token,
        justificationId: justificationId,
        payload: payload,
      );

      _upsert(result);
      _selected = result;
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isReviewing = false;
      notifyListeners();
    }
  }

  void removeFromCache(String justificationId) {
    _documentCache.remove(justificationId);
    notifyListeners();
  }

  void _upsert(AbsenceJustificationModel model) {
    final index = _items.indexWhere((item) => item.id == model.id);
    if (index == -1) {
      _items.add(model);
    } else {
      _items[index] = model;
    }

    _items.sort((a, b) {
      final aDate = a.createdAt ?? a.coverageStartDate;
      final bDate = b.createdAt ?? b.coverageStartDate;
      return bDate.compareTo(aDate);
    });
  }

  String _requireToken(AuthProvider authProvider) {
    final token = authProvider.token;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Usuário não autenticado.');
    }
    return token;
  }

  int _statusPriority(AbsenceJustificationStatus status) {
    switch (status) {
      case AbsenceJustificationStatus.approved:
        return 0;
      case AbsenceJustificationStatus.pending:
        return 1;
      case AbsenceJustificationStatus.rejected:
        return 2;
      case AbsenceJustificationStatus.expired:
        return 3;
      case AbsenceJustificationStatus.unknown:
        return 4;
    }
  }
}
