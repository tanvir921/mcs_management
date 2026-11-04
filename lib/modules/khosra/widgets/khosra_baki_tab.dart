import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_time.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/models/customer_model.dart';
import '../../customer/providers/customer_provider.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';
import 'customer_autocomplete_field.dart';

class KhosraBakiTab extends StatefulWidget {
  const KhosraBakiTab({super.key});

  @override
  State<KhosraBakiTab> createState() => _KhosraBakiTabState();
}

class _KhosraBakiTabState extends State<KhosraBakiTab> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  String? _selectedCustomerId;
  Customer? _selectedCustomer;
  String _selectedCategoryKey = 'product'; // product | service | msfRecharge | cashBorrow | previousDue
  bool _showMoreDetails = false;
  DateTime? _customTime;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _selectCustomerForDue(Customer c) {
    setState(() {
      _nameCtrl.text = c.name;
      _selectedCustomerId = c.id;
      _selectedCustomer = c;
    });
    _amountFocus.requestFocus();
  }

  double _getCategoryAmount(Customer c, String key) {
    switch (key) {
      case 'product':
        return c.productDue;
      case 'service':
        return c.serviceDue;
      case 'msfRecharge':
        return c.msfRechargeDue;
      case 'cashBorrow':
        return c.cashBorrowDue;
      case 'previousDue':
        return c.previousDue;
      default:
        return 0.0;
    }
  }

  Future<void> _saveBaki() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final name = _nameCtrl.text.trim();
    final amountPaisa = KhosraMoney.parseToPaisa(_amountCtrl.text);

    if (name.isEmpty || amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('গ্রাহকের নাম এবং টাকার পরিমাণ লিখুন')),
      );
      return;
    }

    final categoryObj = KhosraConstants.dueCategories
        .firstWhere((cat) => cat.key == _selectedCategoryKey);
    final categoryLabel = categoryObj.labelBn;
    final noteText = _noteCtrl.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(categoryObj.icon, color: Colors.deepOrange.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'বকেয়া নিশ্চিতকরণ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('গ্রাহকের নাম: $name', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            const SizedBox(height: 6),
            Text(
              'বকেয়ার টাকা: ${KhosraMoney.formatPaisa(amountPaisa)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: Text(
                    'খাত: $categoryLabel',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.deepOrange.shade900),
                  ),
                ),
              ],
            ),
            if (noteText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('নোট: $noteText', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            const Text('এই বকেয়া এন্ট্রিটি খসড়া খাতায় যুক্ত করতে চান?', style: TextStyle(fontSize: 12.5, color: Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('হ্যাঁ, বকেয়া যোগ করুন'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final created = await provider.addBaki(
      name: name,
      customerId: _selectedCustomerId,
      amountPaisa: amountPaisa,
      dueType: _selectedCategoryKey,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      details: {'rawDueType': _selectedCategoryKey},
      createdAt: _customTime,
      userId: user.id,
      userName: user.name,
    );

    setState(() {
      _nameCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
      _selectedCustomerId = null;
      _selectedCustomer = null;
      _customTime = null;
    });

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          'বকেয়া যোগ হয়েছে: ${created.name} ($categoryLabel) — ${KhosraMoney.formatPaisa(created.amountPaisa)}',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => provider.deleteEntry(created.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bTime = AppTime.toBusiness(_customTime ?? AppTime.utcNow());
    final allRegistered = context.watch<CustomerProvider>().customers;
    final khosraEntries = context.watch<KhosraProvider>().entries;

    // Resolve current selected customer object if registered
    final resolvedCustomer = _selectedCustomer ??
        allRegistered.where((c) => c.id == _selectedCustomerId).firstOrNull;

    // Group today's dues by customer name
    final todayDueCustomers = <String, ({String name, String? customerId, int totalDuePaisa, Map<String, int> categories})>{};
    for (final e in khosraEntries) {
      if (e.type == KhosraEntryType.baki || (e.type == KhosraEntryType.sale && e.duePaisa > 0)) {
        final custName = e.type == KhosraEntryType.sale
            ? ((e.details?['customerName'] as String?)?.trim().isNotEmpty == true
                ? (e.details!['customerName'] as String).trim()
                : e.name)
            : e.name;
        if (custName.isEmpty) continue;

        final duePaisa = e.type == KhosraEntryType.sale ? e.duePaisa : e.amountPaisa;
        final catKey = (e.details?['rawDueType'] as String?) ?? (e.dueType ?? 'product');

        final existing = todayDueCustomers[custName.toLowerCase()];
        if (existing == null) {
          todayDueCustomers[custName.toLowerCase()] = (
            name: custName,
            customerId: e.customerId,
            totalDuePaisa: duePaisa,
            categories: {catKey: duePaisa},
          );
        } else {
          final updatedCats = Map<String, int>.from(existing.categories);
          updatedCats[catKey] = (updatedCats[catKey] ?? 0) + duePaisa;
          todayDueCustomers[custName.toLowerCase()] = (
            name: existing.name,
            customerId: existing.customerId ?? e.customerId,
            totalDuePaisa: existing.totalDuePaisa + duePaisa,
            categories: updatedCats,
          );
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Customer input and Amount input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: CustomerAutocompleteField(
                  controller: _nameCtrl,
                  selectedCustomerId: _selectedCustomerId,
                  labelText: 'গ্রাহকের নাম *',
                  hintText: 'নাম বা ফোন নম্বর লিখুন...',
                  onCustomerSelected: (Customer? c) {
                    setState(() {
                      _selectedCustomerId = c?.id;
                      _selectedCustomer = c;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _amountCtrl,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'বকেয়া টাকা (৳) *',
                    prefixText: '৳ ',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. All 5 Due Category Chips
          Text(
            'বকেয়ার খাত নির্বাচন করুন (Category):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: KhosraConstants.dueCategories.map((cat) {
              final isSelected = _selectedCategoryKey == cat.key;
              return ChoiceChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  cat.icon,
                  size: 14,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                label: Text(
                  cat.labelBn,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                selected: isSelected,
                selectedColor: Colors.deepOrange.shade700,
                backgroundColor: Colors.grey.shade100,
                onSelected: (val) {
                  if (val) setState(() => _selectedCategoryKey = cat.key);
                },
              );
            }).toList(),
          ),

          // 3. Customer Category Amounts & Live Balance Reflection
          if (resolvedCustomer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${resolvedCustomer.name}-এর বর্তমান বকেয়ার খাতসমূহ:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                      Text(
                        'মোট: ৳${resolvedCustomer.totalDue.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: KhosraConstants.dueCategories.map((cat) {
                      final amt = _getCategoryAmount(resolvedCustomer, cat.key);
                      final isCurrentCat = _selectedCategoryKey == cat.key;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCurrentCat ? Colors.deepOrange.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCurrentCat ? Colors.deepOrange.shade400 : Colors.grey.shade300,
                            width: isCurrentCat ? 1.4 : 1,
                          ),
                        ),
                        child: Text(
                          '${cat.labelBn}: ৳${amt.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrentCat ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentCat ? Colors.deepOrange.shade900 : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Live projection for selected category
                  Builder(builder: (ctx) {
                    final curr = _getCategoryAmount(resolvedCustomer, _selectedCategoryKey);
                    final enteredPaisa = KhosraMoney.parseToPaisa(_amountCtrl.text);
                    final enteredTaka = KhosraMoney.paisaToTaka(enteredPaisa);
                    final newTotal = curr + enteredTaka;

                    if (enteredTaka > 0) {
                      final selectedCatLabel = KhosraConstants.dueCategories
                          .firstWhere((c) => c.key == _selectedCategoryKey)
                          .labelBn;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '➜ এই এন্ট্রির পর $selectedCatLabel হবে: ৳${curr.toStringAsFixed(0)} + ৳${enteredTaka.toStringAsFixed(0)} = ৳${newTotal.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // 4. Details / Note toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _showMoreDetails = !_showMoreDetails),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showMoreDetails ? 'কম তথ্য ▲' : '+ নোট / সময় পরিবর্তন',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (_selectedCustomerId != null || _nameCtrl.text.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _nameCtrl.clear();
                      _amountCtrl.clear();
                      _noteCtrl.clear();
                      _selectedCustomerId = null;
                      _selectedCustomer = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('রিসেট', style: TextStyle(fontSize: 11.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),

          if (_showMoreDetails) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'নোট বা পণ্যের বিবরণ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: bTime.hour,
                        minute: bTime.minute,
                      ),
                    );
                    if (picked != null) {
                      final nextB = DateTime.utc(
                        bTime.year,
                        bTime.month,
                        bTime.day,
                        picked.hour,
                        picked.minute,
                      );
                      setState(
                        () => _customTime = AppTime.toUtcFromBusiness(nextB),
                      );
                    }
                  },
                  icon: const Icon(Icons.schedule, size: 15),
                  label: Text(DateFormat('hh:mm a').format(bTime)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // 5. Submit Button
          FilledButton.icon(
            onPressed: _saveBaki,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text(
              'বকেয়া যোগ করুন (Add Bokeya)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // 6. Request 3 Feature: Today's Due Customers Quick Re-add & Modify
          if (todayDueCustomers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_edu_rounded, size: 17, color: Colors.deepOrange.shade800),
                    const SizedBox(width: 6),
                    Text(
                      'আজকের বকেয়া গ্রহণকারী গ্রাহকগণ (${todayDueCustomers.length})',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    ),
                  ],
                ),
                Text(
                  'ক্লিক করে পুনরায় বাকি যোগ করুন',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayDueCustomers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final cust = todayDueCustomers.values.elementAt(index);
                final registered = allRegistered.where((c) => c.name.toLowerCase() == cust.name.toLowerCase() || (cust.customerId != null && c.id == cust.customerId)).firstOrNull;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.deepOrange.shade100,
                        child: Text(
                          cust.name.isNotEmpty ? cust.name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  cust.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'আজ মোট: ${KhosraMoney.formatPaisa(cust.totalDuePaisa)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800),
                                ),
                              ],
                            ),
                            Text(
                              cust.categories.entries.map((cat) {
                                final label = KhosraConstants.dueCategories.where((c) => c.key == cat.key).firstOrNull?.labelBn ?? cat.key;
                                return '$label: ${KhosraMoney.formatPaisa(cat.value)}';
                              }).join(' • '),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.deepOrange.shade50,
                          foregroundColor: Colors.deepOrange.shade800,
                        ),
                        onPressed: () {
                          if (registered != null) {
                            _selectCustomerForDue(registered);
                          } else {
                            final synthetic = Customer(
                              id: cust.customerId ?? 'intraday_${cust.name.toLowerCase().replaceAll(' ', '_')}',
                              name: cust.name,
                              createdAt: AppTime.utcNow(),
                              updatedAt: AppTime.utcNow(),
                              isActive: true,
                              productDue: KhosraMoney.paisaToTaka(cust.totalDuePaisa),
                            );
                            _selectCustomerForDue(synthetic);
                          }
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('বাকি যোগ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
