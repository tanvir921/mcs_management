/// Base model class for all domain models
/// Extended by: Wallet, Transaction, Customer, Profit
abstract class BaseModel {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  BaseModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  /// Convert model to Map for Firestore
  Map<String, dynamic> toMap();

  /// Create a copy with updated fields
  BaseModel copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  });
}
