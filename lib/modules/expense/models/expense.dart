class Expense {
  final String id;
  final String expenseNumber;
  final DateTime expenseDate;
  final String category; // shop, personal, other
  final double amount;
  final String description;
  final String paymentMethod; // cash, card, mobile_banking
  final String? notes;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
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
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      expenseNumber: map['expenseNumber'] ?? '',
      expenseDate: map['expenseDate']?.toDate() ?? DateTime.now(),
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      notes: map['notes'],
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseNumber': expenseNumber,
      'expenseDate': expenseDate,
      'category': category,
      'amount': amount,
      'description': description,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
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
      case 'other':
        return 'Other Expense';
      default:
        return category;
    }
  }
}
