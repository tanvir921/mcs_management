import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../../auth/providers/auth_provider.dart';

class InventoryDetailScreen extends StatefulWidget {
  final InventoryItem item;

  const InventoryDetailScreen({super.key, required this.item});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  late InventoryItem _currentItem;
  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _stockController;

  File? _selectedImage;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _imageUrl = _currentItem.image;
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: _currentItem.name);
    _descriptionController = TextEditingController(
      text: _currentItem.description,
    );
    _costPriceController = TextEditingController(
      text: _currentItem.costPrice.toString(),
    );
    _sellingPriceController = TextEditingController(
      text: _currentItem.sellingPrice.toString(),
    );
    _stockController = TextEditingController(
      text: _currentItem.stock.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImage != null || _imageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _imageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    try {
      final inventory = Provider.of<InventoryProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (auth.currentUser == null) throw Exception('User not found');

      // Upload new image if selected
      String? uploadedImageUrl = _imageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await inventory.uploadImage(
          _selectedImage!,
          auth.currentUser!.id,
        );
      }

      final updatedItem = _currentItem.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        costPrice: double.tryParse(_costPriceController.text) ?? 0,
        sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
        stock: _currentItem.isProduct
            ? double.tryParse(_stockController.text) ?? 0
            : 0,
        image: uploadedImageUrl,
        updatedBy: auth.currentUser!.id,
      );

      await inventory.updateItem(updatedItem);

      setState(() {
        _currentItem = updatedItem;
        _imageUrl = uploadedImageUrl;
        _selectedImage = null;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to delete "${_currentItem.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final inventory = Provider.of<InventoryProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (auth.currentUser == null) throw Exception('User not found');

      await inventory.deleteItem(_currentItem.id, auth.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleStockUpdate() async {
    if (_currentItem.isService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot update stock for services')),
      );
      return;
    }

    final quantityController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${_currentItem.stock}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantity to Add/Remove',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final quantity = double.tryParse(quantityController.text) ?? 0;
                if (quantity == 0) {
                  if (mounted) Navigator.pop(context);
                  return;
                }

                final inventory = Provider.of<InventoryProvider>(
                  context,
                  listen: false,
                );
                final isDecrement = quantity < 0;

                await inventory.updateStock(
                  _currentItem.id,
                  quantity.abs(),
                  isDecrement: isDecrement,
                );

                // Reload the item
                final updatedItem = _currentItem.copyWith(
                  stock: isDecrement
                      ? _currentItem.stock - quantity.abs()
                      : _currentItem.stock + quantity.abs(),
                );

                setState(() => _currentItem = updatedItem);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'bn_BD',
      symbol: '৳',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentItem.name),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => setState(() => _isEditing = true),
                  child: const Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 12),
                      Text('Edit'),
                    ],
                  ),
                ),
                if (_currentItem.isProduct)
                  PopupMenuItem(
                    onTap: _handleStockUpdate,
                    child: const Row(
                      children: [
                        Icon(Icons.inventory),
                        SizedBox(width: 12),
                        Text('Update Stock'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  onTap: _handleDelete,
                  child: const Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type Badge
            Chip(
              avatar: Icon(
                _currentItem.isProduct ? Icons.inventory_2 : Icons.handshake,
              ),
              label: Text(_currentItem.type.displayName),
              backgroundColor: _currentItem.isProduct
                  ? Colors.orange.shade100
                  : Colors.blue.shade100,
            ),
            const SizedBox(height: 20),

            if (_isEditing)
              _buildEditForm(currency)
            else
              _buildViewMode(currency),
          ],
        ),
      ),
    );
  }

  Widget _buildViewMode(NumberFormat currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoSection(
          title: 'Item Information',
          children: [
            _InfoRow(label: 'Name', value: _currentItem.name),
            _InfoRow(label: 'SKU', value: _currentItem.sku),
            _InfoRow(label: 'Category', value: _currentItem.category),
            _InfoRow(label: 'Unit', value: _currentItem.unit),
            _InfoRow(label: 'Description', value: _currentItem.description),
          ],
        ),
        const SizedBox(height: 20),
        _InfoSection(
          title: 'Pricing Information',
          children: [
            _InfoRow(
              label: 'Cost Price',
              value: currency.format(_currentItem.costPrice),
            ),
            _InfoRow(
              label: 'Selling Price',
              value: currency.format(_currentItem.sellingPrice),
            ),
            _InfoRow(
              label: 'Profit per Unit',
              value: currency.format(_currentItem.profit),
              valueColor: Colors.green,
            ),
            _InfoRow(
              label: 'Profit Margin',
              value: '${_currentItem.profitPercentage.toStringAsFixed(1)}%',
              valueColor: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_currentItem.isProduct) ...[
          _InfoSection(
            title: 'Stock Information',
            children: [
              _InfoRow(
                label: 'Current Stock',
                value: _currentItem.stock.toStringAsFixed(0),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _InfoSection(
          title: 'Metadata',
          children: [
            _InfoRow(
              label: 'Created By',
              value: _currentItem.createdBy ?? 'Unknown',
            ),
            _InfoRow(
              label: 'Created At',
              value: DateFormat(
                'dd MMM yyyy, HH:mm',
              ).format(_currentItem.createdAt),
            ),
            _InfoRow(
              label: 'Last Updated',
              value: DateFormat(
                'dd MMM yyyy, HH:mm',
              ).format(_currentItem.updatedAt),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm(NumberFormat currency) {
    return Form(
      child: Column(
        children: [
          // Product Image
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : _imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap to change photo',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to add product photo',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Cost Price',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _sellingPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Selling Price',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_currentItem.isProduct) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Stock',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleUpdate,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children:
                  children.expand((child) => [child, const Divider()]).toList()
                    ..removeLast(),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
