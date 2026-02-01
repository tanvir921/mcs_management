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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
            ),
          ),
          child: child!,
        );
      },
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
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            onPressed: _pickDateRange,
            tooltip: 'Custom Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh',
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
        child: Column(
          children: [
            // Period Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 10),
                    _buildFilterChip('Today', 'today'),
                    const SizedBox(width: 10),
                    _buildFilterChip('This Week', 'week'),
                    const SizedBox(width: 10),
                    _buildFilterChip('This Month', 'month'),
                    const SizedBox(width: 10),
                    _buildFilterChip('This Year', 'year'),
                  ],
                ),
              ),
            ),

            // Category Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(null, 'All Categories', Colors.grey),
                    const SizedBox(width: 10),
                    _buildCategoryChip('personal', 'Personal', const Color(0xFF5856D6)),
                    const SizedBox(width: 10),
                    _buildCategoryChip('shop', 'Shop', const Color(0xFFFF9500)),
                    const SizedBox(width: 10),
                    _buildCategoryChip('repair', 'Repair', const Color(0xFFFF3B30)),
                    const SizedBox(width: 10),
                    _buildCategoryChip('other', 'Other', const Color(0xFF007AFF)),
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
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (provider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${provider.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                            ),
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
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 72,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No expenses found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a new expense to get started',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _loadData(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        return _ExpenseCard(
                          expense: expense,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExpenseDetailScreen(expenseId: expense.id),
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
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterPeriod == value;
    return FilterChip(
      onSelected: (_) => _applyFilter(value),
      selected: isSelected,
      label: Text(label),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade600 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      selectedColor: Colors.blue.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildCategoryChip(String? category, String label, Color color) {
    final isSelected = _categoryFilter == category;
    return FilterChip(
      onSelected: (_) => _applyCategoryFilter(category),
      selected: isSelected,
      label: Text(label),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? color : Colors.grey.shade300,
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      selectedColor: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00');
    final categoryColor = Expense.getCategoryColor(expense.category);
    final categoryIcon = Expense.getCategoryIcon(expense.category);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Category Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      categoryIcon,
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Description and Category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            Expense.getCategoryDisplayName(expense.category),
                            style: TextStyle(
                              color: categoryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '৳${currencyFormat.format(expense.amount)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expense.paymentMethod == 'cash'
                            ? 'Cash'
                            : expense.paymentMethod == 'card'
                                ? 'Card'
                                : 'Mobile',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Divider
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[300]!,
                      Colors.grey[200]!,
                      Colors.grey[300]!,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Footer Row
              Row(
                children: [
                  // Date
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateFormat.format(expense.expenseDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Receipt Number
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_rounded,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        expense.expenseNumber,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),

                  // Photo indicator
                  if (expense.receiptPhotos.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_rounded,
                            size: 12,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${expense.receiptPhotos.length}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
