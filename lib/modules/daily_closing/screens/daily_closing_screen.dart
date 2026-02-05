import 'package:flutter/foundation.dart' show kIsWeb;
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
  final _cashoutChargeController = TextEditingController();
  final _remarksController = TextEditingController();
  bool _showCalculations = false;
  bool _expandedIncomeSection = false;
  bool _expandedExpensesSection = false;
  double _dueClearProfit = 0;

  @override
  void initState() {
    super.initState();
    _loadClosingData();
  }

  Future<void> _loadDueClearProfit() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      final profit = await context
          .read<DailyClosingProvider>()
          .getTodaysDueClearProfit(currentUser.id);
      if (mounted) {
        setState(() {
          _dueClearProfit = profit;
        });
      }
    }
  }

  Future<void> _loadClosingData() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser != null) {
      // Load due clear profit
      _loadDueClearProfit();

      // Check if closing already exists for today
      final closingProvider = context.read<DailyClosingProvider>();
      final todayClosing = await closingProvider.getTodaysClosing(
        currentUser.id,
      );

      if (todayClosing != null && mounted) {
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
    _cashoutChargeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 1100;

    if (kIsWeb && isWideScreen) {
      return _buildWebLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Consumer<DailyClosingProvider>(
        builder: (context, closingProvider, child) {
          return Column(
            children: [
              // Web Header
              Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade900]),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily Closing', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    // Stats in header
                    if (closingProvider.draftClosing != null) ...[
                      _WebHeaderStat(label: 'Subtotal', value: '৳${closingProvider.draftClosing!.subtotal.toStringAsFixed(0)}', icon: Icons.calculate),
                      const SizedBox(width: 24),
                      _WebHeaderStat(label: 'Profit', value: '৳${closingProvider.draftClosing!.totalProfit.toStringAsFixed(0)}', icon: Icons.trending_up),
                      const SizedBox(width: 24),
                    ],
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ClosingHistoryScreen()));
                      },
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: closingProvider.isLoading
                    ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.blue.shade600)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: !_showCalculations
                            ? _buildWebInputSection()
                            : closingProvider.draftClosing != null
                                ? _buildWebClosingReport(context, closingProvider.draftClosing!)
                                : const SizedBox(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWebInputSection() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            // Welcome Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade700]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              padding: const EdgeInsets.all(32),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.wallet, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Closing', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Input Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hand Cash Entry', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Enter the cash amount you have on hand', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _handCashController,
                      decoration: InputDecoration(
                        labelText: 'Hand Cash',
                        hintText: 'Enter amount',
                        prefixIcon: const Icon(Icons.currency_exchange),
                        suffixText: '৳',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _createDraftClosing,
                        icon: const Icon(Icons.calculate, size: 20),
                        label: const Text('Calculate Daily Closing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.blue.shade600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebClosingReport(BuildContext context, DailyClosing closing) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel - Main Report
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Summary Cards Row
              Row(
                children: [
                  Expanded(child: _buildWebSummaryCard('Wallet Balance', closing.walletBalancesTotal, Icons.account_balance_wallet, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildWebSummaryCard('Total Expenses', closing.todaysExpenses, Icons.trending_down, Colors.red)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildWebSummaryCard('Today\'s Subtotal', closing.subtotal, Icons.calculate, Colors.green)),
                ],
              ),
              const SizedBox(height: 24),
              // Income & Deductions in two columns
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildWebBreakdownCard('Income', Icons.arrow_upward, Colors.green, _buildIncomeBreakdown(closing))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildWebBreakdownCard('Deductions', Icons.arrow_downward, Colors.red, _buildExpensesBreakdown(closing))),
                ],
              ),
              const SizedBox(height: 24),
              // Cashout & Comparison
              _buildCashoutChargeSection(context, closing),
              const SizedBox(height: 16),
              if (closing.yesterdaySubtotal > 0)
                _buildComparisonCard(context, closing)
              else
                _buildInfoCard('No previous closing found (first closing)', Colors.amber),
              const SizedBox(height: 24),
              // Profits & Deduction
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildProfitsSection(context, closing)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildProfitDeductionSection(context, closing)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Right Panel - Final Balance & Actions
        SizedBox(
          width: 380,
          child: Column(
            children: [
              // Final Balance Card
              _buildFinalBalanceCard(closing),
              const SizedBox(height: 24),
              // Remarks
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note_outlined, color: Colors.blue.shade400, size: 20),
                          const SizedBox(width: 8),
                          const Text('Remarks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _remarksController,
                        decoration: InputDecoration(
                          hintText: 'Add any notes about today\'s closing...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        maxLines: 3,
                      ),
                    ],
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
                        _cashoutChargeController.clear();
                        _remarksController.clear();
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveDailyClosing,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Approve & Save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebSummaryCard(String label, double amount, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.85), color.withOpacity(0.65)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('৳${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWebBreakdownCard(String title, IconData icon, Color color, Widget content) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
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
        // Professional Header with Gradient and Shadow
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.blue.shade800],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(26),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Closing Report',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat(
                      'EEEE, MMMM d, yyyy',
                    ).format(closing.closingDate),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(14),
                child: const Icon(
                  Icons.summarize_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // SECTION 1: Key Summary (3 Important Numbers)
        _buildSummaryCards(closing),
        const SizedBox(height: 24),

        // SECTION 2: Income Breakdown (Collapsible)
        _buildCollapsibleSection(
          title: 'Income',
          icon: Icons.arrow_upward,
          color: Colors.green,
          isExpanded: _expandedIncomeSection,
          onToggle: () =>
              setState(() => _expandedIncomeSection = !_expandedIncomeSection),
          children: [_buildIncomeBreakdown(closing)],
        ),
        const SizedBox(height: 16),

        // SECTION 3: Expenses Breakdown (Collapsible)
        _buildCollapsibleSection(
          title: 'Deductions',
          icon: Icons.arrow_downward,
          color: Colors.red,
          isExpanded: _expandedExpensesSection,
          onToggle: () => setState(
            () => _expandedExpensesSection = !_expandedExpensesSection,
          ),
          children: [_buildExpensesBreakdown(closing)],
        ),
        const SizedBox(height: 24),

        // SECTION 4: Subtotal Card
        _buildSubtotalCard('Today\'s Subtotal', closing.subtotal, Colors.blue),
        const SizedBox(height: 16),

        // SECTION 5: Balancing Section
        _buildBalancingSection(context, closing),
        const SizedBox(height: 24),

        // SECTION 6: Adjustments
        _buildAdjustmentsSection(context, closing),
        const SizedBox(height: 24),

        // SECTION 7: Final Balance - Large and Prominent
        _buildFinalBalanceCard(closing),
        const SizedBox(height: 24),

        // SECTION 8: Remarks
        _buildRemarksCard(),
        const SizedBox(height: 24),

        // SECTION 9: Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<DailyClosingProvider>().clearDraft();
                  setState(() => _showCalculations = false);
                  _handCashController.clear();
                  _deductedProfitController.clear();
                  _cashoutChargeController.clear();
                  _remarksController.clear();
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saveDailyClosing,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Approve & Save'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // Collapsible Section Widget - Professional Design
  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: color,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Column(
              children: [
                Container(height: 1, color: Colors.grey.shade100),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Column(children: children),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Income Breakdown (ADDED items)
  Widget _buildIncomeBreakdown(DailyClosing closing) {
    return Column(
      children: [
        _buildBreakdownRow(
          'Wallet Balances',
          closing.walletBalancesTotal,
          Colors.blue,
        ),
        _buildDivider(),
        _buildBreakdownRow('Hand Cash', closing.todaysHandCash, Colors.green),
        _buildDivider(),
        _buildBreakdownRow(
          'MSF/Recharge Due Added',
          closing.todaysMSFRecharge,
          Colors.orange,
        ),
        _buildDivider(),
        _buildBreakdownRow(
          'Cash Borrow Added',
          closing.todaysCashBorrowDue,
          Colors.purple,
        ),
        _buildDivider(),
        _buildBreakdownRow('Expenses', closing.todaysExpenses, Colors.amber),
      ],
    );
  }

  // Deductions Breakdown (SUBTRACTED items)
  Widget _buildExpensesBreakdown(DailyClosing closing) {
    return Column(
      children: [
        _buildBreakdownRow(
          'Temporary Balance',
          closing.temporaryBalancesTotal,
          Colors.teal,
          isNegative: true,
        ),
        _buildDivider(),
        _buildBreakdownRow(
          'Product Sales Balance',
          closing.todaysSalesTotal,
          Colors.indigo,
          isNegative: true,
        ),
        _buildDivider(),
        _buildBreakdownRow(
          'Total Due Collections',
          closing.totalDueCollections,
          Colors.green,
          isNegative: true,
        ),
      ],
    );
  }

  // NEW: Balancing Section
  Widget _buildBalancingSection(BuildContext context, DailyClosing closing) {
    return Column(
      children: [
        _buildCashoutChargeSection(context, closing),
        const SizedBox(height: 16),
        if (closing.yesterdaySubtotal > 0)
          _buildComparisonCard(context, closing)
        else
          _buildInfoCard(
            'No previous closing found (first closing)',
            Colors.amber,
          ),
      ],
    );
  }

  // NEW: Adjustments Section
  Widget _buildAdjustmentsSection(BuildContext context, DailyClosing closing) {
    return Column(
      children: [
        _buildProfitsSection(context, closing),
        const SizedBox(height: 16),
        _buildProfitDeductionSection(context, closing),
      ],
    );
  }

  // NEW: Remarks Card
  Widget _buildRemarksCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: TextField(
          controller: _remarksController,
          decoration: InputDecoration(
            labelText: 'Remarks (Optional)',
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            hintText: 'Add any notes about today\'s closing...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.note_outlined, color: Colors.blue.shade400),
          ),
          maxLines: 3,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // Breakdown Row Helper - Professional Design
  Widget _buildBreakdownRow(
    String label,
    double amount,
    Color color, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          Text(
            '${isNegative ? '−' : '+'}৳${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isNegative ? Colors.red.shade600 : Colors.green.shade600,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // Divider Helper - Professional Design
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[200]!, Colors.grey[100]!, Colors.grey[200]!],
          ),
        ),
      ),
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildProfessionalSummaryCard(
                label: 'Wallet Balance',
                amount: closing.walletBalancesTotal,
                icon: Icons.account_balance_wallet,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildProfessionalSummaryCard(
                label: 'Total Expenses',
                amount: closing.todaysExpenses,
                icon: Icons.trending_down,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _buildProfessionalSummaryCard(
            label: 'Today\'s Subtotal',
            amount: closing.subtotal,
            icon: Icons.calculate,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalSummaryCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.85), color.withOpacity(0.65)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '৳${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.shade600, color.shade700],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '৳${closing.finalClosingBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Total Profit: ৳${closing.totalProfit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalCard(String title, double amount, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.05), color.withOpacity(0.02)],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '৳${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: color.withOpacity(0.8),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.currency_exchange, color: color, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard(BuildContext context, DailyClosing closing) {
    final difference = closing.remainingCash;
    final isPositive = difference >= 0;
    final subtotalForComparison = closing.subtotal - closing.cashoutCharge;
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.06), color.withOpacity(0.02)],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Daily Balance Check (For Balancing Only)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yesterday',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '৳${closing.yesterdaySubtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_forward, color: color, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Today (Adjusted)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '৳${subtotalForComparison.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Difference',
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isPositive ? '+' : ''}৳${difference.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color.shade700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPositive ? '(Small Sales / Card)' : '(Loss)',
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
              'Sales profit + due clear profit + optional profits',
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
                const Text('Due Clear Profit'),
                Text(
                  '৳${_dueClearProfit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
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

  Widget _buildCashoutChargeSection(
    BuildContext context,
    DailyClosing closing,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.amber.shade50, Colors.orange.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.attach_money,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Extra Cash / Cashout Charge',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'For balancing only (e.g., 1015 tk received for 1000 tk)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cashoutChargeController,
                decoration: InputDecoration(
                  labelText: 'Amount (৳)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.currency_exchange,
                    color: Colors.orange,
                  ),
                  hintText: '0',
                  filled: true,
                  fillColor: Colors.white,
                  suffixText: closing.cashoutCharge > 0 ? '✓ Applied' : '',
                  suffixStyle: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0;
                  context.read<DailyClosingProvider>().updateCashoutCharge(
                    amount,
                  );
                },
              ),
              if (closing.cashoutCharge > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'For Balancing Only:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.orange.shade900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        '৳${(closing.subtotal - closing.cashoutCharge).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange.shade900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
              final authProvider = context.read<AuthProvider>();
              final userId = authProvider.currentUser?.id ?? '';
              if (closingProvider.draftClosing != null) {
                final updatedEntries = [
                  ...closingProvider.draftClosing!.profitEntries,
                  newEntry,
                ];
                closingProvider.updateProfitEntries(updatedEntries, userId);
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
    final isWideScreen = MediaQuery.of(context).size.width > 1100;

    if (kIsWeb && isWideScreen) {
      return _buildWebLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Web Header
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade900]),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Closing History', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('View past daily closings', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Consumer<DailyClosingProvider>(
              builder: (context, closingProvider, child) {
                if (closingProvider.isLoading) {
                  return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.blue.shade600)));
                }

                if (closingProvider.closingHistory.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No closing history found', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Stats
                      Row(
                        children: [
                          _buildWebStatCard('Total Closings', closingProvider.closingHistory.length.toString(), Icons.calendar_month, Colors.blue),
                          const SizedBox(width: 16),
                          _buildWebStatCard('Total Profit', '৳${closingProvider.closingHistory.fold<double>(0, (sum, c) => sum + c.totalProfit).toStringAsFixed(0)}', Icons.trending_up, Colors.green),
                          const SizedBox(width: 16),
                          _buildWebStatCard('Avg. Balance', '৳${(closingProvider.closingHistory.fold<double>(0, (sum, c) => sum + c.finalClosingBalance) / closingProvider.closingHistory.length).toStringAsFixed(0)}', Icons.account_balance, Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // History Table
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54))),
                                    const Expanded(flex: 2, child: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54))),
                                    const Expanded(flex: 2, child: Text('Profit', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54))),
                                    const Expanded(flex: 2, child: Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54))),
                                    const Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54))),
                                    const SizedBox(width: 50),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              // Table Body
                              Expanded(
                                child: ListView.separated(
                                  itemCount: closingProvider.closingHistory.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final closing = closingProvider.closingHistory[index];
                                    final isPositive = closing.finalClosingBalance >= 0;
                                    return InkWell(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClosingDetailScreen(closing: closing))),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(DateFormat('EEEE, MMM d, yyyy').format(closing.closingDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text('৳${closing.finalClosingBalance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w600, color: isPositive ? Colors.green : Colors.red)),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text('৳${closing.totalProfit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text('৳${closing.subtotal.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(isPositive ? 'Positive' : 'Negative', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isPositive ? Colors.green : Colors.red)),
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
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
    final isWideScreen = MediaQuery.of(context).size.width > 1100;

    if (kIsWeb && isWideScreen) {
      return _buildWebLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildWebLayout(BuildContext context) {
    final isPositive = closing.finalClosingBalance >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Web Header
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade900]),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, MMMM d, yyyy').format(closing.closingDate), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text('Closing Details', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                _WebHeaderStatDetail(label: 'Balance', value: '৳${closing.finalClosingBalance.toStringAsFixed(0)}', color: isPositive ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 24),
                _WebHeaderStatDetail(label: 'Profit', value: '৳${closing.totalProfit.toStringAsFixed(0)}', color: Colors.greenAccent),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel - Summary & Breakdowns
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Summary Card
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                isPositive ? Colors.green.shade600 : Colors.red.shade600,
                                isPositive ? Colors.green.shade700 : Colors.red.shade700,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: (isPositive ? Colors.green : Colors.red).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Final Closing Balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    Text('৳${closing.finalClosingBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36)),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        _buildDetailMetric(label: 'Profit', amount: closing.totalProfit, icon: Icons.trending_up, color: Colors.white),
                                        const SizedBox(width: 16),
                                        _buildDetailMetric(label: 'Remaining', amount: closing.remainingCash, icon: Icons.compare_arrows, color: Colors.white),
                                        const SizedBox(width: 16),
                                        _buildDetailMetric(label: 'Subtotal', amount: closing.subtotal, icon: Icons.calculate, color: Colors.white),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.all(20),
                                child: Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 50),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Breakdowns in Grid
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildDetailedBreakdownSection(title: 'Wallet Balances', breakdown: closing.walletBreakdown, total: closing.walletBalancesTotal)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDetailedBreakdownSection(title: 'Expenses', breakdown: closing.expenseBreakdown, total: closing.todaysExpenses, isNegative: true)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildDetailedBreakdownSection(title: 'MSF/Recharge', breakdown: closing.msfBreakdown, total: closing.todaysMSFRecharge)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDetailedBreakdownSection(title: 'Cash Borrow Due', breakdown: closing.cashBorrowBreakdown, total: closing.todaysCashBorrowDue)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailedBreakdownSection(title: 'Temporary Wallet Balance', breakdown: closing.temporaryBalanceBreakdown, total: closing.temporaryBalancesTotal, isNegative: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right Panel - Quick Info
                  SizedBox(
                    width: 350,
                    child: Column(
                      children: [
                        // Quick Stats
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Quick Stats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 16),
                                _buildQuickStatRow('Hand Cash', closing.todaysHandCash, Icons.account_balance_wallet),
                                _buildQuickStatRow('Total Sales', closing.todaysSalesTotal, Icons.shopping_cart),
                                _buildQuickStatRow('Sales Profit', closing.todaysSalesProfit, Icons.trending_up),
                                _buildQuickStatRow('Cashout Charge', closing.cashoutCharge, Icons.attach_money),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Profit Entries
                        if (closing.profitEntries.isNotEmpty)
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Profit Entries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 16),
                                  ...closing.profitEntries.map((entry) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(entry.source, style: const TextStyle(fontWeight: FontWeight.w500)),
                                              if (entry.note != null) Text(entry.note!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        Text('৳${entry.amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Approval Info
                        if (closing.isApproved)
                          Card(
                            elevation: 2,
                            color: Colors.green.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.verified, color: Colors.green.shade600, size: 20),
                                      const SizedBox(width: 8),
                                      const Text('Approved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text('By: ${closing.approvedByName ?? closing.approvedBy ?? 'Unknown'}', style: const TextStyle(fontSize: 14)),
                                  Text('At: ${DateFormat('MMM d, yyyy HH:mm').format(closing.approvedAt ?? DateTime.now())}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                  if (closing.remarks != null) ...[
                                    const SizedBox(height: 8),
                                    Text('Remarks: ${closing.remarks}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatRow(String label, double amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade400),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text('৳${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
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
                      Text(
                        'Approved by: ${closing.approvedByName ?? closing.approvedBy ?? 'Unknown'}',
                      ),
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

// Web Header Stat Widget for DailyClosingScreen
class _WebHeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _WebHeaderStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

// Web Header Stat Widget for ClosingDetailScreen
class _WebHeaderStatDetail extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WebHeaderStatDetail({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
