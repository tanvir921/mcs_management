import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';

class ExpenseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'expenses';

  // Generate expense number: EXP-YYYYMM-XXXX
  Future<String> _generateExpenseNumber() async {
    final now = DateTime.now();
    final prefix = 'EXP-${now.year}${now.month.toString().padLeft(2, '0')}';
    
    final query = await _db
        .collection(_collection)
        .where('expenseNumber', isGreaterThanOrEqualTo: prefix)
        .where('expenseNumber', isLessThan: '${prefix}Z')
        .orderBy('expenseNumber', descending: true)
        .limit(1)
        .get();

    int nextNumber = 1;
    if (query.docs.isNotEmpty) {
      final lastNumber = query.docs.first.data()['expenseNumber'] as String;
      final parts = lastNumber.split('-');
      if (parts.length == 3) {
        nextNumber = (int.tryParse(parts[2]) ?? 0) + 1;
      }
    }

    return '$prefix-${nextNumber.toString().padLeft(4, '0')}';
  }

  // Create expense
  Future<String> createExpense(Expense expense) async {
    try {
      final docRef = _db.collection(_collection).doc();
      final expenseNumber = await _generateExpenseNumber();
      
      final newExpense = expense.copyWith(
        id: docRef.id,
        expenseNumber: expenseNumber,
      );

      await docRef.set(newExpense.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create expense: $e');
    }
  }

  // Get expense by ID
  Future<Expense?> getExpenseById(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return Expense.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get expense: $e');
    }
  }

  // Get all expenses
  Stream<List<Expense>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    try {
      Query query = _db.collection(_collection).where('isActive', isEqualTo: true);

      if (startDate != null) {
        query = query.where('expenseDate', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('expenseDate', isLessThanOrEqualTo: endDate);
      }
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      return query
          .orderBy('expenseDate', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
              .toList());
    } catch (e) {
      throw Exception('Failed to get expenses: $e');
    }
  }

  // Update expense
  Future<void> updateExpense(Expense expense) async {
    try {
      final updatedExpense = expense.copyWith(updatedAt: DateTime.now());
      await _db
          .collection(_collection)
          .doc(expense.id)
          .update(updatedExpense.toMap());
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  // Delete expense (soft delete)
  Future<void> deleteExpense(String id) async {
    try {
      await _db.collection(_collection).doc(id).update({
        'isActive': false,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }

  // Get expense statistics
  Future<Map<String, dynamic>> getExpenseStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _db.collection(_collection).where('isActive', isEqualTo: true);

      if (startDate != null) {
        query = query.where('expenseDate', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('expenseDate', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final expenses = snapshot.docs
          .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      double totalExpenses = 0;
      double shopExpenses = 0;
      double personalExpenses = 0;
      double otherExpenses = 0;

      for (var expense in expenses) {
        totalExpenses += expense.amount;
        switch (expense.category) {
          case 'shop':
            shopExpenses += expense.amount;
            break;
          case 'personal':
            personalExpenses += expense.amount;
            break;
          case 'other':
            otherExpenses += expense.amount;
            break;
        }
      }

      return {
        'totalExpenses': totalExpenses,
        'shopExpenses': shopExpenses,
        'personalExpenses': personalExpenses,
        'otherExpenses': otherExpenses,
        'totalTransactions': expenses.length,
        'expensesByCategory': {
          'shop': shopExpenses,
          'personal': personalExpenses,
          'other': otherExpenses,
        },
      };
    } catch (e) {
      throw Exception('Failed to get expense stats: $e');
    }
  }
}
