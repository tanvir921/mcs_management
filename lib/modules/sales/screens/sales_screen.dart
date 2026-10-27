import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../app/app_routes.dart';
import '../../../core/config/environment.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/sale.dart';
import '../providers/cart_provider.dart';
import '../providers/sales_provider.dart';
import 'add_sale_screen.dart';
import 'sale_invoice_screen.dart';
import 'sales_history_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      await context.read<SalesProvider>().loadSales(auth.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLarge = Responsive.isLargeScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Sales (বিক্রি ও ইনভয়েস)'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade600, Colors.purple.shade800],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadStats,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isLarge ? 24 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Cart Banner
              Consumer<CartProvider>(
                builder: (context, cart, _) {
                  if (cart.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildCartBanner(context, cart),
                  );
                },
              ),

              // Live Sales Summary Strip (visible on both Mobile and Web)
              Consumer<SalesProvider>(
                builder: (context, salesProvider, _) {
                  final stats = salesProvider.stats ?? {};
                  final totalSales =
                      (stats['totalSales'] as num?)?.toDouble() ?? 0;
                  final totalProfit =
                      (stats['totalProfit'] as num?)?.toDouble() ?? 0;
                  final totalTx =
                      (stats['totalTransactions'] as num?)?.toInt() ?? 0;
                  final margin =
                      (stats['profitMargin'] as num?)?.toDouble() ?? 0;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              title: 'মোট বিক্রি (Sales)',
                              value: '৳${totalSales.toStringAsFixed(0)}',
                              icon: Icons.point_of_sale_rounded,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              title: 'নগদ লাভ (Profit)',
                              value: '৳${totalProfit.toStringAsFixed(0)}',
                              icon: Icons.trending_up_rounded,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              title: 'মোট লেনদেন',
                              value: '$totalTx টি',
                              icon: Icons.receipt_long_rounded,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              title: 'লাভের হার (Margin)',
                              value: '${margin.toStringAsFixed(1)}%',
                              icon: Icons.percent_rounded,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Quick Actions Grid (2x2 on mobile, 4-col on desktop)
              GridView.count(
                crossAxisCount: isLarge ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _ActionTile(
                    icon: Icons.add_shopping_cart_rounded,
                    title: 'New Sale',
                    subtitle: 'নতুন বিক্রি ও মেমো',
                    color: Colors.purple.shade700,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddSaleScreen()),
                    ).then((_) => _loadStats()),
                  ),
                  _ActionTile(
                    icon: Icons.history_rounded,
                    title: 'Sales History',
                    subtitle: 'সকল বিক্রির তালিকা',
                    color: Colors.orange.shade800,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalesHistoryScreen(),
                      ),
                    ).then((_) => _loadStats()),
                  ),
                  _ActionTile(
                    icon: Icons.edit_note_rounded,
                    title: 'খসড়া (Khosra)',
                    subtitle: '১-ট্যাপ দ্রুত এন্ট্রি',
                    color: Colors.teal.shade700,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.khosra,
                    ).then((_) => _loadStats()),
                  ),
                  _ActionTile(
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventory',
                    subtitle: 'পণ্য ও সার্ভিস স্টক',
                    color: Colors.indigo.shade700,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.inventory),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Recent Sales Section
              Consumer<SalesProvider>(
                builder: (context, salesProvider, _) {
                  if (salesProvider.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final recentSales = salesProvider.sales.take(6).toList();
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'সাম্প্রতিক বিক্রি (Recent Sales)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SalesHistoryScreen(),
                                ),
                              ),
                              child: const Text('সব দেখুন →'),
                            ),
                          ],
                        ),
                        if (recentSales.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'এখনও কোনো বিক্রি রেকর্ড নেই',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),
                          )
                        else
                          ...recentSales.map(
                            (sale) => _RecentSaleRow(sale: sale),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSaleScreen()),
        ).then((_) => _loadStats()),
        backgroundColor: Colors.purple.shade700,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('New Sale'),
      ),
    );
  }

  Widget _buildCartBanner(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade800],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_cart_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shopping Cart Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${cart.itemCount} items • ৳${cart.totalSelling.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddSaleScreen()),
            ).then((_) => _loadStats()),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade800,
            ),
            child: const Text('Checkout'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSaleRow extends StatelessWidget {
  final Sale sale;
  const _RecentSaleRow({required this.sale});

  @override
  Widget build(BuildContext context) {
    final bDate = AppTime.toBusiness(sale.saleDate);
    final dateStr = DateFormat('d MMM, hh:mm a').format(bDate);
    final netAmount = sale.totalSelling - sale.discountAmount;

    return InkWell(
      onTap: () {
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
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt_rounded,
                size: 18,
                color: Colors.purple.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.customerName ?? 'Walk-in Customer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    '${sale.saleNumber} • $dateStr',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '৳${netAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (sale.dueAmount > 0)
                  Text(
                    'বাকি: ৳${sale.dueAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
