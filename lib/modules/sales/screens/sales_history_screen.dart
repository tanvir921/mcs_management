import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../providers/sales_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/config/environment.dart';
import 'qr_scanner_screen.dart';
import 'sale_invoice_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterPeriod = 'all';
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      await context.read<SalesProvider>().loadSales(
        auth.currentUser!.id,
        startDate: _startDate,
        endDate: _endDate,
      );
    }
  }

  void _applyFilter(String period) {
    setState(() {
      _filterPeriod = period;
      final now = DateTime.now();

      switch (period) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = now;
          break;
        default:
          _startDate = null;
          _endDate = null;
      }
    });
    _loadData();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (range != null) {
      setState(() {
        _filterPeriod = 'custom';
        _startDate = range.start;
        _endDate = range.end;
      });
      _loadData();
    }
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(
          title: 'Scan Invoice QR',
          subtitle: 'Point camera at invoice QR code',
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      // QR code contains saleNumber directly (e.g., SAL-00001-26)
      final searchTerm = result.trim();

      setState(() {
        _isSearching = true;
        _searchController.text = searchTerm;
        _searchQuery = searchTerm;
      });

      // Try to find and show the specific sale by saleNumber
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final matchingSale = salesProvider.sales.firstWhere(
        (s) => s.saleNumber.toLowerCase() == searchTerm.toLowerCase(),
        orElse: () => Sale(
          id: '',
          saleNumber: '',
          saleDate: DateTime.now(),
          items: [],
          totalCost: 0,
          totalSelling: 0,
          totalProfit: 0,
          discountAmount: 0,
          paidAmount: 0,
          dueAmount: 0,
          realizedProfit: 0,
          potentialProfit: 0,
          paymentMethod: '',
          createdBy: '',
          createdByName: '',
          createdAt: DateTime.now(),
          isActive: false,
        ),
      );

      if (matchingSale.id.isNotEmpty &&
          matchingSale.saleNumber.toLowerCase() == searchTerm.toLowerCase()) {
        _showSaleInvoice(matchingSale);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice "$searchTerm" not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSaleInvoice(Sale sale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SaleInvoiceScreen(
          sale: sale,
          shopName: Environment.shopName,
          shopAddress: Environment.shopAddress,
          shopPhone: Environment.shopPhone,
          shopEmail: Environment.shopEmail,
        ),
      ),
    );
  }

  List<Sale> _filterSales(List<Sale> sales) {
    if (_searchQuery.isEmpty) return sales;
    return sales.where((sale) {
      return sale.saleNumber.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          sale.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (sale.customerName?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by Invoice ID...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : const Text('Sales History'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade600, Colors.orange.shade800],
            ),
          ),
        ),
        actions: [
          // Search Toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
            tooltip: _isSearching ? 'Close Search' : 'Search Invoice',
          ),
          // QR Scanner
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQrCode,
            tooltip: 'Scan Invoice QR',
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
            tooltip: 'Custom Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
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
        child: Column(
          children: [
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterPeriod == 'all',
                    onSelected: (_) => _applyFilter('all'),
                    selectedColor: Colors.orange.shade100,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Today'),
                    selected: _filterPeriod == 'today',
                    onSelected: (_) => _applyFilter('today'),
                    selectedColor: Colors.orange.shade100,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('This Week'),
                    selected: _filterPeriod == 'week',
                    onSelected: (_) => _applyFilter('week'),
                    selectedColor: Colors.orange.shade100,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('This Month'),
                    selected: _filterPeriod == 'month',
                    onSelected: (_) => _applyFilter('month'),
                    selectedColor: Colors.orange.shade100,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('This Year'),
                    selected: _filterPeriod == 'year',
                    onSelected: (_) => _applyFilter('year'),
                    selectedColor: Colors.orange.shade100,
                  ),
                  const SizedBox(width: 8),
                  if (_filterPeriod == 'custom')
                    FilterChip(
                      label: Text(
                        '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}',
                      ),
                      selected: true,
                      onSelected: (_) {},
                      selectedColor: Colors.orange.shade100,
                    ),
                ],
              ),
            ),

            // Sales List
            Expanded(
              child: Consumer<SalesProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${provider.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadData,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Apply search filter
                  final filteredSales = _filterSales(provider.sales);

                  if (filteredSales.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.receipt_long,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No sales matching "$_searchQuery"'
                                : 'No sales found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _isSearching = false;
                                });
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear Search'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      itemCount: filteredSales.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final sale = filteredSales[index];
                        return _SaleCard(
                          sale: sale,
                          onTap: () => _showSaleInvoice(sale),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleCard extends StatefulWidget {
  final Sale sale;
  final VoidCallback onTap;

  const _SaleCard({required this.sale, required this.onTap});

  @override
  State<_SaleCard> createState() => _SaleCardState();
}

class _SaleCardState extends State<_SaleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (hovered) {
        setState(() => _isHovered = hovered);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          elevation: _isHovered ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.sale.saleNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 13,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'MMM d, y - hh:mm a',
                                ).format(widget.sale.saleDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getPaymentColor(
                          widget.sale.paymentMethod,
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getPaymentColor(
                            widget.sale.paymentMethod,
                          ).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _getPaymentLabel(widget.sale.paymentMethod),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getPaymentColor(widget.sale.paymentMethod),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Customer & Items Info
                Row(
                  children: [
                    if (widget.sale.customerName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.sale.customerName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Walk-in Customer',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_bag,
                            size: 13,
                            color: Colors.purple.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.sale.items.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Totals Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '৳${widget.sale.totalSelling.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Profit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '৳${widget.sale.totalProfit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: widget.sale.totalProfit >= 0
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPaymentColor(String method) {
    switch (method) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'mobile_banking':
        return Colors.purple;
      case 'credit':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'mobile_banking':
        return 'Mobile';
      case 'credit':
        return 'Credit';
      default:
        return method;
    }
  }
}
