import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseHistory {
  final String id;
  final String customerId;
  final String description;
  final double amount;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final String? note;

  const PurchaseHistory({
    required this.id,
    required this.customerId,
    required this.description,
    required this.amount,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.note,
  });

  factory PurchaseHistory.fromJson(Map<String, dynamic> json) {
    return PurchaseHistory(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      createdBy: json['createdBy'] as String,
      createdByName: json['createdByName'] as String,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'description': description,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'note': note,
    };
  }
}
