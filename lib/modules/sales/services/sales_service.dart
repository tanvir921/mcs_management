import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';

class SalesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _salesCollection = 'sales';

  // Generate sale number
  Future<String> _generateSaleNumber() async {
    final now = DateTime.now();
    final prefix = 'SAL-${now.year}${now.month.toString().padLeft(2, '0')}';

    final query = await _firestore
        .collection(_salesCollection)
        .where('saleNumber', isGreaterThanOrEqualTo: prefix)
        .where('saleNumber', isLessThan: '$prefix\uf8ff')
        .orderBy('saleNumber', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return '$prefix-0001';
    }

    final lastNumber = query.docs.first.data()['saleNumber'] as String;
    final lastSeq = int.parse(lastNumber.split('-').last);
    return '$prefix-${(lastSeq + 1).toString().padLeft(4, '0')}';
  }

  // Create sale
  Future<String> createSale(Sale sale) async {
    try {
      final saleNumber = await _generateSaleNumber();
      final docRef = _firestore.collection(_salesCollection).doc();

      final saleWithNumber = sale.copyWith(
        id: docRef.id,
        saleNumber: saleNumber,
      );

      await docRef.set(saleWithNumber.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create sale: $e');
    }
  }

  // Get all sales
  Future<List<Sale>> getAllSales({
    DateTime? startDate,
    DateTime? endDate,
    bool includeInactive = false,
  }) async {
    try {
      Query query = _firestore.collection(_salesCollection);

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      if (startDate != null) {
        query = query.where('saleDate', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('saleDate', isLessThanOrEqualTo: endDate);
      }

      query = query.orderBy('saleDate', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Sale.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch sales: $e');
    }
  }

  // Get sale by ID
  Future<Sale?> getSaleById(String id) async {
    try {
      final doc = await _firestore.collection(_salesCollection).doc(id).get();
      if (!doc.exists) return null;
      return Sale.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch sale: $e');
    }
  }

  // Update sale
  Future<void> updateSale(Sale sale) async {
    try {
      await _firestore
          .collection(_salesCollection)
          .doc(sale.id)
          .update(sale.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Failed to update sale: $e');
    }
  }

  // Delete sale (soft delete)
  Future<void> deleteSale(String id) async {
    try {
      await _firestore.collection(_salesCollection).doc(id).update({
        'isActive': false,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to delete sale: $e');
    }
  }

  // Get sales statistics
  Future<Map<String, dynamic>> getSalesStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_salesCollection)
          .where('isActive', isEqualTo: true);

      if (startDate != null) {
        query = query.where('saleDate', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('saleDate', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final sales = snapshot.docs
          .map((doc) => Sale.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      double totalSales = 0;
      double totalCost = 0;
      double totalProfit = 0;
      int totalTransactions = sales.length;
      Map<String, int> paymentMethods = {};

      for (var sale in sales) {
        totalSales += sale.totalSelling;
        totalCost += sale.totalCost;
        totalProfit += sale.totalProfit;
        paymentMethods[sale.paymentMethod] =
            (paymentMethods[sale.paymentMethod] ?? 0) + 1;
      }

      return {
        'totalSales': totalSales,
        'totalCost': totalCost,
        'totalProfit': totalProfit,
        'profitMargin': totalSales > 0 ? (totalProfit / totalSales) * 100 : 0,
        'totalTransactions': totalTransactions,
        'averageSale': totalTransactions > 0
            ? totalSales / totalTransactions
            : 0,
        'paymentMethods': paymentMethods,
      };
    } catch (e) {
      throw Exception('Failed to fetch sales statistics: $e');
    }
  }

  // Get today's sales
  Future<List<Sale>> getTodaySales() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return getAllSales(startDate: startOfDay, endDate: endOfDay);
  }

  // Get sales by customer
  Future<List<Sale>> getSalesByCustomer(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection(_salesCollection)
          .where('customerId', isEqualTo: customerId)
          .where('isActive', isEqualTo: true)
          .orderBy('saleDate', descending: true)
          .get();

      return snapshot.docs.map((doc) => Sale.fromMap(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to fetch customer sales: $e');
    }
  }
}
