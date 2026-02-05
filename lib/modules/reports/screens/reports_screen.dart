import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/reports_service.dart';
import '../../sales/providers/sales_provider.dart';
import '../../customer/providers/customer_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final ReportsService _service = ReportsService();
  DateFilter _filter = DateFilter.today;
  Future<ReportsSummary>? _future;
  late TabController _tabController;

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
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
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
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('isApproved', isEqualTo: true)
          .get();

      double totalOptionalProfit = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final profitEntries = (data['profitEntries'] as List<dynamic>?) ?? [];
        for (final entry in profitEntries) {
          final amount = ((entry as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0;
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
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
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
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = _service.getSummary(_filter);
    });

    context.read<CustomerProvider>().loadCustomers();

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
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
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

    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      salesProvider.loadSales(auth.currentUser!.id, startDate: startDate, endDate: endDate);
    }
  }

  String _getFilterLabel() {
    switch (_filter) {
      case DateFilter.today:
        return 'Today - ${DateFormat('MMM d, yyyy').format(DateTime.now())}';
      case DateFilter.yesterday:
        return 'Yesterday - ${DateFormat('MMM d, yyyy').format(DateTime.now().subtract(const Duration(days: 1)))}';
      case DateFilter.thisMonth:
        return DateFormat('MMMM yyyy').format(DateTime.now());
      case DateFilter.thisYear:
        return 'Year ${DateTime.now().year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;
    final colorScheme = Theme.of(context).colorScheme;

    if (kIsWeb && isWideScreen) {
      return _buildWebLayout(colorScheme);
    }
    return _buildMobileLayout(colorScheme);
  }

  Widget _buildWebLayout(ColorScheme colorScheme) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildWebHeader(colorScheme),
          Expanded(
            child: FutureBuilder<ReportsSummary>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error);
                }
                final summary = snapshot.data;
                if (summary == null) {
                  return const Center(child: Text('No data'));
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(right: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: _buildQuickSummaryPanel(summary),
                    ),
                    Expanded(child: _buildDetailedReportsPanel(summary)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebHeader(ColorScheme colorScheme) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reports & Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_getFilterLabel(), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const Spacer(),
          _buildFilterChips(colorScheme),
          const SizedBox(width: 16),
          _ActionButton(icon: Icons.refresh_rounded, label: 'Refresh', onPressed: _load, color: colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterChip(label: 'Today', isSelected: _filter == DateFilter.today, onTap: () => _selectFilter(DateFilter.today)),
          _FilterChip(label: 'Yesterday', isSelected: _filter == DateFilter.yesterday, onTap: () => _selectFilter(DateFilter.yesterday)),
          _FilterChip(label: 'This Month', isSelected: _filter == DateFilter.thisMonth, onTap: () => _selectFilter(DateFilter.thisMonth)),
          _FilterChip(label: 'This Year', isSelected: _filter == DateFilter.thisYear, onTap: () => _selectFilter(DateFilter.thisYear)),
        ],
      ),
    );
  }

  void _selectFilter(DateFilter filter) {
    setState(() => _filter = filter);
    _load();
  }

  Widget _buildQuickSummaryPanel(ReportsSummary summary) {
    final currency = NumberFormat('#,##0.00');
    
    return Consumer2<SalesProvider, CustomerProvider>(
      builder: (context, salesProvider, customerProvider, _) {
        final stats = salesProvider.stats ?? {'totalSales': 0.0, 'totalProfit': 0.0, 'totalTransactions': 0};
        
        double totalDue = 0;
        for (var customer in customerProvider.customers) {
          totalDue += customer.productDue + customer.serviceDue + 
                      customer.msfRechargeDue + customer.cashBorrowDue + customer.previousDue;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              const SizedBox(height: 16),
              
              _QuickStatCard(
                title: 'Total Sales',
                value: '৳${currency.format(stats['totalSales'] ?? 0)}',
                subtitle: '${stats['totalTransactions'] ?? 0} transactions',
                icon: Icons.point_of_sale_rounded,
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(height: 12),
              
              FutureBuilder<List<double>>(
                future: Future.wait([_getOptionalProfits(), _getDueClearProfit()]),
                builder: (context, profitSnapshot) {
                  final salesProfit = (stats['totalProfit'] as num?)?.toDouble() ?? 0;
                  final optionalProfit = profitSnapshot.data?[0] ?? 0;
                  final dueClearProfit = profitSnapshot.data?[1] ?? 0;
                  final totalProfit = salesProfit + optionalProfit + dueClearProfit;
                  
                  return _QuickStatCard(
                    title: 'Total Profit',
                    value: '৳${currency.format(totalProfit)}',
                    subtitle: 'Sales + Optional + Due Clear',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF4CAF50),
                  );
                },
              ),
              const SizedBox(height: 12),
              
              _QuickStatCard(
                title: 'Dues Added',
                value: '৳${currency.format(summary.totalDuesAdded)}',
                subtitle: 'New credit given',
                icon: Icons.add_circle_outline_rounded,
                color: const Color(0xFFFF9800),
              ),
              const SizedBox(height: 12),
              
              _QuickStatCard(
                title: 'Collections',
                value: '৳${currency.format(summary.totalCollections)}',
                subtitle: 'Payments received',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF009688),
              ),
              const SizedBox(height: 12),
              
              _QuickStatCard(
                title: 'Expenses',
                value: '৳${currency.format(summary.expenseStats?['totalExpenses'] ?? 0)}',
                subtitle: 'All expense categories',
                icon: Icons.money_off_rounded,
                color: const Color(0xFFF44336),
              ),
              const SizedBox(height: 12),
              
              _QuickStatCard(
                title: 'Outstanding Dues',
                value: '৳${currency.format(totalDue)}',
                subtitle: '${customerProvider.customers.length} customers',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF9C27B0),
              ),
              const SizedBox(height: 24),
              
              _buildNetPositionCard(summary, stats, currency),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetPositionCard(ReportsSummary summary, Map<String, dynamic> stats, NumberFormat currency) {
    final totalSales = (stats['totalSales'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (summary.expenseStats?['totalExpenses'] as num?)?.toDouble() ?? 0;
    final netCashFlow = totalSales + summary.totalCollections - summary.totalDuesAdded - totalExpenses;
    final isPositive = netCashFlow >= 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive 
              ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
              : [const Color(0xFFF44336), const Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: (isPositive ? Colors.green : Colors.red).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white.withOpacity(0.9), size: 20),
              const SizedBox(width: 8),
              Text('Net Cash Flow', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${isPositive ? '+' : ''}৳${currency.format(netCashFlow)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(isPositive ? 'Positive cash position' : 'Negative cash position', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDetailedReportsPanel(ReportsSummary summary) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.point_of_sale_rounded), text: 'Sales'),
              Tab(icon: Icon(Icons.account_balance_wallet_rounded), text: 'Dues'),
              Tab(icon: Icon(Icons.payments_rounded), text: 'Collections'),
              Tab(icon: Icon(Icons.money_off_rounded), text: 'Expenses'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSalesTab(summary),
              _buildDuesTab(summary),
              _buildCollectionsTab(summary),
              _buildExpensesTab(summary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTab(ReportsSummary summary) {
    final currency = NumberFormat('#,##0.00');
    
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, _) {
        final stats = salesProvider.stats ?? {
          'totalSales': 0.0, 'totalCost': 0.0, 'totalProfit': 0.0,
          'profitMargin': 0.0, 'totalTransactions': 0, 'averageSale': 0.0,
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _WebStatCard(title: 'Total Sales', value: '৳${currency.format(stats['totalSales'] ?? 0)}', icon: Icons.shopping_cart_rounded, color: const Color(0xFF2196F3))),
                  const SizedBox(width: 16),
                  Expanded(child: _WebStatCard(title: 'Total Cost', value: '৳${currency.format(stats['totalCost'] ?? 0)}', icon: Icons.payments_rounded, color: const Color(0xFFFF9800))),
                  const SizedBox(width: 16),
                  Expanded(child: _WebStatCard(title: 'Sales Profit', value: '৳${currency.format(stats['totalProfit'] ?? 0)}', icon: Icons.trending_up_rounded, color: const Color(0xFF4CAF50))),
                  const SizedBox(width: 16),
                  Expanded(child: _WebStatCard(title: 'Profit Margin', value: '${(stats['profitMargin'] ?? 0).toStringAsFixed(1)}%', icon: Icons.percent_rounded, color: const Color(0xFF9C27B0))),
                ],
              ),
              const SizedBox(height: 24),
              
              FutureBuilder<List<double>>(
                future: Future.wait([_getOptionalProfits(), _getDueClearProfit()]),
                builder: (context, profitSnapshot) {
                  final salesProfit = (stats['totalProfit'] as num?)?.toDouble() ?? 0;
                  final optionalProfit = profitSnapshot.data?[0] ?? 0;
                  final dueClearProfit = profitSnapshot.data?[1] ?? 0;
                  final totalProfit = salesProfit + optionalProfit + dueClearProfit;
                  
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _WebDetailCard(
                          title: 'Profit Breakdown',
                          icon: Icons.pie_chart_rounded,
                          children: [
                            _WebDetailRow(label: 'Sales Profit', value: '৳${currency.format(salesProfit)}', color: const Color(0xFF4CAF50), percentage: totalProfit > 0 ? (salesProfit / totalProfit * 100) : 0),
                            _WebDetailRow(label: 'Optional Profit', value: '৳${currency.format(optionalProfit)}', color: const Color(0xFF673AB7), percentage: totalProfit > 0 ? (optionalProfit / totalProfit * 100) : 0),
                            _WebDetailRow(label: 'Due Clear Profit', value: '৳${currency.format(dueClearProfit)}', color: const Color(0xFF009688), percentage: totalProfit > 0 ? (dueClearProfit / totalProfit * 100) : 0),
                            const Divider(height: 32),
                            _WebDetailRow(label: 'Combined Total', value: '৳${currency.format(totalProfit)}', color: Colors.black, isBold: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _WebDetailCard(
                          title: 'Transaction Stats',
                          icon: Icons.receipt_long_rounded,
                          children: [
                            _WebDetailRow(label: 'Total Transactions', value: '${stats['totalTransactions'] ?? 0}', color: const Color(0xFF2196F3)),
                            _WebDetailRow(label: 'Average Sale Value', value: '৳${currency.format(stats['averageSale'] ?? 0)}', color: const Color(0xFF9C27B0)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDuesTab(ReportsSummary summary) {
    final currency = NumberFormat('#,##0.00');
    
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, _) {
        double totalProductDue = 0, totalServiceDue = 0, totalMsfRechargeDue = 0, totalCashBorrowDue = 0, totalPreviousDue = 0;

        for (var customer in customerProvider.customers) {
          totalProductDue += customer.productDue;
          totalServiceDue += customer.serviceDue;
          totalMsfRechargeDue += customer.msfRechargeDue;
          totalCashBorrowDue += customer.cashBorrowDue;
          totalPreviousDue += customer.previousDue;
        }

        final grandTotal = totalProductDue + totalServiceDue + totalMsfRechargeDue + totalCashBorrowDue + totalPreviousDue;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WebDetailCard(
                title: 'Dues Added (${_getFilterLabel()})',
                icon: Icons.add_circle_outline_rounded,
                headerColor: const Color(0xFFFF9800),
                children: [
                  _WebDetailRow(label: 'Product Due', value: '৳${currency.format(summary.duesAddedByType['product'] ?? 0)}', color: const Color(0xFFF44336), icon: Icons.inventory_2_rounded),
                  _WebDetailRow(label: 'Service Due', value: '৳${currency.format(summary.duesAddedByType['service'] ?? 0)}', color: const Color(0xFFFF5722), icon: Icons.build_rounded),
                  _WebDetailRow(label: 'MSF/Recharge Due', value: '৳${currency.format(summary.duesAddedByType['msfRecharge'] ?? 0)}', color: const Color(0xFF9C27B0), icon: Icons.phone_android_rounded),
                  _WebDetailRow(label: 'Cash Borrow', value: '৳${currency.format(summary.duesAddedByType['cashBorrow'] ?? 0)}', color: const Color(0xFF795548), icon: Icons.account_balance_wallet_rounded),
                  const Divider(height: 32),
                  _WebDetailRow(label: 'Total Dues Added', value: '৳${currency.format(summary.totalDuesAdded)}', color: const Color(0xFFFF9800), isBold: true),
                ],
              ),
              const SizedBox(height: 24),
              
              Text('Outstanding Customer Dues', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: _WebStatCard(title: 'Product Due', value: '৳${currency.format(totalProductDue)}', icon: Icons.inventory_2_rounded, color: const Color(0xFFF44336))),
                  const SizedBox(width: 16),
                  Expanded(child: _WebStatCard(title: 'Service Due', value: '৳${currency.format(totalServiceDue)}', icon: Icons.build_rounded, color: const Color(0xFFFF5722))),
                  const SizedBox(width: 16),
                  Expanded(child: _WebStatCard(title: 'MSF/Recharge', value: '৳${currency.format(totalMsfRechargeDue)}', icon: Icons.phone_android_rounded, color: const Color(0xFF9C27B0))),
                  const SizedBox(width: 16),
                  Expanded(child: _WebStatCard(title: 'Cash Borrow', value: '৳${currency.format(totalCashBorrowDue)}', icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF795548))),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: _WebStatCard(title: 'Previous Due', value: '৳${currency.format(totalPreviousDue)}', icon: Icons.history_rounded, color: const Color(0xFF607D8B))),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFD32F2F)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, color: Colors.white, size: 40),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Grand Total Outstanding', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                              Text('৳${currency.format(grandTotal)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Spacer(),
                          Text('${customerProvider.customers.where((c) => c.totalDue > 0).length} customers', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollectionsTab(ReportsSummary summary) {
    final currency = NumberFormat('#,##0.00');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _WebStatCard(title: 'Total Collections', value: '৳${currency.format(summary.totalCollections)}', icon: Icons.check_circle_rounded, color: const Color(0xFF4CAF50))),
              const SizedBox(width: 16),
              Expanded(
                child: _WebStatCard(
                  title: 'Net Due Change',
                  value: '${summary.totalCollections >= summary.totalDuesAdded ? '-' : '+'}৳${currency.format((summary.totalDuesAdded - summary.totalCollections).abs())}',
                  icon: summary.totalCollections >= summary.totalDuesAdded ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                  color: summary.totalCollections >= summary.totalDuesAdded ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _WebDetailCard(
            title: 'Collection Breakdown',
            icon: Icons.receipt_long_rounded,
            headerColor: const Color(0xFF4CAF50),
            children: [
              _WebDetailRow(label: 'Product Due', value: '৳${currency.format(summary.collectionsByType['product'] ?? 0)}', color: const Color(0xFF4CAF50), icon: Icons.inventory_2_rounded, percentage: summary.totalCollections > 0 ? ((summary.collectionsByType['product'] ?? 0) / summary.totalCollections * 100) : 0),
              _WebDetailRow(label: 'Service Due', value: '৳${currency.format(summary.collectionsByType['service'] ?? 0)}', color: const Color(0xFF4CAF50), icon: Icons.build_rounded, percentage: summary.totalCollections > 0 ? ((summary.collectionsByType['service'] ?? 0) / summary.totalCollections * 100) : 0),
              _WebDetailRow(label: 'MSF/Recharge', value: '৳${currency.format(summary.collectionsByType['msfRecharge'] ?? 0)}', color: const Color(0xFF4CAF50), icon: Icons.phone_android_rounded, percentage: summary.totalCollections > 0 ? ((summary.collectionsByType['msfRecharge'] ?? 0) / summary.totalCollections * 100) : 0),
              _WebDetailRow(label: 'Cash Borrow', value: '৳${currency.format(summary.collectionsByType['cashBorrow'] ?? 0)}', color: const Color(0xFF4CAF50), icon: Icons.account_balance_wallet_rounded, percentage: summary.totalCollections > 0 ? ((summary.collectionsByType['cashBorrow'] ?? 0) / summary.totalCollections * 100) : 0),
              _WebDetailRow(label: 'Previous Due', value: '৳${currency.format(summary.collectionsByType['previousDue'] ?? 0)}', color: const Color(0xFF4CAF50), icon: Icons.history_rounded, percentage: summary.totalCollections > 0 ? ((summary.collectionsByType['previousDue'] ?? 0) / summary.totalCollections * 100) : 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(ReportsSummary summary) {
    final currency = NumberFormat('#,##0.00');
    final expenseStats = summary.expenseStats ?? {};
    final totalExpenses = (expenseStats['totalExpenses'] as num?)?.toDouble() ?? 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _WebStatCard(title: 'Shop Expenses', value: '৳${currency.format(expenseStats['shopExpenses'] ?? 0)}', icon: Icons.store_rounded, color: const Color(0xFF2196F3))),
              const SizedBox(width: 16),
              Expanded(child: _WebStatCard(title: 'Personal Expenses', value: '৳${currency.format(expenseStats['personalExpenses'] ?? 0)}', icon: Icons.person_rounded, color: const Color(0xFF9C27B0))),
              const SizedBox(width: 16),
              Expanded(child: _WebStatCard(title: 'Repair Expenses', value: '৳${currency.format(expenseStats['repairExpenses'] ?? 0)}', icon: Icons.build_rounded, color: const Color(0xFFFF5722))),
              const SizedBox(width: 16),
              Expanded(child: _WebStatCard(title: 'Other Expenses', value: '৳${currency.format(expenseStats['otherExpenses'] ?? 0)}', icon: Icons.category_rounded, color: const Color(0xFF607D8B))),
            ],
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFD32F2F)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.money_off_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Expenses', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                    Text('৳${currency.format(totalExpenses)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${expenseStats['totalCount'] ?? 0} transactions', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(_getFilterLabel(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          _WebDetailCard(
            title: 'Expense Distribution',
            icon: Icons.pie_chart_rounded,
            headerColor: const Color(0xFFF44336),
            children: [
              _WebDetailRow(label: 'Shop Expenses', value: '৳${currency.format(expenseStats['shopExpenses'] ?? 0)}', color: const Color(0xFF2196F3), icon: Icons.store_rounded, percentage: totalExpenses > 0 ? ((expenseStats['shopExpenses'] ?? 0) / totalExpenses * 100) : 0),
              _WebDetailRow(label: 'Personal Expenses', value: '৳${currency.format(expenseStats['personalExpenses'] ?? 0)}', color: const Color(0xFF9C27B0), icon: Icons.person_rounded, percentage: totalExpenses > 0 ? ((expenseStats['personalExpenses'] ?? 0) / totalExpenses * 100) : 0),
              _WebDetailRow(label: 'Repair & Maintenance', value: '৳${currency.format(expenseStats['repairExpenses'] ?? 0)}', color: const Color(0xFFFF5722), icon: Icons.build_rounded, percentage: totalExpenses > 0 ? ((expenseStats['repairExpenses'] ?? 0) / totalExpenses * 100) : 0),
              _WebDetailRow(label: 'Other Expenses', value: '৳${currency.format(expenseStats['otherExpenses'] ?? 0)}', color: const Color(0xFF607D8B), icon: Icons.category_rounded, percentage: totalExpenses > 0 ? ((expenseStats['otherExpenses'] ?? 0) / totalExpenses * 100) : 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('Error loading reports', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text('$error', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    );
  }

  // Mobile Layout
  Widget _buildMobileLayout(ColorScheme colorScheme) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load, tooltip: 'Refresh')],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Period:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateFilter>(
                      value: _filter,
                      icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: DateFilter.today, child: Text('Today')),
                        DropdownMenuItem(value: DateFilter.yesterday, child: Text('Yesterday')),
                        DropdownMenuItem(value: DateFilter.thisMonth, child: Text('This Month')),
                        DropdownMenuItem(value: DateFilter.thisYear, child: Text('This Year')),
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
          Expanded(child: _buildMobileContent()),
        ],
      ),
    );
  }

  Widget _buildMobileContent() {
    return FutureBuilder<ReportsSummary>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _buildErrorState(snapshot.error);
        final summary = snapshot.data;
        if (summary == null) return const Center(child: Text('No data'));

        final currency = NumberFormat('#,##0.00');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Consumer<SalesProvider>(
              builder: (context, salesProvider, _) {
                final stats = salesProvider.stats ?? {'totalSales': 0.0, 'totalProfit': 0.0, 'totalTransactions': 0, 'profitMargin': 0.0, 'totalCost': 0.0, 'averageSale': 0.0};
                
                return FutureBuilder<List<double>>(
                  future: Future.wait([_getOptionalProfits(), _getDueClearProfit()]),
                  builder: (context, profitSnapshot) {
                    final salesProfit = (stats['totalProfit'] as num?)?.toDouble() ?? 0;
                    final optionalProfit = profitSnapshot.data?[0] ?? 0;
                    final dueClearProfit = profitSnapshot.data?[1] ?? 0;
                    final combinedTotalProfit = salesProfit + optionalProfit + dueClearProfit;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(icon: Icons.point_of_sale_rounded, title: 'Sales Performance', color: Colors.blue),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          children: [
                            _StatCard(title: 'Total Sales', value: '৳${currency.format(stats['totalSales'] ?? 0)}', icon: Icons.shopping_cart_rounded, color: Colors.blue, gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)])),
                            _StatCard(title: 'Combined Profit', value: '৳${currency.format(combinedTotalProfit)}', icon: Icons.trending_up_rounded, color: Colors.green, gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF388E3C)])),
                            _StatCard(title: 'Transactions', value: '${stats['totalTransactions'] ?? 0}', icon: Icons.receipt_long_rounded, color: Colors.purple, gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)])),
                            _StatCard(title: 'Profit Margin', value: '${(stats['profitMargin'] ?? 0).toStringAsFixed(1)}%', icon: Icons.percent_rounded, color: Colors.orange, gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DetailCard(children: [
                          _DetailRow(label: 'Sales Profit', value: '৳${currency.format(stats['totalProfit'] ?? 0)}', icon: Icons.sell_rounded, color: Colors.green),
                          _DetailRow(label: 'Optional Profit', value: '৳${currency.format(optionalProfit)}', icon: Icons.card_giftcard_rounded, color: Colors.deepPurple),
                          _DetailRow(label: 'Due Clear Profit', value: '৳${currency.format(dueClearProfit)}', icon: Icons.price_check_rounded, color: Colors.teal),
                        ]),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            _SectionHeader(icon: Icons.add_circle_outline_rounded, title: 'Dues Added', color: Colors.orange),
            const SizedBox(height: 12),
            _DetailCard(children: [
              _DetailRow(label: 'Product', value: '৳${currency.format(summary.duesAddedByType['product'] ?? 0)}', icon: Icons.inventory_2_rounded, color: Colors.orange),
              _DetailRow(label: 'Service', value: '৳${currency.format(summary.duesAddedByType['service'] ?? 0)}', icon: Icons.build_rounded, color: Colors.blue),
              _DetailRow(label: 'MSF/Recharge', value: '৳${currency.format(summary.duesAddedByType['msfRecharge'] ?? 0)}', icon: Icons.phone_android_rounded, color: Colors.purple),
              _DetailRow(label: 'Cash Borrow', value: '৳${currency.format(summary.duesAddedByType['cashBorrow'] ?? 0)}', icon: Icons.account_balance_wallet_rounded, color: Colors.brown),
              const Divider(height: 24),
              _DetailRow(label: 'Total Dues', value: '৳${currency.format(summary.totalDuesAdded)}', icon: Icons.calculate_rounded, color: Colors.black, isBold: true),
            ]),
            const SizedBox(height: 24),
            _SectionHeader(icon: Icons.check_circle_outline_rounded, title: 'Collections', color: Colors.green),
            const SizedBox(height: 12),
            _DetailCard(children: [
              _DetailRow(label: 'Product', value: '৳${currency.format(summary.collectionsByType['product'] ?? 0)}', icon: Icons.inventory_2_rounded, color: Colors.green),
              _DetailRow(label: 'Service', value: '৳${currency.format(summary.collectionsByType['service'] ?? 0)}', icon: Icons.build_rounded, color: Colors.green),
              _DetailRow(label: 'MSF/Recharge', value: '৳${currency.format(summary.collectionsByType['msfRecharge'] ?? 0)}', icon: Icons.phone_android_rounded, color: Colors.green),
              _DetailRow(label: 'Cash Borrow', value: '৳${currency.format(summary.collectionsByType['cashBorrow'] ?? 0)}', icon: Icons.account_balance_wallet_rounded, color: Colors.green),
              _DetailRow(label: 'Previous Due', value: '৳${currency.format(summary.collectionsByType['previousDue'] ?? 0)}', icon: Icons.history_rounded, color: Colors.green),
              const Divider(height: 24),
              _DetailRow(label: 'Total Collections', value: '৳${currency.format(summary.totalCollections)}', icon: Icons.calculate_rounded, color: Colors.black, isBold: true),
            ]),
            const SizedBox(height: 24),
            if (summary.expenseStats != null) ...[
              _SectionHeader(icon: Icons.money_off_rounded, title: 'Expenses', color: Colors.red),
              const SizedBox(height: 12),
              _DetailCard(children: [
                _DetailRow(label: 'Shop Expenses', value: '৳${currency.format(summary.expenseStats!['shopExpenses'] ?? 0)}', icon: Icons.store_rounded, color: Colors.blue),
                _DetailRow(label: 'Personal Expenses', value: '৳${currency.format(summary.expenseStats!['personalExpenses'] ?? 0)}', icon: Icons.person_rounded, color: Colors.purple),
                _DetailRow(label: 'Other Expenses', value: '৳${currency.format(summary.expenseStats!['otherExpenses'] ?? 0)}', icon: Icons.category_rounded, color: Colors.orange),
                const Divider(height: 24),
                _DetailRow(label: 'Total Expenses', value: '৳${currency.format(summary.expenseStats!['totalExpenses'] ?? 0)}', icon: Icons.calculate_rounded, color: Colors.red, isBold: true),
              ]),
            ],
          ],
        );
      },
    );
  }
}

// ============= WIDGETS =============

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({required this.icon, required this.label, required this.onPressed, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))]),
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _QuickStatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _WebStatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebDetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? headerColor;
  final List<Widget> children;

  const _WebDetailCard({required this.title, required this.icon, this.headerColor, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (headerColor ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: headerColor ?? Colors.grey, size: 20)),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(20), child: Column(children: children)),
        ],
      ),
    );
  }
}

class _WebDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final double? percentage;
  final bool isBold;

  const _WebDetailRow({required this.label, required this.value, required this.color, this.icon, this.percentage, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(label, style: TextStyle(fontSize: isBold ? 15 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: Colors.grey.shade700))),
          if (percentage != null) ...[
            Container(
              width: 100,
              height: 6,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (percentage! / 100).clamp(0, 1),
                child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              ),
            ),
            SizedBox(width: 45, child: Text('${percentage!.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          ],
          Text(value, style: TextStyle(fontSize: isBold ? 15 : 14, fontWeight: FontWeight.bold, color: isBold ? Colors.black : color)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Gradient gradient;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
            const Spacer(),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isBold;

  const _DetailRow({required this.label, required this.value, required this.icon, required this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: isBold ? 16 : 15, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: Colors.grey[800]))),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 15, fontWeight: FontWeight.bold, color: isBold ? Colors.black : color)),
        ],
      ),
    );
  }
}
