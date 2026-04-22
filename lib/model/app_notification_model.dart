enum AppNotificationDomain {
  documents,
  activities,
  finance,
  academic,
  system,
}

enum AppNotificationPriority {
  info,
  success,
  warning,
  critical,
}

class AppNotificationHistoryEntry {
  final String type;
  final String title;
  final String summary;
  final DateTime occurredAt;
  final AppNotificationPriority priority;

  const AppNotificationHistoryEntry({
    required this.type,
    required this.title,
    required this.summary,
    required this.occurredAt,
    this.priority = AppNotificationPriority.info,
  });

  factory AppNotificationHistoryEntry.fromNotification(
    AppNotificationItem item,
  ) {
    return AppNotificationHistoryEntry(
      type: item.type,
      title: item.title,
      summary: item.summary,
      occurredAt: item.createdAt,
      priority: item.priority,
    );
  }
}

class AppNotificationItem {
  final String id;
  final String threadKey;
  final AppNotificationDomain domain;
  final String type;
  final String title;
  final String summary;
  final DateTime createdAt;
  final DateTime? readAt;
  final AppNotificationPriority priority;
  final String routeKey;
  final Map<String, dynamic> metadata;
  final List<AppNotificationHistoryEntry> history;

  const AppNotificationItem({
    required this.id,
    required this.domain,
    required this.type,
    required this.title,
    required this.summary,
    required this.createdAt,
    required this.routeKey,
    this.threadKey = '',
    this.readAt,
    this.priority = AppNotificationPriority.info,
    this.metadata = const {},
    this.history = const [],
  });

  bool get isUnread => readAt == null;

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return AppNotificationItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      threadKey: (json['threadKey'] ?? '').toString(),
      domain: _domainFromString((json['domain'] ?? '').toString()),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? 'Notificação').toString(),
      summary: (json['summary'] ?? '').toString(),
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      readAt: DateTime.tryParse('${json['readAt'] ?? ''}'),
      priority: _priorityFromString((json['priority'] ?? '').toString()),
      routeKey: (json['routeKey'] ?? '').toString(),
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const {},
    );
  }

  AppNotificationItem copyWith({
    String? id,
    String? threadKey,
    AppNotificationDomain? domain,
    String? type,
    String? title,
    String? summary,
    DateTime? createdAt,
    DateTime? readAt,
    bool clearReadAt = false,
    AppNotificationPriority? priority,
    String? routeKey,
    Map<String, dynamic>? metadata,
    List<AppNotificationHistoryEntry>? history,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      threadKey: threadKey ?? this.threadKey,
      domain: domain ?? this.domain,
      type: type ?? this.type,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      priority: priority ?? this.priority,
      routeKey: routeKey ?? this.routeKey,
      metadata: metadata ?? this.metadata,
      history: history ?? this.history,
    );
  }
}

AppNotificationDomain _domainFromString(String value) {
  switch (value.trim().toLowerCase()) {
    case 'documents':
      return AppNotificationDomain.documents;
    case 'activities':
      return AppNotificationDomain.activities;
    case 'finance':
      return AppNotificationDomain.finance;
    case 'academic':
    case 'attendance':
      return AppNotificationDomain.academic;
    case 'system':
    default:
      return AppNotificationDomain.system;
  }
}

AppNotificationPriority _priorityFromString(String value) {
  switch (value.trim().toLowerCase()) {
    case 'success':
      return AppNotificationPriority.success;
    case 'warning':
      return AppNotificationPriority.warning;
    case 'critical':
      return AppNotificationPriority.critical;
    case 'info':
    default:
      return AppNotificationPriority.info;
  }
}
