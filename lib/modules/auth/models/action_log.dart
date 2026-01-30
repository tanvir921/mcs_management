import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking admin actions
class ActionLog {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String module;
  final String? details;
  final DateTime timestamp;

  const ActionLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.module,
    this.details,
    required this.timestamp,
  });

  factory ActionLog.fromJson(Map<String, dynamic> json) {
    return ActionLog(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      action: json['action'] as String,
      module: json['module'] as String,
      details: json['details'] as String?,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'action': action,
      'module': module,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
