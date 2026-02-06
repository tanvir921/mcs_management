import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/due_transaction.dart';
import '../models/purchase_history.dart';
import '../services/customer_service.dart';

class CustomerDueTrackerScreen extends StatefulWidget {
  const CustomerDueTrackerScreen({super.key});

  @override
  State<CustomerDueTrackerScreen> createState() =>
      _CustomerDueTrackerScreenState();
}

class _CustomerDueTrackerScreenState extends State<CustomerDueTrackerScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final CustomerService _customerService = CustomerService();

  bool _isLoading = false;
  String? _errorMessage;
  Customer? _customer;
  List<DueTransaction> _transactions = [];
  List<PurchaseHistory> _purchases = [];
  int _selectedTab = 0; // 0 = Due History, 1 = Purchase History

  @override
  void initState() {
    super.initState();
    // Redirect to home if not web
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/home');
      });
    }
  }

  Future<void> _searchCustomer() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'অনুগ্রহ করে ফোন নম্বর লিখুন';
        _customer = null;
        _transactions = [];
        _purchases = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _customer = null;
      _transactions = [];
      _purchases = [];
      _selectedTab = 0;
    });

    try {
      final customer = await _customerService.getCustomerByPhone(
        _phoneController.text.trim(),
      );

      if (customer == null) {
        setState(() {
          _errorMessage = 'এই নম্বরে কোনো গ্রাহক খুঁজে পাওয়া যায়নি।';
          _isLoading = false;
        });
        return;
      }

      final transactions = await _customerService.getDueTransactions(
        customer.id,
      );
      final purchases = await _customerService.getPurchaseHistory(customer.id);

      setState(() {
        _customer = customer;
        _transactions = transactions;
        _purchases = purchases;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'সমস্যা হয়েছে। আবার চেষ্টা করুন।';
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return '৳${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _getDueTypeLabel(String dueType) {
    switch (dueType) {
      case 'product':
        return 'পণ্য বকেয়া';
      case 'service':
        return 'সার্ভিস বকেয়া';
      case 'msfRecharge':
        return 'MSF/রিচার্জ বকেয়া';
      case 'cashBorrow':
        return 'নগদ ঋণ';
      case 'previousDue':
        return 'পূর্ববর্তী বকেয়া';
      default:
        return dueType;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final maxWidth = isMobile ? double.infinity : (isTablet ? 900.0 : 1200.0);
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 32.0 : 48.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isMobile ? 16.0 : 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: isMobile ? 20 : 40),

                // Header
                _buildHeader(isMobile),

                SizedBox(height: isMobile ? 20 : 32),

                // Search Card
                _buildSearchCard(isMobile),

                // Error Message
                if (_errorMessage != null) ...[
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildErrorMessage(),
                ],

                // Customer Due Summary
                if (_customer != null) ...[
                  SizedBox(height: isMobile ? 16 : 24),
                  _buildCustomerInfo(isMobile),

                  SizedBox(height: isMobile ? 16 : 24),
                  _buildDueSummary(isMobile),

                  SizedBox(height: isMobile ? 16 : 24),
                  _buildTabSelector(isMobile),

                  SizedBox(height: isMobile ? 12 : 16),
                  _buildHistorySection(isMobile),
                ],

                SizedBox(height: isMobile ? 30 : 40),

                // Footer
                _buildFooter(),

                SizedBox(height: isMobile ? 20 : 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Card(
      elevation: isMobile ? 4 : 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
      ),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 24 : 40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1976D2), Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: isMobile ? 48 : 64,
                color: Colors.white,
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              'গ্রাহক বকেয়া ট্র্যাকার',
              style: TextStyle(
                fontSize: isMobile ? 24 : 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'MCS Management System',
              style: TextStyle(
                fontSize: isMobile ? 14 : 18,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(bool isMobile) {
    return Card(
      elevation: isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.search,
                  color: const Color(0xFF1976D2),
                  size: isMobile ? 24 : 28,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(
                    'আপনার বকেয়া দেখতে ফোন নম্বর লিখুন',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF263238),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: isMobile ? 16 : 18),
              decoration: InputDecoration(
                labelText: 'ফোন নম্বর',
                hintText: '01XXXXXXXXX',
                prefixIcon: const Icon(Icons.phone_android),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1976D2),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onSubmitted: (_) => _searchCustomer(),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _searchCustomer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'খুঁজুন',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
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

  Widget _buildErrorMessage() {
    return Card(
      color: const Color(0xFFFFEBEE),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEF5350), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo(bool isMobile) {
    return Card(
      elevation: isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1976D2).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: isMobile ? 28 : 36,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customer!.name,
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_customer!.phone != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 16,
                              color: Color(0xFF757575),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _customer!.phone!,
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                color: const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32, thickness: 1),

            // Payment Request Message
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB300), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: const Color(0xFFE65100),
                      size: isMobile ? 24 : 32,
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Text(
                      'দয়া করে আপনার বকেয়া টাকা পরিশোধ করুন।',
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE65100),
                      ),
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

  Widget _buildDueSummary(bool isMobile) {
    return Card(
      elevation: isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Due
            Container(
              padding: EdgeInsets.all(isMobile ? 20 : 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _customer!.totalDue > 0
                      ? [
                          const Color(0xFFD32F2F),
                          const Color(0xFFC62828),
                          const Color(0xFFB71C1C),
                        ]
                      : [
                          const Color(0xFF388E3C),
                          const Color(0xFF2E7D32),
                          const Color(0xFF1B5E20),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_customer!.totalDue > 0
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF388E3C))
                            .withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _customer!.totalDue > 0
                            ? Icons.trending_up
                            : Icons.check_circle_outline,
                        color: Colors.white,
                        size: isMobile ? 24 : 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'মোট বকেয়া',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  Text(
                    _formatCurrency(_customer!.totalDue),
                    style: TextStyle(
                      fontSize: isMobile ? 32 : 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isMobile ? 20 : 28),

            // Due Breakdown Header
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: const Color(0xFF1976D2),
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Text(
                  'বকেয়ার বিস্তারিত',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF263238),
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 16 : 20),

            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildDueItem(
                    'পণ্য বকেয়া',
                    _customer!.productDue,
                    Icons.shopping_bag,
                    isMobile,
                  ),
                  _buildDueDivider(),
                  _buildDueItem(
                    'সার্ভিস বকেয়া',
                    _customer!.serviceDue,
                    Icons.build,
                    isMobile,
                  ),
                  _buildDueDivider(),
                  _buildDueItem(
                    'MSF/রিচার্জ বকেয়া',
                    _customer!.msfRechargeDue,
                    Icons.sim_card,
                    isMobile,
                  ),
                  _buildDueDivider(),
                  _buildDueItem(
                    'নগদ ঋণ',
                    _customer!.cashBorrowDue,
                    Icons.money,
                    isMobile,
                  ),
                  _buildDueDivider(),
                  _buildDueItem(
                    'পূর্ববর্তী বকেয়া',
                    _customer!.previousDue,
                    Icons.history,
                    isMobile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 1),
    );
  }

  Widget _buildTabSelector(bool isMobile) {
    return Card(
      elevation: isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                label: 'বকেয়া ইতিহাস',
                icon: Icons.account_balance_wallet,
                index: 0,
                count: _transactions.length,
                isMobile: isMobile,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTabButton(
                label: 'ক্রয়ের ইতিহাস',
                icon: Icons.shopping_cart,
                index: 1,
                count: _purchases.length,
                isMobile: isMobile,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required int index,
    required int count,
    required bool isMobile,
  }) {
    final isSelected = _selectedTab == index;

    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 12 : 16,
          horizontal: isMobile ? 8 : 12,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF757575),
                  size: isMobile ? 18 : 20,
                ),
                const SizedBox(width: 6),
                if (!isMobile)
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF757575),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            if (isMobile) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF757575),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF757575),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(bool isMobile) {
    if (_selectedTab == 0) {
      return _buildTransactionHistory(isMobile);
    } else {
      return _buildPurchaseHistory(isMobile);
    }
  }

  Widget _buildTransactionHistory(bool isMobile) {
    if (_transactions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long,
        message: 'কোনো লেনদেনের ইতিহাস নেই',
        isMobile: isMobile,
      );
    }

    return Card(
      elevation: isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: const Color(0xFF1976D2),
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(
                    'লেনদেনের সম্পূর্ণ ইতিহাস',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF263238),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_transactions.length} টি',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => SizedBox(height: isMobile ? 12 : 16),
              itemBuilder: (context, index) {
                return _buildTransactionItem(_transactions[index], isMobile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseHistory(bool isMobile) {
    if (_purchases.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_cart,
        message: 'কোনো ক্রয়ের ইতিহাস নেই',
        isMobile: isMobile,
      );
    }

    return Card(
      elevation: isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_bag,
                  color: const Color(0xFF1976D2),
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(
                    'ক্রয়ের সম্পূর্ণ ইতিহাস',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF263238),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_purchases.length} টি',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _purchases.length,
              separatorBuilder: (_, __) => SizedBox(height: isMobile ? 12 : 16),
              itemBuilder: (context, index) {
                return _buildPurchaseItem(_purchases[index], isMobile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required bool isMobile,
  }) {
    return Card(
      elevation: isMobile ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 40 : 60),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isMobile ? 48 : 64,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            Text(
              message,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'MCS Management System',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF546E7A),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} All Rights Reserved',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  Widget _buildDueItem(
    String label,
    double amount,
    IconData icon,
    bool isMobile,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: amount > 0
                  ? const Color(0xFFD32F2F).withOpacity(0.1)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: isMobile ? 18 : 20,
              color: amount > 0 ? const Color(0xFFD32F2F) : Colors.grey[600],
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: const Color(0xFF546E7A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: isMobile ? 15 : 17,
              fontWeight: FontWeight.bold,
              color: amount > 0
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(DueTransaction transaction, bool isMobile) {
    final isAddition = transaction.isAddition;
    final color = isAddition
        ? const Color(0xFFD32F2F)
        : const Color(0xFF388E3C);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.08), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isAddition ? Icons.add_circle : Icons.remove_circle,
                  size: isMobile ? 18 : 22,
                  color: color,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDueTypeLabel(transaction.dueType),
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(transaction.createdAt),
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isAddition ? '+' : '-'} ${_formatCurrency(transaction.amount)}',
                    style: TextStyle(
                      fontSize: isMobile ? 17 : 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (isAddition)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'বকেয়া',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD32F2F),
                        ),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF388E3C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'পরিশোধ',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF388E3C),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (transaction.note != null && transaction.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.note,
                    size: isMobile ? 14 : 16,
                    color: const Color(0xFF757575),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      transaction.note!,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: const Color(0xFF546E7A),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPurchaseItem(PurchaseHistory purchase, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
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
                  color: const Color(0xFF1976D2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shopping_bag_rounded,
                  size: isMobile ? 18 : 22,
                  color: const Color(0xFF1976D2),
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.description,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(purchase.createdAt),
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(purchase.amount),
                style: TextStyle(
                  fontSize: isMobile ? 17 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          if (purchase.note != null && purchase.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF1976D2).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: isMobile ? 14 : 16,
                    color: const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      purchase.note!,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: const Color(0xFF546E7A),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
