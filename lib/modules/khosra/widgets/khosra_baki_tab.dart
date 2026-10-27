import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_time.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/models/customer_model.dart';
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

  String? _selectedCustomerId;
  String _dueType = 'product'; // 'product' | 'cash_balance'
  bool _showMoreDetails = false;
  DateTime? _customTime;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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

    HapticFeedback.mediumImpact();
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final rawDueType = _dueType == 'product' ? 'product' : 'cashBorrow';
    final created = await provider.addBaki(
      name: name,
      customerId: _selectedCustomerId,
      amountPaisa: amountPaisa,
      dueType: _dueType,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      details: {'rawDueType': rawDueType},
      createdAt: _customTime,
      userId: user.id,
      userName: user.name,
    );

    setState(() {
      _nameCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
      _selectedCustomerId = null;
      _customTime = null;
    });

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          'বকেয়া যোগ হয়েছে: ${created.name} — ${KhosraMoney.formatPaisa(created.amountPaisa)}',
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
          Row(
            children: [
              Expanded(
                flex: 5,
                child: CustomerAutocompleteField(
                  controller: _nameCtrl,
                  selectedCustomerId: _selectedCustomerId,
                  labelText: 'গ্রাহকের নাম',
                  hintText: 'নাম বা ফোন...',
                  onCustomerSelected: (Customer? c) {
                    setState(() => _selectedCustomerId = c?.id);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
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
                    labelText: 'টাকা (৳)',
                    prefixText: '৳ ',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: const Text('পণ্য বাকি', style: TextStyle(fontSize: 12)),
                selected: _dueType == 'product',
                onSelected: (_) => setState(() => _dueType = 'product'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: const Text('নগদ/ব্যালেন্স', style: TextStyle(fontSize: 12)),
                selected: _dueType == 'cash_balance',
                onSelected: (_) => setState(() => _dueType = 'cash_balance'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    setState(() => _showMoreDetails = !_showMoreDetails),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showMoreDetails ? 'কম তথ্য ▲' : '+ নোট/সময়',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (_showMoreDetails) ...[
            const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveBaki,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'বকেয়া যোগ করুন',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
