import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../services/sales_service.dart';

class SalesProvider extends ChangeNotifier {
  final SalesService _service = SalesService();

  List<Sale> _sales = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _stats;

  List<Sale> get sales => _sales;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get stats => _stats;

  // Create sale
  Future<String> createSale(Sale sale) async {
    try {
      _error = null;
      final saleId = await _service.createSale(sale);
      return saleId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Get sale by ID
  Future<Sale?> getSaleById(String id) async {
    try {
      _error = null;
      return await _service.getSaleById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Load sales for user
  Future<void> loadSales(String userId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final allSales = await _service.getAllSales(
        startDate: startDate,
        endDate: endDate,
      );

      // Filter by user (createdBy)
      _sales = allSales.where((sale) => sale.createdBy == userId).toList();

      // Calculate stats
      _calculateStats();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update sale
  Future<void> updateSale(Sale sale) async {
    try {
      _error = null;
      await _service.updateSale(sale);
      // Update local list
      final index = _sales.indexWhere((s) => s.id == sale.id);
      if (index != -1) {
        _sales[index] = sale;
      }
      _calculateStats();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _calculateStats() {
    if (_sales.isEmpty) {
      _stats = {
        'totalSales': 0.0,
        'totalCost': 0.0,
        'totalProfit': 0.0,
        'profitMargin': 0.0,
        'totalTransactions': 0,
        'averageSale': 0.0,
        'optionalProfit': 0.0,
      };
      return;
    }

    final totalSales = _sales.length;
    final totalAmount = _sales.fold<double>(0, (sum, sale) => sum + sale.totalSelling);
    final totalCost = _sales.fold<double>(0, (sum, sale) => sum + sale.totalCost);
    final totalProfit = _sales.fold<double>(0, (sum, sale) => sum + sale.realizedProfit);
    final totalPotentialProfit = _sales.fold<double>(0, (sum, sale) => sum + sale.potentialProfit);

    _stats = {
      'totalSales': totalAmount,
      'totalCost': totalCost,
      'totalProfit': totalProfit,
      'profitMargin': totalAmount > 0 ? (totalProfit / totalAmount) * 100 : 0.0,
      'totalTransactions': totalSales,
      'averageSale': totalAmount / totalSales,
      'optionalProfit': totalPotentialProfit,
    };
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
