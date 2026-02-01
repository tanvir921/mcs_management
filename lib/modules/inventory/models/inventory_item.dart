import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of inventory item: product or service
enum ItemType { product, service }

extension ItemTypeExtension on ItemType {
  String get displayName {
    switch (this) {
      case ItemType.product:
        return 'Product';
      case ItemType.service:
        return 'Service';
    }
  }

  String get value {
    switch (this) {
      case ItemType.product:
        return 'product';
      case ItemType.service:
        return 'service';
    }
  }

  static ItemType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'product':
        return ItemType.product;
      case 'service':
        return ItemType.service;
      default:
        return ItemType.product;
    }
  }
}

/// Unified inventory item model supporting both products and services
class InventoryItem {
  final String id;
  final String userId;
  final String category; // Category must be set first
  final String name;
  final String description;
  final ItemType type; // Product or Service
  final double costPrice;
  final double sellingPrice;
  final double stock; // Only for products, 0 for services
  final String unit; // kg, pcs, meter, hour, etc.
  final String sku; // Stock keeping unit
  final String? image; // Image URL
  final Map<String, dynamic>? metadata; // Additional fields
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  InventoryItem({
    required this.id,
    required this.userId,
    required this.category,
    required this.name,
    required this.description,
    required this.type,
    required this.costPrice,
    required this.sellingPrice,
    required this.stock,
    required this.unit,
    required this.sku,
    this.image,
    this.metadata,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  /// Calculate profit for this item
  double get profit => sellingPrice - costPrice;

  /// Calculate profit percentage
  double get profitPercentage {
    if (costPrice == 0) return 0;
    return ((sellingPrice - costPrice) / costPrice) * 100;
  }

  /// Check if this is a service
  bool get isService => type == ItemType.service;

  /// Check if this is a product
  bool get isProduct => type == ItemType.product;

  /// Create a copy with updated fields
  InventoryItem copyWith({
    String? id,
    String? userId,
    String? category,
    String? name,
    String? description,
    ItemType? type,
    double? costPrice,
    double? sellingPrice,
    double? stock,
    String? unit,
    String? sku,
    String? image,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      sku: sku ?? this.sku,
      image: image ?? this.image,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'name': name,
      'description': description,
      'type': type.value,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'stock': stock,
      'unit': unit,
      'sku': sku,
      'image': image,
      'metadata': metadata,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  /// Create from JSON
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      category: json['category'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: ItemTypeExtension.fromString(json['type'] as String? ?? 'product'),
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      image: json['image'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
    );
  }

  /// Create from Firestore document snapshot
  factory InventoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItem.fromJson({...data, 'id': doc.id});
  }
}

/// Category model for organizing inventory items
class InventoryCategory {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String? icon;
  final ItemType type; // Which type this category is for
  final bool isActive;
  final DateTime createdAt;

  InventoryCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    this.icon,
    required this.type,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'icon': icon,
      'type': type.value,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  factory InventoryCategory.fromJson(Map<String, dynamic> json) {
    return InventoryCategory(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String?,
      type: ItemTypeExtension.fromString(json['type'] as String? ?? 'product'),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory InventoryCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryCategory.fromJson({...data, 'id': doc.id});
  }
}
