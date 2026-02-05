import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/sales_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../app/app_routes.dart';
import '../../../core/utils/responsive.dart';
import 'add_sale_screen.dart';
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

  void _loadStats() {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      context.read<SalesProvider>().loadSales(auth.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

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
          _buildWebHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cart Banner (if items exist)
                  Consumer<CartProvider>(
                    builder: (context, cart, _) {
                      if (cart.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildWebCartBanner(context, cart),
                      );
                    },
                  ),

                  // Stats Row
                  Consumer<SalesProvider>(
                    builder: (context, salesProvider, _) {
                      final stats =
                          salesProvider.stats ??
                          {
                            'totalSales': 0.0,
                            'totalProfit': 0.0,
                            'totalTransactions': 0,
                            'profitMargin': 0.0,
                          };

                      return Row(
                        children: [
                          Expanded(
                            child: _WebStatCard(
                              title: 'Total Sales',
                              value:
                                  '৳${(stats['totalSales'] ?? 0).toStringAsFixed(2)}',
                              icon: Icons.point_of_sale_rounded,
                              color: const Color(0xFF9C27B0),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _WebStatCard(
                              title: 'Total Profit',
                              value:
                                  '৳${(stats['totalProfit'] ?? 0).toStringAsFixed(2)}',
                              icon: Icons.trending_up_rounded,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _WebStatCard(
                              title: 'Transactions',
                              value: '${stats['totalTransactions'] ?? 0}',
                              icon: Icons.receipt_long_rounded,
                              color: const Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _WebStatCard(
                              title: 'Profit Margin',
                              value:
                                  '${(stats['profitMargin'] ?? 0).toStringAsFixed(1)}%',
                              icon: Icons.percent_rounded,
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Main Content
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions
                      Expanded(flex: 2, child: _buildWebQuickActions(context)),
                      const SizedBox(width: 32),

                      // Side Panel
                      SizedBox(
                        width: 380,
                        child: Column(
                          children: [
                            _buildWebRecentActivity(),
                            const SizedBox(height: 24),
                            _buildWebTipsCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebHeader(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.purple.shade800],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Management',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                'Create and manage sales transactions',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const Spacer(),
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              return _WebActionButton(
                icon: Icons.shopping_cart_rounded,
                label: cart.isEmpty ? 'Cart Empty' : 'Cart (${cart.itemCount})',
                color: cart.isEmpty ? Colors.grey : const Color(0xFF4CAF50),
                onPressed: cart.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddSaleScreen(),
                        ),
                      ),
              );
            },
          ),
          const SizedBox(width: 12),
          _WebActionButton(
            icon: Icons.add_rounded,
            label: 'New Sale',
            color: const Color(0xFF9C27B0),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddSaleScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _WebActionButton(
            icon: Icons.history_rounded,
            label: 'History',
            color: const Color(0xFFFF9800),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebCartBanner(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_cart_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shopping Cart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cart.itemCount} items in cart • Total: ৳${cart.totalSelling.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddSaleScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.shopping_bag_rounded),
            label: const Text(
              'Proceed to Checkout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color: Colors.purple.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _WebQuickActionCard(
                  icon: Icons.add_shopping_cart_rounded,
                  title: 'New Sale',
                  subtitle: 'Create a new sale transaction',
                  color: const Color(0xFF9C27B0),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddSaleScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _WebQuickActionCard(
                  icon: Icons.history_rounded,
                  title: 'Sales History',
                  subtitle: 'View all transactions',
                  color: const Color(0xFFFF9800),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SalesHistoryScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _WebQuickActionCard(
                  icon: Icons.inventory_2_rounded,
                  title: 'Inventory',
                  subtitle: 'Manage products & services',
                  color: const Color(0xFF009688),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.inventory),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _WebQuickActionCard(
                  icon: Icons.people_rounded,
                  title: 'Customers',
                  subtitle: 'Manage customer records',
                  color: const Color(0xFF2196F3),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.customers),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _WebQuickActionCard(
                  icon: Icons.analytics_rounded,
                  title: 'Reports',
                  subtitle: 'View sales analytics',
                  color: const Color(0xFF673AB7),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _WebQuickActionCard(
                  icon: Icons.refresh_rounded,
                  title: 'Refresh',
                  subtitle: 'Reload sales data',
                  color: const Color(0xFF607D8B),
                  onTap: _loadStats,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sales Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Consumer<SalesProvider>(
            builder: (context, salesProvider, _) {
              final stats = salesProvider.stats ?? {};
              return Column(
                children: [
                  _SummaryRow(
                    label: 'Total Revenue',
                    value: '৳${(stats['totalSales'] ?? 0).toStringAsFixed(2)}',
                    color: const Color(0xFF9C27B0),
                  ),
                  _SummaryRow(
                    label: 'Total Cost',
                    value: '৳${(stats['totalCost'] ?? 0).toStringAsFixed(2)}',
                    color: const Color(0xFFF44336),
                  ),
                  _SummaryRow(
                    label: 'Net Profit',
                    value: '৳${(stats['totalProfit'] ?? 0).toStringAsFixed(2)}',
                    color: const Color(0xFF4CAF50),
                  ),
                  _SummaryRow(
                    label: 'Average Sale',
                    value: '৳${(stats['averageSale'] ?? 0).toStringAsFixed(2)}',
                    color: const Color(0xFF2196F3),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWebTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Sales Tips',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use barcode scanner for faster product entry and reduce errors during checkout.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Mobile Layout
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cart Summary Card
                Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    if (cart.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_cart,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Shopping Cart',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${cart.itemCount} items • ৳${cart.totalSelling.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddSaleScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.shopping_bag),
                                label: const Text(
                                  'Proceed to Checkout',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    if (cart.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return const SizedBox(height: 16);
                  },
                ),

                // New Sale Card
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isLargeScreen = Responsive.isLargeScreen(context);

                    final actionCards = [
                      _SaleActionCard(
                        icon: Icons.add_shopping_cart,
                        title: 'New Sale',
                        subtitle: 'Create a new sale transaction',
                        gradient: [
                          Colors.purple.shade400,
                          Colors.purple.shade600,
                        ],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddSaleScreen(),
                            ),
                          );
                        },
                      ),
                      _SaleActionCard(
                        icon: Icons.history,
                        title: 'Sales History',
                        subtitle: 'View all sales transactions',
                        gradient: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SalesHistoryScreen(),
                            ),
                          );
                        },
                      ),
                      _SaleActionCard(
                        icon: Icons.inventory_2,
                        title: 'Inventory',
                        subtitle: 'Manage products and services',
                        gradient: [Colors.teal.shade400, Colors.teal.shade600],
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.inventory),
                      ),
                    ];

                    if (isLargeScreen) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: actionCards
                            .map(
                              (card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: card,
                                ),
                              ),
                            )
                            .toList(),
                      );
                    }

                    return Column(
                      children: actionCards
                          .map(
                            (card) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: card,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaleActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _SaleActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_SaleActionCard> createState() => _SaleActionCardState();
}

class _SaleActionCardState extends State<_SaleActionCard> {
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
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: _isHovered ? 6 : 2,
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
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.gradient,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.gradient[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.gradient,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============= WEB WIDGETS =============

class _WebStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _WebStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _WebActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? Colors.grey.shade300 : color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebQuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _WebQuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_WebQuickActionCard> createState() => _WebQuickActionCardState();
}

class _WebQuickActionCardState extends State<_WebQuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withOpacity(0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withOpacity(0.3)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.color, widget.color.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
