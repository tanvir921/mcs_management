import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryService _service = InventoryService();

  List<InventoryItem> _items = [];
  List<InventoryItem> _filteredItems = [];
  List<InventoryCategory> _productCategories = [];
  List<InventoryCategory> _serviceCategories = [];
  bool _isLoading = false;
  String? _error;
  ItemType _currentFilter = ItemType.product;
  String? _currentCategoryFilter;
  Map<String, dynamic>? _statistics;

  // Getters
  List<InventoryItem> get items =>
      _filteredItems.isEmpty ? _items : _filteredItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ItemType get currentFilter => _currentFilter;
  String? get currentCategoryFilter => _currentCategoryFilter;
  List<InventoryCategory> get productCategories => _productCategories;
  List<InventoryCategory> get serviceCategories => _serviceCategories;
  Map<String, dynamic>? get statistics => _statistics;

  /// Load inventory categories
  Future<void> loadCategories(String userId) async {
    try {
      final products = await _service.getCategories(userId, ItemType.product);
      final services = await _service.getCategories(userId, ItemType.service);

      _productCategories = products;
      _serviceCategories = services;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load all inventory items
  Future<void> loadItems(
    String userId, {
    ItemType? type,
    String? category,
  }) async {
    _isLoading = true;
    _error = null;
    _filteredItems = [];
    notifyListeners();

    try {
      _items = await _service.getItems(userId, type: type, category: category);
      _currentFilter = type ?? ItemType.product;
      _currentCategoryFilter = category;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load statistics
  Future<void> loadStatistics(String userId) async {
    try {
      _statistics = await _service.getStatistics(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
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
      await _service.createCategory(userId, name, description, type);
      await loadCategories(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Add a new inventory item
  Future<void> addItem(InventoryItem item) async {
    try {
      await _service.createItem(item);
      await loadItems(
        item.userId,
        type: _currentFilter,
        category: _currentCategoryFilter,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update an inventory item
  Future<void> updateItem(InventoryItem item) async {
    try {
      await _service.updateItem(item);
      await loadItems(
        item.userId,
        type: _currentFilter,
        category: _currentCategoryFilter,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete an inventory item
  Future<void> deleteItem(String itemId, String userId) async {
    try {
      await _service.deleteItem(itemId);
      await loadItems(
        userId,
        type: _currentFilter,
        category: _currentCategoryFilter,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Restore an inventory item
  Future<void> restoreItem(String itemId, String userId) async {
    try {
      await _service.restoreItem(itemId);
      await loadItems(
        userId,
        type: _currentFilter,
        category: _currentCategoryFilter,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update stock quantity for a product
  Future<void> updateStock(
    String itemId,
    double quantity, {
    bool isDecrement = false,
  }) async {
    try {
      await _service.updateStock(itemId, quantity, isDecrement: isDecrement);
      // Reload items to reflect stock changes
      final item = _items.firstWhere((i) => i.id == itemId);
      await loadItems(
        item.userId,
        type: _currentFilter,
        category: _currentCategoryFilter,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Filter items by type (product or service)
  void filterByType(ItemType type) {
    _currentFilter = type;
    _currentCategoryFilter = null;
    _filteredItems = _items.where((item) => item.type == type).toList();
    notifyListeners();
  }

  /// Filter items by category
  void filterByCategory(String category) {
    _currentCategoryFilter = category;
    _filteredItems = _items
        .where(
          (item) => item.category == category && item.type == _currentFilter,
        )
        .toList();
    notifyListeners();
  }

  /// Search items by name or SKU
  Future<void> searchItems(String userId, String query) async {
    try {
      if (query.isEmpty) {
        _filteredItems = [];
        notifyListeners();
        return;
      }

      _filteredItems = await _service.searchItems(
        userId,
        query,
        type: _currentFilter,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get low stock items
  Future<List<InventoryItem>> getLowStockItems(String userId) async {
    try {
      return await _service.getLowStockItems(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Clear filters
  void clearFilters() {
    _filteredItems = [];
    _currentCategoryFilter = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Upload product image to Firebase Storage
  Future<String> uploadImage(File imageFile, String userId) async {
    try {
      final String fileName =
          'product_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('product_images')
          .child(fileName);

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete image from Firebase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Image might not exist or already deleted
      debugPrint('Failed to delete image: $e');
    }
  }
}
