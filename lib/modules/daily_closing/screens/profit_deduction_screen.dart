import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/daily_closing_service.dart';

class ProfitDeductionScreen extends StatefulWidget {
  const ProfitDeductionScreen({Key? key}) : super(key: key);

  @override
  State<ProfitDeductionScreen> createState() => _ProfitDeductionScreenState();
}

class _ProfitDeductionScreenState extends State<ProfitDeductionScreen> {
  late DateTime _selectedMonth;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _withdrawController = TextEditingController();
  final _withdrawNoteController = TextEditingController();
  final _dailyClosingService = DailyClosingService();

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _withdrawController.dispose();
    _withdrawNoteController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getProfitDeductionData() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      return {
        'total': 0.0,
        'totalAdded': 0.0,
        'totalExpenses': 0.0,
        'records': [],
        'walletBalance': 0.0,
      };
    }

    try {
      // Get profitDeduction wallet
      final walletsSnapshot = await FirebaseFirestore.instance
          .collection('wallets')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'profitDeduction')
          .get();

      if (walletsSnapshot.docs.isEmpty) {
        return {
          'total': 0.0,
          'totalAdded': 0.0,
          'totalExpenses': 0.0,
          'records': [],
          'walletBalance': 0.0,
        };
      }

      final walletId = walletsSnapshot.docs.first.id;
      final walletData = walletsSnapshot.docs.first.data();
      final walletBalance =
          (walletData['permanentBalance'] as num?)?.toDouble() ?? 0.0;

      // Get balance history records for this month
      final startOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
      final endOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      );

      final historySnapshot = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(walletId)
          .collection('balance_history')
          .where(
            'changedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where(
            'changedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
          )
          .orderBy('changedAt', descending: true)
          .get();

      double total = 0.0;
      double totalAdded = 0.0;
      double totalExpenses = 0.0;
      List<Map<String, dynamic>> records = [];

      for (var doc in historySnapshot.docs) {
        final data = doc.data();
        final amount = (data['change'] ?? 0).toDouble();
        total += amount;
        
        // Track positive (deductions) and negative (withdrawals) separately
        if (amount > 0) {
          totalAdded += amount;
        } else {
          totalExpenses += amount.abs();
        }
        
        records.add({
          'id': doc.id,
          'date': (data['changedAt'] as Timestamp).toDate(),
          'amount': amount,
          'note': data['note'] ?? 'No note',
          'changedByName': data['changedByName'] ?? 'System',
        });
      }

      return {
        'total': total,
        'totalAdded': totalAdded,
        'totalExpenses': totalExpenses,
        'records': records,
        'walletId': walletId,
        'walletBalance': walletBalance,
      };
    } catch (e) {
      debugPrint('Error fetching profit deduction data: $e');
      return {
        'total': 0.0,
        'totalAdded': 0.0,
        'totalExpenses': 0.0,
        'records': [],
        'walletBalance': 0.0,
      };
    }
  }

  Future<void> _addManualDeduction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      final userName = authProvider.currentUser?.name ?? 'Unknown';

      if (userId == null) return;

      // Get or create profitDeduction wallet
      final walletsSnapshot = await FirebaseFirestore.instance
          .collection('wallets')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'profitDeduction')
          .get();

      late String walletId;
      if (walletsSnapshot.docs.isEmpty) {
        final newWallet = await FirebaseFirestore.instance
            .collection('wallets')
            .add({
              'userId': userId,
              'type': 'profitDeduction',
              'permanentBalance': amount,
              'temporaryBalance': 0,
              'createdAt': Timestamp.now(),
            });
        walletId = newWallet.id;
      } else {
        walletId = walletsSnapshot.docs.first.id;
        // Update wallet balance
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(walletId)
            .update({'permanentBalance': FieldValue.increment(amount)});
      }

      // Add balance history record
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(walletId)
          .collection('balance_history')
          .add({
            'balanceType': 'permanent',
            'change': amount,
            'changedAt': Timestamp.now(),
            'note': _noteController.text.isEmpty
                ? 'Manual deduction'
                : _noteController.text,
            'changedBy': userId,
            'changedByName': userName,
            'previousBalance': 0,
            'newBalance': amount,
            'walletId': walletId,
          });

      _amountController.clear();
      _noteController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deduction recorded successfully')),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _withdrawForPersonalUse(double totalAvailable) async {
    if (_withdrawController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(_withdrawController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount > totalAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. Available: Tk. ${totalAvailable.toStringAsFixed(2)}',
          ),
        ),
      );
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final userName = authProvider.currentUser?.name ?? 'Unknown';

      // Use the service to withdraw from profit deduction
      await _dailyClosingService.withdrawFromProfitDeduction(
        userId: authProvider.currentUser?.id ?? '',
        amount: amount,
        notes: _withdrawNoteController.text.isEmpty
            ? 'Personal withdrawal'
            : _withdrawNoteController.text,
        withdrawnByName: userName,
      );

      _withdrawController.clear();
      _withdrawNoteController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount withdrawn for personal use successfully'),
        ),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddDeductionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Profit Deduction',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Tk. ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _addManualDeduction();
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawDialog(double totalAvailable) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Withdraw for Personal Use',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Available: Tk. ${totalAvailable.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _withdrawController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Withdrawal Amount',
                  prefixText: 'Tk. ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _withdrawNoteController,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _withdrawForPersonalUse(totalAvailable);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Withdraw'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Deduction Tracking'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade700, Colors.amber.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.amber.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                        1,
                      );
                    });
                  },
                ),
                GestureDetector(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedMonth,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedMonth = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          1,
                        );
                      });
                    }
                  },
                  child: Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _selectedMonth.month < DateTime.now().month
                      ? () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                            );
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
          // Records and total
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getProfitDeductionData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final data = snapshot.data ?? {
                  'total': 0.0,
                  'totalAdded': 0.0,
                  'totalExpenses': 0.0,
                  'records': [],
                  'walletBalance': 0.0,
                };
                final records = (data['records'] as List<Map<String, dynamic>>);
                final total = (data['total'] as num).toDouble();
                final totalAdded = (data['totalAdded'] as num).toDouble();
                final totalExpenses = (data['totalExpenses'] as num).toDouble();

                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_down,
                          size: 64,
                          color: Colors.amber.shade200,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No deductions recorded',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  children: [
                    // Total card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade100,
                            Colors.orange.shade100,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Total Amount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.amber.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                'Tk. ${totalAdded.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          // Expenses Amount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Expenses Amount',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                'Tk. ${totalExpenses.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          // Remaining Amount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Remaining Amount',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Tk. ${total.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Records list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Deduction Records',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...records.asMap().entries.map((entry) {
                      final record = entry.value;
                      final date = record['date'] as DateTime;
                      final amount = record['amount'] as double;
                      final note = record['note'] as String;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.trending_down,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            title: Text(
                              'Tk. ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  note,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<Map<String, dynamic>>(
        future: _getProfitDeductionData(),
        builder: (context, snapshot) {
          final walletBalance = snapshot.hasData
              ? (snapshot.data!['walletBalance'] as num?)?.toDouble() ?? 0.0
              : 0.0;

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                onPressed: _showAddDeductionDialog,
                label: const Text('Add Deduction'),
                icon: const Icon(Icons.add),
                backgroundColor: Colors.amber.shade600,
                heroTag: 'add_deduction',
              ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                onPressed: walletBalance > 0
                    ? () => _showWithdrawDialog(walletBalance)
                    : null,
                label: const Text('Withdraw'),
                icon: const Icon(Icons.remove_circle_outline),
                backgroundColor:
                    walletBalance > 0 ? Colors.orange.shade600 : Colors.grey,
                heroTag: 'withdraw',
              ),
            ],
          );
        },
      ),
    );
  }
}
