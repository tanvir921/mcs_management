import 'package:cloud_firestore/cloud_firestore.dart';

class DueTransaction {
  final String id;
  final String customerId;
  final String
  dueType; // product, service, msfRecharge, cashBorrow, previousDue
  final double amount;
  final bool isAddition; // true for add, false for subtract
  final String? saleId; // Reference to sale if from product sale
  final double potentialProfit; // Profit pending in this due
  final bool profitRealized; // Whether profit was added when due cleared
  final double realizedProfitAmount; // Actual profit realized when clearing due
  final String? note;
  final DateTime createdAt;
  final String createdBy; // Admin user ID
  final String createdByName; // Admin user name

  const DueTransaction({
    required this.id,
    required this.customerId,
    required this.dueType,
    required this.amount,
    required this.isAddition,
    this.saleId,
    this.potentialProfit = 0,
    this.profitRealized = false,
    this.realizedProfitAmount = 0,
    this.note,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
  });

  factory DueTransaction.fromJson(Map<String, dynamic> json) {
    return DueTransaction(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      dueType: json['dueType'] as String,
      amount: (json['amount'] as num).toDouble(),
      isAddition: json['isAddition'] as bool,
      saleId: json['saleId'] as String?,
      potentialProfit: (json['potentialProfit'] as num?)?.toDouble() ?? 0,
      profitRealized: json['profitRealized'] as bool? ?? false,
      realizedProfitAmount:
          (json['realizedProfitAmount'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      createdBy: json['createdBy'] as String,
      createdByName: json['createdByName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'dueType': dueType,
      'amount': amount,
      'isAddition': isAddition,
      'saleId': saleId,
      'potentialProfit': potentialProfit,
      'profitRealized': profitRealized,
      'realizedProfitAmount': realizedProfitAmount,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }

  String get dueTypeLabel {
    switch (dueType) {
      case 'product':
        return 'Product Due';
      case 'service':
        return 'Service Due';
      case 'msfRecharge':
        return 'MSF/Recharge Due';
      case 'cashBorrow':
        return 'Cash Borrow';
      case 'previousDue':
        return 'Previous Due';
      default:
        return dueType;
    }
  }

  String get transactionType {
    return isAddition ? 'Due Added' : 'Payment Received';
  }
}
