enum AppNotificationType {
  eventStartingSoon,
  eventCancelledOrDeleted,
  eventInvite,
  eventUpdated,
}

AppNotificationType appNotificationTypeFromString(String raw) {
  switch (raw) {
    case 'eventStartingSoon':
      return AppNotificationType.eventStartingSoon;
    case 'eventCancelledOrDeleted':
      return AppNotificationType.eventCancelledOrDeleted;
    case 'eventInvite':
      return AppNotificationType.eventInvite;
    case 'eventUpdated':
      return AppNotificationType.eventUpdated;
    default:
      return AppNotificationType.eventInvite;
  }
}

String appNotificationTypeToString(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.eventStartingSoon:
      return 'eventStartingSoon';
    case AppNotificationType.eventCancelledOrDeleted:
      return 'eventCancelledOrDeleted';
    case AppNotificationType.eventInvite:
      return 'eventInvite';
    case AppNotificationType.eventUpdated:
      return 'eventUpdated';
  }
}

class AppNotification {
  final String id;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? targetEventId;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.targetEventId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': appNotificationTypeToString(type),
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'targetEventId': targetEventId,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      type: appNotificationTypeFromString((map['type'] ?? '').toString()),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      isRead: map['isRead'] == true,
      targetEventId: map['targetEventId']?.toString(),
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    AppNotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    String? targetEventId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      targetEventId: targetEventId ?? this.targetEventId,
    );
  }
}
