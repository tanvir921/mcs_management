import 'package:flutter/material.dart';
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
  List<Customer> _filteredCustomers = [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUser != null) {
        context.read<InventoryProvider>().loadItems(authProvider.currentUser!.id);
      }
      
      // Set default to guest customer
      final customers = context.read<CustomerProvider>().customers;
      final guestCustomer = customers.firstWhere(
        (c) => c.name.toLowerCase() == 'guest',
        orElse: () => Customer(
          id: 'guest',
          userId: authProvider.currentUser?.id ?? 'system',
          name: 'Guest',
          phone: null,
          email: null,
          address: null,
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
      setState(() => _selectedCustomer = guestCustomer);
      _paidAmountController.text = finalAmount.toStringAsFixed(2);
      
      // Load cart items into sale
      final cartProvider = context.read<CartProvider>();
      if (cartProvider.items.isNotEmpty) {
        final itemsToAdd = <SaleItem>[];
        for (final cartItem in cartProvider.items) {
          final saleItem = SaleItem(
            id: 'item_${++_itemCounter}',
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

  void _filterCustomers(String query) {
    final customers = context.read<CustomerProvider>().customers;
    if (query.isEmpty) {
      setState(() => _filteredCustomers = customers.where((c) => c.isActive).toList());
      return;
    }

    setState(() {
      _filteredCustomers = customers.where((customer) {
        final nameLower = customer.name.toLowerCase();
        final phoneLower = customer.phone?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();
        return (nameLower.contains(queryLower) ||
            phoneLower.contains(queryLower)) && customer.isActive;
      }).toList();
    });
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade600,
                        Colors.purple.shade400,
                      ],
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
                                final nameLower =
                                    customer.name.toLowerCase();
                                final phoneLower =
                                    customer.phone?.toLowerCase() ?? '';
                                final queryLower = query.toLowerCase();
                                return (nameLower.contains(queryLower) ||
                                    phoneLower.contains(queryLower)) &&
                                    customer.isActive;
                              }).toList();
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
          });
        },
      ),
    );
  }

  void _addItemFromInventory() {
    final inventory = context.read<InventoryProvider>();
    final products = inventory.items
        .where((item) => item.isProduct && item.stock > 0)
        .toList();

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available in inventory')),
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
          final saleItem = SaleItem(
            id: 'item_${++_itemCounter}',
            itemName: product.name,
            quantity: quantity,
            unit: product.unit,
            costPrice: product.costPrice,
            sellingPrice: product.sellingPrice,
            totalCost: quantity * product.costPrice,
            totalSelling: quantity * product.sellingPrice,
            profit: (quantity * product.sellingPrice) -
                (quantity * product.costPrice),
            notes: null,
          );

          setState(() {
            _items.add(saleItem);
          });

          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${product.name} added to sale',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (context) => _ItemDialog(
        item: _items[index],
        onSave: (item) {
          setState(() {
            _items[index] = item;
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
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

      // Calculate payment and due
      final paidAmount = double.tryParse(_paidAmountController.text) ?? finalAmount;
      final dueAmount = finalAmount - paidAmount;

      // Calculate realized and potential profit
      // Formula: If paid < cost, no profit. If paid >= cost, profit proportionally
      double realizedProfit = 0;
      double potentialProfit = 0;

      final costAfterDiscount = totalCost; // Cost remains same
      final profitBeforePayment = finalProfit;

      if (paidAmount >= costAfterDiscount) {
        // Customer paid more than cost, calculate profit
        final profitRatio = profitBeforePayment / finalAmount;
        realizedProfit = paidAmount * profitRatio;
        potentialProfit = dueAmount * profitRatio;
      } else {
        // Customer paid less than cost, no profit yet
        realizedProfit = 0;
        potentialProfit = profitBeforePayment;
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

      await context.read<SalesProvider>().createSale(sale);

      // If there's a due and customer selected, add due transaction
      if (dueAmount > 0 && _selectedCustomer != null) {
        await context.read<CustomerProvider>().addDueTransaction(
              customerId: _selectedCustomer!.id,
              dueType: 'product',
              amount: dueAmount,
              isAddition: true,
              saleId: sale.id,
              potentialProfit: potentialProfit,
              note: 'Product sale due - ${sale.saleNumber}',
              createdBy: currentUser.id,
              createdByName: currentUser.name,
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
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade600,
                Colors.purple.shade800,
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _saveSale,
            tooltip: 'Save Sale',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                            Icons.note_add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sale Information',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sale Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.purple.shade600,
                        ),
                      ),
                      title: const Text('Sale Date'),
                      subtitle: Text(
                        DateFormat('MMM d, y - hh:mm a').format(_saleDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(
                        Icons.edit,
                        color: Colors.purple.shade600,
                      ),
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
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Payment Method
                    Text(
                      'Payment Method',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Cash'),
                          selected: _paymentMethod == 'cash',
                          onSelected: (selected) {
                            setState(() => _paymentMethod = 'cash');
                          },
                          selectedColor: Colors.purple.shade100,
                        ),
                        ChoiceChip(
                          label: const Text('Card'),
                          selected: _paymentMethod == 'card',
                          onSelected: (selected) {
                            setState(() => _paymentMethod = 'card');
                          },
                          selectedColor: Colors.purple.shade100,
                        ),
                        ChoiceChip(
                          label: const Text('Mobile Banking'),
                          selected: _paymentMethod == 'mobile_banking',
                          onSelected: (selected) {
                            setState(() => _paymentMethod = 'mobile_banking');
                          },
                          selectedColor: Colors.purple.shade100,
                        ),
                        ChoiceChip(
                          label: const Text('Credit'),
                          selected: _paymentMethod == 'credit',
                          onSelected: (selected) {
                            setState(() => _paymentMethod = 'credit');
                          },
                          selectedColor: Colors.purple.shade100,
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
                        return GestureDetector(
                          onTap: _showCustomerSelectionDialog,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.purple.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.purple.shade50,
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Customer',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.purple.shade600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedCustomer?.name ?? 'Guest',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (_selectedCustomer?.phone != null)
                                      Text(
                                        _selectedCustomer!.phone!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                                Icon(
                                  Icons.edit,
                                  color: Colors.purple.shade600,
                                  size: 28,
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(
                          Icons.note,
                          color: Colors.purple.shade600,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (value) =>
                          _notes = value.trim().isEmpty ? null : value.trim(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cart Summary (if items were added from cart)
            if (_items.isNotEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
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
                      const Divider(
                        color: Colors.white24,
                        height: 1,
                      ),
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade50,
                            child: Icon(
                              Icons.shopping_bag,
                              color: Colors.purple.shade600,
                            ),
                          ),
                          title: Text(
                            item.itemName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${item.quantity} ${item.unit} × ৳${item.sellingPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Total: ৳${item.totalSelling.toStringAsFixed(2)} | Profit: ৳${item.profit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.purple.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.blue.shade600,
                                ),
                                onPressed: () => _editItem(index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Totals Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.shade50,
                      Colors.purple.shade100,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
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
                                  contentPadding:
                                      const EdgeInsets.symmetric(
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
                                  contentPadding:
                                      const EdgeInsets.symmetric(
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Details',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
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
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _paidAmountController.text =
                                        finalAmount.toStringAsFixed(2);
                                  });
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Full'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Tk. ${(finalAmount - (double.tryParse(_paidAmountController.text) ?? 0)).toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.purple.shade600,
                            Colors.purple.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Final Amount',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '৳${finalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
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
                              'Profit',
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: totalProfit >= 0
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: finalProfit >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            child: Text(
                              '৳${finalProfit.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: finalProfit >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _saveSale,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Sale',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
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

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;

  const _TotalRow({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ProductTile extends StatefulWidget {
  final InventoryItem product;
  final Function(double) onSelect;

  const _ProductTile({
    required this.product,
    required this.onSelect,
  });

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  double _selectedQuantity = 1;

  @override
  Widget build(BuildContext context) {
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
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2,
                          color: Colors.white, size: 20),
                    );
                  },
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2,
                    color: Colors.white, size: 20),
              ),
      ),
      title: Text(
        widget.product.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Cost: ৳${widget.product.costPrice.toStringAsFixed(2)} | Sell: ৳${widget.product.sellingPrice.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'Stock: ${widget.product.stock} ${widget.product.unit}',
            style: TextStyle(
              fontSize: 12,
              color: widget.product.stock > 0
                  ? Colors.green.shade600
                  : Colors.red.shade600,
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    if (_selectedQuantity > widget.product.stock) {
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
                backgroundColor: Colors.purple.shade600,
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
            .where((product) =>
                product.name.toLowerCase().contains(query) ||
                product.sku.toLowerCase().contains(query) ||
                product.category.toLowerCase().contains(query))
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
                      'Select Product',
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
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

