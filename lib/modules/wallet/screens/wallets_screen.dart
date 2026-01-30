import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_type.dart';
import '../models/wallet.dart';
import '../providers/wallet_provider.dart';
import '../../auth/providers/auth_provider.dart';
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
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        context.read<WalletProvider>().loadUserWallets(currentUser.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final authProvider = context.read<AuthProvider>();
              final currentUser = authProvider.currentUser;
              if (currentUser != null) {
                context.read<WalletProvider>().loadUserWallets(currentUser.id);
              }
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          if (walletProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (walletProvider.wallets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text('No wallets created yet'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddWalletScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Wallet'),
                  ),
                ],
              ),
            );
          }

          // Group wallets by type
          final walletsByType = <WalletType, List<Wallet>>{};
          for (final wallet in walletProvider.wallets) {
            walletsByType.putIfAbsent(wallet.type, () => []).add(wallet);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: walletsByType.length + 1,
            itemBuilder: (context, index) {
              if (index == walletsByType.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddWalletScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Wallet'),
                  ),
                );
              }

              final walletType = walletsByType.keys.toList()[index];
              final walletsOfType = walletsByType[walletType]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      walletType.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...walletsOfType.map((wallet) => _WalletCard(wallet: wallet)),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final Wallet wallet;

  const _WalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.account_balance_wallet, color: Colors.green),
        title: Text(
          wallet.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '৳${wallet.permanentBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '৳${wallet.temporaryBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          '৳${wallet.totalBalance.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue,
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WalletDetailScreen(wallet: wallet)),
        ),
      ),
    );
  }
}
