import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';

class DatabaseCleanupScreen extends StatefulWidget {
  const DatabaseCleanupScreen({super.key});

  @override
  State<DatabaseCleanupScreen> createState() => _DatabaseCleanupScreenState();
}

class _DatabaseCleanupScreenState extends State<DatabaseCleanupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selection states
  final Map<String, Set<String>> _selectedRecords = {
    'sales': {},
    'expenses': {},
    'closing': {},
    'customers': {},
  };

  final Map<String, List<dynamic>> _allRecords = {
    'sales': [],
    'expenses': [],
    'closing': [],
    'customers': [],
  };

  // Filter states
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _activeModule = 'sales';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllRecords();
  }

  Future<void> _loadAllRecords() async {
    setState(() => _isLoading = true);
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
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredRecords {
    List<dynamic> records = _allRecords[_activeModule] ?? [];

    if (_selectedStartDate != null || _selectedEndDate != null) {
      records = records.where((record) {
        Timestamp? dateField;

        if (_activeModule == 'sales') {
          dateField = record['saleDate'];
        } else if (_activeModule == 'expenses') {
          dateField = record['expenseDate'];
        } else if (_activeModule == 'closing') {
          dateField = record['closingDate'];
        }

        if (dateField == null) return false;

        final date = dateField.toDate();

        if (_selectedStartDate != null && date.isBefore(_selectedStartDate!)) {
          return false;
        }

        if (_selectedEndDate != null) {
          final endOfDay = _selectedEndDate!.add(const Duration(days: 1));
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

    // Confirm deletion
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final batch = _firestore.batch();
      final collectionName = _getCollectionName(_activeModule);

      for (final docId in selected) {
        batch.delete(_firestore.collection(collectionName).doc(docId));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} record(s) deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _selectedRecords[_activeModule]?.clear();
      await _loadAllRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDateRange() async {
    if (_selectedStartDate == null && _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range')),
      );
      return;
    }

    final dateRangeRecords = _filteredRecords;
    if (dateRangeRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records found in selected date range'),
        ),
      );
      return;
    }

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Date Range Deletion'),
        content: Text(
          'Delete ${dateRangeRecords.length} ${_activeModule} record(s) from ${_selectedStartDate?.toString().split(' ')[0] ?? 'start'} to ${_selectedEndDate?.toString().split(' ')[0] ?? 'end'}?\n\nThis action cannot be undone!',
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final batch = _firestore.batch();
      final collectionName = _getCollectionName(_activeModule);

      for (final record in dateRangeRecords) {
        batch.delete(_firestore.collection(collectionName).doc(record['id']));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${dateRangeRecords.length} record(s) deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      _selectedRecords[_activeModule]?.clear();
      await _loadAllRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete All'),
        content: Text(
          'Delete ALL ${_allRecords[_activeModule]?.length ?? 0} ${_activeModule} record(s)?\n\nThis action CANNOT be undone!',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final batch = _firestore.batch();
      final collectionName = _getCollectionName(_activeModule);

      for (final record in (_allRecords[_activeModule] ?? [])) {
        batch.delete(_firestore.collection(collectionName).doc(record['id']));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All ${_activeModule} records deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      _selectedRecords[_activeModule]?.clear();
      _allRecords[_activeModule] = [];
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getCollectionName(String module) {
    switch (module) {
      case 'sales':
        return 'sales';
      case 'expenses':
        return 'expenses';
      case 'closing':
        return 'daily_closing';
      case 'customers':
        return 'customers';
      default:
        return '';
    }
  }

  String _getRecordTitle(String module, Map<String, dynamic> record) {
    switch (module) {
      case 'sales':
        return 'Sale #${record['saleNumber'] ?? record['id'].toString().substring(0, 8)}';
      case 'expenses':
        return '${record['description'] ?? 'Expense'} - Rs.${record['amount']}';
      case 'closing':
        return 'Closing #${record['closingNumber'] ?? record['id'].toString().substring(0, 8)}';
      case 'customers':
        return record['name'] ?? 'Unknown Customer';
      default:
        return 'Record';
    }
  }

  String _getRecordDate(String module, Map<String, dynamic> record) {
    Timestamp? dateField;
    if (module == 'sales') {
      dateField = record['saleDate'];
    } else if (module == 'expenses') {
      dateField = record['expenseDate'];
    } else if (module == 'closing') {
      dateField = record['closingDate'];
    }

    if (dateField == null) return 'N/A';
    return dateField.toDate().toString().split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Only Master Admin can access
        if (authProvider.currentUser == null ||
            !authProvider.currentUser!.isMasterAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Database Cleanup')),
            body: const Center(
              child: Text(
                'Access Denied\n\nOnly Master Admin can access this feature',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Database Cleanup (Admin Only)'),
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade600, Colors.red.shade800],
                ),
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Module Selector
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _buildModuleButton(
                            'sales',
                            'Sales',
                            Icons.shopping_cart,
                          ),
                          _buildModuleButton(
                            'expenses',
                            'Expenses',
                            Icons.receipt,
                          ),
                          _buildModuleButton('closing', 'Closing', Icons.close),
                          _buildModuleButton(
                            'customers',
                            'Customers',
                            Icons.people,
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Column(
                        children: [
                          // Filter Section
                          _buildFilterSection(),

                          // Records List
                          Expanded(child: _buildRecordsList()),

                          // Action Buttons
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildModuleButton(String key, String label, IconData icon) {
    final isActive = _activeModule == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 20,
          color: isActive ? Colors.white : Colors.grey,
        ),
        label: Text(label),
        selected: isActive,
        onSelected: (_) {
          setState(() => _activeModule = key);
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.red.shade600,
        labelStyle: TextStyle(
          color: isActive ? Colors.white : Colors.grey[700],
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: isActive ? Colors.red.shade600 : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Date Range (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _selectedStartDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedStartDate?.toString().split(' ')[0] ??
                                'Select',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _selectedEndDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedEndDate?.toString().split(' ')[0] ??
                                'Select',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedStartDate != null || _selectedEndDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedStartDate = null;
                        _selectedEndDate = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_filteredRecords.length} record(s) found',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList() {
    final records = _filteredRecords;
    final selected = _selectedRecords[_activeModule] ?? {};

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No records found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        // Select All Checkbox
        Card(
          child: CheckboxListTile(
            value: selected.length == records.length && records.isNotEmpty,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedRecords[_activeModule] = records
                      .map((r) => r['id'] as String)
                      .toSet();
                } else {
                  _selectedRecords[_activeModule]?.clear();
                }
              });
            },
            title: Text(
              'Select All (${selected.length}/${records.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            checkboxShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...records.map((record) {
          final recordId = record['id'] as String;
          final isSelected = selected.contains(recordId);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedRecords[_activeModule]?.add(recordId);
                  } else {
                    _selectedRecords[_activeModule]?.remove(recordId);
                  }
                });
              },
              title: Text(_getRecordTitle(_activeModule, record)),
              subtitle: Text(_getRecordDate(_activeModule, record)),
              checkboxShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildActionButtons() {
    final selected = _selectedRecords[_activeModule]?.length ?? 0;
    final total = _allRecords[_activeModule]?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        color: Colors.grey[50],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: selected > 0 ? _deleteSelectedRecords : null,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete Selected ($selected)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      (_selectedStartDate != null || _selectedEndDate != null)
                      ? _deleteDateRange
                      : null,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Delete by Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: total > 0 ? _deleteAllRecords : null,
              icon: const Icon(Icons.delete_forever),
              label: Text('Delete All ($total)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
