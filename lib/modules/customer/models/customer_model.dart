import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  // Dues tracking
  final double productDue;
  final double serviceDue;
  final double msfRechargeDue;
  final double cashBorrowDue;
  final double previousDue;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    this.productDue = 0,
    this.serviceDue = 0,
    this.msfRechargeDue = 0,
    this.cashBorrowDue = 0,
    this.previousDue = 0,
  });

  double get totalDue =>
      productDue + serviceDue + msfRechargeDue + cashBorrowDue + previousDue;

  // Net balance is negative when customer owes; no advance deposit concept
  double get netBalance => -totalDue;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      isActive: json['isActive'] as bool? ?? true,
      productDue: (json['productDue'] as num?)?.toDouble() ?? 0,
      serviceDue: (json['serviceDue'] as num?)?.toDouble() ?? 0,
      msfRechargeDue: (json['msfRechargeDue'] as num?)?.toDouble() ?? 0,
      cashBorrowDue: (json['cashBorrowDue'] as num?)?.toDouble() ?? 0,
      previousDue: (json['previousDue'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'productDue': productDue,
      'serviceDue': serviceDue,
      'msfRechargeDue': msfRechargeDue,
      'cashBorrowDue': cashBorrowDue,
      'previousDue': previousDue,
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    double? productDue,
    double? serviceDue,
    double? msfRechargeDue,
    double? cashBorrowDue,
    double? previousDue,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      productDue: productDue ?? this.productDue,
      serviceDue: serviceDue ?? this.serviceDue,
      msfRechargeDue: msfRechargeDue ?? this.msfRechargeDue,
      cashBorrowDue: cashBorrowDue ?? this.cashBorrowDue,
      previousDue: previousDue ?? this.previousDue,
    );
  }
}
