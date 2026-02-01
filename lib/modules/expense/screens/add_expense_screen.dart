import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  DateTime _expenseDate = DateTime.now();
  String _category = 'personal';
  String _paymentMethod = 'cash';
  List<File> _selectedPhotos = [];
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> categories = [
    {
      'id': 'personal',
      'label': 'Personal Expense',
      'icon': Icons.person_rounded,
      'color': const Color(0xFF5856D6),
    },
    {
      'id': 'shop',
      'label': 'Shop Expense',
      'icon': Icons.shopping_bag_rounded,
      'color': const Color(0xFFFF9500),
    },
    {
      'id': 'repair',
      'label': 'Repair & Maintenance',
      'icon': Icons.build_rounded,
      'color': const Color(0xFFFF3B30),
    },
    {
      'id': 'other',
      'label': 'Other Expense',
      'icon': Icons.more_horiz_rounded,
      'color': const Color(0xFF007AFF),
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade600),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null && _selectedPhotos.length < 5) {
        setState(() => _selectedPhotos.add(File(image.path)));
      } else if (_selectedPhotos.length >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 photos allowed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _selectedPhotos.removeAt(index));
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final expense = Expense(
        id: '',
        expenseNumber: '',
        expenseDate: _expenseDate,
        category: _category,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        receiptPhotos: [],
        createdBy: currentUser.id,
        createdByName: currentUser.name,
        createdAt: DateTime.now(),
      );

      final expenseProvider = context.read<ExpenseProvider>();
      final id = await expenseProvider.createExpense(
        expense,
        receiptPhotos: _selectedPhotos,
      );

      if (id != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(expenseProvider.error ?? 'Failed to record expense'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: const Text('Record Expense'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
              // Date Selector
              _buildModernDateCard(),
              const SizedBox(height: 20),

              // Category Selection
              _buildCategorySection(),
              const SizedBox(height: 20),

              // Description Input
              _buildInputField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'e.g., Electricity bill, Equipment repair',
                icon: Icons.description_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Amount Input
              _buildInputField(
                controller: _amountController,
                label: 'Amount',
                hint: '0.00',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid amount';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Payment Method
              _buildPaymentMethodSection(),
              const SizedBox(height: 20),

              // Receipt Photos
              _buildReceiptPhotosSection(),
              const SizedBox(height: 20),

              // Notes
              _buildInputField(
                controller: _notesController,
                label: 'Notes (Optional)',
                hint: 'Additional information',
                icon: Icons.note_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDateCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense Date',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMM dd, yyyy').format(_expenseDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Expense Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = _category == cat['id'];
            return _buildCategoryCard(cat, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _category = category['id']),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? category['color'] : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1.5,
          ),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    category['color'].withOpacity(0.1),
                    category['color'].withOpacity(0.05),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: category['color'].withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(category['icon'], color: category['color'], size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              category['label'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: category['color'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    final methods = [
      {'id': 'cash', 'label': 'Cash', 'icon': Icons.money_rounded},
      {'id': 'card', 'label': 'Card', 'icon': Icons.credit_card_rounded},
      {
        'id': 'mobile_banking',
        'label': 'Mobile Banking',
        'icon': Icons.phone_android_rounded,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: methods.map((method) => _buildMethodChip(method)).toList(),
        ),
      ],
    );
  }

  Widget _buildMethodChip(Map<String, dynamic> method) {
    final isSelected = _paymentMethod == method['id'];
    return FilterChip(
      onSelected: (selected) => setState(() => _paymentMethod = method['id']),
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            method['icon'],
            size: 18,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          Text(method['label']),
        ],
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: Colors.blue.shade600,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildReceiptPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Receipt Photos (${_selectedPhotos.length}/5)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (_selectedPhotos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _selectedPhotos.length,
            itemBuilder: (context, index) => _buildPhotoTile(index),
          ),
        if (_selectedPhotos.length < 5)
          Padding(
            padding: EdgeInsets.only(top: _selectedPhotos.isEmpty ? 0 : 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildUploadButton(
                    label: 'Camera',
                    icon: Icons.camera_alt_rounded,
                    onTap: () => _pickImage(ImageSource.camera),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUploadButton(
                    label: 'Gallery',
                    icon: Icons.image_rounded,
                    onTap: () => _pickImage(ImageSource.gallery),
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoTile(int index) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_selectedPhotos[index], fit: BoxFit.cover),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _removePhoto(index),
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
          color: color.withOpacity(0.08),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            icon: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(icon, color: Colors.blue.shade600),
            ),
            border: InputBorder.none,
            labelStyle: TextStyle(color: Colors.grey.shade600),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton.icon(
      onPressed: _isSubmitting ? null : _saveExpense,
      icon: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.check_circle_outline_rounded),
      label: Text(
        _isSubmitting ? 'Recording...' : 'Record Expense',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }
}
