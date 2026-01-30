class SaleItem {
  final String id;
  final String itemName;
  final double quantity;
  final String unit; // e.g., pcs, kg, ltr
  final double costPrice;
  final double sellingPrice;
  final double totalCost;
  final double totalSelling;
  final double profit;
  final String? notes;

  SaleItem({
    required this.id,
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

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'pcs',
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

  SaleItem copyWith({
    String? id,
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
}
