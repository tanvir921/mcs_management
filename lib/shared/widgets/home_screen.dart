import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app/app_routes.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/app_time.dart';
import '../../core/utils/responsive.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/khosra/models/khosra_entry.dart';
import '../../modules/khosra/providers/khosra_provider.dart';
import '../../modules/reports/services/reports_service.dart';

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
  final ReportsService _reportsService = ReportsService();

  double _todaySales = 0;
  double _todayDuesAdded = 0;
  double _todayCollections = 0;
  double _todayExpenses = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<KhosraProvider>().init();
      }
    });
  }

  Future<void> _loadTodayStats() async {
    if (mounted) {
      setState(() => _isLoadingStats = true);
    }
    try {
      final summary = await _reportsService.getSummary(DateFilter.today);
      final now = AppTime.businessNow();
      final todayStart = AppTime.startOfBusinessDayUtc(now);
      final todayEnd = AppTime.endOfBusinessDayUtc(now);

      final salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where(
            'saleDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .get();

      double totalSales = 0;
      for (final doc in salesSnapshot.docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        final totalSelling = (data['totalSelling'] as num?)?.toDouble() ?? 0;
        final discountAmount =
            (data['discountAmount'] as num?)?.toDouble() ?? 0;
        totalSales += (totalSelling - discountAmount);
      }

      if (mounted) {
        setState(() {
          _todaySales = totalSales;
          _todayDuesAdded = summary.totalDuesAdded;
          _todayCollections = summary.totalCollections;
          _todayExpenses =
              (summary.expenseStats?['totalExpenses'] as num?)?.toDouble() ?? 0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading today stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '৳${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 100000) {
      return '৳${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '৳${amount.toStringAsFixed(0)}';
  }

  Future<void> _navigateAndRefresh(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (mounted) {
      _loadTodayStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = Responsive.isLargeScreen(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: isLargeScreen ? null : _buildMobileAppBar(context),
      body: isLargeScreen
          ? _buildWebLayout(context)
          : _buildMobileLayout(context),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.storefront_rounded, size: 22, color: Colors.white),
          SizedBox(width: 8),
          Text('MCS Management'),
        ],
      ),
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade700, Colors.indigo.shade800],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh Dashboard',
          onPressed: _loadTodayStats,
        ),
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.currentUser;
            return PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_rounded),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'user',
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (user != null)
                        Text(
                          _getRoleDisplayName(user.role),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  onTap: () => authProvider.signOut(),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
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

  Widget _buildMobileLayout(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        if (user == null) return const SizedBox();

        final moduleCards = _buildModuleCards(context, user);

        return RefreshIndicator(
          onRefresh: _loadTodayStats,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              // Compact greeting + live date/time bar
              _buildCompactWelcomeHeader(user),
              const SizedBox(height: 12),

              // Prominent Khosra (খসড়া খাতা) live card
              _buildKhosraHeroCard(context),
              const SizedBox(height: 12),

              // Today's 4 live stats in a compact 2x2 grid
              _buildMobileStatsGrid(),
              const SizedBox(height: 14),

              // 1-Tap Quick Actions row
              _buildQuickActionsStrip(context, user),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'সকল মডিউল (Modules)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    '${moduleCards.length} items',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.45,
                ),
                itemCount: moduleCards.length,
                itemBuilder: (context, index) {
                  final card = moduleCards[index];
                  return _ModuleCard(
                    title: card.title,
                    subtitle: card.subtitle,
                    icon: card.icon,
                    color: card.color,
                    onTap: card.onTap,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactWelcomeHeader(dynamic user) {
    final now = AppTime.businessNow();
    final dateStr = DateFormat('EEE, d MMM yyyy').format(now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade700, Colors.indigo.shade800],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              user.name.toString().trim().isNotEmpty
                  ? user.name.toString().trim()[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_getRoleDisplayName(user.role)} • $dateStr',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKhosraHeroCard(BuildContext context) {
    return Consumer<KhosraProvider>(
      builder: (context, khosra, _) {
        final pendingCount = khosra.pendingCount;
        final olderCount = khosra.olderPendingEntries.length;
        final totalSellText = KhosraMoney.formatPaisa(khosra.totalSellPaisa);

        return InkWell(
          onTap: () => _navigateAndRefresh(AppRoutes.khosra),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.teal.shade700, Colors.teal.shade900],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'খসড়া খাতা (Khosra Quick Log)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pendingCount > 0
                            ? 'আজকের খসড়া বিক্রি: $totalSellText • $pendingCount টি বাকি'
                            : '১-ট্যাপে দ্রুত বিক্রি, বকেয়া, আদায় ও খরচ লিখে রাখুন',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                      if (olderCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade300,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'পুরনো দিনের $olderCount টি খসড়া বাকি আছে',
                            style: TextStyle(
                              color: Colors.brown.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (pendingCount > 0)
                  FilledButton(
                    onPressed: () =>
                        _navigateAndRefresh(AppRoutes.khosraReview),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal.shade900,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _CompactStatTile(
                title: 'আজকের বিক্রি (Sales)',
                value: _isLoadingStats ? '...' : _formatCurrency(_todaySales),
                icon: Icons.point_of_sale_rounded,
                color: Colors.green.shade700,
                onTap: () => _navigateAndRefresh(AppRoutes.salesHistory),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactStatTile(
                title: 'নতুন বাকি (Due)',
                value: _isLoadingStats
                    ? '...'
                    : _formatCurrency(_todayDuesAdded),
                icon: Icons.person_add_alt_1_rounded,
                color: Colors.deepOrange.shade700,
                onTap: () => _navigateAndRefresh(AppRoutes.customerDueTracker),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CompactStatTile(
                title: 'বাকি আদায় (Aday)',
                value: _isLoadingStats
                    ? '...'
                    : _formatCurrency(_todayCollections),
                icon: Icons.payments_rounded,
                color: Colors.blue.shade700,
                onTap: () => _navigateAndRefresh(AppRoutes.customerDueTracker),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactStatTile(
                title: 'আজকের খরচ (Expense)',
                value: _isLoadingStats
                    ? '...'
                    : _formatCurrency(_todayExpenses),
                icon: Icons.receipt_long_rounded,
                color: Colors.red.shade700,
                onTap: () => _navigateAndRefresh(AppRoutes.expenses),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsStrip(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickShortcutButton(
            icon: Icons.add_shopping_cart_rounded,
            label: '+ বিক্রি',
            color: Colors.purple.shade700,
            onTap: () => _navigateAndRefresh(AppRoutes.saleAdd),
          ),
          _QuickShortcutButton(
            icon: Icons.edit_note_rounded,
            label: 'খসড়া খাতা',
            color: Colors.teal.shade700,
            onTap: () => _navigateAndRefresh(AppRoutes.khosra),
          ),
          _QuickShortcutButton(
            icon: Icons.account_balance_rounded,
            label: 'বাকি আদায়',
            color: Colors.blue.shade700,
            onTap: () => _navigateAndRefresh(AppRoutes.customerDueTracker),
          ),
          _QuickShortcutButton(
            icon: Icons.post_add_rounded,
            label: '+ খরচ',
            color: Colors.red.shade700,
            onTap: () => _navigateAndRefresh(AppRoutes.expenseAdd),
          ),
        ],
      ),
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;
        if (user == null) return const SizedBox();

        final moduleCards = _buildModuleCards(context, user);

        return Row(
          children: [
            _buildSidebar(context, authProvider),
            Expanded(
              child: Container(
                color: const Color(0xFFF4F6FA),
                child: Column(
                  children: [
                    _buildWebTopBar(context, user),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildKhosraHeroCard(context),
                            const SizedBox(height: 20),
                            _buildWebStatsRow(),
                            const SizedBox(height: 28),
                            Text(
                              'Quick Access Modules',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: Responsive.value(
                                      context,
                                      mobile: 2,
                                      tablet: 3,
                                      desktop: 4,
                                    ),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.45,
                                  ),
                              itemCount: moduleCards.length,
                              itemBuilder: (context, index) {
                                final card = moduleCards[index];
                                return _WebModuleCard(
                                  title: card.title,
                                  subtitle: card.subtitle,
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

  Widget _buildWebStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: "Today's Sales",
            value: _isLoadingStats ? '...' : _formatCurrency(_todaySales),
            icon: Icons.point_of_sale,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Due Added',
            value: _isLoadingStats ? '...' : _formatCurrency(_todayDuesAdded),
            icon: Icons.add_circle_outline,
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Due Collection',
            value: _isLoadingStats ? '...' : _formatCurrency(_todayCollections),
            icon: Icons.payments_outlined,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Expenses',
            value: _isLoadingStats ? '...' : _formatCurrency(_todayExpenses),
            icon: Icons.receipt_long,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade700, Colors.indigo.shade800],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'MCS Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                _buildNavSection('MAIN', [
                  _NavItem(Icons.home, 'Dashboard', true, () {}),
                  _NavItem(
                    Icons.edit_note_rounded,
                    'Khosra (খসড়া খাতা)',
                    false,
                    () => _navigateAndRefresh(AppRoutes.khosra),
                  ),
                ]),
                if (user?.hasPermission(Permission.customers) ?? false)
                  _buildNavSection('MANAGEMENT', [
                    _NavItem(
                      Icons.people,
                      'Customers',
                      false,
                      () => _navigateAndRefresh(AppRoutes.customers),
                    ),
                    _NavItem(
                      Icons.account_balance_rounded,
                      'Due Tracker',
                      false,
                      () => _navigateAndRefresh(AppRoutes.customerDueTracker),
                    ),
                    if (user?.hasPermission(Permission.msfTransactions) ??
                        false)
                      _NavItem(
                        Icons.account_balance_wallet,
                        'Wallets',
                        false,
                        () => _navigateAndRefresh(AppRoutes.wallets),
                      ),
                    if (user?.hasPermission(Permission.products) ?? false)
                      _NavItem(
                        Icons.inventory_2,
                        'Inventory',
                        false,
                        () => _navigateAndRefresh(AppRoutes.inventory),
                      ),
                    if (user?.hasPermission(Permission.products) ?? false)
                      _NavItem(
                        Icons.point_of_sale,
                        'Sales',
                        false,
                        () => _navigateAndRefresh(AppRoutes.sales),
                      ),
                  ]),
                if (user?.hasPermission(Permission.reports) ?? false)
                  _buildNavSection('REPORTS & FINANCE', [
                    _NavItem(
                      Icons.summarize,
                      'Daily Closing',
                      false,
                      () => _navigateAndRefresh(AppRoutes.dailyClosing),
                    ),
                    _NavItem(
                      Icons.receipt_long,
                      'Expenses',
                      false,
                      () => _navigateAndRefresh(AppRoutes.expenses),
                    ),
                    _NavItem(
                      Icons.analytics,
                      'Reports',
                      false,
                      () => _navigateAndRefresh(AppRoutes.reports),
                    ),
                    _NavItem(
                      Icons.trending_down,
                      'Profit Deduction',
                      false,
                      () => _navigateAndRefresh(AppRoutes.profitDeduction),
                    ),
                  ]),
                if (user?.hasPermission(Permission.userManagement) ?? false)
                  _buildNavSection('ADMIN', [
                    _NavItem(
                      Icons.admin_panel_settings,
                      'User Management',
                      false,
                      () => _navigateAndRefresh(AppRoutes.users),
                    ),
                    if (user?.isMasterAdmin ?? false)
                      _NavItem(
                        Icons.build,
                        'Admin Tools',
                        false,
                        () => _navigateAndRefresh(AppRoutes.adminTools),
                      ),
                  ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () => authProvider.signOut(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade600, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(_buildNavTile),
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
              Icon(
                item.icon,
                size: 20,
                color: item.isSelected
                    ? Colors.blue.shade700
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Text(
                item.title,
                style: TextStyle(
                  color: item.isSelected
                      ? Colors.blue.shade700
                      : Colors.grey.shade700,
                  fontWeight: item.isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadTodayStats,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Stats',
          ),
          const SizedBox(width: 8),
          const _RealtimeClock(),
        ],
      ),
    );
  }

  List<_ModuleCardData> _buildModuleCards(BuildContext context, dynamic user) {
    final moduleCards = <_ModuleCardData>[];

    if (user.hasPermission(Permission.products)) {
      moduleCards.add(
        _ModuleCardData(
          title: 'Sales',
          subtitle: 'বিক্রি ও ইনভয়েস',
          icon: Icons.point_of_sale_rounded,
          color: Colors.purple.shade700,
          onTap: () => _navigateAndRefresh(AppRoutes.sales),
        ),
      );
    }
    if (user.hasPermission(Permission.customers)) {
      moduleCards.add(
        _ModuleCardData(
          title: 'Customers',
          subtitle: 'গ্রাহক তালিকা',
          icon: Icons.people_alt_rounded,
          color: Colors.blue.shade700,
          onTap: () => _navigateAndRefresh(AppRoutes.customers),
        ),
      );
      moduleCards.add(
        _ModuleCardData(
          title: 'Due Tracker',
          subtitle: 'বকেয়া ও আদায়',
          icon: Icons.account_balance_rounded,
          color: Colors.indigo.shade700,
          onTap: () => _navigateAndRefresh(AppRoutes.customerDueTracker),
        ),
      );
    }
    if (user.hasPermission(Permission.products) ||
        user.hasPermission(Permission.services)) {
      moduleCards.add(
        _ModuleCardData(
          title: 'Inventory',
          subtitle: 'পণ্য ও সার্ভিস স্টক',
          icon: Icons.inventory_2_rounded,
          color: Colors.teal.shade700,
          onTap: () => _navigateAndRefresh(AppRoutes.inventory),
        ),
      );
    }
    if (user.hasPermission(Permission.msfTransactions)) {
      moduleCards.add(
        _ModuleCardData(
          title: 'Wallets',
          subtitle: 'বিকাশ / নগদ / ক্যাশ',
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.green.shade700,
          onTap: () => _navigateAndRefresh(AppRoutes.wallets),
        ),
      );
    }
    if (user.hasPermission(Permission.reports)) {
      moduleCards.add(
        _ModuleCardData(
          title: 'Expenses',
          subtitle: 'দোকান ও অন্যান্য খরচ',
          icon: Icons.receipt_long_rounded,
          color: Colors.red.shade700,
          onTap: () => _navigateAndRefresh(AppRoutes.expenses),
        ),
      );
      moduleCards.add(
        _ModuleCardData(
          title: 'Daily Closing',
          subtitle: 'দৈনিক ক্যাশ ক্লোজিং',
          icon: Icons.summarize_rounded,
          color: Colors.deepOrange.shade700,
          onTap: () => _navigateAndRefresh(AppRoutes.dailyClosing),
        ),
      );
      moduleCards.add(
        _ModuleCardData(
          title: 'Reports',
          subtitle: 'লাভ ও হিসাব রিপোর্ট',
          icon: Icons.analytics_rounded,
          color: Colors.orange.shade800,
          onTap: () => _navigateAndRefresh(AppRoutes.reports),
        ),
      );
      moduleCards.add(
        _ModuleCardData(
          title: 'Profit Deduction',
          subtitle: 'লাভ সমন্বয়',
          icon: Icons.trending_down_rounded,
          color: Colors.amber.shade800,
          onTap: () => _navigateAndRefresh(AppRoutes.profitDeduction),
        ),
      );
    }
    if (user.hasPermission(Permission.userManagement)) {
      moduleCards.add(
        _ModuleCardData(
          title: 'Users',
          subtitle: 'অ্যাডমিন ও পারমিশন',
          icon: Icons.admin_panel_settings_rounded,
          color: Colors.blueGrey.shade700,
          onTap: () => _navigateAndRefresh(AppRoutes.users),
        ),
      );
    }
    if (user.isMasterAdmin) {
      moduleCards.add(
        _ModuleCardData(
          title: 'Admin Tools',
          subtitle: 'ডাটাবেস ও টুলস',
          icon: Icons.build_circle_rounded,
          color: Colors.red.shade800,
          onTap: () => _navigateAndRefresh(AppRoutes.adminTools),
        ),
      );
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
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ModuleCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _CompactStatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CompactStatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
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
      ),
    );
  }
}

class _QuickShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickShortcutButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
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
          padding: const EdgeInsets.all(14),
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
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 24, color: color),
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
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
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

class _WebModuleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WebModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.22)
                  : Colors.grey.shade200,
              blurRadius: _isHovered ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.45)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 28, color: widget.color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RealtimeClock extends StatefulWidget {
  const _RealtimeClock();

  @override
  State<_RealtimeClock> createState() => _RealtimeClockState();
}

class _RealtimeClockState extends State<_RealtimeClock> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = AppTime.businessNow();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = AppTime.businessNow());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('hh:mm:ss a');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            color: Colors.indigo.shade600,
            size: 20,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateFormat.format(_currentTime),
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
              Text(
                timeFormat.format(_currentTime),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
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
