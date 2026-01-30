import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../providers/wallet_provider.dart';
import '../../auth/providers/auth_provider.dart';

class WalletDetailScreen extends StatefulWidget {
  final Wallet wallet;

  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  late Future<List<BalanceHistory>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = context.read<WalletProvider>().getBalanceHistory(
      widget.wallet.id,
    );
  }

  void _showEditBalanceDialog(String balanceType) {
    showDialog(
      context: context,
      builder: (context) => _EditBalanceDialog(
        wallet: widget.wallet,
        balanceType: balanceType,
        onSuccess: () {
          setState(() {
            _historyFuture = context.read<WalletProvider>().getBalanceHistory(
              widget.wallet.id,
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wallet.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _historyFuture = context
                    .read<WalletProvider>()
                    .getBalanceHistory(widget.wallet.id);
              });
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wallet Balances Card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Permanent Balance
                  Column(
                    children: [
                      const Text(
                        'Permanent Balance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '৳${widget.wallet.permanentBalance.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        onPressed: () => _showEditBalanceDialog('permanent'),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  // Temporary Balance
                  Column(
                    children: [
                      const Text(
                        'Temporary Balance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '৳${widget.wallet.temporaryBalance.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        onPressed: () => _showEditBalanceDialog('temporary'),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  // Total Balance
                  Column(
                    children: [
                      const Text(
                        'Total Balance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '৳${widget.wallet.totalBalance.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Balance History Header
          Text(
            'Balance History',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Balance History List
          FutureBuilder<List<BalanceHistory>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final history = snapshot.data ?? [];

              if (history.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No balance changes yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final record = history[index];
                  final isIncrease = record.change >= 0;
                  final balanceTypeLabel = record.balanceType == 'permanent'
                      ? 'Permanent'
                      : 'Temporary';
                  final balanceColor = record.balanceType == 'permanent'
                      ? Colors.green
                      : Colors.orange;

                  return ListTile(
                    leading: Icon(
                      isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isIncrease ? Colors.green : Colors.red,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.note,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: balanceColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            balanceTypeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: balanceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${record.previousBalance.toStringAsFixed(2)} → ${record.newBalance.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'By: ${record.changedByName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          DateFormat(
                            'MMM d, y - hh:mm a',
                          ).format(record.changedAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${isIncrease ? '+' : ''}৳${record.change.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isIncrease ? Colors.green : Colors.red,
                      ),
                    ),
                    isThreeLine: true,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EditBalanceDialog extends StatefulWidget {
  final Wallet wallet;
  final String balanceType; // 'permanent' or 'temporary'
  final VoidCallback onSuccess;

  const _EditBalanceDialog({
    required this.wallet,
    required this.balanceType,
    required this.onSuccess,
  });

  @override
  State<_EditBalanceDialog> createState() => _EditBalanceDialogState();
}

class _EditBalanceDialogState extends State<_EditBalanceDialog> {
  late TextEditingController _balanceController;
  late TextEditingController _noteController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final currentBalance = widget.balanceType == 'permanent'
        ? widget.wallet.permanentBalance
        : widget.wallet.temporaryBalance;
    _balanceController = TextEditingController(
      text: currentBalance.toStringAsFixed(2),
    );
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitBalance() async {
    final newBalance = double.tryParse(_balanceController.text);
    if (newBalance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid balance')),
      );
      return;
    }

    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a note')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final currentBalance = widget.balanceType == 'permanent'
          ? widget.wallet.permanentBalance
          : widget.wallet.temporaryBalance;

      await context.read<WalletProvider>().updateBalance(
        walletId: widget.wallet.id,
        balanceType: widget.balanceType,
        newBalance: newBalance,
        note: _noteController.text.trim(),
        userId: currentUser.id,
        userName: currentUser.name,
      );

      // Log action
      final change = newBalance - currentBalance;
      final balanceTypeLabel = widget.balanceType == 'permanent'
          ? 'Permanent'
          : 'Temporary';
      await authProvider.logAction(
        action: 'EDIT_WALLET_BALANCE',
        module: 'Wallet',
        details:
            'Updated ${widget.wallet.displayName} $balanceTypeLabel balance by ${change >= 0 ? '+' : ''}৳$change',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balance updated successfully')),
        );
        Navigator.pop(context);
        widget.onSuccess();
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

  @override
  Widget build(BuildContext context) {
    final balanceTypeLabel = widget.balanceType == 'permanent'
        ? 'Permanent Balance'
        : 'Temporary Balance';

    return AlertDialog(
      title: Text('Edit $balanceTypeLabel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _balanceController,
            decoration: const InputDecoration(
              labelText: 'New Balance',
              border: OutlineInputBorder(),
              prefixText: '৳ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
              hintText: 'e.g., Manual correction, reconciliation, etc.',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitBalance,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
