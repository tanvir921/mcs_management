import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddInventoryScreen extends StatefulWidget {
  final ItemType? initialType;

  const AddInventoryScreen({super.key, this.initialType});

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final _formKey = GlobalKey<FormState>();

  late ItemType _selectedType;
  String? _selectedCategory;
  String _categoryName = '';
  bool _createNewCategory = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _unitController = TextEditingController();
  final _skuController = TextEditingController();

  File? _selectedImage;
  String? _imageUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? ItemType.product;
    if (_selectedType == ItemType.service) {
      _stockController.text = '1';
      _unitController.text = 'service';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _skuController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
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
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null && !_createNewCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a category')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;
      final inventory = Provider.of<InventoryProvider>(context, listen: false);

      if (user == null) throw Exception('User not found');

      // Create category if needed
      String categoryId = _selectedCategory ?? '';
      if (_createNewCategory) {
        await inventory.createCategory(
          user.id,
          _categoryName,
          _categoryName,
          _selectedType,
        );
        categoryId = _categoryName;
      }

      // Upload image if selected
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl =
            await inventory.uploadImage(_selectedImage!, user.id);
      }

      // Create inventory item
      final item = InventoryItem(
        id: '',
        userId: user.id,
        category: categoryId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        costPrice: double.tryParse(_costPriceController.text) ?? 0,
        sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
        stock: _selectedType == ItemType.product
            ? double.tryParse(_stockController.text) ?? 0
            : 0,
        unit: _unitController.text.trim(),
        sku: _skuController.text.trim(),
        image: uploadedImageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user.id,
        updatedBy: user.id,
      );

      await inventory.addItem(item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedType.displayName} added successfully'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${_selectedType.displayName}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selection
              Text('Item Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<ItemType>(
                      segments: const [
                        ButtonSegment(
                          value: ItemType.product,
                          label: Text('Product'),
                          icon: Icon(Icons.inventory_2),
                        ),
                        ButtonSegment(
                          value: ItemType.service,
                          label: Text('Service'),
                          icon: Icon(Icons.handshake),
                        ),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedType = newSelection.first;
                          if (_selectedType == ItemType.service) {
                            _stockController.text = '0';
                            _unitController.text = 'service';
                          } else {
                            _unitController.clear();
                            _stockController.clear();
                          }
                          _selectedCategory = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Category Selection/Creation
              Text('Category', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Consumer<InventoryProvider>(
                builder: (context, inventory, _) {
                  final categories = _selectedType == ItemType.product
                      ? inventory.productCategories
                      : inventory.serviceCategories;

                  return Column(
                    children: [
                      if (categories.isNotEmpty && !_createNewCategory)
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Select Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat.id,
                                  child: Text(cat.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value),
                          validator: (value) {
                            if (!_createNewCategory && value == null) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        )
                      else if (_createNewCategory)
                        TextFormField(
                          onChanged: (value) =>
                              setState(() => _categoryName = value),
                          decoration: InputDecoration(
                            labelText: 'New Category Name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (_createNewCategory &&
                                (value?.isEmpty ?? true)) {
                              return 'Category name required';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => setState(
                          () => _createNewCategory = !_createNewCategory,
                        ),
                        icon: Icon(
                          _createNewCategory ? Icons.close : Icons.add,
                        ),
                        label: Text(
                          _createNewCategory
                              ? 'Cancel New Category'
                              : 'Create New Category',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Product Image
              Text('Product Image',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
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
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _imageUrl!,
                                fit: BoxFit.cover,
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
                                const SizedBox(height: 4),
                                Text(
                                  'Camera or Gallery',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${_selectedType.displayName} Name',
                  prefixIcon: const Icon(Icons.label),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SKU
              TextFormField(
                controller: _skuController,
                decoration: InputDecoration(
                  labelText: 'SKU (Stock Keeping Unit)',
                  prefixIcon: const Icon(Icons.qr_code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Unique identifier for this item',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'SKU is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Unit
              TextFormField(
                controller: _unitController,
                decoration: InputDecoration(
                  labelText: 'Unit (kg, pcs, meter, hour, etc)',
                  prefixIcon: const Icon(Icons.straighten),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Unit is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cost Price & Selling Price Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Cost Price (৳)',
                        prefixIcon: const Icon(Icons.local_offer),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Cost price required';
                        }
                        if (double.tryParse(value!) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
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
                        labelText: 'Selling Price (৳)',
                        prefixIcon: const Icon(Icons.sell),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Selling price required';
                        }
                        if (double.tryParse(value!) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Profit Display
              if (_costPriceController.text.isNotEmpty &&
                  _sellingPriceController.text.isNotEmpty)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Profit per unit:'),
                        const SizedBox(width: 8),
                        Text(
                          '৳${(double.tryParse(_sellingPriceController.text) ?? 0) - (double.tryParse(_costPriceController.text) ?? 0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${((double.tryParse(_sellingPriceController.text) ?? 0) - (double.tryParse(_costPriceController.text) ?? 0)) / (double.tryParse(_costPriceController.text) ?? 1) * 100}.toStringAsFixed(1)%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Stock (Only for Products)
              if (_selectedType == ItemType.product)
                TextFormField(
                  controller: _stockController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Initial Stock Quantity',
                    prefixIcon: const Icon(Icons.inventory),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText: 'Number of units in stock',
                  ),
                  validator: (value) {
                    if (_selectedType == ItemType.product) {
                      if (value?.isEmpty ?? true) {
                        return 'Stock is required for products';
                      }
                      if (double.tryParse(value!) == null) {
                        return 'Invalid number';
                      }
                    }
                    return null;
                  },
                ),
              if (_selectedType == ItemType.product) const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Add ${_selectedType.displayName}',
                          style: const TextStyle(fontSize: 16),
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
