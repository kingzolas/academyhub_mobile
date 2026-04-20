import 'dart:typed_data';

import 'package:academyhub_mobile/model/guardian_official_document_model.dart';
import 'package:academyhub_mobile/services/guardian_official_document_service.dart';
import 'package:flutter/material.dart';

class GuardianOfficialDocumentsProvider extends ChangeNotifier {
  final GuardianOfficialDocumentService _service =
      GuardianOfficialDocumentService();

  List<GuardianOfficialDocumentCatalogItem> _catalog =
      GuardianOfficialDocumentCatalogItem.defaults;
  List<GuardianOfficialDocumentRequest> _requests = [];
  List<GuardianOfficialDocument> _documents = [];

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isSubmitting = false;
  String? _downloadingDocumentId;
  String? _error;
  String? _studentId;

  List<GuardianOfficialDocumentCatalogItem> get catalog => _catalog;
  List<GuardianOfficialDocumentRequest> get requests => _requests;
  List<GuardianOfficialDocument> get documents => _documents;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSubmitting => _isSubmitting;
  String? get downloadingDocumentId => _downloadingDocumentId;
  String? get error => _error;
  String? get loadedStudentId => _studentId;

  List<GuardianOfficialDocumentRequest> get activeRequests {
    return _requests
        .where((request) =>
            request.status !=
                GuardianOfficialDocumentRequestStatuses.rejected &&
            request.status !=
                GuardianOfficialDocumentRequestStatuses.downloaded &&
            request.status != GuardianOfficialDocumentRequestStatuses.cancelled)
        .toList();
  }

  List<GuardianOfficialDocumentRequest> get rejectedRequests {
    return _requests
        .where((request) =>
            request.status ==
                GuardianOfficialDocumentRequestStatuses.rejected ||
            request.status == GuardianOfficialDocumentRequestStatuses.cancelled)
        .toList();
  }

  bool handleRealtimeEvent(
    Map<String, dynamic> message, {
    String? studentId,
  }) {
    final type = message['type']?.toString().trim() ?? '';
    if (!type.startsWith('official_document_')) return false;

    final payload = _mapValue(message['payload']);
    if (payload == null) return false;

    final payloadStudentId = _stringValue(payload['studentId']) ??
        _stringValue(_mapValue(payload['request'])?['studentId']) ??
        _stringValue(_mapValue(payload['document'])?['studentId']);
    final currentStudentId =
        studentId?.trim().isNotEmpty == true ? studentId!.trim() : _studentId;

    if (currentStudentId != null &&
        payloadStudentId != null &&
        payloadStudentId != currentStudentId) {
      return false;
    }

    var changed = false;
    final requestJson = _mapValue(payload['request']);
    if (requestJson != null) {
      _upsertRequest(GuardianOfficialDocumentRequest.fromJson(requestJson));
      changed = true;
    }

    final documentJson = _mapValue(payload['document']);
    if (documentJson != null) {
      final document = GuardianOfficialDocument.fromJson(documentJson);
      if (document.isPublished) {
        _upsertDocument(document);
      } else {
        _documents.removeWhere((item) => item.id == document.id);
      }
      changed = true;
    }

    if (!changed) return false;

    _requests.sort(_sortRequests);
    _documents.sort(_sortDocuments);
    notifyListeners();
    return true;
  }

  Future<void> load({
    required String token,
    required String studentId,
    bool silent = false,
  }) async {
    final normalizedStudentId = studentId.trim();
    if (normalizedStudentId.isEmpty) {
      _requests = [];
      _documents = [];
      _error = 'Selecione um aluno para visualizar documentações.';
      notifyListeners();
      return;
    }

    _studentId = normalizedStudentId;
    if (silent) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _service.getCatalog(token: token),
        _service.getRequests(token: token, studentId: normalizedStudentId),
        _service.getPublishedDocuments(
          token: token,
          studentId: normalizedStudentId,
        ),
      ]);

      _catalog = (results[0] as List<GuardianOfficialDocumentCatalogItem>)
          .where((item) => item.type.trim().isNotEmpty)
          .toList();
      if (_catalog.isEmpty) {
        _catalog = GuardianOfficialDocumentCatalogItem.defaults;
      }

      _requests = (results[1] as List<GuardianOfficialDocumentRequest>).toList()
        ..sort(_sortRequests);
      _documents = (results[2] as List<GuardianOfficialDocument>).toList()
        ..sort(_sortDocuments);
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<bool> createRequest({
    required String token,
    required String studentId,
    required String documentType,
    required String purpose,
    String? notes,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final request = await _service.createRequest(
        token: token,
        studentId: studentId,
        documentType: documentType,
        purpose: purpose,
        notes: notes,
      );
      _requests = [request, ..._requests]..sort(_sortRequests);
      notifyListeners();

      await load(token: token, studentId: studentId, silent: true);
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> downloadDocument({
    required String token,
    required GuardianOfficialDocument document,
  }) async {
    _downloadingDocumentId = document.id;
    _error = null;
    notifyListeners();

    try {
      final bytes = await _service.downloadPublishedDocument(
        token: token,
        documentId: document.id,
        fileUrl: document.fileUrl,
      );
      await _service.markDownloaded(token: token, documentId: document.id);
      return bytes;
    } catch (e) {
      _error = _friendlyError(e);
      return null;
    } finally {
      _downloadingDocumentId = null;
      notifyListeners();
    }
  }

  void clear() {
    _requests = [];
    _documents = [];
    _error = null;
    _studentId = null;
    notifyListeners();
  }

  void _upsertRequest(GuardianOfficialDocumentRequest request) {
    final index = _requests.indexWhere((item) => item.id == request.id);
    if (index >= 0) {
      _requests[index] = request;
    } else {
      _requests.add(request);
    }
  }

  void _upsertDocument(GuardianOfficialDocument document) {
    final index = _documents.indexWhere((item) => item.id == document.id);
    if (index >= 0) {
      _documents[index] = document;
    } else {
      _documents.add(document);
    }
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is Map<String, dynamic>) {
      return _stringValue(value['_id']) ?? _stringValue(value['id']);
    }
    if (value is Map) {
      return _stringValue(value['_id']) ?? _stringValue(value['id']);
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int _sortRequests(
    GuardianOfficialDocumentRequest a,
    GuardianOfficialDocumentRequest b,
  ) {
    final left =
        a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right =
        b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  }

  int _sortDocuments(
    GuardianOfficialDocument a,
    GuardianOfficialDocument b,
  ) {
    final left = a.publishedAt ??
        a.signedAt ??
        a.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.publishedAt ??
        b.signedAt ??
        b.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) {
      return 'Não foi possível carregar as documentações agora.';
    }
    if (raw.toLowerCase().contains('socket') ||
        raw.toLowerCase().contains('connection') ||
        raw.toLowerCase().contains('failed host lookup')) {
      return 'Sem conexão com a internet. Verifique a rede e tente novamente.';
    }
    return raw;
  }
}
