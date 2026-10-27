import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_routes.dart';
import '../../../core/utils/responsive.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';

enum SortOption {
  dueHighToLow,
  nameAsc,
  nameDesc,
  dueLowToHigh,
  newestFirst,
  oldestFirst,
}

enum _DueFilter { all, hasDue, noDue }

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _selectedSort = SortOption.dueHighToLow;
  _DueFilter _dueFilter = _DueFilter.all;

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
    List<Customer> filtered = customers;

    if (_dueFilter == _DueFilter.hasDue) {
      filtered = filtered.where((c) => c.totalDue > 0).toList();
    } else if (_dueFilter == _DueFilter.noDue) {
      filtered = filtered.where((c) => c.totalDue <= 0).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((customer) {
        final nameMatch = customer.name.toLowerCase().contains(query);
        final phoneMatch = customer.phone?.contains(query) ?? false;
        return nameMatch || phoneMatch;
      }).toList();
    }

    final sorted = List<Customer>.from(filtered);
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
      case SortOption.dueHighToLow:
        return 'Due (High → Low)';
      case SortOption.dueLowToHigh:
        return 'Due (Low → High)';
      case SortOption.nameAsc:
        return 'Name (A-Z)';
      case SortOption.nameDesc:
        return 'Name (Z-A)';
      case SortOption.newestFirst:
        return 'Newest First';
      case SortOption.oldestFirst:
        return 'Oldest First';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Customers (গ্রাহক)'),
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
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.customerDueTracker),
            icon: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Due Tracker',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort by',
            onSelected: (SortOption value) {
              setState(() => _selectedSort = value);
            },
            itemBuilder: (context) => SortOption.values.map((option) {
              return PopupMenuItem<SortOption>(
                value: option,
                child: Row(
                  children: [
                    if (_selectedSort == option)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(_getSortLabel(option)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => provider.loadCustomers(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allCustomers = provider.customers;
          final customers = _filterAndSortCustomers(allCustomers);
          final dueCustomersCount = allCustomers
              .where((c) => c.totalDue > 0)
              .length;
          final totalReceivable = allCustomers.fold<double>(
            0,
            (sum, c) => sum + c.totalDue,
          );

          return Column(
            children: [
              // Top Summary & Search Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  children: [
                    // Quick receivable summary bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'মোট গ্রাহক: ${allCustomers.length} (বাকি: $dueCustomersCount জন)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          Text(
                            'মোট পাওনা: ৳${totalReceivable.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'গ্রাহকের নাম বা মোবাইল নম্বর খুঁজুন...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            'সব (${allCustomers.length})',
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _dueFilter == _DueFilter.all,
                          onSelected: (_) =>
                              setState(() => _dueFilter = _DueFilter.all),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          selectedColor: Colors.red.shade100,
                          label: Text(
                            'বাকি আছে ($dueCustomersCount)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _dueFilter == _DueFilter.hasDue,
                          onSelected: (_) =>
                              setState(() => _dueFilter = _DueFilter.hasDue),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          selectedColor: Colors.green.shade100,
                          label: const Text(
                            'বাকি নেই',
                            style: TextStyle(fontSize: 12),
                          ),
                          selected: _dueFilter == _DueFilter.noDue,
                          onSelected: (_) =>
                              setState(() => _dueFilter = _DueFilter.noDue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (customers.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.people_outline_rounded,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'কোনো গ্রাহক পাওয়া যায়নি'
                              : 'এখনও কোনো গ্রাহক যোগ করা হয়নি',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => provider.loadCustomers(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isLargeScreen = Responsive.isLargeScreen(context);
                        final crossAxisCount = Responsive.value(
                          context,
                          mobile: 1,
                          tablet: 2,
                          desktop: 3,
                        );

                        if (isLargeScreen) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(14),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 2.3,
                                ),
                            itemCount: customers.length,
                            itemBuilder: (context, index) =>
                                _buildCustomerCard(context, customers[index]),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                          itemCount: customers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _buildCustomerCard(context, customers[index]),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.customerAdd),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, Customer customer) {
    final hasDue = customer.totalDue > 0;
    final trimmedName = customer.name.trim();
    final initial = trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDue ? Colors.red.shade200 : Colors.grey.shade200,
          width: hasDue ? 1.3 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.customerEdit,
              arguments: customer,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: hasDue
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  backgroundImage: customer.imageUrl != null
                      ? NetworkImage(customer.imageUrl!)
                      : null,
                  child: customer.imageUrl == null
                      ? Text(
                          initial,
                          style: TextStyle(
                            color: hasDue
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customer.phone != null &&
                          customer.phone!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 13.5,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              customer.phone!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildDueBadge(
                            'মোট বাকি',
                            customer.totalDue,
                            hasDue ? Colors.red : Colors.green,
                          ),
                          if (customer.cashBorrowDue > 0)
                            _buildDueBadge(
                              'নগদ',
                              customer.cashBorrowDue,
                              Colors.orange,
                            ),
                          if (customer.previousDue > 0)
                            _buildDueBadge(
                              'পুরাতন',
                              customer.previousDue,
                              Colors.teal,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDueBadge(String label, double amount, Color color) {
    final Color darkColor = Color.lerp(color, Colors.black, 0.55)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: ৳${amount.toStringAsFixed(0)}',
        style: TextStyle(
          color: darkColor,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
