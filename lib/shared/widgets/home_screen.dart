import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_routes.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/responsive.dart';

String _getRoleDisplayName(UserRole role) {
  switch (role) {
    case UserRole.masterAdmin:
      return 'Master Admin';
    case UserRole.subAdmin:
      return 'Sub Admin';
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _todaySales = 0;
  double _pendingDues = 0;
  double _thisMonthSales = 0;
  int _totalCustomers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      // Get today's sales
      final todaySalesSnapshot = await firestore
          .collection('sales')
          .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();
      
      double todayTotal = 0;
      for (var doc in todaySalesSnapshot.docs) {
        todayTotal += (doc.data()['total'] ?? 0).toDouble();
      }

      // Get this month's sales
      final monthSalesSnapshot = await firestore
          .collection('sales')
          .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();
      
      double monthTotal = 0;
      for (var doc in monthSalesSnapshot.docs) {
        monthTotal += (doc.data()['total'] ?? 0).toDouble();
      }

      // Get pending dues (customers with positive dues)
      final customersSnapshot = await firestore.collection('customers').get();
      
      double totalDues = 0;
      int customerCount = customersSnapshot.docs.length;
      for (var doc in customersSnapshot.docs) {
        totalDues += (doc.data()['totalDue'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _todaySales = todayTotal;
          _thisMonthSales = monthTotal;
          _pendingDues = totalDues;
          _totalCustomers = customerCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '৳${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '৳${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '৳${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = Responsive.isLargeScreen(context);

    return Scaffold(
      appBar: isLargeScreen ? null : _buildAppBar(context),
      body: isLargeScreen ? _buildWebLayout(context) : _buildMobileLayout(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('MCS Management'),
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade600, Colors.blue.shade800],
          ),
        ),
      ),
      actions: [
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'user',
                  enabled: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 18),
                      const SizedBox(width: 8),
                      Text(authProvider.currentUser?.name ?? 'User'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'role',
                  enabled: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        authProvider.currentUser != null ? _getRoleDisplayName(authProvider.currentUser!.role) : '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  onTap: () async => await authProvider.signOut(),
                  child: const Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        if (user == null) return const SizedBox();

        final moduleCards = _buildModuleCards(context, user);

        return Row(
          children: [
            _buildSidebar(context, authProvider),
            Expanded(
              child: Container(
                color: Colors.grey.shade50,
                child: Column(
                  children: [
                    _buildWebTopBar(context, user),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatsRow(context),
                            const SizedBox(height: 32),
                            Text(
                              'Quick Access',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: Responsive.value(context, mobile: 2, tablet: 3, desktop: 4),
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                childAspectRatio: 1.3,
                              ),
                              itemCount: moduleCards.length,
                              itemBuilder: (context, index) {
                                final card = moduleCards[index];
                                return _WebModuleCard(
                                  title: card.title,
                                  icon: card.icon,
                                  color: card.color,
                                  onTap: card.onTap,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade600, Colors.blue.shade800],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'MCS Management',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavSection('MAIN', [
                  _NavItem(Icons.home, 'Dashboard', true, () {}),
                ]),
                if (user?.hasPermission(Permission.customers) ?? false)
                  _buildNavSection('MANAGEMENT', [
                    _NavItem(Icons.people, 'Customers', false, () => Navigator.pushNamed(context, AppRoutes.customers)),
                    if (user?.hasPermission(Permission.msfTransactions) ?? false)
                      _NavItem(Icons.account_balance_wallet, 'Wallets', false, () => Navigator.pushNamed(context, AppRoutes.wallets)),
                    if (user?.hasPermission(Permission.products) ?? false)
                      _NavItem(Icons.inventory_2, 'Inventory', false, () => Navigator.pushNamed(context, AppRoutes.inventory)),
                    if (user?.hasPermission(Permission.products) ?? false)
                      _NavItem(Icons.point_of_sale, 'Sales', false, () => Navigator.pushNamed(context, AppRoutes.sales)),
                  ]),
                if (user?.hasPermission(Permission.reports) ?? false)
                  _buildNavSection('REPORTS', [
                    _NavItem(Icons.summarize, 'Daily Closing', false, () => Navigator.pushNamed(context, AppRoutes.dailyClosing)),
                    _NavItem(Icons.receipt_long, 'Expenses', false, () => Navigator.pushNamed(context, AppRoutes.expenses)),
                    _NavItem(Icons.analytics, 'Reports', false, () => Navigator.pushNamed(context, AppRoutes.reports)),
                    _NavItem(Icons.trending_down, 'Profit Deduction', false, () => Navigator.pushNamed(context, AppRoutes.profitDeduction)),
                  ]),
                if (user?.hasPermission(Permission.userManagement) ?? false)
                  _buildNavSection('ADMIN', [
                    _NavItem(Icons.admin_panel_settings, 'User Management', false, () => Navigator.pushNamed(context, AppRoutes.users)),
                    if (user?.isMasterAdmin ?? false)
                      _NavItem(Icons.build, 'Admin Tools', false, () => Navigator.pushNamed(context, AppRoutes.adminTools)),
                  ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () async => await authProvider.signOut(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSection(String title, List<_NavItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildNavTile(item)),
        ],
      ),
    );
  }

  Widget _buildNavTile(_NavItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: item.isSelected ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: item.isSelected ? Colors.blue.shade700 : Colors.grey.shade600),
              const SizedBox(width: 12),
              Text(
                item.title,
                style: TextStyle(
                  color: item.isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                  fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebTopBar(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Icon(Icons.verified_user, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(_getRoleDisplayName(user.role), style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          title: 'Today\'s Sales',
          value: _isLoading ? '...' : _formatCurrency(_todaySales),
          icon: Icons.point_of_sale,
          color: Colors.green,
        )),
        const SizedBox(width: 20),
        Expanded(child: _StatCard(
          title: 'Pending Dues',
          value: _isLoading ? '...' : _formatCurrency(_pendingDues),
          icon: Icons.pending_actions,
          color: Colors.orange,
        )),
        const SizedBox(width: 20),
        Expanded(child: _StatCard(
          title: 'This Month',
          value: _isLoading ? '...' : _formatCurrency(_thisMonthSales),
          icon: Icons.calendar_today,
          color: Colors.purple,
        )),
        const SizedBox(width: 20),
        Expanded(child: _StatCard(
          title: 'Total Customers',
          value: _isLoading ? '...' : '$_totalCustomers',
          icon: Icons.people,
          color: Colors.blue,
        )),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          if (user == null) return const SizedBox();

          final moduleCards = _buildModuleCards(context, user);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Welcome Back', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(user.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text(_getRoleDisplayName(user.role), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: moduleCards.length.isOdd ? moduleCards.length - 1 : moduleCards.length,
                      itemBuilder: (context, index) {
                        final card = moduleCards[index];
                        return _ModuleCard(title: card.title, icon: card.icon, color: card.color, onTap: card.onTap);
                      },
                    ),
                    if (moduleCards.length.isOdd) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: MediaQuery.of(context).size.width / 2 * 0.9,
                        child: _ModuleCard(title: moduleCards.last.title, icon: moduleCards.last.icon, color: moduleCards.last.color, onTap: moduleCards.last.onTap),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_ModuleCardData> _buildModuleCards(BuildContext context, dynamic user) {
    final moduleCards = <_ModuleCardData>[];

    if (user.hasPermission(Permission.customers)) {
      moduleCards.add(_ModuleCardData(title: 'Customers', icon: Icons.people, color: Colors.blue, onTap: () => Navigator.pushNamed(context, AppRoutes.customers)));
    }
    if (user.hasPermission(Permission.msfTransactions)) {
      moduleCards.add(_ModuleCardData(title: 'Wallets', icon: Icons.account_balance_wallet, color: Colors.green, onTap: () => Navigator.pushNamed(context, AppRoutes.wallets)));
    }
    if (user.hasPermission(Permission.reports)) {
      moduleCards.add(_ModuleCardData(title: 'Daily Closing', icon: Icons.summarize, color: Colors.deepOrange, onTap: () => Navigator.pushNamed(context, AppRoutes.dailyClosing)));
    }
    if (user.hasPermission(Permission.products) || user.hasPermission(Permission.services)) {
      moduleCards.add(_ModuleCardData(title: 'Inventory', icon: Icons.inventory_2, color: Colors.teal, onTap: () => Navigator.pushNamed(context, AppRoutes.inventory)));
    }
    if (user.hasPermission(Permission.products)) {
      moduleCards.add(_ModuleCardData(title: 'Sales', icon: Icons.point_of_sale, color: Colors.purple, onTap: () => Navigator.pushNamed(context, AppRoutes.sales)));
    }
    if (user.hasPermission(Permission.reports)) {
      moduleCards.add(_ModuleCardData(title: 'Expenses', icon: Icons.receipt_long, color: Colors.red, onTap: () => Navigator.pushNamed(context, AppRoutes.expenses)));
    }
    if (user.hasPermission(Permission.reports)) {
      moduleCards.add(_ModuleCardData(title: 'Reports', icon: Icons.analytics, color: Colors.orange, onTap: () => Navigator.pushNamed(context, AppRoutes.reports)));
    }
    if (user.hasPermission(Permission.userManagement)) {
      moduleCards.add(_ModuleCardData(title: 'User Management', icon: Icons.admin_panel_settings, color: Colors.indigo, onTap: () => Navigator.pushNamed(context, AppRoutes.users)));
    }
    if (user.hasPermission(Permission.reports)) {
      moduleCards.add(_ModuleCardData(title: 'Profit Deduction', icon: Icons.trending_down, color: Colors.amber, onTap: () => Navigator.pushNamed(context, AppRoutes.profitDeduction)));
    }
    if (user.isMasterAdmin) {
      moduleCards.add(_ModuleCardData(title: 'Admin Tools', icon: Icons.build, color: Colors.red.shade700, onTap: () => Navigator.pushNamed(context, AppRoutes.adminTools)));
    }

    return moduleCards;
  }
}

class _NavItem {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  _NavItem(this.icon, this.title, this.isSelected, this.onTap);
}

class _ModuleCardData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ModuleCardData({required this.title, required this.icon, required this.color, required this.onTap});
}

class _ModuleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (hovered) => setState(() => _isHovered = hovered),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: _isHovered ? 6 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Colors.grey.shade50]),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [widget.color.withOpacity(0.3), widget.color.withOpacity(0.1)]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 40, color: widget.color),
                ),
                const SizedBox(height: 12),
                Text(widget.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebModuleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WebModuleCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  State<_WebModuleCard> createState() => _WebModuleCardState();
}

class _WebModuleCardState extends State<_WebModuleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (hovered) => setState(() => _isHovered = hovered),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: _isHovered ? widget.color.withOpacity(0.3) : Colors.grey.shade200, blurRadius: _isHovered ? 16 : 8, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: _isHovered ? widget.color.withOpacity(0.5) : Colors.transparent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: widget.color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(widget.icon, size: 32, color: widget.color),
              ),
              const SizedBox(height: 14),
              Text(widget.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
