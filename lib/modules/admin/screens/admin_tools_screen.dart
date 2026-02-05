import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/action_log.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Activity Log states
  List<ActionLog> _activityLogs = [];
  bool _isLoadingLogs = false;
  String? _selectedModule;
  String? _selectedUser;
  DateTime? _logStartDate;
  DateTime? _logEndDate;
  List<Map<String, String>> _users = [];

  // Database Cleanup states
  final Map<String, Set<String>> _selectedRecords = {
    'sales': {},
    'expenses': {},
    'closing': {},
    'customers': {},
    'inventory_items': {},
  };

  final Map<String, List<dynamic>> _allRecords = {
    'sales': [],
    'expenses': [],
    'closing': [],
    'customers': [],
    'inventory_items': [],
  };

  DateTime? _cleanupStartDate;
  DateTime? _cleanupEndDate;
  String _activeModule = 'sales';
  bool _isLoadingRecords = false;
  bool _isDeleting = false;

  final List<String> _modules = [
    'Auth',
    'Sales',
    'Inventory',
    'Customers',
    'Expenses',
    'Wallet',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActivityLogs();
    _loadUsers();
    _loadAllRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      setState(() {
        _users = snapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'name': doc.data()['name']?.toString() ?? 'Unknown',
              },
            )
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _loadActivityLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      Query query = _firestore
          .collection('action_logs')
          .orderBy('timestamp', descending: true)
          .limit(100);

      if (_selectedModule != null) {
        query = query.where('module', isEqualTo: _selectedModule);
      }

      if (_selectedUser != null) {
        query = query.where('userId', isEqualTo: _selectedUser);
      }

      final snapshot = await query.get();

      List<ActionLog> logs = snapshot.docs
          .map(
            (doc) => ActionLog.fromJson({
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            }),
          )
          .toList();

      // Filter by date client-side if needed
      if (_logStartDate != null) {
        logs = logs
            .where(
              (log) =>
                  log.timestamp != null &&
                  (log.timestamp!.isAfter(_logStartDate!) ||
                      log.timestamp!.isAtSameMomentAs(_logStartDate!)),
            )
            .toList();
      }
      if (_logEndDate != null) {
        final endOfDay = DateTime(
          _logEndDate!.year,
          _logEndDate!.month,
          _logEndDate!.day,
          23,
          59,
          59,
        );
        logs = logs
            .where(
              (log) =>
                  log.timestamp != null && log.timestamp!.isBefore(endOfDay),
            )
            .toList();
      }

      setState(() {
        _activityLogs = logs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingLogs = false);
    }
  }

  Future<void> _loadAllRecords() async {
    setState(() => _isLoadingRecords = true);
    try {
      // Load Sales
      final salesSnap = await _firestore
          .collection('sales')
          .orderBy('saleDate', descending: true)
          .get();
      _allRecords['sales'] = salesSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // Load Expenses
      final expensesSnap = await _firestore
          .collection('expenses')
          .orderBy('expenseDate', descending: true)
          .get();
      _allRecords['expenses'] = expensesSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // Load Daily Closing
      final closingSnap = await _firestore
          .collection('daily_closing')
          .orderBy('closingDate', descending: true)
          .get();
      _allRecords['closing'] = closingSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // Load Customers
      final customersSnap = await _firestore.collection('customers').get();
      _allRecords['customers'] = customersSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // Load Inventory Items
      final inventorySnap = await _firestore
          .collection('inventory_items')
          .get();
      _allRecords['inventory_items'] = inventorySnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading records: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingRecords = false);
    }
  }

  List<dynamic> get _filteredRecords {
    List<dynamic> records = _allRecords[_activeModule] ?? [];

    if (_cleanupStartDate != null || _cleanupEndDate != null) {
      records = records.where((record) {
        Timestamp? dateField;

        if (_activeModule == 'sales') {
          dateField = record['saleDate'];
        } else if (_activeModule == 'expenses') {
          dateField = record['expenseDate'];
        } else if (_activeModule == 'closing') {
          dateField = record['closingDate'];
        } else if (_activeModule == 'inventory_items') {
          dateField = record['createdAt'];
        }

        if (dateField == null) return true; // Include if no date field

        final date = dateField.toDate();

        if (_cleanupStartDate != null && date.isBefore(_cleanupStartDate!)) {
          return false;
        }

        if (_cleanupEndDate != null) {
          final endOfDay = _cleanupEndDate!.add(const Duration(days: 1));
          if (date.isAfter(endOfDay)) {
            return false;
          }
        }

        return true;
      }).toList();
    }

    return records;
  }

  Future<void> _deleteSelectedRecords() async {
    final selected = _selectedRecords[_activeModule] ?? {};
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select records to delete')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete ${selected.length} ${_activeModule} record(s)?\n\nThis action cannot be undone!',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      String collectionName = _activeModule;
      if (_activeModule == 'closing') collectionName = 'daily_closing';

      final batch = _firestore.batch();
      for (final id in selected) {
        batch.delete(_firestore.collection(collectionName).doc(id));
      }
      await batch.commit();

      // Log the action
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        await auth.logAction(
          action: 'DELETE_RECORDS',
          module: 'Admin',
          details: 'Deleted ${selected.length} records from $_activeModule',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${selected.length} records'),
          backgroundColor: Colors.green,
        ),
      );

      _selectedRecords[_activeModule]?.clear();
      await _loadAllRecords();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting records: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _deleteAllRecords() async {
    final total = _filteredRecords.length;
    if (total == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete All'),
        content: Text(
          'Delete ALL $total $_activeModule record(s)?\n\nThis action CANNOT be undone!',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      String collectionName = _activeModule;
      if (_activeModule == 'closing') collectionName = 'daily_closing';

      for (final record in _filteredRecords) {
        await _firestore.collection(collectionName).doc(record['id']).delete();
      }

      // Log the action
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        await auth.logAction(
          action: 'DELETE_ALL_RECORDS',
          module: 'Admin',
          details: 'Deleted all $total records from $_activeModule',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted all $total records'),
          backgroundColor: Colors.green,
        ),
      );

      _selectedRecords[_activeModule]?.clear();
      await _loadAllRecords();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _clearActivityLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Activity Logs'),
        content: const Text(
          'Are you sure you want to clear all activity logs?\n\nThis action cannot be undone!',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoadingLogs = true);

    try {
      final snapshot = await _firestore.collection('action_logs').get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity logs cleared'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadActivityLogs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Only master admin can access
    if (auth.currentUser == null || !auth.currentUser!.isMasterAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Tools')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Only Master Admin can access this section'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Tools'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade700, Colors.red.shade900],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Activity Logs'),
            Tab(icon: Icon(Icons.delete_sweep), text: 'Database Cleanup'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildActivityLogsTab(), _buildDatabaseCleanupTab()],
      ),
    );
  }

  Widget _buildActivityLogsTab() {
    return Column(
      children: [
        // Filters
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedModule,
                        decoration: const InputDecoration(
                          labelText: 'Module',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Modules'),
                          ),
                          ..._modules.map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedModule = value);
                          _loadActivityLogs();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _selectedUser,
                        decoration: const InputDecoration(
                          labelText: 'User',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Users'),
                          ),
                          ..._users.map(
                            (u) => DropdownMenuItem(
                              value: u['id'],
                              child: Text(u['name'] ?? 'Unknown'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedUser = value);
                          _loadActivityLogs();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _logStartDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _logStartDate = date);
                            _loadActivityLogs();
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _logStartDate == null
                              ? 'Start Date'
                              : DateFormat('MMM d, y').format(_logStartDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _logEndDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _logEndDate = date);
                            _loadActivityLogs();
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _logEndDate == null
                              ? 'End Date'
                              : DateFormat('MMM d, y').format(_logEndDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedModule = null;
                          _selectedUser = null;
                          _logStartDate = null;
                          _logEndDate = null;
                        });
                        _loadActivityLogs();
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear Filters',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_activityLogs.length} log entries',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _loadActivityLogs,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed: _clearActivityLogs,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    tooltip: 'Clear All Logs',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Logs List
        Expanded(
          child: _isLoadingLogs
              ? const Center(child: CircularProgressIndicator())
              : _activityLogs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No activity logs found'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _activityLogs.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final log = _activityLogs[index];
                    return _buildLogCard(log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLogCard(ActionLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getModuleColor(log.module).withOpacity(0.2),
          child: Icon(
            _getModuleIcon(log.module),
            color: _getModuleColor(log.module),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              log.action,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getModuleColor(log.module).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                log.module,
                style: TextStyle(
                  fontSize: 11,
                  color: _getModuleColor(log.module),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  log.userName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  DateFormat(
                    'MMM d, y - hh:mm a',
                  ).format(log.timestamp ?? DateTime.now()),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (log.details != null) ...[
              const SizedBox(height: 4),
              Text(
                log.details!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        isThreeLine: log.details != null,
      ),
    );
  }

  Color _getModuleColor(String module) {
    switch (module.toLowerCase()) {
      case 'auth':
        return Colors.blue;
      case 'sales':
        return Colors.green;
      case 'inventory':
        return Colors.orange;
      case 'customers':
        return Colors.purple;
      case 'expenses':
        return Colors.red;
      case 'wallet':
        return Colors.teal;
      case 'admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module.toLowerCase()) {
      case 'auth':
        return Icons.login;
      case 'sales':
        return Icons.point_of_sale;
      case 'inventory':
        return Icons.inventory;
      case 'customers':
        return Icons.people;
      case 'expenses':
        return Icons.money_off;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.history;
    }
  }

  Widget _buildDatabaseCleanupTab() {
    final records = _filteredRecords;
    final selected = _selectedRecords[_activeModule] ?? {};

    return Column(
      children: [
        // Module Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildModuleChip('sales', 'Sales', Icons.point_of_sale),
              const SizedBox(width: 8),
              _buildModuleChip('expenses', 'Expenses', Icons.money_off),
              const SizedBox(width: 8),
              _buildModuleChip(
                'closing',
                'Daily Closing',
                Icons.assignment_turned_in,
              ),
              const SizedBox(width: 8),
              _buildModuleChip('customers', 'Customers', Icons.people),
              const SizedBox(width: 8),
              _buildModuleChip('inventory_items', 'Inventory', Icons.inventory),
            ],
          ),
        ),

        // Date Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _cleanupStartDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _cleanupStartDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _cleanupStartDate == null
                        ? 'Start Date'
                        : DateFormat('MMM d').format(_cleanupStartDate!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _cleanupEndDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _cleanupEndDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _cleanupEndDate == null
                        ? 'End Date'
                        : DateFormat('MMM d').format(_cleanupEndDate!),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _cleanupStartDate = null;
                    _cleanupEndDate = null;
                  });
                },
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Stats & Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${records.length} records | ${selected.length} selected',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (selected.length == records.length) {
                          _selectedRecords[_activeModule]?.clear();
                        } else {
                          _selectedRecords[_activeModule] = records
                              .map<String>((r) => r['id'] as String)
                              .toSet();
                        }
                      });
                    },
                    child: Text(
                      selected.length == records.length
                          ? 'Deselect All'
                          : 'Select All',
                    ),
                  ),
                  IconButton(
                    onPressed: _loadAllRecords,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Records List
        Expanded(
          child: _isLoadingRecords
              ? const Center(child: CircularProgressIndicator())
              : records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No $_activeModule records found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: records.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final id = record['id'] as String;
                    final isSelected = selected.contains(id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? Colors.red.shade50 : null,
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedRecords[_activeModule]?.add(id);
                            } else {
                              _selectedRecords[_activeModule]?.remove(id);
                            }
                          });
                        },
                        title: Text(
                          _getRecordTitle(record),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          _getRecordSubtitle(record),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        secondary: Icon(
                          _getModuleIconForCleanup(_activeModule),
                          color: isSelected ? Colors.red : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Delete Actions
        if (records.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: selected.isEmpty || _isDeleting
                          ? null
                          : _deleteSelectedRecords,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete),
                      label: Text('Delete Selected (${selected.length})'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isDeleting ? null : _deleteAllRecords,
                      icon: const Icon(Icons.delete_forever),
                      label: Text('Delete All (${records.length})'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModuleChip(String module, String label, IconData icon) {
    final isActive = _activeModule == module;
    final count = _allRecords[module]?.length ?? 0;

    return FilterChip(
      selected: isActive,
      onSelected: (_) {
        setState(() => _activeModule = module);
      },
      avatar: Icon(
        icon,
        size: 18,
        color: isActive ? Colors.white : Colors.grey,
      ),
      label: Text('$label ($count)'),
      selectedColor: Colors.red.shade600,
      labelStyle: TextStyle(color: isActive ? Colors.white : null),
      checkmarkColor: Colors.white,
    );
  }

  String _getRecordTitle(Map<String, dynamic> record) {
    switch (_activeModule) {
      case 'sales':
        return record['saleNumber'] ?? record['id'];
      case 'expenses':
        return record['category'] ?? record['id'];
      case 'closing':
        return 'Closing ${record['closingDate'] != null ? DateFormat('MMM d').format((record['closingDate'] as Timestamp).toDate()) : record['id']}';
      case 'customers':
        return record['name'] ?? record['id'];
      case 'inventory_items':
        return record['name'] ?? record['id'];
      default:
        return record['id'];
    }
  }

  String _getRecordSubtitle(Map<String, dynamic> record) {
    switch (_activeModule) {
      case 'sales':
        final date = record['saleDate'] as Timestamp?;
        final amount = record['totalSelling'] ?? 0;
        return '${date != null ? DateFormat('MMM d, y').format(date.toDate()) : ''} | ৳$amount';
      case 'expenses':
        final date = record['expenseDate'] as Timestamp?;
        final amount = record['amount'] ?? 0;
        return '${date != null ? DateFormat('MMM d, y').format(date.toDate()) : ''} | ৳$amount';
      case 'closing':
        final cash = record['totalCash'] ?? 0;
        return 'Cash: ৳$cash';
      case 'customers':
        return record['phone'] ?? 'No phone';
      case 'inventory_items':
        final stock = record['stock'] ?? 0;
        final price = record['sellingPrice'] ?? 0;
        return 'Stock: $stock | ৳$price';
      default:
        return record['id'];
    }
  }

  IconData _getModuleIconForCleanup(String module) {
    switch (module) {
      case 'sales':
        return Icons.point_of_sale;
      case 'expenses':
        return Icons.money_off;
      case 'closing':
        return Icons.assignment_turned_in;
      case 'customers':
        return Icons.people;
      case 'inventory_items':
        return Icons.inventory;
      default:
        return Icons.folder;
    }
  }
}
