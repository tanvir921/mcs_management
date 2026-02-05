import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking admin actions
class ActionLog {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String module;
  final String? details;
  final DateTime?
  timestamp; // Nullable - will be set by server timestamp on create

  const ActionLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.module,
    this.details,
    this.timestamp, // Optional - server timestamp used on create
  });

  factory ActionLog.fromJson(Map<String, dynamic> json) {
    return ActionLog(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      action: json['action'] as String,
      module: json['module'] as String,
      details: json['details'] as String?,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  /// Use this for creating new documents - uses server timestamp
  Map<String, dynamic> toJsonForCreate() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'action': action,
      'module': module,
      'details': details,
      'timestamp':
          FieldValue.serverTimestamp(), // Server timestamp for accuracy
    };
  }

  /// Use this for updates or when timestamp is already set
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'action': action,
      'module': module,
      'details': details,
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
    };
  }
}
