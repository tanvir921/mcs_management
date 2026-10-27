import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/environment.dart';
import '../models/sale.dart';
import '../providers/sales_provider.dart';
import 'sale_invoice_screen.dart';

class SaleDetailScreen extends StatefulWidget {
  final String saleId;
  final Sale? initialSale;

  const SaleDetailScreen({
    super.key,
    required this.saleId,
    this.initialSale,
  });

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Sale? _sale;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialSale != null) {
      _sale = widget.initialSale;
      _isLoading = false;
    } else {
      _loadSale();
    }
  }

  Future<void> _loadSale() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sale = await context.read<SalesProvider>().getSaleById(widget.saleId);
      if (mounted) {
        setState(() {
          _sale = sale;
          _isLoading = false;
          if (sale == null) _error = 'Sale record not found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
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

    if (_error != null || _sale == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sale Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Sale not found',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadSale,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SaleInvoiceScreen(
      sale: _sale!,
      shopName: Environment.shopName,
      shopAddress: Environment.shopAddress,
      shopPhone: Environment.shopPhone,
      shopEmail: Environment.shopEmail,
    );
  }
}

