import 'package:cloud_firestore/cloud_firestore.dart';

class BalanceHistory {
  final String id;
  final String walletId;
  final String balanceType; // 'permanent' or 'temporary'
  final double previousBalance;
  final double newBalance;
  final double change; // Can be positive or negative
  final String note;
  final DateTime changedAt;
  final String changedBy;
  final String changedByName;

  BalanceHistory({
    required this.id,
    required this.walletId,
    required this.balanceType,
    required this.previousBalance,
    required this.newBalance,
    required this.change,
    required this.note,
    required this.changedAt,
    required this.changedBy,
    required this.changedByName,
  });

  factory BalanceHistory.fromJson(Map<String, dynamic> json) {
    return BalanceHistory(
      id: json['id'] as String,
      walletId: json['walletId'] as String,
      balanceType: json['balanceType'] as String? ?? 'permanent',
      previousBalance: (json['previousBalance'] as num?)?.toDouble() ?? 0,
      newBalance: (json['newBalance'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String? ?? '',
      changedAt: (json['changedAt'] as Timestamp).toDate(),
      changedBy: json['changedBy'] as String? ?? '',
      changedByName: json['changedByName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'balanceType': balanceType,
      'previousBalance': previousBalance,
      'newBalance': newBalance,
      'change': change,
      'note': note,
      'changedAt': Timestamp.fromDate(changedAt),
      'changedBy': changedBy,
      'changedByName': changedByName,
    };
  }
}
