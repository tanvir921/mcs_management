import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../inventory/models/inventory_item.dart';
import '../../inventory/providers/inventory_provider.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _barcodeController = TextEditingController();
  List<InventoryItem> _scannedProducts = [];

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  void _scanBarcode() {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or scan a barcode')),
      );
      return;
    }

    final inventory = context.read<InventoryProvider>();
    // Search both products and services by SKU or ID
    final product = inventory.items.firstWhere(
      (item) =>
          ((item.isProduct && item.stock > 0) || item.isService) &&
          (item.sku.toLowerCase() == barcode.toLowerCase() ||
              item.id.toLowerCase() == barcode.toLowerCase()),
      orElse: () => InventoryItem(
        id: '',
        userId: '',
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

    if (product.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item not found or product out of stock')),
      );
      _barcodeController.clear();
      return;
    }

    // Check if product already scanned
    if (_scannedProducts.any((p) => p.id == product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} already scanned')),
      );
    } else {
      setState(() {
        _scannedProducts.add(product);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${product.name} added')));
    }

    _barcodeController.clear();
  }

  void _removeProduct(int index) {
    setState(() {
      _scannedProducts.removeAt(index);
    });
  }

  void _confirmSelection() {
    if (_scannedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan at least one product')),
      );
      return;
    }
    Navigator.pop(context, _scannedProducts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcodes'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade600, Colors.purple.shade800],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Scanner Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple.shade50, Colors.white],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan or Enter Barcode/SKU',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    hintText: 'Place cursor here and scan...',
                    prefixIcon: const Icon(Icons.qr_code_2),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _scanBarcode,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (_) => _scanBarcode(),
                  autofocus: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Scanned Products List
          Expanded(
            child: _scannedProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products scanned yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _scannedProducts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final product = _scannedProducts[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
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
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SKU: ${product.sku}'),
                            Text(
                              'Price: ৳${product.sellingPrice.toStringAsFixed(0)} | Stock: ${product.stock}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _removeProduct(index),
                        ),
                      );
                    },
                  ),
          ),

          // Footer with Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirmSelection,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Add ${_scannedProducts.length} Product(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
