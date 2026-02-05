import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  Expense? _expense;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpense();
  }

  Future<void> _loadExpense() async {
    setState(() => _isLoading = true);
    try {
      final expense = await context.read<ExpenseProvider>().getExpenseById(
        widget.expenseId,
      );
      setState(() {
        _expense = expense;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Are you sure you want to delete expense ${_expense?.expenseNumber}?',
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

    if (confirm != true || _expense == null) return;

    try {
      await context.read<ExpenseProvider>().deleteExpense(_expense!.id);

      // Log action
      final authProvider = context.read<AuthProvider>();
      await authProvider.logAction(
        action: 'DELETE_EXPENSE',
        module: 'Expense',
        details: 'Deleted expense: ${_expense!.expenseNumber}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_expense!.expenseNumber} deleted'),
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

  Color _getCategoryColor() {
    if (_expense == null) return Colors.grey;
    switch (_expense!.category) {
      case 'shop':
        return Colors.blue;
      case 'personal':
        return Colors.purple;
      case 'other':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon() {
    if (_expense == null) return Icons.receipt;
    switch (_expense!.category) {
      case 'shop':
        return Icons.store;
      case 'personal':
        return Icons.person;
      case 'other':
        return Icons.category;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_expense == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Details')),
        body: const Center(child: Text('Expense not found')),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00');
    final categoryColor = _getCategoryColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteExpense,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(),
                      size: 48,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _expense!.expenseNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '৳${currencyFormat.format(_expense!.amount)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      Expense.getCategoryDisplayName(_expense!.category),
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.description,
                    label: 'Description',
                    value: _expense!.description,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: dateFormat.format(_expense!.expenseDate),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.payment,
                    label: 'Payment Method',
                    value: _getPaymentMethodName(_expense!.paymentMethod),
                  ),
                  if (_expense!.notes != null &&
                      _expense!.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.notes,
                      label: 'Notes',
                      value: _expense!.notes!,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Created By Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Record Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.person,
                    label: 'Created By',
                    value: _expense!.createdByName,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.access_time,
                    label: 'Created At',
                    value: DateFormat(
                      'MMM dd, yyyy hh:mm a',
                    ).format(_expense!.createdAt ?? DateTime.now()),
                  ),
                  if (_expense!.updatedAt != null) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.update,
                      label: 'Updated At',
                      value: DateFormat(
                        'MMM dd, yyyy hh:mm a',
                      ).format(_expense!.updatedAt!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'mobile_banking':
        return 'Mobile Banking';
      default:
        return method;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
