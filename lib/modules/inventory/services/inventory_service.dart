import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _itemsCollection = 'inventory_items';
  static const String _categoriesCollection = 'inventory_categories';

  /// Get categories for a specific type (product or service)
  Future<List<InventoryCategory>> getCategories(
    String userId,
    ItemType type, {
    bool includeInactive = false,
  }) async {
    try {
      Query query = _firestore
          .collection(_categoriesCollection)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type.value);

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => InventoryCategory.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Create a new category
  Future<void> createCategory(
    String userId,
    String name,
    String description,
    ItemType type,
  ) async {
    try {
      final docRef = _firestore.collection(_categoriesCollection).doc();
      final category = InventoryCategory(
        id: docRef.id,
        name: name,
        description: description,
        type: type,
        createdAt: DateTime.now(),
      );
      await docRef.set(category.toJson());
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  /// Get all inventory items for user
  Future<List<InventoryItem>> getItems(
    String userId, {
    ItemType? type,
    String? category,
    bool includeInactive = false,
  }) async {
    try {
      Query query = _firestore
          .collection(_itemsCollection)
          .where('userId', isEqualTo: userId);

      if (type != null) {
        query = query.where('type', isEqualTo: type.value);
      }

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.orderBy('name').get();
      return snapshot.docs
          .map((doc) => InventoryItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch items: $e');
    }
  }

  /// Get a single inventory item by ID
  Future<InventoryItem?> getItemById(String itemId) async {
    try {
      final doc = await _firestore
          .collection(_itemsCollection)
          .doc(itemId)
          .get();

      if (!doc.exists) return null;
      return InventoryItem.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch item: $e');
    }
  }

  /// Create a new inventory item
  Future<InventoryItem> createItem(InventoryItem item) async {
    try {
      final docRef = _firestore.collection(_itemsCollection).doc();
      final newItem = item.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await docRef.set(newItem.toJson());
      return newItem;
    } catch (e) {
      throw Exception('Failed to create item: $e');
    }
  }

  /// Update an inventory item
  Future<void> updateItem(InventoryItem item) async {
    try {
      final updatedItem = item.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_itemsCollection)
          .doc(item.id)
          .update(updatedItem.toJson());
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  /// Delete an inventory item (soft delete)
  Future<void> deleteItem(String itemId) async {
    try {
      await _firestore.collection(_itemsCollection).doc(itemId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }

  /// Restore an inactive item
  Future<void> restoreItem(String itemId) async {
    try {
      await _firestore.collection(_itemsCollection).doc(itemId).update({
        'isActive': true,
      });
    } catch (e) {
      throw Exception('Failed to restore item: $e');
    }
  }

  /// Update stock for a product (decrement for sales, increment for returns)
  Future<void> updateStock(
    String itemId,
    double quantity, {
    bool isDecrement = false,
  }) async {
    try {
      final item = await getItemById(itemId);
      if (item == null) throw Exception('Item not found');
      if (item.isService) throw Exception('Cannot update stock for service');

      final newStock = isDecrement
          ? item.stock - quantity
          : item.stock + quantity;
      if (newStock < 0) throw Exception('Insufficient stock');

      await _firestore.collection(_itemsCollection).doc(itemId).update({
        'stock': newStock,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }

  /// Search items by name or SKU
  Future<List<InventoryItem>> searchItems(
    String userId,
    String query, {
    ItemType? type,
  }) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This fetches all items and filters in memory
      final items = await getItems(userId, type: type);
      final lowerQuery = query.toLowerCase();

      return items
          .where(
            (item) =>
                item.name.toLowerCase().contains(lowerQuery) ||
                item.sku.toLowerCase().contains(lowerQuery),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to search items: $e');
    }
  }

  /// Get inventory statistics
  Future<Map<String, dynamic>> getStatistics(String userId) async {
    try {
      final items = await getItems(userId);

      double totalCostValue = 0;
      double totalSellingValue = 0;
      double totalStockValue = 0;
      int productCount = 0;
      int serviceCount = 0;
      double totalProfit = 0;

      for (final item in items) {
        final itemCostValue =
            item.costPrice * (item.isProduct ? item.stock : 1);
        final itemSellingValue =
            item.sellingPrice * (item.isProduct ? item.stock : 1);
        final itemProfit = item.profit * (item.isProduct ? item.stock : 1);

        totalCostValue += itemCostValue;
        totalSellingValue += itemSellingValue;
        totalProfit += itemProfit;

        if (item.isProduct) {
          productCount++;
          totalStockValue += item.stock;
        } else {
          serviceCount++;
        }
      }

      return {
        'totalItems': items.length,
        'productCount': productCount,
        'serviceCount': serviceCount,
        'totalCostValue': totalCostValue,
        'totalSellingValue': totalSellingValue,
        'totalProfit': totalProfit,
        'totalStockValue': totalStockValue,
        'averageProfitMargin': items.isEmpty
            ? 0
            : totalProfit / totalCostValue * 100,
      };
    } catch (e) {
      throw Exception('Failed to calculate statistics: $e');
    }
  }

  /// Get low stock items (products only)
  Future<List<InventoryItem>> getLowStockItems(
    String userId, {
    double threshold = 10,
  }) async {
    try {
      final items = await getItems(userId, type: ItemType.product);
      return items.where((item) => item.stock <= threshold).toList();
    } catch (e) {
      throw Exception('Failed to fetch low stock items: $e');
    }
  }
}
