import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../services/sales_service.dart';

class SalesProvider extends ChangeNotifier {
  final SalesService _salesService = SalesService();

  List<Sale> _sales = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _stats;

  List<Sale> get sales => _sales;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get stats => _stats;

  Future<void> loadSales({
    DateTime? startDate,
    DateTime? endDate,
    bool includeInactive = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sales = await _salesService.getAllSales(
        startDate: startDate,
        endDate: endDate,
        includeInactive: includeInactive,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTodaySales() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sales = await _salesService.getTodaySales();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Sale?> getSaleById(String id) async {
    try {
      return await _salesService.getSaleById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<String> createSale(Sale sale) async {
    try {
      final saleId = await _salesService.createSale(sale);
      await loadSales();
      await _loadStatsInternal();
      return saleId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateSale(Sale sale) async {
    try {
      await _salesService.updateSale(sale);
      await loadSales();
      await _loadStatsInternal();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSale(String id) async {
    try {
      await _salesService.deleteSale(id);
      await loadSales();
      await _loadStatsInternal();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadStats({DateTime? startDate, DateTime? endDate}) async {
    try {
      _stats = await _salesService.getSalesStats(
        startDate: startDate,
        endDate: endDate,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Internal method that doesn't notify listeners
  Future<void> _loadStatsInternal({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _stats = await _salesService.getSalesStats(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<List<Sale>> getSalesByCustomer(String customerId) async {
    try {
      return await _salesService.getSalesByCustomer(customerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
