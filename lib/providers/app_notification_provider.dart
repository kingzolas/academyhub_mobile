import 'dart:async';

import 'package:academyhub_mobile/model/app_notification_model.dart';
import 'package:academyhub_mobile/services/app_notification_realtime_mapper.dart';
import 'package:academyhub_mobile/services/app_notification_service.dart';
import 'package:flutter/foundation.dart';

class AppNotificationProvider extends ChangeNotifier {
  final AppNotificationService _service = AppNotificationService();
  final List<AppNotificationItem> _items = [];
  static const int _maxItems = 60;
  static const int _maxThreadHistory = 5;
  bool _isLoading = false;

  List<AppNotificationItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  int get unreadCount => _items.where((item) => item.isUnread).length;

  Future<void> loadPersisted({required String token}) async {
    if (token.trim().isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final persisted = await _service.fetchNotifications(token: token);
      for (final item in persisted.reversed) {
        _upsertNotification(item, preserveLocalReadState: false);
      }
      _trimAndSort();
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
            '[AppNotificationProvider] Falha ao carregar histórico: $error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool handleRealtimeEvent(
    Map<String, dynamic> message, {
    String? currentStudentId,
    List<String> linkedStudentIds = const [],
  }) {
    final notification = AppNotificationRealtimeMapper.fromWebSocketMessage(
      message,
      currentStudentId: currentStudentId,
      linkedStudentIds: linkedStudentIds,
    );
    if (notification == null) return false;

    _upsertNotification(notification);
    _trimAndSort();
    notifyListeners();
    return true;
  }

  void markAsRead(String id, [String? token]) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || !_items[index].isUnread) return;

    _items[index] = _items[index].copyWith(readAt: DateTime.now());
    notifyListeners();

    if ((token ?? '').trim().isNotEmpty) {
      unawaited(
        _service
            .markAsRead(token: token!.trim(), notificationId: id)
            .catchError((_) {}),
      );
    }
  }

  void markAllAsRead([String? token]) {
    var changed = false;
    final now = DateTime.now();
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].isUnread) {
        _items[index] = _items[index].copyWith(readAt: now);
        changed = true;
      }
    }
    if (changed) notifyListeners();

    if ((token ?? '').trim().isNotEmpty) {
      unawaited(
          _service.markAllAsRead(token: token!.trim()).catchError((_) {}));
    }
  }

  void markDisplayedAsRead(
    Iterable<AppNotificationItem> notifications, [
    String? token,
  ]) {
    final ids = notifications.map((item) => item.id).toSet();
    if (ids.isEmpty) return;

    var changed = false;
    final now = DateTime.now();
    for (var index = 0; index < _items.length; index++) {
      if (ids.contains(_items[index].id) && _items[index].isUnread) {
        _items[index] = _items[index].copyWith(readAt: now);
        changed = true;
      }
    }
    if (changed) notifyListeners();

    if ((token ?? '').trim().isNotEmpty) {
      unawaited(
          _service.markAllAsRead(token: token!.trim()).catchError((_) {}));
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  int _findNotificationIndex(AppNotificationItem notification) {
    final threadKey = notification.threadKey.trim();
    if (threadKey.isNotEmpty) {
      final index = _items.indexWhere((item) => item.threadKey == threadKey);
      if (index >= 0) return index;
    }
    return _items.indexWhere((item) => item.id == notification.id);
  }

  void _upsertNotification(
    AppNotificationItem notification, {
    bool preserveLocalReadState = true,
  }) {
    final index = _findNotificationIndex(notification);
    if (index >= 0) {
      final previous = _items[index];
      final readAt = preserveLocalReadState && previous.readAt != null
          ? previous.readAt
          : notification.readAt;

      if (previous.id == notification.id) {
        _items[index] = notification.copyWith(
          readAt: readAt,
          history: previous.history,
        );
      } else {
        final history = <AppNotificationHistoryEntry>[
          AppNotificationHistoryEntry.fromNotification(previous),
          ...previous.history,
        ].take(_maxThreadHistory).toList();

        _items[index] = notification.copyWith(
          readAt: readAt,
          history: history,
        );
      }
    } else {
      _items.insert(0, notification);
    }
  }

  void _trimAndSort() {
    _items.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }
  }
}
