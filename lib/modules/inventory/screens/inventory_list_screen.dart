import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sales/providers/cart_provider.dart';
import '../../../app/app_routes.dart';
import 'add_inventory_screen.dart';
import 'inventory_detail_screen.dart';
import 'product_barcode_print_screen.dart';
import 'inventory_category_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _searchController = TextEditingController();
  late ItemType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = ItemType.product;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final inventory = Provider.of<InventoryProvider>(context, listen: false);

    if (auth.currentUser != null) {
      await inventory.loadCategories(auth.currentUser!.id);
      await inventory.loadItems(auth.currentUser!.id);
      await inventory.loadStatistics(auth.currentUser!.id);
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      final inventory = Provider.of<InventoryProvider>(context, listen: false);
      inventory.clearFilters();
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final inventory = Provider.of<InventoryProvider>(context, listen: false);

    if (auth.currentUser != null) {
      await inventory.searchItems(auth.currentUser!.id, query);
    }
  }

  Future<void> _filterByCategory(String? categoryId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final inventory = Provider.of<InventoryProvider>(context, listen: false);

    if (auth.currentUser != null) {
      await inventory.loadItems(
        auth.currentUser!.id,
        type: _selectedType,
        category: categoryId,
      );
    }
  }

  Future<void> _scanBarcode() async {
    // Navigate to barcode scanner screen
    final result = await Navigator.pushNamed(context, '/barcode-scanner');
    if (result != null && result is String) {
      // Search for item with scanned barcode (SKU)
      _searchController.text = result;
      _handleSearch(result);
    }
  }

  void _showPrintBarcodesDialog() {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    final items = inventory.items
        .where((item) => item.type == _selectedType)
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items available to print barcodes')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.print, color: Colors.teal.shade600),
            const SizedBox(width: 8),
            const Text('Print Barcodes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select items to print barcodes:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.select_all, color: Colors.teal.shade600),
              title: const Text('Print All Items'),
              subtitle: Text('${items.length} items'),
              onTap: () {
                Navigator.pop(context);
                _navigateToPrintScreen(items);
              },
            ),
            ListTile(
              leading: Icon(Icons.checklist, color: Colors.teal.shade600),
              title: const Text('Select Items'),
              subtitle: const Text('Choose specific items'),
              onTap: () {
                Navigator.pop(context);
                _showSelectItemsForPrint(items);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSelectItemsForPrint(List<InventoryItem> items) {
    final selectedItems = <InventoryItem>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Items'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedItems.contains(item);
                return CheckboxListTile(
                  title: Text(item.name),
                  subtitle: Text('SKU: ${item.sku}'),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedItems.add(item);
                      } else {
                        selectedItems.remove(item);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedItems.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _navigateToPrintScreen(selectedItems.toList());
                    },
              child: Text('Print (${selectedItems.length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPrintScreen(List<InventoryItem> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductBarcodePrintScreen(items: items),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.category, color: Colors.teal.shade600),
            const SizedBox(width: 8),
            Text('Add ${_selectedType.displayName} Category'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Category Name *',
                hintText: 'e.g., Electronics, Mobile Phones',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.label),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description of this category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter category name')),
                );
                return;
              }

              try {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final inventory = Provider.of<InventoryProvider>(
                  context,
                  listen: false,
                );

                if (auth.currentUser != null) {
                  await inventory.createCategory(
                    auth.currentUser!.id,
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    _selectedType,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Category "${nameController.text}" created!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory Management'),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.category),
              tooltip: 'Manage Categories',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InventoryCategoryScreen(),
                  ),
                ).then((_) => _loadInitialData()); // Reload after returning
              },
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan Barcode',
              onPressed: _scanBarcode,
            ),
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print Barcodes',
              onPressed: _showPrintBarcodesDialog,
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.teal.shade600, Colors.teal.shade800],
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.teal.shade600, Colors.teal.shade700],
                ),
              ),
              child: TabBar(
                tabs: const [
                  Tab(text: 'Products', icon: Icon(Icons.inventory_2)),
                  Tab(text: 'Services', icon: Icon(Icons.handshake)),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                onTap: (index) {
                  setState(() {
                    _selectedType = index == 0
                        ? ItemType.product
                        : ItemType.service;
                    _searchController.clear();
                  });
                  final inventory = Provider.of<InventoryProvider>(
                    context,
                    listen: false,
                  );
                  inventory.filterByType(_selectedType);
                },
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey.shade50, Colors.white],
            ),
          ),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _handleSearch,
                  decoration: InputDecoration(
                    hintText: 'Search by name or SKU...',
                    prefixIcon: Icon(Icons.search, color: Colors.teal.shade600),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.teal.shade600,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _handleSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),

              // Category Filter Chips
              Consumer<InventoryProvider>(
                builder: (context, inventory, _) {
                  final categories = _selectedType == ItemType.product
                      ? inventory.productCategories
                      : inventory.serviceCategories;

                  return SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // "All" chip
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: inventory.currentCategoryFilter == null,
                            onSelected: (_) => _filterByCategory(null),
                            selectedColor: Colors.teal.shade100,
                            checkmarkColor: Colors.teal.shade700,
                          ),
                        ),
                        // Category chips
                        ...categories.map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category.name),
                              selected:
                                  inventory.currentCategoryFilter ==
                                  category.id,
                              onSelected: (_) => _filterByCategory(category.id),
                              selectedColor: Colors.teal.shade100,
                              checkmarkColor: Colors.teal.shade700,
                            ),
                          ),
                        ),
                        // Add Category button
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.teal.shade700,
                            ),
                            label: const Text('Add Category'),
                            onPressed: () => _showAddCategoryDialog(),
                            backgroundColor: Colors.teal.shade50,
                            side: BorderSide(color: Colors.teal.shade300),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Statistics Card
              Consumer<InventoryProvider>(
                builder: (context, inventory, _) {
                  final stats = inventory.statistics;
                  if (stats == null) return const SizedBox.shrink();

                  final itemCount = _selectedType == ItemType.product
                      ? stats['productCount'] as int
                      : stats['serviceCount'] as int;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
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
                            colors: [Colors.teal.shade50, Colors.teal.shade100],
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatisticColumn(
                              label: 'Total Items',
                              value: '$itemCount',
                              icon: Icons.inventory_2,
                              color: Colors.teal,
                            ),
                            if (_selectedType == ItemType.product)
                              _StatisticColumn(
                                label: 'Total Stock',
                                value:
                                    '${(stats['totalStockValue'] as num).toStringAsFixed(0)}',
                                icon: Icons.storage,
                                color: Colors.blue,
                              ),
                            _StatisticColumn(
                              label: 'Profit Margin',
                              value:
                                  '${(stats['averageProfitMargin'] as num).toStringAsFixed(1)}%',
                              icon: Icons.trending_up,
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Items List
              Expanded(
                child: Consumer<InventoryProvider>(
                  builder: (context, inventory, _) {
                    if (inventory.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (inventory.error != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              inventory.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _loadInitialData,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal.shade600,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final items = inventory.items;
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedType == ItemType.product
                                  ? Icons.inventory_2
                                  : Icons.handshake,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No ${_selectedType.displayName.toLowerCase()}s found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddInventoryScreen(
                                      initialType: _selectedType,
                                    ),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal.shade600,
                              ),
                              child: Text('Add ${_selectedType.displayName}'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _InventoryItemCard(
                          item: item,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InventoryDetailScreen(item: item),
                              ),
                            );
                          },
                          onAddToCart: (quantity) {
                            final cart = Provider.of<CartProvider>(
                              context,
                              listen: false,
                            );
                            cart.addItem(item, quantity);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added ${item.name} to cart (${quantity} ${item.unit})',
                                ),
                                duration: const Duration(seconds: 2),
                                action: SnackBarAction(
                                  label: 'View Cart',
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.sales,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          onPrintBarcode: () {
                            // Navigate to single product barcode print screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductBarcodePrintScreen(items: [item]),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Consumer<CartProvider>(
          builder: (context, cart, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cart.isNotEmpty)
                FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.sales);
                  },
                  heroTag: 'cart',
                  backgroundColor: Colors.purple.shade600,
                  label: Text('Cart (${cart.itemCount})'),
                  icon: const Icon(Icons.shopping_cart),
                ),
              if (cart.isNotEmpty) const SizedBox(height: 12),
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddInventoryScreen(initialType: _selectedType),
                    ),
                  );
                },
                heroTag: 'add',
                backgroundColor: Colors.teal.shade600,
                label: Text('Add ${_selectedType.displayName}'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final MaterialColor color;

  const _StatisticColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color.shade700,
          ),
        ),
      ],
    );
  }
}

class _InventoryItemCard extends StatefulWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final Function(double) onAddToCart;
  final VoidCallback onPrintBarcode;

  const _InventoryItemCard({
    required this.item,
    required this.onTap,
    required this.onAddToCart,
    required this.onPrintBarcode,
  });

  @override
  State<_InventoryItemCard> createState() => _InventoryItemCardState();
}

class _InventoryItemCardState extends State<_InventoryItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'bn_BD',
      symbol: '৳',
      decimalDigits: 0,
    );

    final profitColor = widget.item.profit > 0
        ? Colors.green.shade600
        : Colors.red.shade600;

    return InkWell(
      onTap: widget.onTap,
      onHover: (hovered) {
        setState(() => _isHovered = hovered);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: _isHovered ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.item.isProduct
                                ? Colors.orange.shade400
                                : Colors.blue.shade400,
                            widget.item.isProduct
                                ? Colors.orange.shade600
                                : Colors.blue.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.item.isProduct
                            ? Icons.inventory_2
                            : Icons.handshake,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'SKU: ${widget.item.sku}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.item.isProduct)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.teal.shade200,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Stock: ${widget.item.stock}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ),
                    // Print Barcode Button
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: widget.onPrintBarcode,
                      icon: Icon(
                        Icons.qr_code_2,
                        color: Colors.indigo.shade600,
                      ),
                      tooltip: 'Print Barcode',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.indigo.shade50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Pricing & Profit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cost Price',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency.format(widget.item.costPrice),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Selling Price',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency.format(widget.item.sellingPrice),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Profit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              currency.format(widget.item.profit),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: profitColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: profitColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.item.profitPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: profitColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Add to Cart Button (only for products with stock)
                if (widget.item.isProduct && widget.item.stock > 0)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        _showAddToCartDialog(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Add to Cart'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddToCartDialog(BuildContext context) {
    double quantity = 1;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add ${widget.item.name} to Cart'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Stock: ${widget.item.stock} ${widget.item.unit}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (quantity > 1) quantity--;
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      quantity.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (quantity < widget.item.stock) quantity++;
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Total: ৳${(widget.item.sellingPrice * quantity).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onAddToCart(quantity);
              },
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      ),
    );
  }
}
