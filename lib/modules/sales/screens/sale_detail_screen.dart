import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../providers/sales_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SaleDetailScreen extends StatefulWidget {
  final String saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Sale? _sale;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  Future<void> _loadSale() async {
    setState(() => _isLoading = true);
    try {
      final sale = await context.read<SalesProvider>().getSaleById(widget.saleId);
      setState(() {
        _sale = sale;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSale() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Text(
          'Are you sure you want to delete sale ${_sale?.saleNumber}?',
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

    if (confirm != true || _sale == null) return;

    try {
      await context.read<SalesProvider>().deleteSale(_sale!.id);

      // Log action
      final authProvider = context.read<AuthProvider>();
      await authProvider.logAction(
        action: 'DELETE_SALE',
        module: 'Sales',
        details: 'Deleted sale: ${_sale!.saleNumber}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_sale!.saleNumber} deleted'),
            backgroundColor: Colors.orange,
          ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sale Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_sale == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sale Details')),
        body: const Center(
          child: Text('Sale not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_sale!.saleNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSale,
            tooltip: 'Delete Sale',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sale Information Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sale Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.receipt,
                    label: 'Sale Number',
                    value: _sale!.saleNumber,
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Sale Date',
                    value: DateFormat('MMM d, y - hh:mm a').format(_sale!.saleDate),
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.payment,
                    label: 'Payment Method',
                    value: _getPaymentLabel(_sale!.paymentMethod),
                  ),
                  if (_sale!.customerName != null) ...[
                    const Divider(),
                    _InfoRow(
                      icon: Icons.person,
                      label: 'Customer',
                      value: _sale!.customerName!,
                    ),
                  ],
                  if (_sale!.notes != null && _sale!.notes!.isNotEmpty) ...[
                    const Divider(),
                    _InfoRow(
                      icon: Icons.note,
                      label: 'Notes',
                      value: _sale!.notes!,
                    ),
                  ],
                  const Divider(),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Created By',
                    value: _sale!.createdByName,
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Created At',
                    value: DateFormat('MMM d, y - hh:mm a').format(_sale!.createdAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items Card
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Items (${_sale!.items.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sale!.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _sale!.items[index];
                    return ListTile(
                      title: Text(
                        item.itemName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity: ${item.quantity} ${item.unit}',
                          ),
                          Text(
                            'Cost: ৳${item.costPrice.toStringAsFixed(2)} × ${item.quantity} = ৳${item.totalCost.toStringAsFixed(2)}',
                          ),
                          Text(
                            'Selling: ৳${item.sellingPrice.toStringAsFixed(2)} × ${item.quantity} = ৳${item.totalSelling.toStringAsFixed(2)}',
                          ),
                          Text(
                            'Profit: ৳${item.profit.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: item.profit >= 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Text(
                              'Note: ${item.notes}',
                              style: const TextStyle(fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary Card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SummaryRow(
                    label: 'Total Cost',
                    value: '৳${_sale!.totalCost.toStringAsFixed(2)}',
                  ),
                  const Divider(),
                  _SummaryRow(
                    label: 'Total Selling',
                    value: '৳${_sale!.totalSelling.toStringAsFixed(2)}',
                  ),
                  const Divider(),
                  _SummaryRow(
                    label: 'Total Profit',
                    value: '৳${_sale!.totalProfit.toStringAsFixed(2)}',
                    valueColor: _sale!.totalProfit >= 0 ? Colors.green : Colors.red,
                    isLarge: true,
                  ),
                  const Divider(),
                  _SummaryRow(
                    label: 'Profit Margin',
                    value: '${_sale!.profitMargin.toStringAsFixed(2)}%',
                    valueColor: _sale!.totalProfit >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'mobile_banking':
        return 'Mobile Banking';
      case 'credit':
        return 'Credit';
      default:
        return method;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLarge;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 18 : 16,
            fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
