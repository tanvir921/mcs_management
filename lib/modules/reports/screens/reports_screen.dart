import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/reports_service.dart';
import '../../sales/providers/sales_provider.dart';
import '../../customer/providers/customer_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsService _service = ReportsService();
  DateFilter _filter = DateFilter.today;
  Future<ReportsSummary>? _future;

  Future<double> _getOptionalProfits() async {
    final now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;

    switch (_filter) {
      case DateFilter.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
        break;
      case DateFilter.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = now;
        break;
      case DateFilter.thisYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = now;
        break;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('daily_closing')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('isApproved', isEqualTo: true)
          .get();

      double totalOptionalProfit = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final profitEntries = (data['profitEntries'] as List<dynamic>?) ?? [];
        for (final entry in profitEntries) {
          final amount =
              ((entry as Map<String, dynamic>)['amount'] as num?)?.toDouble() ??
              0;
          totalOptionalProfit += amount;
        }
      }
      return totalOptionalProfit;
    } catch (e) {
      debugPrint('Error fetching optional profits: $e');
      return 0;
    }
  }

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;

    switch (_filter) {
      case DateFilter.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
        break;
      case DateFilter.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = now;
        break;
      case DateFilter.thisYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = now;
        break;
    }
    return (startDate, endDate);
  }

  Future<double> _getDueClearProfit() async {
    final (startDate, endDate) = _getDateRange();
    return await context.read<CustomerProvider>().getTotalDueClearProfit(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  void _load() {
    setState(() {
      _future = _service.getSummary(_filter);
    });

    // Load customers data
    context.read<CustomerProvider>().loadCustomers();

    // Load sales stats based on filter
    final salesProvider = context.read<SalesProvider>();
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    switch (_filter) {
      case DateFilter.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
          23,
          59,
          59,
        );
        break;
      case DateFilter.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = now;
        break;
      case DateFilter.thisYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = now;
        break;
    }

    // Load sales data for the date range
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      salesProvider.loadSales(
        auth.currentUser!.id,
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Period:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateFilter>(
                      value: _filter,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: colorScheme.primary,
                      ),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DateFilter.today,
                          child: Text('Today'),
                        ),
                        DropdownMenuItem(
                          value: DateFilter.yesterday,
                          child: Text('Yesterday'),
                        ),
                        DropdownMenuItem(
                          value: DateFilter.thisMonth,
                          child: Text('This Month'),
                        ),
                        DropdownMenuItem(
                          value: DateFilter.thisYear,
                          child: Text('This Year'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _filter = val);
                          _load();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: FutureBuilder<ReportsSummary>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading reports',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final summary = snapshot.data;
                if (summary == null) {
                  return const Center(child: Text('No data'));
                }

                final currency = NumberFormat('#,##0.00');

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Sales Statistics Section
                    Consumer<SalesProvider>(
                      builder: (context, salesProvider, child) {
                        final stats =
                            salesProvider.stats ??
                            {
                              'totalSales': 0.0,
                              'totalCost': 0.0,
                              'totalProfit': 0.0,
                              'profitMargin': 0.0,
                              'totalTransactions': 0,
                              'averageSale': 0.0,
                              'optionalProfit': 0.0,
                            };

                        return FutureBuilder<double>(
                          future: _getOptionalProfits(),
                          builder: (context, optionalProfitSnapshot) {
                            if (optionalProfitSnapshot.hasData) {
                              stats['optionalProfit'] =
                                  optionalProfitSnapshot.data ?? 0.0;
                            }

                            return FutureBuilder<double>(
                              future: _getDueClearProfit(),
                              builder: (context, dueClearSnapshot) {
                                final dueClearProfit =
                                    dueClearSnapshot.data ?? 0.0;
                                // Calculate combined total profit
                                final salesProfit =
                                    (stats['totalProfit'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final optionalProfit =
                                    (stats['optionalProfit'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final combinedTotalProfit =
                                    salesProfit +
                                    optionalProfit +
                                    dueClearProfit;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                      icon: Icons.point_of_sale_rounded,
                                      title: 'Sales Performance',
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(height: 12),

                                    // Grid of stats cards
                                    GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1.5,
                                      children: [
                                        _StatCard(
                                          title: 'Total Sales',
                                          value:
                                              '৳${currency.format(stats['totalSales'] ?? 0)}',
                                          icon: Icons.shopping_cart_rounded,
                                          color: Colors.blue,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF2196F3),
                                              Color(0xFF1976D2),
                                            ],
                                          ),
                                        ),
                                        _StatCard(
                                          title: 'Combined Profit',
                                          value:
                                              '৳${currency.format(combinedTotalProfit)}',
                                          icon: Icons.trending_up_rounded,
                                          color: Colors.green,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF4CAF50),
                                              Color(0xFF388E3C),
                                            ],
                                          ),
                                        ),
                                        _StatCard(
                                          title: 'Transactions',
                                          value:
                                              '${stats['totalTransactions'] ?? 0}',
                                          icon: Icons.receipt_long_rounded,
                                          color: Colors.purple,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF9C27B0),
                                              Color(0xFF7B1FA2),
                                            ],
                                          ),
                                        ),
                                        _StatCard(
                                          title: 'Profit Margin',
                                          value:
                                              '${(stats['profitMargin'] ?? 0).toStringAsFixed(1)}%',
                                          icon: Icons.percent_rounded,
                                          color: Colors.orange,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFF9800),
                                              Color(0xFFF57C00),
                                            ],
                                          ),
                                        ),
                                        _StatCard(
                                          title: 'Optional Profits',
                                          value:
                                              '৳${currency.format(stats['optionalProfit'] ?? 0)}',
                                          icon: Icons.card_giftcard_rounded,
                                          color: Colors.deepPurple,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF673AB7),
                                              Color(0xFF512DA8),
                                            ],
                                          ),
                                        ),
                                        _StatCard(
                                          title: 'Due Clear Profit',
                                          value:
                                              '৳${currency.format(dueClearProfit)}',
                                          icon: Icons.price_check_rounded,
                                          color: Colors.teal,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF009688),
                                              Color(0xFF00695C),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Detailed breakdown card
                                    _DetailCard(
                                      children: [
                                        _DetailRow(
                                          label: 'Sales Profit',
                                          value:
                                              '৳${currency.format(stats['totalProfit'] ?? 0)}',
                                          icon: Icons.sell_rounded,
                                          color: Colors.green,
                                        ),
                                        _DetailRow(
                                          label: 'Total Cost',
                                          value:
                                              '৳${currency.format(stats['totalCost'] ?? 0)}',
                                          icon: Icons.payments_rounded,
                                          color: Colors.orange,
                                        ),
                                        _DetailRow(
                                          label: 'Average Sale',
                                          value:
                                              '৳${currency.format(stats['averageSale'] ?? 0)}',
                                          icon: Icons.analytics_rounded,
                                          color: Colors.indigo,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Outstanding Dues Section
                    Consumer<CustomerProvider>(
                      builder: (context, customerProvider, child) {
                        final customers = customerProvider.customers;

                        double totalProductDue = 0;
                        double totalServiceDue = 0;
                        double totalMsfRechargeDue = 0;
                        double totalCashBorrowDue = 0;
                        double totalPreviousDue = 0;

                        for (var customer in customers) {
                          totalProductDue += customer.productDue;
                          totalServiceDue += customer.serviceDue;
                          totalMsfRechargeDue += customer.msfRechargeDue;
                          totalCashBorrowDue += customer.cashBorrowDue;
                          totalPreviousDue += customer.previousDue;
                        }

                        double grandTotal =
                            totalProductDue +
                            totalServiceDue +
                            totalMsfRechargeDue +
                            totalCashBorrowDue +
                            totalPreviousDue;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(
                              icon: Icons.account_balance_wallet_rounded,
                              title: 'Outstanding Customer Dues',
                              color: Colors.red,
                            ),
                            const SizedBox(height: 12),

                            // Grid of dues cards
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.5,
                              children: [
                                _StatCard(
                                  title: 'Product Due',
                                  value: '৳${currency.format(totalProductDue)}',
                                  icon: Icons.inventory_2_rounded,
                                  color: Colors.red,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF44336),
                                      Color(0xFFD32F2F),
                                    ],
                                  ),
                                ),
                                _StatCard(
                                  title: 'Service Due',
                                  value: '৳${currency.format(totalServiceDue)}',
                                  icon: Icons.build_rounded,
                                  color: Colors.deepOrange,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF5722),
                                      Color(0xFFE64A19),
                                    ],
                                  ),
                                ),
                                _StatCard(
                                  title: 'MSF/RE Due',
                                  value:
                                      '৳${currency.format(totalMsfRechargeDue)}',
                                  icon: Icons.phone_android_rounded,
                                  color: Colors.purple,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF9C27B0),
                                      Color(0xFF7B1FA2),
                                    ],
                                  ),
                                ),
                                _StatCard(
                                  title: 'Cash Borrow',
                                  value:
                                      '৳${currency.format(totalCashBorrowDue)}',
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: Colors.brown,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF795548),
                                      Color(0xFF5D4037),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Detailed breakdown card
                            _DetailCard(
                              children: [
                                _DetailRow(
                                  label: 'Previous Due',
                                  value:
                                      '৳${currency.format(totalPreviousDue)}',
                                  icon: Icons.history_rounded,
                                  color: Colors.teal,
                                ),
                                const Divider(height: 24),
                                _DetailRow(
                                  label: 'Grand Total Due',
                                  value: '৳${currency.format(grandTotal)}',
                                  icon: Icons.account_balance_rounded,
                                  color: Colors.red,
                                  isBold: true,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Dues Section
                    _SectionHeader(
                      icon: Icons.add_circle_outline_rounded,
                      title: 'Dues Added',
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _DetailCard(
                      children: [
                        _DetailRow(
                          label: 'Product',
                          value:
                              '৳${currency.format(summary.duesAddedByType['product'] ?? 0)}',
                          icon: Icons.inventory_2_rounded,
                          color: Colors.orange,
                        ),
                        _DetailRow(
                          label: 'Service',
                          value:
                              '৳${currency.format(summary.duesAddedByType['service'] ?? 0)}',
                          icon: Icons.build_rounded,
                          color: Colors.blue,
                        ),
                        _DetailRow(
                          label: 'MSF/Recharge',
                          value:
                              '৳${currency.format(summary.duesAddedByType['msfRecharge'] ?? 0)}',
                          icon: Icons.phone_android_rounded,
                          color: Colors.purple,
                        ),
                        _DetailRow(
                          label: 'Cash Borrow',
                          value:
                              '৳${currency.format(summary.duesAddedByType['cashBorrow'] ?? 0)}',
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.brown,
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          label: 'Total Dues',
                          value: '৳${currency.format(summary.totalDuesAdded)}',
                          icon: Icons.calculate_rounded,
                          color: Colors.black,
                          isBold: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Collections Section
                    _SectionHeader(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Collections',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _DetailCard(
                      children: [
                        _DetailRow(
                          label: 'Product',
                          value:
                              '৳${currency.format(summary.collectionsByType['product'] ?? 0)}',
                          icon: Icons.inventory_2_rounded,
                          color: Colors.green,
                        ),
                        _DetailRow(
                          label: 'Service',
                          value:
                              '৳${currency.format(summary.collectionsByType['service'] ?? 0)}',
                          icon: Icons.build_rounded,
                          color: Colors.green,
                        ),
                        _DetailRow(
                          label: 'MSF/Recharge',
                          value:
                              '৳${currency.format(summary.collectionsByType['msfRecharge'] ?? 0)}',
                          icon: Icons.phone_android_rounded,
                          color: Colors.green,
                        ),
                        _DetailRow(
                          label: 'Cash Borrow',
                          value:
                              '৳${currency.format(summary.collectionsByType['cashBorrow'] ?? 0)}',
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.green,
                        ),
                        _DetailRow(
                          label: 'Previous Due',
                          value:
                              '৳${currency.format(summary.collectionsByType['previousDue'] ?? 0)}',
                          icon: Icons.history_rounded,
                          color: Colors.green,
                        ),
                        const Divider(height: 24),
                        _DetailRow(
                          label: 'Total Collections',
                          value:
                              '৳${currency.format(summary.totalCollections)}',
                          icon: Icons.calculate_rounded,
                          color: Colors.black,
                          isBold: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Expenses Section
                    if (summary.expenseStats != null) ...[
                      _SectionHeader(
                        icon: Icons.money_off_rounded,
                        title: 'Expenses',
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _DetailCard(
                        children: [
                          _DetailRow(
                            label: 'Shop Expenses',
                            value:
                                '৳${currency.format(summary.expenseStats!['shopExpenses'] ?? 0)}',
                            icon: Icons.store_rounded,
                            color: Colors.blue,
                          ),
                          _DetailRow(
                            label: 'Personal Expenses',
                            value:
                                '৳${currency.format(summary.expenseStats!['personalExpenses'] ?? 0)}',
                            icon: Icons.person_rounded,
                            color: Colors.purple,
                          ),
                          _DetailRow(
                            label: 'Other Expenses',
                            value:
                                '৳${currency.format(summary.expenseStats!['otherExpenses'] ?? 0)}',
                            icon: Icons.category_rounded,
                            color: Colors.orange,
                          ),
                          const Divider(height: 24),
                          _DetailRow(
                            label: 'Total Expenses',
                            value:
                                '৳${currency.format(summary.expenseStats!['totalExpenses'] ?? 0)}',
                            icon: Icons.calculate_rounded,
                            color: Colors.red,
                            isBold: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

// Stat Card Widget with Gradient
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Gradient gradient;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Detail Card Widget
class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
    );
  }
}

// Detail Row Widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 16 : 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 15,
              fontWeight: FontWeight.bold,
              color: isBold ? Colors.black : color,
            ),
          ),
        ],
      ),
    );
  }
}
