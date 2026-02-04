import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_type.dart';
import '../models/wallet.dart';
import '../providers/wallet_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import 'add_wallet_screen.dart';
import 'wallet_detail_screen.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWallets();
    });
  }

  void _loadWallets() {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      context.read<WalletProvider>().loadUserWallets(currentUser.id);
    }
  }

  Future<void> _deleteWallet(Wallet wallet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: Text(
          'Are you sure you want to delete "${wallet.displayName}"?\n\n'
          'Current balance: ৳${wallet.totalBalance.toStringAsFixed(2)}\n\n'
          'This action cannot be undone.',
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

    if (confirmed == true) {
      try {
        await context.read<WalletProvider>().deleteWallet(wallet.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${wallet.displayName} deleted'),
              backgroundColor: Colors.green,
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade600, Colors.green.shade800],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWallets,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddWalletScreen()),
        ).then((_) => _loadWallets()),
        icon: const Icon(Icons.add),
        label: const Text('Add Wallet'),
        backgroundColor: Colors.green,
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          if (walletProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter out profit deduction wallets
          final wallets = walletProvider.wallets
              .where((w) => w.type != WalletType.profitDeduction)
              .toList();

          if (wallets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No wallets yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a wallet to track your balances',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Calculate total balance
          double totalPermanent = 0;
          double totalTemporary = 0;
          for (final wallet in wallets) {
            totalPermanent += wallet.permanentBalance;
            totalTemporary += wallet.temporaryBalance;
          }

          // Group wallets by type
          final walletsByType = <WalletType, List<Wallet>>{};
          for (final wallet in wallets) {
            walletsByType.putIfAbsent(wallet.type, () => []).add(wallet);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.green.shade600, Colors.green.shade800],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '৳${(totalPermanent + totalTemporary).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _BalanceSummary(
                            label: 'Permanent',
                            amount: totalPermanent,
                            color: Colors.white,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white30,
                          ),
                          _BalanceSummary(
                            label: 'Temporary',
                            amount: totalTemporary,
                            color: Colors.orange.shade200,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Wallets by Type
              ...walletsByType.entries.map((entry) {
                final walletType = entry.key;
                final walletsOfType = entry.value;
                final isLargeScreen = Responsive.isLargeScreen(context);
                final crossAxisCount = Responsive.value(context, mobile: 1, tablet: 2, desktop: 3);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _getWalletTypeIcon(walletType),
                            size: 20,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            walletType.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${walletsOfType.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLargeScreen)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.0,
                        ),
                        itemCount: walletsOfType.length,
                        itemBuilder: (context, index) => _WalletCard(
                          wallet: walletsOfType[index],
                          onDelete: () => _deleteWallet(walletsOfType[index]),
                        ),
                      )
                    else
                      ...walletsOfType.map(
                        (wallet) => _WalletCard(
                          wallet: wallet,
                          onDelete: () => _deleteWallet(wallet),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
              const SizedBox(height: 80), // Space for FAB
            ],
          );
        },
      ),
    );
  }

  IconData _getWalletTypeIcon(WalletType type) {
    switch (type) {
      case WalletType.bkashAgent:
      case WalletType.bkashMerchant:
      case WalletType.bkashB2B:
        return Icons.phone_android;
      case WalletType.nagadAgent:
      case WalletType.nagadB2B:
        return Icons.smartphone;
      case WalletType.rocketAgent:
        return Icons.rocket_launch;
      case WalletType.gp1:
      case WalletType.gp2:
        return Icons.sim_card;
      case WalletType.blRetailer:
        return Icons.store;
      case WalletType.profitDeduction:
        return Icons.trending_down;
      case WalletType.custom:
        return Icons.account_balance_wallet;
    }
  }
}

class _BalanceSummary extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _BalanceSummary({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  final Wallet wallet;
  final VoidCallback onDelete;

  const _WalletCard({required this.wallet, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(wallet.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onDelete();
        return false; // We handle deletion in onDelete
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WalletDetailScreen(wallet: wallet),
            ),
          ),
          onLongPress: onDelete,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Wallet Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Wallet Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _BalanceChip(
                            label: 'P',
                            amount: wallet.permanentBalance,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _BalanceChip(
                            label: 'T',
                            amount: wallet.temporaryBalance,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Total Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '৳${wallet.totalBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _BalanceChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '৳${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
