import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';

class ExpenseProvider with ChangeNotifier {
  final ExpenseService _service = ExpenseService();
  
  List<Expense> _expenses = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  String? _error;

  List<Expense> get expenses => _expenses;
  Map<String, dynamic>? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load expenses
  void loadExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _service
        .getExpenses(
          startDate: startDate,
          endDate: endDate,
          category: category,
        )
        .listen(
          (expenses) {
            _expenses = expenses;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  // Load statistics (internal version without notifyListeners to prevent build errors)
  Future<void> _loadStatsInternal({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _stats = await _service.getExpenseStats(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = e.toString();
      _stats = {
        'totalExpenses': 0.0,
        'shopExpenses': 0.0,
        'personalExpenses': 0.0,
        'otherExpenses': 0.0,
        'totalTransactions': 0,
        'expensesByCategory': {
          'shop': 0.0,
          'personal': 0.0,
          'other': 0.0,
        },
      };
    }
  }

  // Public method to load stats
  Future<void> loadStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _loadStatsInternal(startDate: startDate, endDate: endDate);
    notifyListeners();
  }

  // Create expense
  Future<String?> createExpense(Expense expense) async {
    try {
      _error = null;
      final id = await _service.createExpense(expense);
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Get expense by ID
  Future<Expense?> getExpenseById(String id) async {
    try {
      return await _service.getExpenseById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Update expense
  Future<bool> updateExpense(Expense expense) async {
    try {
      _error = null;
      await _service.updateExpense(expense);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete expense
  Future<bool> deleteExpense(String id) async {
    try {
      _error = null;
      await _service.deleteExpense(id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
