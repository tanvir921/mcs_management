import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_time.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/models/customer_model.dart';
import '../../inventory/models/inventory_item.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';
import 'customer_autocomplete_field.dart';

class KhosraSellTab extends StatefulWidget {
  const KhosraSellTab({super.key});

  @override
  State<KhosraSellTab> createState() => _KhosraSellTabState();
}

class _KhosraSellTabState extends State<KhosraSellTab> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _paidCtrl = TextEditingController();
  final TextEditingController _costCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  int _quickQty = 1;
  bool _isBokeya = false;
  bool _isFullBokeya = true;
  bool _showMoreDetails = false;
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  InventoryItem? _selectedInventoryItem;
  DateTime? _customTime;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _paidCtrl.dispose();
    _costCtrl.dispose();
    _discountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _onQuickActionTap(KhosraQuickAction action) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    HapticFeedback.lightImpact();

    final qty = _quickQty;
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final created = await provider.addQuickSale(
      action,
      quantity: qty,
      userId: user.id,
      userName: user.name,
    );
    if (mounted && _quickQty != 1) setState(() => _quickQty = 1);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          'যোগ হয়েছে: ${created.name} ${qty > 1 ? "×$qty " : ""}— ${KhosraMoney.formatPaisa(created.amountPaisa)}',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => provider.deleteEntry(created.id),
        ),
      ),
    );
  }

  Future<void> _saveCustomSale() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final rawAmount = KhosraMoney.parseToPaisa(_amountCtrl.text);
    final discount = KhosraMoney.parseToPaisa(_discountCtrl.text);
    final netAmount = (rawAmount - discount).clamp(0, rawAmount);
    if (netAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('টাকার পরিমাণ লিখুন')));
      return;
    }

    final split = KhosraMoney.splitSalePayment(
      amountPaisa: netAmount,
      isBokeya: _isBokeya,
      isFullBokeya: _isFullBokeya,
      partialPaidPaisa: KhosraMoney.parseToPaisa(_paidCtrl.text),
    );
    final costPaisa = _costCtrl.text.trim().isEmpty
        ? (_selectedInventoryItem != null
              ? KhosraMoney.takaToPaisa(_selectedInventoryItem!.costPrice)
              : null)
        : KhosraMoney.parseToPaisa(_costCtrl.text);
    final rawName = _nameCtrl.text.trim();
    final entryName = rawName.isNotEmpty
        ? rawName
        : (_selectedInventoryItem?.name ?? _selectedCustomerName ?? 'Walk-in');

    HapticFeedback.mediumImpact();
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final createdList = await provider.addSale(
      name: entryName,
      customerId: _selectedCustomerId,
      amountPaisa: netAmount,
      paidPaisa: split.paidPaisa,
      duePaisa: split.duePaisa,
      costPaisa: costPaisa,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      details: {
        if (_selectedCustomerName != null) 'customerName': _selectedCustomerName,
        if (_selectedInventoryItem != null) ...{
          'inventoryItemId': _selectedInventoryItem!.id,
          'itemType': _selectedInventoryItem!.type.value,
        },
        if (discount > 0) 'discountPaisa': discount,
      },
      createdAt: _customTime,
      userId: user.id,
      userName: user.name,
    );

    setState(() {
      _nameCtrl.clear();
      _amountCtrl.clear();
      _paidCtrl.clear();
      _costCtrl.clear();
      _discountCtrl.clear();
      _noteCtrl.clear();
      _isBokeya = false;
      _isFullBokeya = true;
      _selectedCustomerId = null;
      _selectedCustomerName = null;
      _selectedInventoryItem = null;
      _customTime = null;
    });
    _amountFocus.requestFocus();

    final primary = createdList.first;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          split.duePaisa > 0
              ? 'বিক্রি ও বকেয়া (${KhosraMoney.formatPaisa(split.duePaisa)}) যোগ হয়েছে'
              : 'বিক্রি যোগ হয়েছে: ${KhosraMoney.formatPaisa(primary.amountPaisa)}',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => provider.deleteEntry(primary.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final split = KhosraMoney.splitSalePayment(
      amountPaisa: KhosraMoney.parseToPaisa(_amountCtrl.text),
      isBokeya: _isBokeya,
      isFullBokeya: _isFullBokeya,
      partialPaidPaisa: KhosraMoney.parseToPaisa(_paidCtrl.text),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: CustomerAutocompleteField(
                      controller: _nameCtrl,
                      selectedCustomerId: _selectedCustomerId,
                      labelText: 'নাম / পণ্য (ঐচ্ছিক)',
                      hintText: 'Walk-in',
                      onCustomerSelected: (Customer? c) => setState(() {
                        _selectedCustomerId = c?.id;
                        _selectedCustomerName = c?.name;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _amountCtrl,
                      focusNode: _amountFocus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'টাকা (৳)',
                        prefixText: '৳ ',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilterChip(
                    visualDensity: VisualDensity.compact,
                    selected: _isBokeya,
                    selectedColor: Colors.deepOrange.shade100,
                    label: const Text('বকেয়া?', style: TextStyle(fontSize: 12)),
                    onSelected: (val) => setState(() => _isBokeya = val),
                  ),
                  if (_isBokeya) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('পূর্ণ', style: TextStyle(fontSize: 12)),
                      selected: _isFullBokeya,
                      onSelected: (_) => setState(() => _isFullBokeya = true),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('আংশিক', style: TextStyle(fontSize: 12)),
                      selected: !_isFullBokeya,
                      onSelected: (_) => setState(() => _isFullBokeya = false),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _showMoreDetails = !_showMoreDetails),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _showMoreDetails ? 'কম তথ্য ▲' : '+ আরও তথ্য',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_isBokeya && !_isFullBokeya) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _paidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'জমা (Paid ৳)',
                          prefixText: '৳ ',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'বাকি: ${KhosraMoney.formatPaisa(split.duePaisa)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800),
                    ),
                  ],
                ),
              ],
              if (_showMoreDetails) ...[
                const SizedBox(height: 8),
                _buildMoreDetails(context),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saveCustomSale,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _isBokeya && split.duePaisa > 0
                      ? 'বিক্রি ও বকেয়া যোগ করুন (${KhosraMoney.formatPaisa(split.duePaisa)} বাকি)'
                      : 'বিক্রি যোগ করুন',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '১-ট্যাপ দ্রুত এন্ট্রি',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('সংখ্যা: ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                      _qtyBtn(Icons.remove, () {
                        if (_quickQty > 1) setState(() => _quickQty--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$_quickQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      _qtyBtn(Icons.add, () => setState(() => _quickQty = (_quickQty + 1).clamp(1, 99))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildQuickRow('বিক্রি:', KhosraConstants.generalSaleActions, Colors.teal.shade700, Colors.teal.shade50),
              const SizedBox(height: 6),
              _buildQuickRow('ফটোকপি:', KhosraConstants.photocopyActions, Colors.indigo.shade700, Colors.indigo.shade50),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 14),
      ),
    );
  }

  Widget _buildQuickRow(String label, List<KhosraQuickAction> actions, Color color, Color bg) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
        ...actions.map((action) {
          final totalPaisa = action.unitPricePaisa * _quickQty;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 5),
              child: InkWell(
                onTap: () => _onQuickActionTap(action),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    KhosraMoney.formatPaisa(totalPaisa),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMoreDetails(BuildContext context) {
    final inventoryItems = context.watch<InventoryProvider>().items;
    final bTime = AppTime.toBusiness(_customTime ?? AppTime.utcNow());
    return Column(
      children: [
        if (inventoryItems.isNotEmpty) ...[
          DropdownButtonFormField<InventoryItem?>(
            initialValue: _selectedInventoryItem,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'ইনভেন্টরি পণ্য (ঐচ্ছিক)', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem<InventoryItem?>(value: null, child: Text('সাধারণ আইটেম')),
              ...inventoryItems.map(
                (i) => DropdownMenuItem(value: i, child: Text('${i.name} (৳${i.sellingPrice.toStringAsFixed(0)})')),
              ),
            ],
            onChanged: (val) => setState(() {
              _selectedInventoryItem = val;
              if (val != null) {
                if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = val.name;
                _amountCtrl.text = val.sellingPrice.toStringAsFixed(0);
                _costCtrl.text = val.costPrice.toStringAsFixed(0);
              }
            }),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _costCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'কেনা দাম (৳)', prefixText: '৳ ', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'ছাড় (৳)', prefixText: '৳ ', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'নোট', border: OutlineInputBorder(), isDense: true),
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
                  final nextB = DateTime.utc(bTime.year, bTime.month, bTime.day, picked.hour, picked.minute);
                  setState(() => _customTime = AppTime.toUtcFromBusiness(nextB));
                }
              },
              icon: const Icon(Icons.schedule, size: 15),
              label: Text(DateFormat('hh:mm a').format(bTime)),
            ),
          ],
        ),
      ],
    );
  }
}
