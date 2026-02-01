import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_routes.dart';
import '../../../modules/auth/providers/auth_provider.dart';
import '../../../core/constants/enums.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Helper function to format role name professionally
  static String _formatRoleName(String roleName) {
    // Convert camelCase or snake_case to Title Case
    // e.g., "masterAdmin" → "Master Admin", "user_admin" → "User Admin"
    String result = roleName.replaceAllMapped(RegExp(r'([A-Z])|(_)'), (match) {
      if (match.group(1) != null) {
        // camelCase: insert space before uppercase
        return ' ${match.group(1)!}';
      } else {
        // snake_case: replace underscore with space
        return ' ';
      }
    });

    // Capitalize first letter and trim
    result = result.trim();
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(authProvider.currentUser?.name ?? 'User'),
                      ],
                    ),
                    enabled: false,
                  ),
                  PopupMenuItem<String>(
                    value: 'role',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.security, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          authProvider.currentUser?.role.name ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    enabled: false,
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: const Row(
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                    onTap: () async {
                      await authProvider.signOut();
                      // Navigation handled by AuthWrapper
                    },
                  ),
                ],
              );
            },
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
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.currentUser;
            if (user == null) return const SizedBox();

            // Build module cards based on permissions
            final moduleCards = <_ModuleCardData>[];

            // Customers
            if (user.hasPermission(Permission.customers)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Customers',
                  icon: Icons.people,
                  color: Colors.blue,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.customers),
                ),
              );
            }

            // Wallet Transactions
            if (user.hasPermission(Permission.msfTransactions)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Wallets',
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.wallets),
                ),
              );
            }

            // Daily Closing
            if (user.hasPermission(Permission.reports)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Daily Closing',
                  icon: Icons.summarize,
                  color: Colors.deepOrange,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.dailyClosing),
                ),
              );
            }

            // Inventory (Products & Services)
            if (user.hasPermission(Permission.products) ||
                user.hasPermission(Permission.services)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Inventory',
                  icon: Icons.inventory_2,
                  color: Colors.teal,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.inventory),
                ),
              );
            }

            // Sales
            if (user.hasPermission(Permission.products)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Sales',
                  icon: Icons.point_of_sale,
                  color: Colors.purple,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.sales),
                ),
              );
            }

            // Expenses
            if (user.hasPermission(Permission.reports)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Expenses',
                  icon: Icons.receipt_long,
                  color: Colors.red,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.expenses),
                ),
              );
            }

            // Reports
            if (user.hasPermission(Permission.reports)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Reports',
                  icon: Icons.analytics,
                  color: Colors.orange,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
                ),
              );
            }

            // User Management (Master Admin only)
            if (user.hasPermission(Permission.userManagement)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'User Management',
                  icon: Icons.admin_panel_settings,
                  color: Colors.indigo,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.users),
                ),
              );
            }

            // Profit Deduction Tracking
            if (user.hasPermission(Permission.reports)) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Profit Deduction',
                  icon: Icons.trending_down,
                  color: Colors.amber,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.profitDeduction),
                ),
              );
            }
            // Database Cleanup (Master Admin only)
            if (user.isMasterAdmin) {
              moduleCards.add(
                _ModuleCardData(
                  title: 'Database Cleanup',
                  icon: Icons.delete_sweep,
                  color: Colors.redAccent,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.databaseCleanup),
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                // Header Section
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
                      Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatRoleName(user.role.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Modules Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modules',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.9,
                            ),
                        itemCount: moduleCards.length,
                        itemBuilder: (context, index) {
                          final card = moduleCards[index];
                          return _ModuleCard(
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModuleCardData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ModuleCardData({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ModuleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color.withOpacity(0.3),
                        widget.color.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 40, color: widget.color),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
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
