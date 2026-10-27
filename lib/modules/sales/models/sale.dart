import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/app_time.dart';
import 'sale_item.dart';

class Sale {
  final String id;
  final String saleNumber;
  final DateTime saleDate;
  final List<SaleItem> items;
  final double totalCost;
  final double totalSelling;
  final double totalProfit;
  final double discountAmount; // discount in taka
  final double discountPercent; // discount in percentage
  final String paymentMethod; // cash, card, mobile_banking, credit
  final double paidAmount; // amount paid by customer
  final double dueAmount; // remaining amount as due
  final double realizedProfit; // profit from paid amount
  final double potentialProfit; // profit pending in due
  final String? customerId;
  final String? customerName;
  final String? notes;
  final String createdBy;
  final String createdByName;
  final DateTime?
  createdAt; // Nullable - will be set by server timestamp on create
  final DateTime? updatedAt;
  final bool isActive;

  Sale({
    required this.id,
    required this.saleNumber,
    required this.saleDate,
    required this.items,
    required this.totalCost,
    required this.totalSelling,
    required this.totalProfit,
    this.discountAmount = 0,
    this.discountPercent = 0,
    required this.paymentMethod,
    required this.paidAmount,
    this.dueAmount = 0,
    this.realizedProfit = 0,
    this.potentialProfit = 0,
    this.customerId,
    this.customerName,
    this.notes,
    required this.createdBy,
    required this.createdByName,
    this.createdAt, // Optional - server timestamp used on create
    this.updatedAt,
    this.isActive = true,
  });

  double get profitMargin =>
      totalSelling > 0 ? (totalProfit / totalSelling) * 100 : 0;

  double get finalAmount => totalSelling - discountAmount;

  factory Sale.fromMap(Map<String, dynamic> map) {
    final rawSaleDate = map['saleDate'];
    final rawCreatedAt = map['createdAt'];
    final rawUpdatedAt = map['updatedAt'];

    DateTime saleDate;
    if (rawSaleDate is Timestamp) {
      saleDate = AppTime.toBusiness(rawSaleDate.toDate());
    } else if (rawSaleDate is DateTime) {
      saleDate = AppTime.toBusiness(rawSaleDate);
    } else {
      saleDate = AppTime.businessNow();
    }

    DateTime? createdAt;
    if (rawCreatedAt is Timestamp) {
      createdAt = AppTime.toBusiness(rawCreatedAt.toDate());
    } else if (rawCreatedAt is DateTime) {
      createdAt = AppTime.toBusiness(rawCreatedAt);
    }

    DateTime? updatedAt;
    if (rawUpdatedAt is Timestamp) {
      updatedAt = AppTime.toBusiness(rawUpdatedAt.toDate());
    } else if (rawUpdatedAt is DateTime) {
      updatedAt = AppTime.toBusiness(rawUpdatedAt);
    }

    return Sale(
      id: map['id'] ?? '',
      saleNumber: map['saleNumber'] ?? '',
      saleDate: saleDate,
      items:
          (map['items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      totalSelling: (map['totalSelling'] ?? 0).toDouble(),
      totalProfit: (map['totalProfit'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      discountPercent: (map['discountPercent'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'cash',
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      dueAmount: (map['dueAmount'] ?? 0).toDouble(),
      realizedProfit: (map['realizedProfit'] ?? 0).toDouble(),
      potentialProfit: (map['potentialProfit'] ?? 0).toDouble(),
      customerId: map['customerId'],
      customerName: map['customerName'],
      notes: map['notes'],
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleNumber': saleNumber,
      'saleDate': Timestamp.fromDate(AppTime.toUtcFromBusiness(saleDate)),
      'items': items.map((item) => item.toMap()).toList(),
      'totalCost': totalCost,
      'totalSelling': totalSelling,
      'totalProfit': totalProfit,
      'discountAmount': discountAmount,
      'discountPercent': discountPercent,
      'paymentMethod': paymentMethod,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'realizedProfit': realizedProfit,
      'potentialProfit': potentialProfit,
      'customerId': customerId,
      'customerName': customerName,
      'notes': notes,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!.toUtc())
          : FieldValue.serverTimestamp(),
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!.toUtc()) : null,
      'isActive': isActive,
    };
  }

  /// Use this for creating new documents - uses server timestamp
  Map<String, dynamic> toMapForCreate() {
    return {
      'id': id,
      'saleNumber': saleNumber,
      'saleDate': Timestamp.fromDate(AppTime.toUtcFromBusiness(saleDate)),
      'items': items.map((item) => item.toMap()).toList(),
      'totalCost': totalCost,
      'totalSelling': totalSelling,
      'totalProfit': totalProfit,
      'discountAmount': discountAmount,
      'discountPercent': discountPercent,
      'paymentMethod': paymentMethod,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'realizedProfit': realizedProfit,
      'potentialProfit': potentialProfit,
      'customerId': customerId,
      'customerName': customerName,
      'notes': notes,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt':
          FieldValue.serverTimestamp(), // Server timestamp for accuracy
      'updatedAt': updatedAt,
      'isActive': isActive,
    };
  }

  Sale copyWith({
    String? id,
    String? saleNumber,
    DateTime? saleDate,
    List<SaleItem>? items,
    double? totalCost,
    double? totalSelling,
    double? totalProfit,
    double? discountAmount,
    double? discountPercent,
    String? paymentMethod,
    double? paidAmount,
    double? dueAmount,
    double? realizedProfit,
    double? potentialProfit,
    String? customerId,
    String? customerName,
    String? notes,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Sale(
      id: id ?? this.id,
      saleNumber: saleNumber ?? this.saleNumber,
      saleDate: saleDate ?? this.saleDate,
      items: items ?? this.items,
      totalCost: totalCost ?? this.totalCost,
      totalSelling: totalSelling ?? this.totalSelling,
      totalProfit: totalProfit ?? this.totalProfit,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAmount: paidAmount ?? this.paidAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      realizedProfit: realizedProfit ?? this.realizedProfit,
      potentialProfit: potentialProfit ?? this.potentialProfit,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
