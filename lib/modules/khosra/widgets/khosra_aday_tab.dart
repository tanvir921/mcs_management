import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  bool _showNote = false;

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
    if (user == null || _selectedCustomer == null) return;

    final record = openRecords
        .where((r) => r.id == _selectedDueRecordId)
        .firstOrNull;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('একটি বকেয়া নির্বাচন করুন')),
      );
      return;
    }

    final amountPaisa = KhosraMoney.parseToPaisa(_amountCtrl.text);
    if (amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('আদায়ের পরিমাণ লিখুন')),
      );
      return;
    }

    if (amountPaisa > record.effectiveRemainingPaisa) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'অবশিষ্ট বকেয়ার (${KhosraMoney.formatPaisa(record.effectiveRemainingPaisa)}) চেয়ে বেশি হতে পারবে না',
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final created = await provider.addAday(
      customerName: _selectedCustomer!.name,
      customerId: _selectedCustomer!.id,
      dueRecordId: record.id,
      dueCategory: record.dueCategory,
      rawDueType: record.rawDueType,
      amountPaisa: amountPaisa,
      originalDuePaisa: record.originalPaisa,
      potentialProfitPaisa: record.potentialProfitPaisa,
      saleId: record.saleId,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      userId: user.id,
      userName: user.name,
    );

    setState(() {
      _amountCtrl.clear();
      _noteCtrl.clear();
      _selectedDueRecordId = null;
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

    if (_selectedDueRecordId == null && openRecords.isNotEmpty) {
      final firstOpen = openRecords
          .where((r) => r.effectiveRemainingPaisa > 0)
          .firstOrNull;
      if (firstOpen != null) {
        _selectedDueRecordId = firstOpen.id;
      }
    }

    final selectedRecord = openRecords
        .where((r) => r.id == _selectedDueRecordId)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerAutocompleteField(
            controller: _customerSearchCtrl,
            selectedCustomerId: liveCustomer?.id,
            requireExistingCustomer: true,
            labelText: 'গ্রাহকের নাম বা ফোন খুঁজুন',
            hintText: 'নাম বা মোবাইল নম্বর...',
            onCustomerSelected: _onCustomerChosen,
          ),
          if (_loadingDues)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (liveCustomer != null) ...[
            const SizedBox(height: 8),
            if (openRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${liveCustomer.name}-এর কোনো বকেয়া নেই।',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else ...[
              ...openRecords.map((rec) {
                final isSelected = rec.id == _selectedDueRecordId;
                final remPaisa = rec.effectiveRemainingPaisa;
                return InkWell(
                  onTap: remPaisa > 0
                      ? () {
                          setState(() {
                            _selectedDueRecordId = rec.id;
                            _amountCtrl.text = KhosraMoney.paisaToInputString(
                              remPaisa,
                            );
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue.shade600
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: isSelected
                              ? Colors.blue.shade700
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.typeLabelBn,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                [
                                  'মূল: ${KhosraMoney.formatPaisa(rec.originalPaisa)}',
                                  if (rec.pendingAdayPaisa > 0)
                                    'খসড়া বাদে',
                                  DateFormat('dd MMM').format(rec.date),
                                ].join(' • '),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          KhosraMoney.formatPaisa(remPaisa),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: remPaisa > 0
                                ? Colors.blue.shade800
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'আদায়ের টাকা (৳)',
                        prefixText: '৳ ',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  if (selectedRecord != null &&
                      selectedRecord.effectiveRemainingPaisa > 0) ...[
                    const SizedBox(width: 6),
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('পূর্ণ', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _amountCtrl.text = KhosraMoney.paisaToInputString(
                            selectedRecord.effectiveRemainingPaisa,
                          );
                        });
                      },
                    ),
                  ],
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => setState(() => _showNote = !_showNote),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _showNote ? 'কম ▲' : '+ নোট',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_showNote) ...[
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'নোট (ঐচ্ছিক)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _saveAday(openRecords),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'আদায় যোগ করুন',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
