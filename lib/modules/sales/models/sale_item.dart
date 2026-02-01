class SaleItem {
  final String id;
  final String? inventoryItemId;
  final String itemType; // 'product' or 'service'
  final String itemName;
  final double quantity;
  final String unit;
  final double costPrice;
  final double sellingPrice;
  final double totalCost;
  final double totalSelling;
  final double profit;
  final String? notes;

  SaleItem({
    required this.id,
    this.inventoryItemId,
    required this.itemType,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.costPrice,
    required this.sellingPrice,
    required this.totalCost,
    required this.totalSelling,
    required this.profit,
    this.notes,
  });

  SaleItem copyWith({
    String? id,
    String? inventoryItemId,
    String? itemType,
    String? itemName,
    double? quantity,
    String? unit,
    double? costPrice,
    double? sellingPrice,
    double? totalCost,
    double? totalSelling,
    double? profit,
    String? notes,
  }) {
    return SaleItem(
      id: id ?? this.id,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      itemType: itemType ?? this.itemType,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      totalCost: totalCost ?? this.totalCost,
      totalSelling: totalSelling ?? this.totalSelling,
      profit: profit ?? this.profit,
      notes: notes ?? this.notes,
    );
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] ?? '',
      inventoryItemId: map['inventoryItemId'],
      itemType: map['itemType'] ?? 'product',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      costPrice: (map['costPrice'] ?? 0).toDouble(),
      sellingPrice: (map['sellingPrice'] ?? 0).toDouble(),
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      totalSelling: (map['totalSelling'] ?? 0).toDouble(),
      profit: (map['profit'] ?? 0).toDouble(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventoryItemId': inventoryItemId,
      'itemType': itemType,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'totalCost': totalCost,
      'totalSelling': totalSelling,
      'profit': profit,
      'notes': notes,
    };
  }
}
