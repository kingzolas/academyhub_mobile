import 'package:academyhub_mobile/model/app_notification_model.dart';
import 'package:academyhub_mobile/services/app_notification_realtime_mapper.dart';
import 'package:flutter/foundation.dart';

class AppNotificationProvider extends ChangeNotifier {
  final List<AppNotificationItem> _items = [];
  static const int _maxItems = 60;
  static const int _maxThreadHistory = 5;

  List<AppNotificationItem> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((item) => item.isUnread).length;

  bool handleRealtimeEvent(
    Map<String, dynamic> message, {
    String? currentStudentId,
  }) {
    final notification = AppNotificationRealtimeMapper.fromWebSocketMessage(
      message,
      currentStudentId: currentStudentId,
    );
    if (notification == null) return false;

    final index = _findNotificationIndex(notification);
    if (index >= 0) {
      final previous = _items[index];
      if (previous.id == notification.id) {
        _items[index] = notification.copyWith(
          readAt: previous.readAt,
          history: previous.history,
        );
      } else {
        final history = <AppNotificationHistoryEntry>[
          AppNotificationHistoryEntry.fromNotification(previous),
          ...previous.history,
        ].take(_maxThreadHistory).toList();

        _items[index] = notification.copyWith(history: history);
      }
    } else {
      _items.insert(0, notification);
    }

    _items.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }

    notifyListeners();
    return true;
  }

  void markAsRead(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || !_items[index].isUnread) return;

    _items[index] = _items[index].copyWith(readAt: DateTime.now());
    notifyListeners();
  }

  void markAllAsRead() {
    var changed = false;
    final now = DateTime.now();
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].isUnread) {
        _items[index] = _items[index].copyWith(readAt: now);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void markDisplayedAsRead(Iterable<AppNotificationItem> notifications) {
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
}
