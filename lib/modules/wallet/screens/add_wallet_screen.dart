import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet.dart';
import '../models/wallet_type.dart';
import '../providers/wallet_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddWalletScreen extends StatefulWidget {
  const AddWalletScreen({super.key});

  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  late WalletType _selectedType;
  final _customNameController = TextEditingController();
  final _permanentBalanceController = TextEditingController();
  final _temporaryBalanceController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = WalletType.bkashAgent;
    _permanentBalanceController.text = '0';
    _temporaryBalanceController.text = '0';
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _permanentBalanceController.dispose();
    _temporaryBalanceController.dispose();
    super.dispose();
  }

  Future<void> _createWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final walletId = FirebaseFirestore.instance
          .collection('wallets')
          .doc()
          .id;

      final permanentBalance = double.parse(_permanentBalanceController.text);
      final temporaryBalance = double.parse(_temporaryBalanceController.text);

      final wallet = Wallet(
        id: walletId,
        userId: currentUser.id,
        type: _selectedType,
        customName:
            _selectedType == WalletType.custom &&
                _customNameController.text.trim().isNotEmpty
            ? _customNameController.text.trim()
            : null,
        permanentBalance: permanentBalance,
        temporaryBalance: temporaryBalance,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await context.read<WalletProvider>().createWallet(wallet);

      // Log action
      await authProvider.logAction(
        action: 'CREATE_WALLET',
        module: 'Wallet',
        details:
            'Created ${wallet.displayName} wallet with ৳$permanentBalance permanent + ৳$temporaryBalance temporary',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet created successfully')),
        );
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create Wallet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Wallet Type',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WalletType>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              items: WalletType.values.map((type) {
                return DropdownMenuItem(value: type, child: Text(type.label));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Custom name field (only for custom wallets)
            if (_selectedType == WalletType.custom) ...[
              TextFormField(
                controller: _customNameController,
                decoration: const InputDecoration(
                  labelText: 'Custom Wallet Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter wallet name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
            ],

            // Permanent Balance
            Text(
              'Initial Permanent Balance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _permanentBalanceController,
              decoration: const InputDecoration(
                labelText: 'Amount (৳)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
                hintText: '0',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Temporary Balance
            Text(
              'Initial Temporary Balance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _temporaryBalanceController,
              decoration: const InputDecoration(
                labelText: 'Amount (৳)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
                hintText: '0',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            FilledButton(
              onPressed: _isSubmitting ? null : _createWallet,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Wallet', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
