import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/daily_closing_model.dart';
import '../providers/daily_closing_provider.dart';
import '../../auth/providers/auth_provider.dart';

class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> {
  final _handCashController = TextEditingController();
  final _deductedProfitController = TextEditingController();
  final _remarksController = TextEditingController();
  bool _showCalculations = false;

  @override
  void initState() {
    super.initState();
    _loadClosingData();
  }

  Future<void> _loadClosingData() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser != null) {
      // Check if closing already exists for today
      final closingProvider = context.read<DailyClosingProvider>();
      final todayClosing = await closingProvider.getTodaysClosing(
        currentUser.id,
      );

      if (todayClosing != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Today\'s closing already uploaded!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _createDraftClosing() async {
    if (_handCashController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter today\'s hand cash')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    final handCash = double.tryParse(_handCashController.text);
    if (handCash == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid hand cash amount')));
      return;
    }

    try {
      await context.read<DailyClosingProvider>().createDraftClosing(
        userId: currentUser.id,
        todaysHandCash: handCash,
        profitEntries: [],
      );

      setState(() => _showCalculations = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily closing draft created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDailyClosing() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    try {
      await context.read<DailyClosingProvider>().saveDailyClosing(
        userId: currentUser.id,
        approvedByName: currentUser.name,
        remarks: _remarksController.text.isNotEmpty
            ? _remarksController.text
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily closing uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _handCashController.clear();
        _deductedProfitController.clear();
        _remarksController.clear();
        setState(() => _showCalculations = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _handCashController.dispose();
    _deductedProfitController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Closing'),
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
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClosingHistoryScreen()),
              );
            },
            tooltip: 'View History',
          ),
        ],
      ),
      body: Consumer<DailyClosingProvider>(
        builder: (context, closingProvider, child) {
          if (closingProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                  ),
                  const SizedBox(height: 16),
                  const Text('Loading...'),
                ],
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.grey.shade50, Colors.white],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_showCalculations) ...[
                  _buildInputSection(),
                ] else if (closingProvider.draftClosing != null) ...[
                  _buildClosingReport(context, closingProvider.draftClosing!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade700],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.wallet,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Closing',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          DateFormat(
                            'EEEE, MMMM d, yyyy',
                          ).format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Input Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hand Cash Entry',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the cash amount you have on hand',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _handCashController,
                  decoration: InputDecoration(
                    labelText: 'Hand Cash',
                    hintText: 'Enter amount',
                    prefixIcon: const Icon(Icons.currency_exchange),
                    suffixText: '৳',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createDraftClosing,
                    icon: const Icon(Icons.calculate, size: 20),
                    label: const Text(
                      'Calculate Daily Closing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClosingReport(BuildContext context, DailyClosing closing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Header with Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade700],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Closing Report',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'EEEE, MMMM d, yyyy',
                        ).format(closing.closingDate),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.assessment,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Summary Cards (3-column grid)
        _buildSummaryCards(closing),
        const SizedBox(height: 24),

        // Income Components with Breakdown
        _buildSectionCardWithBreakdown(
          title: 'Wallet Balances',
          breakdown: closing.walletBreakdown,
          total: closing.walletBalancesTotal,
          icon: Icons.account_balance_wallet,
          color: Colors.blue,
        ),
        const SizedBox(height: 16),

        // Hand Cash
        _buildModernItemCard(
          title: 'Hand Cash',
          amount: closing.todaysHandCash,
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        const SizedBox(height: 16),

        // Total Sales
        _buildModernItemCard(
          title: 'Total Sales',
          amount: closing.todaysSalesTotal,
          icon: Icons.point_of_sale,
          color: Colors.indigo,
        ),
        const SizedBox(height: 16),

        // MSF/Recharge with Breakdown
        _buildSectionCardWithBreakdown(
          title: 'MSF/Recharge Due',
          breakdown: closing.msfBreakdown,
          total: closing.todaysMSFRecharge,
          icon: Icons.phone_in_talk,
          color: Colors.orange,
        ),
        const SizedBox(height: 16),

        // Cash Borrow with Breakdown
        _buildSectionCardWithBreakdown(
          title: 'Cash Borrow Due',
          breakdown: closing.cashBorrowBreakdown,
          total: closing.todaysCashBorrowDue,
          icon: Icons.money_off,
          color: Colors.purple,
        ),
        const SizedBox(height: 16),

        // Expenses with Breakdown
        _buildSectionCardWithBreakdown(
          title: 'Expenses',
          breakdown: closing.expenseBreakdown,
          total: closing.todaysExpenses,
          icon: Icons.shopping_cart,
          color: Colors.red,
          isNegative: true,
        ),
        const SizedBox(height: 16),

        // Temporary Balance with Breakdown
        _buildSectionCardWithBreakdown(
          title: 'Temporary Balance',
          breakdown: closing.temporaryBalanceBreakdown,
          total: closing.temporaryBalancesTotal,
          icon: Icons.schedule,
          color: Colors.teal,
          isNegative: true,
        ),
        const SizedBox(height: 24),

        // Subtotal
        _buildSubtotalCard('Today\'s Subtotal', closing.subtotal, Colors.blue),
        const SizedBox(height: 16),

        // Comparison with Yesterday
        if (closing.yesterdaySubtotal > 0)
          _buildComparisonCard(context, closing)
        else
          _buildInfoCard(
            'No previous closing found (first closing)',
            Colors.amber,
          ),
        const SizedBox(height: 16),

        // Optional Profits Section
        _buildProfitsSection(context, closing),
        const SizedBox(height: 16),

        // Profit Deduction (Optional)
        _buildProfitDeductionSection(context, closing),
        const SizedBox(height: 24),

        // Final Balance - Large and Prominent
        _buildFinalBalanceCard(closing),
        const SizedBox(height: 24),

        // Remarks
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _remarksController,
              decoration: InputDecoration(
                labelText: 'Remarks (Optional)',
                border: InputBorder.none,
                hintText: 'Add any notes about today\'s closing...',
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 3,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<DailyClosingProvider>().clearDraft();
                  setState(() => _showCalculations = false);
                  _handCashController.clear();
                  _deductedProfitController.clear();
                  _remarksController.clear();
                },
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saveDailyClosing,
                icon: const Icon(Icons.check_circle),
                label: const Text('Approve & Save'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionCardWithBreakdown({
    required String title,
    required List<BreakdownItem> breakdown,
    required double total,
    bool isNegative = false,
    IconData? icon,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                if (icon != null)
                  Container(
                    decoration: BoxDecoration(
                      color: (color ?? Colors.blue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: color ?? Colors.blue, size: 20),
                  ),
                if (icon != null) const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Individual breakdown items
            if (breakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No items',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Column(
                children: breakdown
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.description != null &&
                                      item.description!.isNotEmpty)
                                    Text(
                                      item.description!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${isNegative ? '- ' : ''}৳${item.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isNegative ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            // Divider and Total
            if (breakdown.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${isNegative ? '- ' : ''}৳${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            color ?? (isNegative ? Colors.red : Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(DailyClosing closing) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: 'Wallet Balance',
            amount: closing.walletBalancesTotal,
            icon: Icons.account_balance_wallet,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            label: 'Total Expenses',
            amount: closing.todaysExpenses,
            icon: Icons.shopping_cart,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            label: 'Subtotal',
            amount: closing.subtotal,
            icon: Icons.calculate,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '৳${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernItemCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              '৳${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalBalanceCard(DailyClosing closing) {
    final isPositive = closing.finalClosingBalance >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.shade600, color.shade700]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Final Closing Balance',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '৳${closing.finalClosingBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Final Profit: ৳${closing.totalProfit.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalCard(String title, double amount, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '৳${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: color,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.attach_money, color: color, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard(BuildContext context, DailyClosing closing) {
    final difference = closing.remainingCash;
    final isPositive = difference >= 0;

    return Card(
      color: isPositive
          ? Colors.green.withOpacity(0.1)
          : Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Small Sales (Difference from Yesterday)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yesterday\'s Subtotal',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text('৳${closing.yesterdaySubtotal.toStringAsFixed(2)}'),
                  ],
                ),
                const Icon(Icons.arrow_forward),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Today\'s Subtotal',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text('৳${closing.subtotal.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPositive
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${isPositive ? '+' : ''}৳${difference.toStringAsFixed(2)} ${isPositive ? '(Difference(Small Sales Or Card))' : '(Loss (Someting went wrong))'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String message, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildProfitsSection(BuildContext context, DailyClosing closing) {
    final optionalProfitTotal = closing.profitEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profits Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '৳${closing.totalProfit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sales profit + optional profits (does not affect closing balance)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sales Profit'),
                Text(
                  '৳${closing.todaysSalesProfit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Optional Profit'),
                Text(
                  '৳${optionalProfitTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                _showAddProfitDialog(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Profit'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
            if (closing.profitEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: closing.profitEntries.length,
                itemBuilder: (context, index) {
                  final entry = closing.profitEntries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.source,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (entry.note != null)
                              Text(
                                entry.note!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '৳${entry.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfitDeductionSection(
    BuildContext context,
    DailyClosing closing,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deduct Profit from Closing (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Reduce closing balance by profit amount if needed',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deductedProfitController,
              decoration: InputDecoration(
                labelText: 'Amount to Deduct (৳)',
                border: const OutlineInputBorder(),
                prefixText: '৳ ',
                hintText: '0',
                suffixText: closing.deductedProfit > 0 ? '(Applied)' : '',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0;
                context.read<DailyClosingProvider>().updateDeductedProfit(
                  amount,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProfitDialog(BuildContext context) {
    final sourceController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Profit Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sourceController,
              decoration: const InputDecoration(
                labelText: 'Source (e.g., Bkash Agent, Photocopy)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (৳)',
                border: OutlineInputBorder(),
                prefixText: '৳ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Why this profit...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (sourceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter profit source')),
                );
                return;
              }

              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid amount')),
                );
                return;
              }

              final newEntry = ProfitEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                source: sourceController.text,
                amount: amount,
                note: noteController.text.isEmpty ? null : noteController.text,
              );

              final closingProvider = context.read<DailyClosingProvider>();
              if (closingProvider.draftClosing != null) {
                final updatedEntries = [
                  ...closingProvider.draftClosing!.profitEntries,
                  newEntry,
                ];
                closingProvider.updateProfitEntries(updatedEntries);
              }

              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// Closing History Screen
class ClosingHistoryScreen extends StatefulWidget {
  const ClosingHistoryScreen({super.key});

  @override
  State<ClosingHistoryScreen> createState() => _ClosingHistoryScreenState();
}

class _ClosingHistoryScreenState extends State<ClosingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser != null) {
      await context.read<DailyClosingProvider>().loadClosingHistory(
        currentUser.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Closing History'),
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: Consumer<DailyClosingProvider>(
          builder: (context, closingProvider, child) {
            if (closingProvider.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                    ),
                    const SizedBox(height: 16),
                    const Text('Loading history...'),
                  ],
                ),
              );
            }

            if (closingProvider.closingHistory.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No closing history found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: closingProvider.closingHistory.length,
              itemBuilder: (context, index) {
                final closing = closingProvider.closingHistory[index];
                final isPositive = closing.finalClosingBalance >= 0;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClosingDetailScreen(closing: closing),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            isPositive
                                ? Colors.green.withOpacity(0.05)
                                : Colors.red.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isPositive
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                isPositive
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: isPositive ? Colors.green : Colors.red,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat(
                                      'EEEE, MMM d, yyyy',
                                    ).format(closing.closingDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Balance: ৳${closing.finalClosingBalance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Profit: ৳${closing.totalProfit.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// Closing Detail Screen
class ClosingDetailScreen extends StatelessWidget {
  final DailyClosing closing;

  const ClosingDetailScreen({super.key, required this.closing});

  @override
  Widget build(BuildContext context) {
    final isPositive = closing.finalClosingBalance >= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMM d, yyyy').format(closing.closingDate)),
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
          if (closing.pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PDF download not yet implemented'),
                  ),
                );
              },
              tooltip: 'Download PDF',
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Card with gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isPositive ? Colors.green.shade600 : Colors.red.shade600,
                    isPositive ? Colors.green.shade700 : Colors.red.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isPositive ? Colors.green : Colors.red).withOpacity(
                      0.3,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Closing Summary',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Final Balance',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '৳${closing.finalClosingBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 40,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailMetric(
                          label: 'Final Profit',
                          amount: closing.totalProfit,
                          icon: Icons.trending_up,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailMetric(
                          label: 'Remaining Cash',
                          amount: closing.remainingCash,
                          icon: Icons.compare_arrows,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Detailed Breakdown - Wallet Balances
            _buildDetailedBreakdownSection(
              title: 'Wallet Balances',
              breakdown: closing.walletBreakdown,
              total: closing.walletBalancesTotal,
            ),
            const SizedBox(height: 16),

            // Hand Cash
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hand Cash'),
                    Text('৳${closing.todaysHandCash.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Total Sales
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Sales'),
                    Text('৳${closing.todaysSalesTotal.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // MSF/Recharge Breakdown
            _buildDetailedBreakdownSection(
              title: 'MSF/Recharge',
              breakdown: closing.msfBreakdown,
              total: closing.todaysMSFRecharge,
            ),
            const SizedBox(height: 16),

            // Cash Borrow Breakdown
            _buildDetailedBreakdownSection(
              title: 'Cash Borrow Due',
              breakdown: closing.cashBorrowBreakdown,
              total: closing.todaysCashBorrowDue,
            ),
            const SizedBox(height: 16),

            // Expenses Breakdown
            _buildDetailedBreakdownSection(
              title: 'Expenses',
              breakdown: closing.expenseBreakdown,
              total: closing.todaysExpenses,
              isNegative: true,
            ),
            const SizedBox(height: 16),

            // Temporary Balance Breakdown
            _buildDetailedBreakdownSection(
              title: 'Temporary Wallet Balance',
              breakdown: closing.temporaryBalanceBreakdown,
              total: closing.temporaryBalancesTotal,
              isNegative: true,
            ),
            const SizedBox(height: 16),

            // Profit Entries
            if (closing.profitEntries.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profit Entries',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...closing.profitEntries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.source,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (entry.note != null)
                                    Text(
                                      entry.note!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              Text('৳${entry.amount.toStringAsFixed(2)}'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Approval Info
            if (closing.isApproved)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Approval Info',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Approved by: ${closing.approvedBy}'),
                      Text(
                        'Approved at: ${DateFormat('MMM d, yyyy HH:mm').format(closing.approvedAt ?? DateTime.now())}',
                      ),
                      if (closing.remarks != null) ...[
                        const SizedBox(height: 8),
                        Text('Remarks: ${closing.remarks}'),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailMetric({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.9), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '৳${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedBreakdownSection({
    required String title,
    required List<BreakdownItem> breakdown,
    required double total,
    bool isNegative = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Individual breakdown items
            if (breakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No items',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              )
            else
              ...breakdown.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (item.description != null &&
                                item.description!.isNotEmpty)
                              Text(
                                item.description!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isNegative ? '- ' : ''}৳${item.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isNegative ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Divider and Total
            if (breakdown.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total $title',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${isNegative ? '- ' : ''}৳${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isNegative ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
