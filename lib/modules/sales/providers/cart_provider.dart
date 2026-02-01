import 'package:flutter/foundation.dart';
import '../../inventory/models/inventory_item.dart';

class CartItem {
  final InventoryItem product;
  double quantity;

  CartItem({required this.product, required this.quantity});

  double get totalCost => product.costPrice * quantity;
  double get totalSelling => product.sellingPrice * quantity;
  double get profit => totalSelling - totalCost;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get itemCount => _items.length;

  double get totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalCost => _items.fold(0, (sum, item) => sum + item.totalCost);

  double get totalSelling =>
      _items.fold(0, (sum, item) => sum + item.totalSelling);

  double get totalProfit => totalSelling - totalCost;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  /// Add item to cart
  void addItem(InventoryItem product, double quantity) {
    // Check if product already in cart
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Update quantity if already in cart
      _items[existingIndex].quantity += quantity;
    } else {
      // Add new item to cart
      _items.add(CartItem(product: product, quantity: quantity));
    }

    notifyListeners();
  }

  /// Update item quantity
  void updateQuantity(String productId, double quantity) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  /// Remove item from cart
  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  /// Clear cart
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Get cart item by product id
  CartItem? getItem(String productId) {
    try {
      return _items.firstWhere((item) => item.product.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Check if product is in cart
  bool isInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  /// Get quantity of product in cart
  double getQuantity(String productId) {
    final item = getItem(productId);
    return item?.quantity ?? 0;
  }
}
