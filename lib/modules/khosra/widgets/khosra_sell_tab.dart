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
  final TextEditingController _productNameCtrl = TextEditingController();
  final TextEditingController _customerCtrl = TextEditingController();
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
    _productNameCtrl.dispose();
    _customerCtrl.dispose();
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

    final qty = _quickQty;
    final totalTaka = action.unitPriceTaka * qty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.flash_on_rounded, color: Colors.teal.shade700, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'কুইক সেল নিশ্চিতকরণ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${action.labelBn} ${qty > 1 ? "($qtyটি × ৳${action.unitPriceTaka})" : ""}',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'মোট: ৳$totalTaka',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'এই এন্ট্রিটি খসড়া বিক্রিতে যোগ করতে চান?',
              style: TextStyle(fontSize: 13, color: Colors.black54),
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
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('হ্যাঁ, যোগ করুন'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    HapticFeedback.lightImpact();

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
      ).showSnackBar(const SnackBar(content: Text('বিক্রির সঠিক টাকার পরিমাণ লিখুন')));
      return;
    }

    // Separate Product Name & Customer Name
    final rawProdName = _productNameCtrl.text.trim();
    final productName = rawProdName.isNotEmpty
        ? rawProdName
        : (_selectedInventoryItem?.name ?? 'সাধারণ বিক্রি');

    final rawCustName = _customerCtrl.text.trim();
    final customerName = _selectedCustomerName ??
        (rawCustName.isNotEmpty ? rawCustName : 'Walk-in');

    if (_isBokeya &&
        (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) &&
        rawCustName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.deepOrange,
          content: Text('বকেয়া বিক্রির জন্য অনুগ্রহ করে গ্রাহকের নাম লিখুন বা নির্বাচন করুন'),
        ),
      );
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

    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.point_of_sale_rounded, color: Colors.teal.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'বিক্রি নিশ্চিতকরণ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('পণ্য: $productName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 4),
            Text('ক্রেতা: $customerName', style: TextStyle(color: Colors.grey.shade800, fontSize: 13.5)),
            const SizedBox(height: 8),
            Text(
              'মোট বিক্রি: ${KhosraMoney.formatPaisa(netAmount)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
            ),
            if (split.duePaisa > 0) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('নগদ জমা: ${KhosraMoney.formatPaisa(split.paidPaisa)}',
                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    Text('বকেয়া: ${KhosraMoney.formatPaisa(split.duePaisa)}',
                        style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text('এই বিক্রি এন্ট্রিটি খসড়া খাতায় যোগ করতে চান?', style: TextStyle(fontSize: 12.5, color: Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('হ্যাঁ, বিক্রি যোগ করুন'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final createdList = await provider.addSale(
      name: productName,
      customerId: _selectedCustomerId,
      amountPaisa: netAmount,
      paidPaisa: split.paidPaisa,
      duePaisa: split.duePaisa,
      costPaisa: costPaisa,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      details: {
        'customerName': customerName,
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
      _productNameCtrl.clear();
      _customerCtrl.clear();
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.point_of_sale_rounded, color: Colors.teal.shade700, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'নতুন বিক্রি এন্ট্রি (Sale Entry)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Separate Product Name & Amount Fields
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _productNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'পণ্যের নাম / বিবরণ (ঐচ্ছিক)',
                        hintText: 'যেমন: খাতা, কলম...',
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                      decoration: InputDecoration(
                        labelText: 'টাকা (৳) *',
                        prefixText: '৳ ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Separate Customer Search Field
              CustomerAutocompleteField(
                controller: _customerCtrl,
                selectedCustomerId: _selectedCustomerId,
                requireExistingCustomer: false,
                labelText: 'ক্রেতা / গ্রাহক (Customer)',
                hintText: 'Walk-in (খুচরা ক্রেতা) অথবা নাম খুঁজুন...',
                onCustomerSelected: (Customer? c) => setState(() {
                  _selectedCustomerId = c?.id;
                  _selectedCustomerName = c?.name;
                  if (c != null) {
                    _customerCtrl.text = c.name;
                  }
                }),
              ),
              const SizedBox(height: 10),

              // 3. Bokeya Toggles & More Details Toggle
              Row(
                children: [
                  FilterChip(
                    visualDensity: VisualDensity.compact,
                    selected: _isBokeya,
                    selectedColor: Colors.deepOrange.shade100,
                    label: const Text('বকেয়া?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onSelected: (val) => setState(() => _isBokeya = val),
                  ),
                  if (_isBokeya) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('পূর্ণ বাকি', style: TextStyle(fontSize: 12)),
                      selected: _isFullBokeya,
                      selectedColor: Colors.deepOrange.shade100,
                      onSelected: (_) => setState(() => _isFullBokeya = true),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: const Text('আংশিক জমা', style: TextStyle(fontSize: 12)),
                      selected: !_isFullBokeya,
                      selectedColor: Colors.amber.shade100,
                      onSelected: (_) => setState(() => _isFullBokeya = false),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _showMoreDetails = !_showMoreDetails),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _showMoreDetails ? 'কম তথ্য ▲' : '+ আরও তথ্য (ছাড়/সময়)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              if (_isBokeya && _selectedCustomerId == null && _customerCtrl.text.trim().isEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'বকেয়া বিক্রির জন্য নির্দিষ্ট গ্রাহক নির্বাচন বা নাম লিখুন',
                          style: TextStyle(fontSize: 11.5, color: Colors.brown.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_isBokeya && !_isFullBokeya) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _paidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'নগদ জমা (Paid ৳)',
                          prefixText: '৳ ',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.deepOrange.shade200),
                      ),
                      child: Text(
                        'বাকি: ${KhosraMoney.formatPaisa(split.duePaisa)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade800),
                      ),
                    ),
                  ],
                ),
              ],

              if (_showMoreDetails) ...[
                const SizedBox(height: 10),
                _buildMoreDetails(context),
              ],

              const SizedBox(height: 14),

              FilledButton.icon(
                onPressed: _saveCustomSale,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  _isBokeya && split.duePaisa > 0
                      ? 'বিক্রি ও বকেয়া যোগ করুন (${KhosraMoney.formatPaisa(split.duePaisa)} বাকি)'
                      : 'বিক্রি যোগ করুন (Add Sale)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 1-Tap Quick Action Cards
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 4),
                      Text(
                        '১-ট্যাপ দ্রুত এন্ট্রি (Quick Cards)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('পরিমাণ: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      _qtyBtn(Icons.remove, () {
                        if (_quickQty > 1) setState(() => _quickQty--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$_quickQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ),
                      _qtyBtn(Icons.add, () => setState(() => _quickQty = (_quickQty + 1).clamp(1, 99))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildQuickRow('বিক্রি:', KhosraConstants.generalSaleActions, Colors.teal.shade700, Colors.teal.shade50),
              const SizedBox(height: 8),
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
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey.shade50,
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }

  Widget _buildQuickRow(String label, List<KhosraQuickAction> actions, Color color, Color bg) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
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
                if (_productNameCtrl.text.trim().isEmpty) _productNameCtrl.text = val.name;
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
