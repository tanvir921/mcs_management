import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../models/due_transaction.dart';
import '../models/purchase_history.dart';
import '../services/customer_service.dart';

class CustomerProvider extends ChangeNotifier {
  final CustomerService _customerService = CustomerService();

  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCustomers({bool includeInactive = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _customers = await _customerService.getAllCustomers(
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

  Future<void> addCustomer(Customer customer) async {
    try {
      await _customerService.createCustomer(customer);
      await loadCustomers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      await _customerService.updateCustomer(customer);
      await loadCustomers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _customerService.deleteCustomer(id);
      await loadCustomers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDue({
    required String customerId,
    required double amount,
    required String dueType,
    required bool isAddition,
    double realizedProfit = 0,
    String? note,
    required String userId,
    required String userName,
  }) async {
    try {
      await _customerService.updateDue(
        customerId: customerId,
        amount: amount,
        dueType: dueType,
        isAddition: isAddition,
        realizedProfit: realizedProfit,
        note: note,
        userId: userId,
        userName: userName,
      );
      await loadCustomers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addDueTransaction({
    required String customerId,
    required String dueType,
    required double amount,
    required bool isAddition,
    String? saleId,
    double potentialProfit = 0,
    String? note,
    required String createdBy,
    required String createdByName,
  }) async {
    try {
      await _customerService.addDueTransaction(
        customerId: customerId,
        dueType: dueType,
        amount: amount,
        isAddition: isAddition,
        saleId: saleId,
        potentialProfit: potentialProfit,
        note: note,
        createdBy: createdBy,
        createdByName: createdByName,
      );
      await loadCustomers();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<DueTransaction>> getDueHistory(String customerId) async {
    try {
      return await _customerService.getDueHistory(customerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addPurchaseHistory({
    required String customerId,
    required String description,
    required double amount,
    required String userId,
    required String userName,
    String? note,
  }) async {
    try {
      await _customerService.addPurchase(
        customerId: customerId,
        description: description,
        amount: amount,
        userId: userId,
        userName: userName,
        note: note,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<PurchaseHistory>> getPurchaseHistory(String customerId) async {
    try {
      return await _customerService.getPurchaseHistory(customerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Customer?> getCustomerById(String customerId) async {
    try {
      return await _customerService.getCustomerById(customerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<DueTransaction>> getDueClearProfits({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _customerService.getDueClearProfits(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<double> getTotalDueClearProfit({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _customerService.getTotalDueClearProfit(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
