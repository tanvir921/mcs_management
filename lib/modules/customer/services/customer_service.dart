import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../models/due_transaction.dart';
import '../models/purchase_history.dart';
import '../../../core/errors/app_exceptions.dart';

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'customers';
  static const String _transactionsCollection = 'due_transactions';
  static const String _purchaseCollection = 'purchase_history';

  /// Create a new customer
  Future<void> createCustomer(Customer customer) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(customer.id)
          .set(customer.toJson());
    } catch (e) {
      throw ValidationException('Failed to create customer: $e');
    }
  }

  /// Update customer details
  Future<void> updateCustomer(Customer customer) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(customer.id)
          .update(customer.toJson());
    } catch (e) {
      throw ValidationException('Failed to update customer: $e');
    }
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return Customer.fromJson(doc.data()!);
    } catch (e) {
      throw ValidationException('Failed to get customer: $e');
    }
  }

  /// Get all customers
  Future<List<Customer>> getAllCustomers({bool includeInactive = false}) async {
    try {
      Query query = _firestore.collection(_collection);

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      query = query.orderBy('name');

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Customer.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ValidationException('Failed to get customers: $e');
    }
  }

  /// Search customers by name or phone
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final allCustomers = snapshot.docs
          .map((doc) => Customer.fromJson(doc.data()))
          .toList();

      // Filter locally (Firestore doesn't support OR queries easily)
      return allCustomers.where((customer) {
        final searchQuery = query.toLowerCase();
        final nameMatch = customer.name.toLowerCase().contains(searchQuery);
        final phoneMatch = customer.phone?.contains(searchQuery) ?? false;
        return nameMatch || phoneMatch;
      }).toList();
    } catch (e) {
      throw ValidationException('Failed to search customers: $e');
    }
  }

  /// Update customer due and save transaction history
  Future<void> updateDue({
    required String customerId,
    required double amount,
    required String dueType,
    required bool isAddition,
    String? note,
    required String userId,
    required String userName,
  }) async {
    try {
      final customer = await getCustomerById(customerId);
      if (customer == null) {
        throw ValidationException('Customer not found');
      }

      double productDue = customer.productDue;
      double serviceDue = customer.serviceDue;
      double msfRechargeDue = customer.msfRechargeDue;
      double cashBorrowDue = customer.cashBorrowDue;
      double previousDue = customer.previousDue;

      switch (dueType) {
        case 'product':
          productDue = isAddition ? productDue + amount : productDue - amount;
          break;
        case 'service':
          serviceDue = isAddition ? serviceDue + amount : serviceDue - amount;
          break;
        case 'msfRecharge':
          msfRechargeDue = isAddition
              ? msfRechargeDue + amount
              : msfRechargeDue - amount;
          break;
        case 'cashBorrow':
          cashBorrowDue = isAddition
              ? cashBorrowDue + amount
              : cashBorrowDue - amount;
          break;
        case 'previousDue':
          previousDue = isAddition
              ? previousDue + amount
              : previousDue - amount;
          break;
      }

      final updatedCustomer = customer.copyWith(
        productDue: productDue,
        serviceDue: serviceDue,
        msfRechargeDue: msfRechargeDue,
        cashBorrowDue: cashBorrowDue,
        previousDue: previousDue,
        updatedAt: DateTime.now(),
      );

      // Create transaction record
      final transactionId = _firestore
          .collection(_transactionsCollection)
          .doc()
          .id;
      final transaction = DueTransaction(
        id: transactionId,
        customerId: customerId,
        dueType: dueType,
        amount: amount,
        isAddition: isAddition,
        note: note,
        createdAt: DateTime.now(),
        createdBy: userId,
        createdByName: userName,
      );

      // Use batch write to update both customer and create transaction
      final batch = _firestore.batch();

      batch.update(
        _firestore.collection(_collection).doc(customerId),
        updatedCustomer.toJson(),
      );

      batch.set(
        _firestore.collection(_transactionsCollection).doc(transactionId),
        transaction.toJson(),
      );

      await batch.commit();
    } catch (e) {
      throw ValidationException('Failed to update due: $e');
    }
  }

  /// Add due transaction with profit tracking
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
      final customer = await getCustomerById(customerId);
      if (customer == null) {
        throw ValidationException('Customer not found');
      }

      // Update customer due
      double productDue = customer.productDue;
      double serviceDue = customer.serviceDue;
      double msfRechargeDue = customer.msfRechargeDue;
      double cashBorrowDue = customer.cashBorrowDue;
      double previousDue = customer.previousDue;

      switch (dueType) {
        case 'product':
          productDue = isAddition ? productDue + amount : productDue - amount;
          break;
        case 'service':
          serviceDue = isAddition ? serviceDue + amount : serviceDue - amount;
          break;
        case 'msfRecharge':
          msfRechargeDue = isAddition
              ? msfRechargeDue + amount
              : msfRechargeDue - amount;
          break;
        case 'cashBorrow':
          cashBorrowDue = isAddition
              ? cashBorrowDue + amount
              : cashBorrowDue - amount;
          break;
        case 'previousDue':
          previousDue = isAddition
              ? previousDue + amount
              : previousDue - amount;
          break;
      }

      final updatedCustomer = customer.copyWith(
        productDue: productDue,
        serviceDue: serviceDue,
        msfRechargeDue: msfRechargeDue,
        cashBorrowDue: cashBorrowDue,
        previousDue: previousDue,
        updatedAt: DateTime.now(),
      );

      // Create transaction record
      final transactionId = _firestore
          .collection(_transactionsCollection)
          .doc()
          .id;
      final transaction = DueTransaction(
        id: transactionId,
        customerId: customerId,
        dueType: dueType,
        amount: amount,
        isAddition: isAddition,
        saleId: saleId,
        potentialProfit: potentialProfit,
        profitRealized: false,
        note: note,
        createdAt: DateTime.now(),
        createdBy: createdBy,
        createdByName: createdByName,
      );

      // Use batch write to update both customer and create transaction
      final batch = _firestore.batch();

      batch.update(
        _firestore.collection(_collection).doc(customerId),
        updatedCustomer.toJson(),
      );

      batch.set(
        _firestore.collection(_transactionsCollection).doc(transactionId),
        transaction.toJson(),
      );

      await batch.commit();
    } catch (e) {
      throw ValidationException('Failed to add due transaction: $e');
    }
  }

  /// Get due transaction history for a customer
  Future<List<DueTransaction>> getDueHistory(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => DueTransaction.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw ValidationException('Failed to get due history: $e');
    }
  }

  /// Add a purchase entry for a customer
  Future<void> addPurchase({
    required String customerId,
    required String description,
    required double amount,
    required String userId,
    required String userName,
    String? note,
    DateTime? createdAt,
  }) async {
    try {
      final purchaseId = _firestore.collection(_purchaseCollection).doc().id;
      final purchase = PurchaseHistory(
        id: purchaseId,
        customerId: customerId,
        description: description,
        amount: amount,
        note: note,
        createdAt: createdAt ?? DateTime.now(),
        createdBy: userId,
        createdByName: userName,
      );

      await _firestore
          .collection(_purchaseCollection)
          .doc(purchaseId)
          .set(purchase.toJson());
    } catch (e) {
      throw ValidationException('Failed to add purchase: $e');
    }
  }

  /// Get purchase history for a customer
  Future<List<PurchaseHistory>> getPurchaseHistory(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection(_purchaseCollection)
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PurchaseHistory.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw ValidationException('Failed to get purchase history: $e');
    }
  }

  /// Soft delete customer
  Future<void> deleteCustomer(String id) async {
    try {
      final customer = await getCustomerById(id);
      if (customer == null) {
        throw ValidationException('Customer not found');
      }

      final updatedCustomer = customer.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );

      await updateCustomer(updatedCustomer);
    } catch (e) {
      throw ValidationException('Failed to delete customer: $e');
    }
  }
}
