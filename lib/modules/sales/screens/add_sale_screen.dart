import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../providers/sales_provider.dart';
import '../providers/cart_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/providers/customer_provider.dart';
import '../../customer/models/customer_model.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../inventory/models/inventory_item.dart';
import '../../../core/config/environment.dart';
import 'barcode_scanner_screen.dart';
import 'sale_invoice_screen.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _saleDate = DateTime.now();
  String _paymentMethod = 'cash';
  Customer? _selectedCustomer;
  String? _notes;
  bool _isSubmitting = false;
  bool _showProfit = false;

  // Payment and due
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();

  final List<SaleItem> _items = [];
  int _itemCounter = 0;

  // Discount
  double _discountAmount = 0;
  double _discountPercent = 0;
  String _discountType = 'amount'; // 'amount' or 'percent'

  // Totals
  double get totalCost => _items.fold(0, (sum, item) => sum + item.totalCost);
  double get totalSelling =>
      _items.fold(0, (sum, item) => sum + item.totalSelling);
  double get totalProfit => totalSelling - totalCost;

  double get finalDiscount {
    if (_discountType == 'percent') {
      return (totalSelling * _discountPercent) / 100;
    }
    return _discountAmount;
  }

  double get finalProfit => totalProfit - finalDiscount;

  double get finalAmount => totalSelling - finalDiscount;

  @override
  void initState() {
    super.initState();
    // Load customers and inventory
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<CustomerProvider>().loadCustomers();
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUser != null) {
        // Load both products and services
        context.read<InventoryProvider>().loadItems(
          authProvider.currentUser!.id,
        );
      }

      // Set default to guest customer, create if doesn't exist
      await _ensureGuestCustomer();
      final customers = context.read<CustomerProvider>().customers;
      final guestCustomer = customers.firstWhere(
        (c) => c.id == 'guest_customer' || c.name.toLowerCase() == 'guest',
        orElse: () => Customer(
          id: 'guest_customer',
          name: 'Guest',
          phone: null,
          address: 'Walk-in Customer',
          imageUrl: null,
          productDue: 0,
          serviceDue: 0,
          msfRechargeDue: 0,
          cashBorrowDue: 0,
          previousDue: 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (mounted) {
        setState(() => _selectedCustomer = guestCustomer);
        _paidAmountController.text = finalAmount.toStringAsFixed(2);
      }

      // Load cart items into sale
      final cartProvider = context.read<CartProvider>();
      if (cartProvider.items.isNotEmpty) {
        final itemsToAdd = <SaleItem>[];
        for (final cartItem in cartProvider.items) {
          final saleItem = SaleItem(
            id: 'item_${++_itemCounter}',
            inventoryItemId: cartItem.product.id,
            itemType: cartItem.product.type.value,
            itemName: cartItem.product.name,
            quantity: cartItem.quantity,
            unit: cartItem.product.unit,
            costPrice: cartItem.product.costPrice,
            sellingPrice: cartItem.product.sellingPrice,
            totalCost: cartItem.totalCost,
            totalSelling: cartItem.totalSelling,
            profit: cartItem.profit,
            notes: null,
          );
          itemsToAdd.add(saleItem);
        }
        // Update state once with all items
        if (mounted) {
          setState(() {
            _items.addAll(itemsToAdd);
          });
        }
        // Clear cart after loading
        cartProvider.clearCart();
      }
    });
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  double _calculateRealizedProfitForUi(double paidAmount) {
    if (finalProfit <= 0) {
      return finalProfit;
    }

    final costAfterDiscount = totalCost;

    if (paidAmount > costAfterDiscount) {
      final profitFromPayment = paidAmount - costAfterDiscount;
      if (profitFromPayment <= 0) {
        return 0;
      }
      return profitFromPayment > finalProfit ? finalProfit : profitFromPayment;
    }

    return 0;
  }

  Future<void> _ensureGuestCustomer() async {
    final authProvider = context.read<AuthProvider>();
    final customerProvider = context.read<CustomerProvider>();

    // Reload customers to get latest list
    await customerProvider.loadCustomers();
    final customers = customerProvider.customers;

    // Check for guest customer by ID or name
    final guestExists = customers.any(
      (c) => c.id == 'guest_customer' || c.name.toLowerCase() == 'guest',
    );

    if (!guestExists && authProvider.currentUser != null) {
      final guestCustomer = Customer(
        id: 'guest_customer', // Fixed ID for guest
        name: 'Guest',
        phone: null,
        address: 'Walk-in Customer',
        imageUrl: null,
        productDue: 0,
        serviceDue: 0,
        msfRechargeDue: 0,
        cashBorrowDue: 0,
        previousDue: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        await customerProvider.addCustomer(guestCustomer);
        // Reload to get the new customer
        await customerProvider.loadCustomers();
      } catch (e) {
        // Guest customer creation failed, but we'll use it anyway in memory
        debugPrint('Failed to create guest customer: $e');
      }
    }
  }

  void _showCustomerSelectionDialog() {
    final searchController = TextEditingController();
    List<Customer> filteredList = context
        .read<CustomerProvider>()
        .customers
        .where((c) => c.isActive)
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade600, Colors.purple.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Customer',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        onChanged: (query) {
                          setState(() {
                            if (query.isEmpty) {
                              filteredList = context
                                  .read<CustomerProvider>()
                                  .customers
                                  .where((c) => c.isActive)
                                  .toList();
                            } else {
                              filteredList = context
                                  .read<CustomerProvider>()
                                  .customers
                                  .where((customer) {
                                    final nameLower = customer.name
                                        .toLowerCase();
                                    final phoneLower =
                                        customer.phone?.toLowerCase() ?? '';
                                    final queryLower = query.toLowerCase();
                                    return (nameLower.contains(queryLower) ||
                                            phoneLower.contains(queryLower)) &&
                                        customer.isActive;
                                  })
                                  .toList();
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ],
                  ),
                ),
                // Customer List
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final customer = filteredList[index];
                      final isSelected = _selectedCustomer?.id == customer.id;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.purple.shade50,
                        leading: Icon(
                          customer.name.toLowerCase() == 'guest'
                              ? Icons.people
                              : Icons.person,
                          color: isSelected
                              ? Colors.purple.shade600
                              : Colors.grey,
                        ),
                        title: Text(
                          customer.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.purple.shade600
                                : Colors.black,
                          ),
                        ),
                        subtitle: customer.phone != null
                            ? Text(customer.phone!)
                            : null,
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Colors.purple.shade600,
                              )
                            : null,
                        onTap: () {
                          this.setState(() => _selectedCustomer = customer);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _ItemDialog(
        onSave: (item) {
          setState(() {
            _items.add(item.copyWith(id: 'item_${++_itemCounter}'));
            _paidAmountController.text = finalAmount.toStringAsFixed(2);
          });
        },
      ),
    );
  }

  void _addItemFromInventory() {
    final inventory = context.read<InventoryProvider>();
    // Include products with stock > 0 and all services (services don't need stock)
    final products = inventory.items
        .where((item) => (item.isProduct && item.stock > 0) || item.isService)
        .toList();

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No products or services available in inventory'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ProductPickerModal(
        products: products,
        onProductSelected: (product, quantity) {
          // Check if product already exists in items
          final existingIndex = _items.indexWhere(
            (item) => item.inventoryItemId == product.id,
          );

          setState(() {
            if (existingIndex != -1) {
              // Update existing item quantity
              final existingItem = _items[existingIndex];
              final newQuantity = existingItem.quantity + quantity;
              _items[existingIndex] = existingItem.copyWith(
                quantity: newQuantity,
                totalCost: newQuantity * existingItem.costPrice,
                totalSelling: newQuantity * existingItem.sellingPrice,
                profit:
                    (newQuantity * existingItem.sellingPrice) -
                    (newQuantity * existingItem.costPrice),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${product.name} quantity updated to $newQuantity',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              // Add new item
              final saleItem = SaleItem(
                id: 'item_${++_itemCounter}',
                inventoryItemId: product.id,
                itemType: product.type.value,
                itemName: product.name,
                quantity: quantity,
                unit: product.unit,
                costPrice: product.costPrice,
                sellingPrice: product.sellingPrice,
                totalCost: quantity * product.costPrice,
                totalSelling: quantity * product.sellingPrice,
                profit:
                    (quantity * product.sellingPrice) -
                    (quantity * product.costPrice),
                notes: null,
              );
              _items.add(saleItem);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} added to sale'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            _paidAmountController.text = finalAmount.toStringAsFixed(2);
          });
        },
      ),
    );
  }

  void _addItemsFromBarcodeScan() async {
    final result = await Navigator.push<List<InventoryItem>>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      int addedCount = 0;
      int updatedCount = 0;

      setState(() {
        for (final product in result) {
          // Check if product already exists in items
          final existingIndex = _items.indexWhere(
            (item) => item.inventoryItemId == product.id,
          );

          if (existingIndex != -1) {
            // Update existing item quantity
            final existingItem = _items[existingIndex];
            final newQuantity = existingItem.quantity + 1;
            _items[existingIndex] = existingItem.copyWith(
              quantity: newQuantity,
              totalCost: newQuantity * existingItem.costPrice,
              totalSelling: newQuantity * existingItem.sellingPrice,
              profit:
                  (newQuantity * existingItem.sellingPrice) -
                  (newQuantity * existingItem.costPrice),
            );
            updatedCount++;
          } else {
            // Add new item
            final saleItem = SaleItem(
              id: 'item_${++_itemCounter}',
              inventoryItemId: product.id,
              itemType: product.type.value,
              itemName: product.name,
              quantity: 1,
              unit: product.unit,
              costPrice: product.costPrice,
              sellingPrice: product.sellingPrice,
              totalCost: product.costPrice,
              totalSelling: product.sellingPrice,
              profit: product.sellingPrice - product.costPrice,
              notes: null,
            );
            _items.add(saleItem);
            addedCount++;
          }
        }
        _paidAmountController.text = finalAmount.toStringAsFixed(2);
      });

      String message = '';
      if (addedCount > 0) message += '$addedCount product(s) added';
      if (updatedCount > 0) {
        if (message.isNotEmpty) message += ', ';
        message += '$updatedCount product(s) quantity updated';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (context) => _ItemDialog(
        item: _items[index],
        onSave: (item) {
          setState(() {
            _items[index] = item;
            _paidAmountController.text = finalAmount.toStringAsFixed(2);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _paidAmountController.text = finalAmount.toStringAsFixed(2);
    });
  }

  void _updateItemQuantity(int index, double newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }
    final item = _items[index];
    setState(() {
      _items[index] = item.copyWith(
        quantity: newQuantity,
        totalCost: newQuantity * item.costPrice,
        totalSelling: newQuantity * item.sellingPrice,
        profit:
            (newQuantity * item.sellingPrice) - (newQuantity * item.costPrice),
      );
      _paidAmountController.text = finalAmount.toStringAsFixed(2);
    });
  }

  Future<void> _saveSale() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final inventoryProvider = context.read<InventoryProvider>();
      // Load both products and services for validation
      await inventoryProvider.loadItems(currentUser.id);

      // Validate stock availability for products
      final inventoryItems = inventoryProvider.items;
      for (final item in _items) {
        if (item.inventoryItemId == null || item.itemType != 'product') {
          continue;
        }
        final inventoryItem = inventoryItems.firstWhere(
          (inv) => inv.id == item.inventoryItemId,
          orElse: () => InventoryItem(
            id: '',
            userId: currentUser.id,
            category: '',
            name: '',
            description: '',
            type: ItemType.product,
            costPrice: 0,
            sellingPrice: 0,
            stock: 0,
            unit: '',
            sku: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (inventoryItem.id.isEmpty) {
          continue;
        }

        if (inventoryItem.stock < item.quantity) {
          throw Exception(
            'Insufficient stock for ${item.itemName}. Available: ${inventoryItem.stock}, Required: ${item.quantity}',
          );
        }
      }

      // Calculate payment and due
      final paidAmount =
          double.tryParse(_paidAmountController.text) ?? finalAmount;
      final dueAmount = (finalAmount - paidAmount).abs() < 0.01
          ? 0.0
          : finalAmount - paidAmount;

      // Calculate realized and potential profit
      // Formula: profit = max(0, paidAmount - cost), capped at total profit
      double realizedProfit = 0;
      double potentialProfit = finalProfit; // Initially all profit is potential

      final costAfterDiscount = totalCost; // Cost remains same

      // Calculate how much profit is realized based on payment
      if (paidAmount > costAfterDiscount) {
        // Customer paid more than cost
        // Realized profit = min(paidAmount - cost, totalProfit)
        final profitFromPayment = paidAmount - costAfterDiscount;
        realizedProfit = profitFromPayment > finalProfit
            ? finalProfit
            : profitFromPayment;
        potentialProfit = finalProfit - realizedProfit;
      } else {
        // Customer paid less than or equal to cost, no profit yet
        realizedProfit = 0;
        potentialProfit = finalProfit;
      }

      final sale = Sale(
        id: '',
        saleNumber: '',
        saleDate: _saleDate,
        items: _items,
        totalCost: totalCost,
        totalSelling: totalSelling,
        totalProfit: finalProfit,
        discountAmount: _discountType == 'amount' ? _discountAmount : 0,
        discountPercent: _discountType == 'percent' ? _discountPercent : 0,
        paymentMethod: _paymentMethod,
        paidAmount: paidAmount,
        dueAmount: dueAmount,
        realizedProfit: realizedProfit,
        potentialProfit: potentialProfit,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        notes: _notes,
        createdBy: currentUser.id,
        createdByName: currentUser.name,
        createdAt: DateTime.now(),
        isActive: true,
      );

      final saleId = await context.read<SalesProvider>().createSale(sale);

      // Fetch the created sale with generated ID and saleNumber
      final createdSale = await context.read<SalesProvider>().getSaleById(
        saleId,
      );

      if (createdSale == null) {
        throw Exception('Failed to retrieve created sale');
      }

      // Deduct stock for products only
      for (final item in _items) {
        if (item.inventoryItemId == null || item.itemType != 'product') {
          continue;
        }
        await inventoryProvider.updateStock(
          item.inventoryItemId!,
          item.quantity,
          isDecrement: true,
        );
      }

      // If there's a due and customer selected, add due transaction
      if (dueAmount > 0 && _selectedCustomer != null) {
        await context.read<CustomerProvider>().addDueTransaction(
          customerId: _selectedCustomer!.id,
          dueType: 'product',
          amount: dueAmount,
          isAddition: true,
          saleId: createdSale.id,
          potentialProfit: potentialProfit,
          note: 'Product sale due - ${createdSale.saleNumber}',
          createdBy: currentUser.id,
          createdByName: currentUser.name,
        );
      }

      // Add purchase history for the customer (including Guest)
      if (_selectedCustomer != null) {
        final itemsList = _items.map((item) => item.itemName).join(', ');
        await context.read<CustomerProvider>().addPurchaseHistory(
          customerId: _selectedCustomer!.id,
          description: 'Sale ${createdSale.saleNumber}: $itemsList',
          amount: finalAmount,
          userId: currentUser.id,
          userName: currentUser.name,
          note: dueAmount > 0
              ? 'Paid: ৳${paidAmount.toStringAsFixed(2)}, Due: ৳${dueAmount.toStringAsFixed(2)}'
              : 'Fully paid',
        );
      }

      // Log action
      await authProvider.logAction(
        action: 'CREATE_SALE',
        module: 'Sales',
        details:
            'Created sale - Total: ৳${totalSelling.toStringAsFixed(2)}, Paid: ৳${paidAmount.toStringAsFixed(2)}, Due: ৳${dueAmount.toStringAsFixed(2)}, Profit: ৳${realizedProfit.toStringAsFixed(2)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale created successfully')),
        );

        // Navigate to invoice screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SaleInvoiceScreen(
              sale: createdSale,
              shopName: Environment.shopName,
              shopAddress: Environment.shopAddress,
              shopPhone: Environment.shopPhone,
              shopEmail: Environment.shopEmail,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paidAmountForUi = double.tryParse(_paidAmountController.text) ?? 0.0;
    final realizedProfitUi = _calculateRealizedProfitForUi(paidAmountForUi);
    final double potentialProfitUi = finalProfit > 0
        ? (finalProfit - realizedProfitUi)
        : 0.0;

    final isWideScreen = MediaQuery.of(context).size.width > 1100;

    if (kIsWeb && isWideScreen) {
      return _buildWebLayout(
        context,
        paidAmountForUi,
        realizedProfitUi,
        potentialProfitUi,
      );
    }
    return _buildMobileLayout(
      context,
      paidAmountForUi,
      realizedProfitUi,
      potentialProfitUi,
    );
  }

  Widget _buildWebLayout(
    BuildContext context,
    double paidAmountForUi,
    double realizedProfitUi,
    double potentialProfitUi,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Web Header
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade700, Colors.purple.shade900],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Sale',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Create a new sale transaction',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Quick Stats
                _WebHeaderStat(
                  label: 'Items',
                  value: '${_items.length}',
                  icon: Icons.shopping_cart_rounded,
                ),
                const SizedBox(width: 20),
                _WebHeaderStat(
                  label: 'Total',
                  value: '৳${finalAmount.toStringAsFixed(0)}',
                  icon: Icons.payments_rounded,
                ),
                const SizedBox(width: 20),
                _WebHeaderStat(
                  label: 'Profit',
                  value: '৳${finalProfit.toStringAsFixed(0)}',
                  icon: Icons.trending_up_rounded,
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _saveSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSubmitting ? 'Saving...' : 'Complete Sale',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel - Items & Add
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Add Items Section
                          _buildWebAddItemsSection(),
                          const SizedBox(height: 24),
                          // Items List
                          _buildWebItemsList(),
                        ],
                      ),
                    ),
                  ),
                  // Right Panel - Sale Info & Payment
                  Container(
                    width: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade200),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(-2, 0),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWebSaleInfo(),
                          const SizedBox(height: 24),
                          _buildWebCustomerSection(),
                          const SizedBox(height: 24),
                          _buildWebPaymentSection(
                            paidAmountForUi,
                            realizedProfitUi,
                            potentialProfitUi,
                          ),
                          const SizedBox(height: 24),
                          _buildWebSummary(
                            paidAmountForUi,
                            realizedProfitUi,
                            potentialProfitUi,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebAddItemsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_shopping_cart_rounded,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Add Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _WebAddButton(
                  icon: Icons.inventory_2_rounded,
                  label: 'From Inventory',
                  color: const Color(0xFF9C27B0),
                  onTap: _addItemFromInventory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WebAddButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan Barcode',
                  color: const Color(0xFF2196F3),
                  onTap: _addItemsFromBarcodeScan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WebAddButton(
                  icon: Icons.edit_rounded,
                  label: 'Manual Entry',
                  color: const Color(0xFFFF9800),
                  onTap: _addItem,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebItemsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.list_alt_rounded,
                  color: Colors.green.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Items (${_items.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_items.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _items.clear();
                    _paidAmountController.text = '0.00';
                  }),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_basket_outlined,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No items added yet',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the buttons above to add items',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Item',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 1,
                        child: Text(
                          'Qty',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Price',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Items
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                item.itemType == 'service'
                                    ? 'Service'
                                    : 'Product',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => _updateItemQuantity(
                                  index,
                                  item.quantity - 1,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.remove, size: 16),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  '${item.quantity.toInt()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _updateItemQuantity(
                                  index,
                                  item.quantity + 1,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '৳${item.sellingPrice.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '৳${item.totalSelling.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () => _editItem(index),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _removeItem(index),
                                child: Icon(
                                  Icons.delete_rounded,
                                  size: 18,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWebSaleInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: Colors.purple.shade700,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Sale Date & Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _saleDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_saleDate),
                );
                if (time != null) {
                  setState(
                    () => _saleDate = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMM d, y - hh:mm a').format(_saleDate),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: Colors.purple.shade600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Customer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showCustomerSelectionDialog,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedCustomer?.name.toLowerCase() == 'guest'
                        ? Icons.people_rounded
                        : Icons.person_rounded,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomer?.name ?? 'Select Customer',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_selectedCustomer?.phone != null)
                          Text(
                            _selectedCustomer!.phone!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.blue.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_selectedCustomer != null && _selectedCustomer!.totalDue > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 16,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Previous Due: ৳${_selectedCustomer!.totalDue.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebPaymentSection(
    double paidAmountForUi,
    double realizedProfitUi,
    double potentialProfitUi,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payment_rounded,
                color: Colors.green.shade700,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Payment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Payment Method
          Wrap(
            spacing: 8,
            children: ['cash', 'card', 'mobile'].map((method) {
              final isSelected = _paymentMethod == method;
              return ChoiceChip(
                label: Text(method[0].toUpperCase() + method.substring(1)),
                selected: isSelected,
                onSelected: (selected) =>
                    setState(() => _paymentMethod = method),
                selectedColor: Colors.green.shade200,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Paid Amount
          TextField(
            controller: _paidAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Paid Amount',
              prefixText: '৳ ',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.green.shade400),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Quick Fill Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(
                    () => _paidAmountController.text = finalAmount
                        .toStringAsFixed(2),
                  ),
                  child: const Text('Full'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(
                    () => _paidAmountController.text = (finalAmount / 2)
                        .toStringAsFixed(2),
                  ),
                  child: const Text('Half'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _paidAmountController.text = '0.00'),
                  child: const Text('Due'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebSummary(
    double paidAmountForUi,
    double realizedProfitUi,
    double potentialProfitUi,
  ) {
    final dueAmount = finalAmount - paidAmountForUi;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade800],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _WebSummaryRow(
            label: 'Subtotal',
            value: '৳${totalSelling.toStringAsFixed(2)}',
          ),
          if (finalDiscount > 0)
            _WebSummaryRow(
              label: 'Discount',
              value: '-৳${finalDiscount.toStringAsFixed(2)}',
              isNegative: true,
            ),
          const Divider(color: Colors.white24, height: 24),
          _WebSummaryRow(
            label: 'Total',
            value: '৳${finalAmount.toStringAsFixed(2)}',
            isBold: true,
            isLarge: true,
          ),
          _WebSummaryRow(
            label: 'Paid',
            value: '৳${paidAmountForUi.toStringAsFixed(2)}',
          ),
          if (dueAmount > 0.01)
            _WebSummaryRow(
              label: 'Due',
              value: '৳${dueAmount.toStringAsFixed(2)}',
              isWarning: true,
            ),
          const Divider(color: Colors.white24, height: 24),
          _WebSummaryRow(
            label: 'Profit',
            value: '৳${finalProfit.toStringAsFixed(2)}',
            isProfit: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    double paidAmountForUi,
    double realizedProfitUi,
    double potentialProfitUi,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Sale',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade700,
                Colors.purple.shade900,
                Colors.deepPurple.shade900,
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.save_rounded),
              onPressed: _isSubmitting ? null : _saveSale,
              tooltip: 'Save Sale',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade50.withOpacity(0.3),
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Date & Payment Section
              Card(
                elevation: 4,
                shadowColor: Colors.purple.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.shade100, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade600,
                                    Colors.purple.shade800,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.shade200,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Sale Information',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Sale Date
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade50,
                                Colors.purple.shade100.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.purple.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _saleDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    _saleDate,
                                  ),
                                );
                                if (time != null) {
                                  setState(() {
                                    _saleDate = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  });
                                }
                              }
                            },
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.purple.shade100,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.purple.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sale Date & Time',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'MMM d, y - hh:mm a',
                                        ).format(_saleDate),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.edit_rounded,
                                  color: Colors.purple.shade600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Payment Method
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.payment_rounded,
                                  color: Colors.purple.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Payment Method',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _PaymentMethodChip(
                                  label: 'Cash',
                                  icon: Icons.money,
                                  selected: _paymentMethod == 'cash',
                                  onSelected: () =>
                                      setState(() => _paymentMethod = 'cash'),
                                ),
                                _PaymentMethodChip(
                                  label: 'Card',
                                  icon: Icons.credit_card,
                                  selected: _paymentMethod == 'card',
                                  onSelected: () =>
                                      setState(() => _paymentMethod = 'card'),
                                ),
                                _PaymentMethodChip(
                                  label: 'Mobile Banking',
                                  icon: Icons.phone_android,
                                  selected: _paymentMethod == 'mobile_banking',
                                  onSelected: () => setState(
                                    () => _paymentMethod = 'mobile_banking',
                                  ),
                                ),
                                _PaymentMethodChip(
                                  label: 'Credit',
                                  icon: Icons.account_balance_wallet,
                                  selected: _paymentMethod == 'credit',
                                  onSelected: () =>
                                      setState(() => _paymentMethod = 'credit'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),

                        const Divider(),
                        const SizedBox(height: 16),

                        // Customer Selection Button
                        Consumer<CustomerProvider>(
                          builder: (context, customerProvider, _) {
                            return InkWell(
                              onTap: _showCustomerSelectionDialog,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.purple.shade100.withOpacity(0.5),
                                      Colors.purple.shade50,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.purple.shade300,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purple.shade100.withOpacity(
                                        0.5,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.shade200,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _selectedCustomer?.name.toLowerCase() ==
                                                'guest'
                                            ? Icons.people_rounded
                                            : Icons.person_rounded,
                                        color: Colors.purple.shade700,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selected Customer',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _selectedCustomer?.name ?? 'Guest',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          if (_selectedCustomer?.phone != null)
                                            Text(
                                              _selectedCustomer!.phone!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade600,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Notes (Optional)',
                            labelStyle: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.purple.shade200,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.purple.shade200,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.purple.shade600,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.note_alt_rounded,
                              color: Colors.purple.shade600,
                            ),
                            filled: true,
                            fillColor: Colors.purple.shade50.withOpacity(0.3),
                          ),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (value) => _notes = value.trim().isEmpty
                              ? null
                              : value.trim(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cart Summary (if items were added from cart)
              if (_items.isNotEmpty)
                Card(
                  elevation: 6,
                  shadowColor: Colors.blue.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade500,
                          Colors.blue.shade700,
                          Colors.indigo.shade700,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade300,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.shopping_cart,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sale Summary',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_items.length} item${_items.length > 1 ? 's' : ''} ready to checkout',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '৳${totalSelling.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Profit',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '৳${finalProfit.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Items Section
              Card(
                elevation: 4,
                shadowColor: Colors.purple.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.shade100, width: 1),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shopping_cart,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Sale Items (${_items.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'barcode',
                              child: Row(
                                children: [
                                  const Icon(Icons.qr_code_2, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('Scan Barcode'),
                                ],
                              ),
                              onTap: _addItemsFromBarcodeScan,
                            ),
                            PopupMenuItem<String>(
                              value: 'inventory',
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('From Inventory'),
                                ],
                              ),
                              onTap: _addItemFromInventory,
                            ),
                            PopupMenuItem<String>(
                              value: 'manual',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('Manual Entry'),
                                ],
                              ),
                              onTap: _addItem,
                            ),
                          ],
                        ),
                      ),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No items added yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '৳${item.sellingPrice.toStringAsFixed(0)} × ${item.quantity.toStringAsFixed(0)} ${item.unit}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '৳${item.totalSelling.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: Colors.purple.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Quantity Controls
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Decrease button
                                        InkWell(
                                          onTap: () {
                                            if (item.quantity > 1) {
                                              _updateItemQuantity(
                                                index,
                                                item.quantity - 1,
                                              );
                                            } else {
                                              _removeItem(index);
                                            }
                                          },
                                          borderRadius:
                                              const BorderRadius.horizontal(
                                                left: Radius.circular(8),
                                              ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              item.quantity > 1
                                                  ? Icons.remove
                                                  : Icons.delete_outline,
                                              size: 20,
                                              color: item.quantity > 1
                                                  ? Colors.purple.shade700
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                        // Quantity display
                                        Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 40,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            '${item.quantity.toStringAsFixed(0)}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        // Increase button
                                        InkWell(
                                          onTap: () => _updateItemQuantity(
                                            index,
                                            item.quantity + 1,
                                          ),
                                          borderRadius:
                                              const BorderRadius.horizontal(
                                                right: Radius.circular(8),
                                              ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.add,
                                              size: 20,
                                              color: Colors.purple.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Totals Section
              Card(
                elevation: 6,
                shadowColor: Colors.purple.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purple.shade50,
                        Colors.purple.shade100.withOpacity(0.7),
                        Colors.white,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.purple.shade200,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      _TotalRow(label: 'Total Cost', amount: totalCost),
                      const Divider(height: 16),
                      _TotalRow(label: 'Total Selling', amount: totalSelling),
                      const Divider(height: 16),

                      // Discount Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Discount',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Row(
                            children: [
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  initialValue: _discountType == 'amount'
                                      ? _discountAmount.toStringAsFixed(2)
                                      : '',
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    isDense: true,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  enabled: _discountType == 'amount',
                                  onChanged: (value) {
                                    setState(() {
                                      _discountAmount =
                                          double.tryParse(value) ?? 0;
                                      _paidAmountController.text = finalAmount
                                          .toStringAsFixed(2);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              ChoiceChip(
                                label: const Text(
                                  'TK',
                                  style: TextStyle(fontSize: 11),
                                ),
                                selected: _discountType == 'amount',
                                onSelected: (selected) {
                                  setState(() {
                                    _discountType = 'amount';
                                    _discountPercent = 0;
                                    _paidAmountController.text = finalAmount
                                        .toStringAsFixed(2);
                                  });
                                },
                                selectedColor: Colors.purple.shade200,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  initialValue: _discountType == 'percent'
                                      ? _discountPercent.toStringAsFixed(2)
                                      : '',
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    isDense: true,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  enabled: _discountType == 'percent',
                                  onChanged: (value) {
                                    setState(() {
                                      _discountPercent =
                                          double.tryParse(value) ?? 0;
                                      _paidAmountController.text = finalAmount
                                          .toStringAsFixed(2);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              ChoiceChip(
                                label: const Text(
                                  '%',
                                  style: TextStyle(fontSize: 11),
                                ),
                                selected: _discountType == 'percent',
                                onSelected: (selected) {
                                  setState(() {
                                    _discountType = 'percent';
                                    _discountAmount = 0;
                                    _paidAmountController.text = finalAmount
                                        .toStringAsFixed(2);
                                  });
                                },
                                selectedColor: Colors.purple.shade200,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Section - Paid Amount & Due
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade50,
                              Colors.green.shade100.withOpacity(0.3),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.green.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade100,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Details',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            // Paid Amount
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _paidAmountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Amount Paid by Customer',
                                      prefixIcon: Icon(
                                        Icons.attach_money,
                                        color: Colors.green.shade600,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Due Amount (Real-time)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Due Amount:',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Tk. ${(finalAmount - (double.tryParse(_paidAmountController.text) ?? 0)).toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.purple.shade700,
                              Colors.purple.shade900,
                              Colors.deepPurple.shade900,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.shade400,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Final Amount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '৳${finalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.purple.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 20),

                      // Profit Section (Hidden by default)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Profit (Realized)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _showProfit
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    size: 18,
                                    color: Colors.purple.shade600,
                                  ),
                                  onPressed: () {
                                    setState(() => _showProfit = !_showProfit);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: _showProfit
                                      ? 'Hide Profit'
                                      : 'Show Profit',
                                ),
                              ),
                            ],
                          ),
                          if (_showProfit)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: realizedProfitUi >= 0
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: realizedProfitUi >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  child: Text(
                                    '৳${realizedProfitUi.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: realizedProfitUi >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (finalProfit > 0 && potentialProfitUi > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Pending: ৳${potentialProfitUi.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Save Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.shade600,
                      Colors.purple.shade800,
                      Colors.deepPurple.shade800,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.shade400,
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSubmitting ? null : _saveSale,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Complete Sale',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  final SaleItem? item;
  final Function(SaleItem) onSave;

  const _ItemDialog({this.item, required this.onSave});

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _costController;
  late TextEditingController _sellingController;
  late TextEditingController _notesController;
  String _unit = 'pcs';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.itemName ?? '');
    _quantityController = TextEditingController(
      text: widget.item?.quantity.toString() ?? '',
    );
    _costController = TextEditingController(
      text: widget.item?.costPrice.toString() ?? '',
    );
    _sellingController = TextEditingController(
      text: widget.item?.sellingPrice.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _unit = widget.item?.unit ?? 'pcs';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final quantity = double.parse(_quantityController.text);
    final costPrice = double.parse(_costController.text);
    final sellingPrice = double.parse(_sellingController.text);
    final totalCost = quantity * costPrice;
    final totalSelling = quantity * sellingPrice;
    final profit = totalSelling - totalCost;

    final item = SaleItem(
      id: widget.item?.id ?? '',
      itemType: 'product',
      itemName: _nameController.text.trim(),
      quantity: quantity,
      unit: _unit,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      totalCost: totalCost,
      totalSelling: totalSelling,
      profit: profit,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    widget.onSave(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'ltr', child: Text('ltr')),
                        DropdownMenuItem(value: 'box', child: Text('box')),
                        DropdownMenuItem(value: 'set', child: Text('set')),
                      ],
                      onChanged: (value) {
                        setState(() => _unit = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Cost Price (per unit)',
                  border: OutlineInputBorder(),
                  prefixText: '৳ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter cost price';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) < 0) {
                    return 'Invalid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sellingController,
                decoration: const InputDecoration(
                  labelText: 'Selling Price (per unit)',
                  border: OutlineInputBorder(),
                  prefixText: '৳ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter selling price';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) < 0) {
                    return 'Invalid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [Colors.purple.shade600, Colors.purple.shade800],
                )
              : null,
          color: selected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.purple.shade700 : Colors.grey.shade300,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.purple.shade300,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.grey.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade800,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;

  const _TotalRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ProductTile extends StatefulWidget {
  final InventoryItem product;
  final Function(double) onSelect;

  const _ProductTile({required this.product, required this.onSelect});

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  double _selectedQuantity = 1;

  @override
  Widget build(BuildContext context) {
    final isService = widget.product.isService;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: widget.product.image != null && widget.product.image!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.product.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isService
                              ? [Colors.blue.shade400, Colors.blue.shade600]
                              : [
                                  Colors.orange.shade400,
                                  Colors.orange.shade600,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isService ? Icons.design_services : Icons.inventory_2,
                        color: Colors.white,
                        size: 20,
                      ),
                    );
                  },
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isService
                        ? [Colors.blue.shade400, Colors.blue.shade600]
                        : [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isService ? Icons.design_services : Icons.inventory_2,
                  color: Colors.white,
                  size: 20,
                ),
              ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isService)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Service',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Cost: ৳${widget.product.costPrice.toStringAsFixed(2)} | Sell: ৳${widget.product.sellingPrice.toStringAsFixed(2)} | Profit: ৳${widget.product.profit.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          if (!isService)
            Text(
              'Stock: ${widget.product.stock} ${widget.product.unit}',
              style: TextStyle(
                fontSize: 12,
                color: widget.product.stock > 0
                    ? Colors.green.shade600
                    : Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              'Unit: ${widget.product.unit}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      trailing: SizedBox(
        width: 100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 50,
              child: TextFormField(
                initialValue: _selectedQuantity.toStringAsFixed(0),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedQuantity = double.tryParse(value) ?? 1;
                    if (_selectedQuantity < 1) _selectedQuantity = 1;
                    // Only limit by stock for products, not services
                    if (!isService &&
                        _selectedQuantity > widget.product.stock) {
                      _selectedQuantity = widget.product.stock.toDouble();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => widget.onSelect(_selectedQuantity),
              style: FilledButton.styleFrom(
                backgroundColor: isService
                    ? Colors.blue.shade600
                    : Colors.purple.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerModal extends StatefulWidget {
  final List<InventoryItem> products;
  final Function(InventoryItem, double) onProductSelected;

  const _ProductPickerModal({
    required this.products,
    required this.onProductSelected,
  });

  @override
  State<_ProductPickerModal> createState() => _ProductPickerModalState();
}

class _ProductPickerModalState extends State<_ProductPickerModal> {
  late List<InventoryItem> _filteredProducts;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts = widget.products
            .where(
              (product) =>
                  product.name.toLowerCase().contains(query) ||
                  product.sku.toLowerCase().contains(query) ||
                  product.category.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade400,
                          Colors.purple.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Product / Service',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, SKU or category...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Results count
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _filteredProducts.isEmpty
                      ? 'No products found'
                      : '${_filteredProducts.length} product(s) found',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 8),

            // Product List
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No products available'
                                : 'No products match your search',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return _ProductTile(
                          product: product,
                          onSelect: (quantity) {
                            Navigator.pop(context);
                            widget.onProductSelected(product, quantity);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= WEB WIDGETS =============

class _WebHeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _WebHeaderStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebAddButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WebAddButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_WebAddButton> createState() => _WebAddButtonState();
}

class _WebAddButtonState extends State<_WebAddButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withOpacity(0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? widget.color : Colors.grey.shade200,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isHovered ? widget.color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isLarge;
  final bool isNegative;
  final bool isWarning;
  final bool isProfit;

  const _WebSummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isLarge = false,
    this.isNegative = false,
    this.isWarning = false,
    this.isProfit = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = Colors.white;
    if (isNegative) valueColor = Colors.red.shade200;
    if (isWarning) valueColor = Colors.orange.shade200;
    if (isProfit) valueColor = Colors.green.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isLarge ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: isBold || isLarge ? FontWeight.bold : FontWeight.w500,
              fontSize: isLarge ? 22 : 15,
            ),
          ),
        ],
      ),
    );
  }
}
