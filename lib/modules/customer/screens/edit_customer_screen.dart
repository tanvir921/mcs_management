import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/customer_provider.dart';
import '../models/customer_model.dart';
import '../models/due_transaction.dart';
import '../models/purchase_history.dart';
import '../services/image_service.dart';
import '../../auth/providers/auth_provider.dart';

class EditCustomerScreen extends StatefulWidget {
  final Customer customer;

  const EditCustomerScreen({super.key, required this.customer});

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  final _imageService = ImageService();
  bool _isSubmitting = false;
  bool _showDueManagement = false;
  File? _selectedImage;
  bool _imageChanged = false;
  late Customer _currentCustomer;
  int _purchaseHistoryRefresh = 0;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone ?? '');
    _addressController = TextEditingController(
      text: widget.customer.address ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      File? image;
      if (source == ImageSource.camera) {
        image = await _imageService.pickImageFromCamera();
      } else {
        image = await _imageService.pickImageFromGallery();
      }

      if (image != null) {
        setState(() {
          _selectedImage = image;
          _imageChanged = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_currentCustomer.imageUrl != null || _selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Image'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _imageChanged = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl = widget.customer.imageUrl;

      // Handle image changes
      if (_imageChanged) {
        // Delete old image if exists
        if (widget.customer.imageUrl != null) {
          await _imageService.deleteImage(widget.customer.imageUrl!);
        }

        // Upload new image if selected
        if (_selectedImage != null) {
          imageUrl = await _imageService.uploadImage(
            _selectedImage!,
            widget.customer.id,
          );
        } else {
          imageUrl = null;
        }
      }

      final updatedCustomer = widget.customer.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        imageUrl: imageUrl,
        updatedAt: DateTime.now(),
      );

      await context.read<CustomerProvider>().updateCustomer(updatedCustomer);

      // Log action
      final authProvider = context.read<AuthProvider>();
      await authProvider.logAction(
        action: 'UPDATE_CUSTOMER',
        module: 'Customer',
        details: 'Updated customer: ${updatedCustomer.name}',
      );

      // Update current customer state
      setState(() {
        _currentCustomer = updatedCustomer;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer updated successfully')),
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

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete ${widget.customer.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await context.read<CustomerProvider>().deleteCustomer(widget.customer.id);

      // Log action
      final authProvider = context.read<AuthProvider>();
      await authProvider.logAction(
        action: 'DELETE_CUSTOMER',
        module: 'Customer',
        details: 'Deleted customer: ${widget.customer.name}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.customer.name} deleted'),
            backgroundColor: Colors.orange,
          ),
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
    }
  }

  void _showDueDialog(String dueType, String title, double currentAmount) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final profitController = TextEditingController();
    bool isAddition = true;

    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current: ৳${currentAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Add'),
                        value: true,
                        groupValue: isAddition,
                        onChanged: (value) {
                          setDialogState(() => isAddition = value!);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Clear'),
                        value: false,
                        groupValue: isAddition,
                        onChanged: (value) {
                          setDialogState(() => isAddition = value!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: '৳ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                ),
                // Show profit field only when clearing due (not adding)
                if (!isAddition) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.green.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Profit from Due Clear',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: profitController,
                          decoration: InputDecoration(
                            labelText: 'Profit Amount (Optional)',
                            border: const OutlineInputBorder(),
                            prefixText: '৳ ',
                            hintText: 'Enter profit from this payment',
                            filled: true,
                            fillColor: Colors.white,
                            labelStyle: TextStyle(color: Colors.green.shade700),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Paid cash, Purchased items...',
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid amount')),
                  );
                  return;
                }

                final authProvider = parentContext.read<AuthProvider>();
                final currentUser = authProvider.currentUser;
                if (currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not authenticated')),
                  );
                  return;
                }

                final note = noteController.text.trim();
                final profit = double.tryParse(profitController.text) ?? 0;
                final noteText = note.isNotEmpty ? ' - Note: $note' : '';
                final profitText = profit > 0 ? ' (Profit: ৳$profit)' : '';
                final customerId = widget.customer.id;
                final customerName = widget.customer.name;
                final finalAmount = amount;
                final finalIsAddition = isAddition;
                final finalProfit = isAddition
                    ? 0.0
                    : profit; // Only track profit when clearing

                Navigator.pop(context);

                try {
                  await parentContext.read<CustomerProvider>().updateDue(
                    customerId: customerId,
                    amount: finalAmount,
                    dueType: dueType,
                    isAddition: finalIsAddition,
                    realizedProfit: finalProfit,
                    note: note.isEmpty ? null : note,
                    userId: currentUser.id,
                    userName: currentUser.name,
                  );

                  await authProvider.logAction(
                    action: 'UPDATE_DUE',
                    module: 'Customer',
                    details:
                        '${finalIsAddition ? "Added" : "Cleared"} ৳$finalAmount ${finalIsAddition ? "to" : "from"} $title for $customerName$profitText$noteText',
                  );

                  final updatedCustomer = await parentContext
                      .read<CustomerProvider>()
                      .getCustomerById(customerId);
                  if (mounted && updatedCustomer != null) {
                    setState(() {
                      _currentCustomer = updatedCustomer;
                    });
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('$title updated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshPurchaseHistory() {
    setState(() {
      _purchaseHistoryRefresh++;
    });
  }

  void _showAddPurchaseDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Purchase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: '৳ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., product details or payment info',
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final description = descriptionController.text.trim();
                      final amount = double.tryParse(amountController.text);

                      if (description.isEmpty ||
                          amount == null ||
                          amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter description and valid amount',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      final authProvider = context.read<AuthProvider>();
                      final currentUser = authProvider.currentUser;
                      if (currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User not authenticated'),
                          ),
                        );
                        setDialogState(() => isSaving = false);
                        return;
                      }

                      try {
                        await context
                            .read<CustomerProvider>()
                            .addPurchaseHistory(
                              customerId: widget.customer.id,
                              description: description,
                              amount: amount,
                              userId: currentUser.id,
                              userName: currentUser.name,
                              note: noteController.text.trim().isEmpty
                                  ? null
                                  : noteController.text.trim(),
                            );

                        await authProvider.logAction(
                          action: 'ADD_PURCHASE',
                          module: 'Customer',
                          details:
                              'Added purchase ৳$amount for ${widget.customer.name}',
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          _refreshPurchaseHistory();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Purchase added')),
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
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Customer'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.blue.shade800],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteCustomer,
            tooltip: 'Delete Customer',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Image Section
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (_currentCustomer.imageUrl != null
                                        ? NetworkImage(
                                            _currentCustomer.imageUrl!,
                                          )
                                        : null)
                                    as ImageProvider?,
                          child:
                              _selectedImage == null &&
                                  _currentCustomer.imageUrl == null
                              ? Text(
                                  _currentCustomer.name[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.transparent,
                            child: Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Basic Info Section
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
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Basic Information',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          hintText: 'Enter customer name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter customer name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          hintText: 'Enter phone number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Address (Optional)',
                          hintText: 'Enter address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 20),

                      // Update Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _updateCustomer,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  'Update Customer',
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
              const SizedBox(height: 16),

              // Due Management Section
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
                              Colors.orange.shade400,
                              Colors.orange.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Due Management',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Icon(
                        _showDueManagement
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onTap: () {
                        setState(
                          () => _showDueManagement = !_showDueManagement,
                        );
                      },
                    ),
                    if (_showDueManagement) ...[
                      const Divider(),
                      _DueListTile(
                        title: 'Product Due',
                        amount: _currentCustomer.productDue,
                        color: Colors.orange,
                        onTap: () => _showDueDialog(
                          'product',
                          'Product Due',
                          _currentCustomer.productDue,
                        ),
                      ),
                      _DueListTile(
                        title: 'Service Due',
                        amount: _currentCustomer.serviceDue,
                        color: Colors.blue,
                        onTap: () => _showDueDialog(
                          'service',
                          'Service Due',
                          _currentCustomer.serviceDue,
                        ),
                      ),
                      _DueListTile(
                        title: 'MSF/Recharge Due',
                        amount: _currentCustomer.msfRechargeDue,
                        color: Colors.purple,
                        onTap: () => _showDueDialog(
                          'msfRecharge',
                          'MSF/Recharge Due',
                          _currentCustomer.msfRechargeDue,
                        ),
                      ),
                      _DueListTile(
                        title: 'Cash Borrow',
                        amount: _currentCustomer.cashBorrowDue,
                        color: Colors.brown,
                        onTap: () => _showDueDialog(
                          'cashBorrow',
                          'Cash Borrow',
                          _currentCustomer.cashBorrowDue,
                        ),
                      ),
                      _DueListTile(
                        title: 'Previous Due',
                        amount: _currentCustomer.previousDue,
                        color: Colors.teal,
                        onTap: () => _showDueDialog(
                          'previousDue',
                          'Previous Due',
                          _currentCustomer.previousDue,
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Net Balance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '৳${_currentCustomer.netBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _currentCustomer.netBalance >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Due History Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transaction History',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => setState(() {}),
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    FutureBuilder<List<DueTransaction>>(
                      key: ValueKey(_currentCustomer.updatedAt),
                      future: context.read<CustomerProvider>().getDueHistory(
                        widget.customer.id,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        final transactions = snapshot.data ?? [];
                        if (transactions.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text('No transaction history yet'),
                            ),
                          );
                        }

                        return ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: transactions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            final isAddition = tx.isAddition;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isAddition
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50,
                                child: Icon(
                                  isAddition
                                      ? Icons.call_received
                                      : Icons.call_made,
                                  color: isAddition
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                              title: Text(tx.dueTypeLabel),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.transactionType,
                                    style: TextStyle(
                                      color: isAddition
                                          ? Colors.orange
                                          : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (tx.note != null && tx.note!.isNotEmpty)
                                    Text(tx.note!),
                                  Text(
                                    'By ${tx.createdByName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '৳${tx.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isAddition
                                          ? Colors.orange
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, y').format(tx.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Purchase History Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  Icons.receipt_long,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Purchase History',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Add Purchase',
                            onPressed: _showAddPurchaseDialog,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    FutureBuilder<List<PurchaseHistory>>(
                      key: ValueKey(_purchaseHistoryRefresh),
                      future: context
                          .read<CustomerProvider>()
                          .getPurchaseHistory(widget.customer.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        final purchases = snapshot.data ?? [];
                        if (purchases.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text('No purchase history yet'),
                            ),
                          );
                        }

                        final totalPurchases = purchases.length;
                        final totalAmount = purchases.fold<double>(
                          0,
                          (sum, p) => sum + p.amount,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.purple.shade100,
                                      Colors.purple.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade600,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.insights,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$totalPurchases purchase${totalPurchases == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.purple,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total ৳${totalAmount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: purchases.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final purchase = purchases[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.purple.shade50,
                                    child: const Icon(
                                      Icons.shopping_bag,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  title: Text(purchase.description),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (purchase.note != null &&
                                          purchase.note!.isNotEmpty)
                                        Text(purchase.note!),
                                      Text(
                                        'By ${purchase.createdByName}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '৳${purchase.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.purple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMM d, y',
                                        ).format(purchase.createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueListTile extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final VoidCallback onTap;

  const _DueListTile({
    required this.title,
    required this.amount,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        '৳${amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      trailing: const Icon(Icons.edit, size: 20),
      onTap: onTap,
    );
  }
}
