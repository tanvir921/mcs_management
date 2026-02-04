import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../core/constants/enums.dart';
import '../../app/app_routes.dart';
import '../../core/utils/responsive.dart';

/// Navigation item data
class NavItem {
  final String title;
  final IconData icon;
  final String route;
  final Permission? requiredPermission;
  final bool masterAdminOnly;

  const NavItem({
    required this.title,
    required this.icon,
    required this.route,
    this.requiredPermission,
    this.masterAdminOnly = false,
  });
}

/// Responsive scaffold with sidebar for web
class ResponsiveScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final PreferredSizeWidget? bottom;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.showBackButton = false,
    this.onBackPressed,
    this.bottom,
  });

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  // All navigation items
  static const List<NavItem> _allNavItems = [
    NavItem(title: 'Home', icon: Icons.home, route: '/'),
    NavItem(
      title: 'Customers',
      icon: Icons.people,
      route: AppRoutes.customers,
      requiredPermission: Permission.customers,
    ),
    NavItem(
      title: 'Wallets',
      icon: Icons.account_balance_wallet,
      route: AppRoutes.wallets,
      requiredPermission: Permission.msfTransactions,
    ),
    NavItem(
      title: 'Daily Closing',
      icon: Icons.summarize,
      route: AppRoutes.dailyClosing,
      requiredPermission: Permission.reports,
    ),
    NavItem(
      title: 'Inventory',
      icon: Icons.inventory_2,
      route: AppRoutes.inventory,
      requiredPermission: Permission.products,
    ),
    NavItem(
      title: 'Sales',
      icon: Icons.point_of_sale,
      route: AppRoutes.sales,
      requiredPermission: Permission.products,
    ),
    NavItem(
      title: 'Expenses',
      icon: Icons.receipt_long,
      route: AppRoutes.expenses,
      requiredPermission: Permission.reports,
    ),
    NavItem(
      title: 'Reports',
      icon: Icons.analytics,
      route: AppRoutes.reports,
      requiredPermission: Permission.reports,
    ),
    NavItem(
      title: 'Users',
      icon: Icons.admin_panel_settings,
      route: AppRoutes.users,
      requiredPermission: Permission.userManagement,
    ),
    NavItem(
      title: 'Profit Deduction',
      icon: Icons.trending_down,
      route: AppRoutes.profitDeduction,
      requiredPermission: Permission.reports,
    ),
    NavItem(
      title: 'Admin Tools',
      icon: Icons.build,
      route: AppRoutes.adminTools,
      masterAdminOnly: true,
    ),
  ];

  String _currentRoute = '/';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
  }

  List<NavItem> _getFilteredNavItems(AuthProvider authProvider) {
    final user = authProvider.currentUser;
    if (user == null) return [];

    return _allNavItems.where((item) {
      if (item.masterAdminOnly && !user.isMasterAdmin) return false;
      if (item.requiredPermission != null &&
          !user.hasPermission(item.requiredPermission!)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = Responsive.isLargeScreen(context);

    if (isLargeScreen) {
      return _buildWebLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
              )
            : null,
        actions: widget.actions,
        bottom: widget.bottom,
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(context),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                _buildTopBar(context),
                // Body
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final navItems = _getFilteredNavItems(authProvider);
        final user = authProvider.currentUser;

        return Container(
          width: 250,
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
              // Logo/Brand
              Container(
                padding: const EdgeInsets.all(20),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'MCS Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // User info
              if (user != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user.role.name,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Navigation items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: navItems.length,
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected =
                        _currentRoute == item.route ||
                        (item.route != '/' &&
                            _currentRoute.startsWith(item.route));

                    return _buildNavItem(
                      context,
                      item: item,
                      isSelected: isSelected,
                    );
                  },
                ),
              ),
              // Logout button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: InkWell(
                  onTap: () async {
                    await authProvider.signOut();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.red.shade700,
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
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required NavItem item,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () {
          if (item.route == '/') {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          } else {
            Navigator.pushNamed(context, item.route);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: Colors.blue.shade200) : null,
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.blue.shade700
                        : Colors.grey.shade700,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          if (widget.showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
              tooltip: 'Back',
            ),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (widget.actions != null) ...widget.actions!,
        ],
      ),
    );
  }
}
