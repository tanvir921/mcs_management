import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import 'expense_detail_screen.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterPeriod = 'all';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<ExpenseProvider>().loadExpenses(
      startDate: _startDate,
      endDate: _endDate,
      category: _categoryFilter,
    );
  }

  void _applyFilter(String period) {
    setState(() {
      _filterPeriod = period;
      final now = DateTime.now();
      
      switch (period) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = now;
          break;
        default:
          _startDate = null;
          _endDate = null;
      }
    });
    _loadData();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (range != null) {
      setState(() {
        _filterPeriod = 'custom';
        _startDate = range.start;
        _endDate = range.end;
      });
      _loadData();
    }
  }

  void _applyCategoryFilter(String? category) {
    setState(() {
      _categoryFilter = category;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
            tooltip: 'Custom Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Period Filter
          Container(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterPeriod == 'all',
                    onSelected: (_) => _applyFilter('all'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Today'),
                    selected: _filterPeriod == 'today',
                    onSelected: (_) => _applyFilter('today'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('This Week'),
                    selected: _filterPeriod == 'week',
                    onSelected: (_) => _applyFilter('week'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('This Month'),
                    selected: _filterPeriod == 'month',
                    onSelected: (_) => _applyFilter('month'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('This Year'),
                    selected: _filterPeriod == 'year',
                    onSelected: (_) => _applyFilter('year'),
                  ),
                ],
              ),
            ),
          ),

          // Category Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All Categories'),
                    selected: _categoryFilter == null,
                    onSelected: (_) => _applyCategoryFilter(null),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Shop'),
                    selected: _categoryFilter == 'shop',
                    onSelected: (_) => _applyCategoryFilter('shop'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Personal'),
                    selected: _categoryFilter == 'personal',
                    onSelected: (_) => _applyCategoryFilter('personal'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Other'),
                    selected: _categoryFilter == 'other',
                    onSelected: (_) => _applyCategoryFilter('other'),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Expense List
          Expanded(
            child: Consumer<ExpenseProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${provider.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final expenses = provider.expenses;

                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No expenses found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      return _ExpenseCard(
                        expense: expense,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExpenseDetailScreen(expenseId: expense.id),
                            ),
                          ).then((_) => _loadData());
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;

  const _ExpenseCard({
    required this.expense,
    required this.onTap,
  });

  Color _getCategoryColor() {
    switch (expense.category) {
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
    switch (expense.category) {
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
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00');
    final categoryColor = _getCategoryColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getCategoryIcon(), color: categoryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Expense.getCategoryDisplayName(expense.category),
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '৳${currencyFormat.format(expense.amount)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(expense.expenseDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.receipt, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    expense.expenseNumber,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  _PaymentMethodChip(method: expense.paymentMethod),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String method;

  const _PaymentMethodChip({required this.method});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    
    switch (method) {
      case 'cash':
        icon = Icons.money;
        label = 'Cash';
        break;
      case 'card':
        icon = Icons.credit_card;
        label = 'Card';
        break;
      case 'mobile_banking':
        icon = Icons.phone_android;
        label = 'Mobile';
        break;
      default:
        icon = Icons.payment;
        label = method;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
