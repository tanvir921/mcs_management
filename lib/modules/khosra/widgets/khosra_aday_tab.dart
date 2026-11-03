import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_time.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/models/customer_model.dart';
import '../../customer/models/due_transaction.dart';
import '../../customer/providers/customer_provider.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';
import 'customer_autocomplete_field.dart';

class KhosraAdayTab extends StatefulWidget {
  const KhosraAdayTab({super.key});

  @override
  State<KhosraAdayTab> createState() => _KhosraAdayTabState();
}

class _KhosraAdayTabState extends State<KhosraAdayTab> {
  final TextEditingController _customerSearchCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  Customer? _selectedCustomer;
  List<DueTransaction> _dueHistory = [];
  bool _loadingDues = false;
  String? _selectedDueRecordId;
  String _dueCategory = 'product'; // 'product' | 'cash_balance'
  bool _showNote = false;
  DateTime? _customTime;

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCustomerChosen(Customer? customer) async {
    setState(() {
      _selectedCustomer = customer;
      _selectedDueRecordId = null;
      _dueHistory = [];
    });
    if (customer == null) return;

    setState(() => _loadingDues = true);
    try {
      final txList = await context.read<CustomerProvider>().getDueHistory(
        customer.id,
      );
      if (mounted) {
        setState(() {
          _dueHistory = txList;
          _loadingDues = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingDues = false);
      }
    }
  }

  Future<void> _saveAday(List<OpenDueRecord> openRecords) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final customerName = _customerSearchCtrl.text.trim();
    if (customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('গ্রাহকের নাম লিখুন বা নির্বাচন করুন')),
      );
      return;
    }

    final amountPaisa = KhosraMoney.parseToPaisa(_amountCtrl.text);
    if (amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('আদায়ের সঠিক টাকার পরিমাণ লিখুন')),
      );
      return;
    }

    final record = openRecords
        .where((r) => r.id == _selectedDueRecordId)
        .firstOrNull;

    if (record != null && amountPaisa > record.effectiveRemainingPaisa) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'নির্বাচিত রেকর্ডের অবশিষ্ট বকেয়ার (${KhosraMoney.formatPaisa(record.effectiveRemainingPaisa)}) চেয়ে বেশি হতে পারবে না',
          ),
        ),
      );
      return;
    }

    final targetDueCategory = record?.dueCategory ?? _dueCategory;
    final targetRawDueType = record?.rawDueType ??
        (_dueCategory == 'cash_balance' ? 'cashBorrow' : 'product');
    final noteText = _noteCtrl.text.trim();

    // Confirmation Popup Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.payments_rounded, color: Colors.blue.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'আদায় নিশ্চিতকরণ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'গ্রাহক: $customerName',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'আদায়ের টাকা: ${KhosraMoney.formatPaisa(amountPaisa)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'খাত: ${targetDueCategory == "cash_balance" ? "নগদ/ব্যালেন্স বাকি আদায়" : "পণ্য বাকি আদায়"}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            if (record != null) ...[
              const SizedBox(height: 4),
              Text(
                'বকেয়া রেকর্ড: ${record.typeLabelBn} (${DateFormat("dd MMM").format(record.date)})',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (noteText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'নোট: $noteText',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'এই আদায় এন্ট্রিটি খসড়া খাতায় যুক্ত করতে চান?',
              style: TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('হ্যাঁ, আদায় যোগ করুন'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    HapticFeedback.mediumImpact();

    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final created = await provider.addAday(
      customerName: customerName,
      customerId: _selectedCustomer?.id,
      dueRecordId: record?.id,
      dueCategory: targetDueCategory,
      rawDueType: targetRawDueType,
      amountPaisa: amountPaisa,
      originalDuePaisa: record?.originalPaisa,
      potentialProfitPaisa: record?.potentialProfitPaisa,
      saleId: record?.saleId,
      note: noteText.isEmpty ? null : noteText,
      createdAt: _customTime,
      userId: user.id,
      userName: user.name,
    );

    setState(() {
      _customerSearchCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
      _selectedCustomer = null;
      _selectedDueRecordId = null;
      _dueHistory = [];
      _customTime = null;
    });

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          'আদায় যোগ হয়েছে: ${created.name} — ${KhosraMoney.formatPaisa(created.amountPaisa)}',
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
    final khosraProvider = context.watch<KhosraProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final bTime = AppTime.toBusiness(_customTime ?? AppTime.utcNow());

    final liveCustomer = _selectedCustomer == null
        ? null
        : (customerProvider.customers
                  .where((c) => c.id == _selectedCustomer!.id)
                  .firstOrNull ??
              _selectedCustomer);

    final openRecords = liveCustomer == null
        ? <OpenDueRecord>[]
        : OpenDueRecord.computeOpenDueRecords(
            customer: liveCustomer,
            dueHistory: _dueHistory,
            pendingEntries: khosraProvider.pendingEntries,
          );

    final selectedRecord = openRecords
        .where((r) => r.id == _selectedDueRecordId)
        .firstOrNull;

    final customerTotalDuePaisa = liveCustomer != null
        ? KhosraMoney.takaToPaisa(liveCustomer.totalDue)
        : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.payments_rounded, color: Colors.blue.shade700, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'বকেয়া আদায় (Aday Collection)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Customer Search / Input Field
          CustomerAutocompleteField(
            controller: _customerSearchCtrl,
            selectedCustomerId: liveCustomer?.id,
            requireExistingCustomer: false,
            labelText: 'গ্রাহকের নাম বা ফোন নম্বর',
            hintText: 'নাম বা মোবাইল নম্বর লিখুন...',
            onCustomerSelected: _onCustomerChosen,
          ),

          // Customer Live Dues Card (if customer selected)
          if (_loadingDues)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            )
          else if (liveCustomer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 16, color: Colors.blue.shade800),
                          const SizedBox(width: 5),
                          Text(
                            liveCustomer.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          if (liveCustomer.phone != null && liveCustomer.phone!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${liveCustomer.phone})',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: customerTotalDuePaisa > 0 ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: customerTotalDuePaisa > 0 ? Colors.red.shade200 : Colors.green.shade200,
                          ),
                        ),
                        child: Text(
                          'মোট বাকি: ${KhosraMoney.formatPaisa(customerTotalDuePaisa)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: customerTotalDuePaisa > 0 ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'পণ্য বাকি: ৳${liveCustomer.productDue.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      Text(
                        'নগদ/অন্যান্য: ৳${liveCustomer.cashBorrowDue.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      if (customerTotalDuePaisa > 0)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _amountCtrl.text = KhosraMoney.paisaToInputString(customerTotalDuePaisa);
                              _selectedDueRecordId = null;
                            });
                          },
                          child: Text(
                            '• সম্পূর্ণ আদায় করুন',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // 2. Open Due Records (if available)
          if (openRecords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'নির্দিষ্ট বাকি রেকর্ড (ঐচ্ছিক):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                if (_selectedDueRecordId != null)
                  TextButton(
                    onPressed: () => setState(() => _selectedDueRecordId = null),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('সাধারণ আদায়', style: TextStyle(fontSize: 11.5)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ...openRecords.map((rec) {
              final isSelected = rec.id == _selectedDueRecordId;
              final remPaisa = rec.effectiveRemainingPaisa;
              return InkWell(
                onTap: remPaisa > 0
                    ? () {
                        setState(() {
                          _selectedDueRecordId = rec.id;
                          _dueCategory = rec.dueCategory;
                          _amountCtrl.text = KhosraMoney.paisaToInputString(remPaisa);
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 16,
                        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.typeLabelBn,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            Text(
                              'মূল: ${KhosraMoney.formatPaisa(rec.originalPaisa)} • ${DateFormat('dd MMM').format(rec.date)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        KhosraMoney.formatPaisa(remPaisa),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: remPaisa > 0 ? Colors.blue.shade800 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 12),

          // 3. Amount Field & Due Category Chips (Always Prominently Visible)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'আদায়ের টাকা (৳) *',
                    hintText: '0',
                    prefixText: '৳ ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (selectedRecord != null && selectedRecord.effectiveRemainingPaisa > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.blue.shade50,
                    label: const Text('রেকর্ড পূর্ণ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _amountCtrl.text = KhosraMoney.paisaToInputString(
                          selectedRecord.effectiveRemainingPaisa,
                        );
                      });
                    },
                  ),
                )
              else if (liveCustomer != null && customerTotalDuePaisa > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.green.shade50,
                    label: const Text('সম্পূর্ণ বাকি', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _amountCtrl.text = KhosraMoney.paisaToInputString(customerTotalDuePaisa);
                      });
                    },
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Due Category Selector
          Row(
            children: [
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: const Text('পণ্য বাকি আদায়', style: TextStyle(fontSize: 12)),
                selected: _dueCategory == 'product',
                selectedColor: Colors.blue.shade100,
                onSelected: (_) => setState(() => _dueCategory = 'product'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: const Text('নগদ/ব্যালেন্স আদায়', style: TextStyle(fontSize: 12)),
                selected: _dueCategory == 'cash_balance',
                selectedColor: Colors.indigo.shade100,
                onSelected: (_) => setState(() => _dueCategory = 'cash_balance'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showNote = !_showNote),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showNote ? 'কম ▲' : '+ নোট / সময়',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),

          // Optional Note and Time
          if (_showNote) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'নোট (ঐচ্ছিক)',
                      hintText: 'যেমন: বিকাশে দিল, আংশিক ইত্যাদি',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: bTime.hour, minute: bTime.minute),
                    );
                    if (picked != null) {
                      final nextB = DateTime.utc(
                        bTime.year,
                        bTime.month,
                        bTime.day,
                        picked.hour,
                        picked.minute,
                      );
                      setState(() => _customTime = AppTime.toUtcFromBusiness(nextB));
                    }
                  },
                  icon: const Icon(Icons.schedule, size: 15),
                  label: Text(DateFormat('hh:mm a').format(bTime)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // 4. Primary Submit Button (Always Prominently Visible)
          FilledButton.icon(
            onPressed: () => _saveAday(openRecords),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: const Text(
              'আদায় যোগ করুন (Add Collection)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
          ),
        ],
      ),
    );
  }
}
