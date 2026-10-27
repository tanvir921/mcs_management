import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/app_time.dart';

class Expense {
  final String id;
  final String expenseNumber;
  final DateTime expenseDate;
  final String category; // personal, shop, stock_purchase, electricity_wifi, repair, other
  final double amount;
  final String description;
  final String paymentMethod; // cash, card, mobile_banking
  final String? notes;
  final List<String> receiptPhotos; // URLs of receipt photos
  final String createdBy;
  final String createdByName;
  final DateTime?
  createdAt; // Nullable - will be set by server timestamp on create
  final DateTime? updatedAt;
  final bool isActive;

  Expense({
    required this.id,
    required this.expenseNumber,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.description,
    required this.paymentMethod,
    this.notes,
    this.receiptPhotos = const [],
    required this.createdBy,
    required this.createdByName,
    this.createdAt, // Optional - server timestamp used on create
    this.updatedAt,
    this.isActive = true,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    final rawExpenseDate = map['expenseDate'];
    final rawCreatedAt = map['createdAt'];
    final rawUpdatedAt = map['updatedAt'];

    DateTime expenseDate;
    if (rawExpenseDate is Timestamp) {
      expenseDate = AppTime.toBusiness(rawExpenseDate.toDate());
    } else if (rawExpenseDate is DateTime) {
      expenseDate = AppTime.toBusiness(rawExpenseDate);
    } else {
      expenseDate = AppTime.businessNow();
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

    return Expense(
      id: map['id'] ?? '',
      expenseNumber: map['expenseNumber'] ?? '',
      expenseDate: expenseDate,
      category: map['category'] ?? 'other',
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'cash',
      notes: map['notes'],
      receiptPhotos: List<String>.from(map['receiptPhotos'] ?? []),
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
      'expenseNumber': expenseNumber,
      'expenseDate':
          Timestamp.fromDate(AppTime.toUtcFromBusiness(expenseDate)),
      'category': category,
      'amount': amount,
      'description': description,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'receiptPhotos': receiptPhotos,
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
      'expenseNumber': expenseNumber,
      'expenseDate':
          Timestamp.fromDate(AppTime.toUtcFromBusiness(expenseDate)),
      'category': category,
      'amount': amount,
      'description': description,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'receiptPhotos': receiptPhotos,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt':
          FieldValue.serverTimestamp(), // Server timestamp for accuracy
      'updatedAt': updatedAt,
      'isActive': isActive,
    };
  }

  Expense copyWith({
    String? id,
    String? expenseNumber,
    DateTime? expenseDate,
    String? category,
    double? amount,
    String? description,
    String? paymentMethod,
    String? notes,
    List<String>? receiptPhotos,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Expense(
      id: id ?? this.id,
      expenseNumber: expenseNumber ?? this.expenseNumber,
      expenseDate: expenseDate ?? this.expenseDate,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      receiptPhotos: receiptPhotos ?? this.receiptPhotos,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  static String getCategoryDisplayName(String category) {
    switch (category) {
      case 'shop':
        return 'Shop Expense';
      case 'personal':
        return 'Personal Expense';
      case 'stock_purchase':
        return 'Stock Purchase (মালামাল)';
      case 'electricity_wifi':
        return 'Electricity & WiFi';
      case 'repair':
        return 'Repair & Maintenance';
      case 'other':
        return 'Other Expense';
      default:
        return category;
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'shop':
        return Icons.shopping_bag_rounded;
      case 'personal':
        return Icons.person_rounded;
      case 'stock_purchase':
        return Icons.inventory_2_rounded;
      case 'electricity_wifi':
        return Icons.wifi_tethering_rounded;
      case 'repair':
        return Icons.build_rounded;
      case 'other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'shop':
        return const Color(0xFFFF9500); // Orange
      case 'personal':
        return const Color(0xFF5856D6); // Purple
      case 'stock_purchase':
        return const Color(0xFF34C759); // Green
      case 'electricity_wifi':
        return const Color(0xFF00C7BE); // Teal
      case 'repair':
        return const Color(0xFFFF3B30); // Red
      case 'other':
        return const Color(0xFF007AFF); // Blue
      default:
        return const Color(0xFF8E8E93); // Gray
    }
  }
}
