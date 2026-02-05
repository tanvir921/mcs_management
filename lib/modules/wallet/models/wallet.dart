import 'package:cloud_firestore/cloud_firestore.dart';
import 'wallet_type.dart';

class Wallet {
  final String id;
  final String userId;
  final WalletType type;
  final String? customName; // For custom wallets
  final double permanentBalance; // Permanent balance - less frequently deducted
  final double
  temporaryBalance; // Temporary balance - can be deducted in 1-2 days
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Wallet({
    required this.id,
    required this.userId,
    required this.type,
    this.customName,
    required this.permanentBalance,
    required this.temporaryBalance,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  String get displayName {
    if (type == WalletType.custom && customName != null) {
      return customName!;
    }
    return type.label;
  }

  double get totalBalance => permanentBalance + temporaryBalance;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: WalletType.values.firstWhere(
        (e) => e.toString() == 'WalletType.${json['type']}',
        orElse: () => WalletType.custom,
      ),
      customName: json['customName'] as String?,
      permanentBalance: (json['permanentBalance'] as num?)?.toDouble() ?? 0,
      temporaryBalance: (json['temporaryBalance'] as num?)?.toDouble() ?? 0,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString().split('.').last,
      'customName': customName,
      'permanentBalance': permanentBalance,
      'temporaryBalance': temporaryBalance,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  /// Use this for creating new documents - uses server timestamp
  Map<String, dynamic> toJsonForCreate() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString().split('.').last,
      'customName': customName,
      'permanentBalance': permanentBalance,
      'temporaryBalance': temporaryBalance,
      'createdAt': FieldValue.serverTimestamp(), // Server timestamp for accuracy
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  Wallet copyWith({
    String? id,
    String? userId,
    WalletType? type,
    String? customName,
    double? permanentBalance,
    double? temporaryBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      permanentBalance: permanentBalance ?? this.permanentBalance,
      temporaryBalance: temporaryBalance ?? this.temporaryBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
