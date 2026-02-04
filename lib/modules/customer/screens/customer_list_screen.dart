import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../models/customer_model.dart';
import '../../../app/app_routes.dart';
import '../../../core/utils/responsive.dart';

enum SortOption {
  nameAsc,
  nameDesc,
  dueHighToLow,
  dueLowToHigh,
  newestFirst,
  oldestFirst,
}

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _selectedSort = SortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _filterAndSortCustomers(List<Customer> customers) {
    // Filter by search query
    List<Customer> filtered = customers;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = customers.where((customer) {
        final nameMatch = customer.name.toLowerCase().contains(query);
        final phoneMatch = customer.phone?.contains(query) ?? false;
        return nameMatch || phoneMatch;
      }).toList();
    }

    // Sort
    List<Customer> sorted = List.from(filtered);
    switch (_selectedSort) {
      case SortOption.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case SortOption.nameDesc:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case SortOption.dueHighToLow:
        sorted.sort((a, b) => b.totalDue.compareTo(a.totalDue));
        break;
      case SortOption.dueLowToHigh:
        sorted.sort((a, b) => a.totalDue.compareTo(b.totalDue));
        break;
      case SortOption.newestFirst:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldestFirst:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }

    return sorted;
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.nameAsc:
        return 'Name (A-Z)';
      case SortOption.nameDesc:
        return 'Name (Z-A)';
      case SortOption.dueHighToLow:
        return 'Due (High to Low)';
      case SortOption.dueLowToHigh:
        return 'Due (Low to High)';
      case SortOption.newestFirst:
        return 'Newest First';
      case SortOption.oldestFirst:
        return 'Oldest First';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Customers'),
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
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort by',
            onSelected: (SortOption value) {
              setState(() {
                _selectedSort = value;
              });
            },
            itemBuilder: (context) => SortOption.values.map((option) {
              return PopupMenuItem<SortOption>(
                value: option,
                child: Row(
                  children: [
                    if (_selectedSort == option)
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    Text(_getSortLabel(option)),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<CustomerProvider>().loadCustomers();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading customers...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => provider.loadCustomers(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final allCustomers = provider.customers;
          final customers = _filterAndSortCustomers(allCustomers);

          return Column(
            children: [
              // Search Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade600,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Results count and sort indicator
              if (allCustomers.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.indigo.shade50],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${customers.length} customer${customers.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${_getSortLabel(_selectedSort)}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Customer List
              if (customers.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.people_outline_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No customers found'
                              : 'No customers yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try adjusting your search'
                              : 'Add your first customer to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLargeScreen = Responsive.isLargeScreen(context);
                      final crossAxisCount = Responsive.value(context, mobile: 1, tablet: 2, desktop: 3);
                      
                      if (isLargeScreen) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: customers.length,
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            return _buildCustomerCard(context, customer);
                          },
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildCustomerCard(context, customer),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.customerAdd);
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        elevation: 4,
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, Customer customer) {
    final hasDue = customer.totalDue > 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: hasDue ? Colors.red.shade100 : Colors.grey.shade200,
          width: hasDue ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.customerEdit,
              arguments: customer,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: hasDue
                          ? [Colors.red.shade50, Colors.red.shade100]
                          : [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: hasDue ? Colors.red.shade300 : Colors.green.shade300,
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.transparent,
                    backgroundImage: customer.imageUrl != null
                        ? NetworkImage(customer.imageUrl!)
                        : null,
                    child: customer.imageUrl == null
                        ? Text(
                            customer.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: hasDue ? Colors.red.shade700 : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customer.phone != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.phone_rounded, size: 15, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              customer.phone!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildDueBadge('Total', customer.totalDue, hasDue ? Colors.red : Colors.green),
                          if (customer.cashBorrowDue > 0)
                            _buildDueBadge('Cash', customer.cashBorrowDue, Colors.orange),
                          if (customer.previousDue > 0)
                            _buildDueBadge('Prev', customer.previousDue, Colors.teal),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDueBadge(String label, double amount, Color color) {
    // Get darker shades for text
    final Color darkColor = Color.lerp(color, Colors.black, 0.5)!;
    final Color darkerColor = Color.lerp(color, Colors.black, 0.65)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: darkColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '৳${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: darkerColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
