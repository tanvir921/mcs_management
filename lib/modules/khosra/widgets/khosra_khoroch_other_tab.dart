import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_time.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';

class KhosraKhorochTab extends StatefulWidget {
  const KhosraKhorochTab({super.key});

  @override
  State<KhosraKhorochTab> createState() => _KhosraKhorochTabState();
}

class _KhosraKhorochTabState extends State<KhosraKhorochTab> {
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  String _selectedCategory = 'shop';
  bool _showMore = false;
  DateTime? _customTime;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKhoroch() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final amountPaisa = KhosraMoney.parseToPaisa(_amountCtrl.text);
    if (amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('খরচের পরিমাণ লিখুন')),
      );
      return;
    }

    final catLabel = KhosraConstants.expenseCategories
        .where((c) => c.id == _selectedCategory)
        .map((c) => c.labelBn)
        .firstOrNull;
    final desc = _descCtrl.text.trim().isNotEmpty
        ? _descCtrl.text.trim()
        : (catLabel ?? 'দোকান খরচ');
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
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_long_rounded, color: Colors.red.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'খরচ নিশ্চিতকরণ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('বিবরণ: $desc', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              'খরচের টাকা: ${KhosraMoney.formatPaisa(amountPaisa)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade800),
            ),
            const SizedBox(height: 6),
            Text('ক্যাটাগরি: ${catLabel ?? _selectedCategory}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            if (noteText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('নোট: $noteText', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 10),
            const Text('এই খরচ এন্ট্রিটি খসড়া খাতায় যুক্ত করতে চান?', style: TextStyle(fontSize: 12.5, color: Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('হ্যাঁ, খরচ যোগ করুন'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final created = await provider.addKhoroch(
      description: desc,
      amountPaisa: amountPaisa,
      expenseCategory: _selectedCategory,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: _customTime,
      userId: user.id,
      userName: user.name,
    );

    setState(() {
      _descCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
      _customTime = null;
    });

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          'খরচ যোগ হয়েছে: ${created.name} — ${KhosraMoney.formatPaisa(created.amountPaisa)}',
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
                child: TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: 'খরচের বিবরণ (ঐচ্ছিক)',
                    hintText: 'চা-নাস্তা, মাল ক্রয়...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: KhosraConstants.expenseCategories.map((cat) {
                      final selected = _selectedCategory == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            cat.labelBn,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          selected: selected,
                          selectedColor: Colors.red.shade100,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showMore = !_showMore),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showMore ? 'কম ▲' : '+ নোট',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (_showMore) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'নোট (ঐচ্ছিক)',
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
            onPressed: _saveKhoroch,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'খরচ যোগ করুন',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class KhosraOtherTab extends StatefulWidget {
  const KhosraOtherTab({super.key});

  @override
  State<KhosraOtherTab> createState() => _KhosraOtherTabState();
}

class _KhosraOtherTabState extends State<KhosraOtherTab> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveOther() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final name = _nameCtrl.text.trim();
    final amountPaisa = KhosraMoney.parseToPaisa(_amountCtrl.text);
    if (name.isEmpty || amountPaisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('বিবরণ এবং টাকার পরিমাণ লিখুন')),
      );
      return;
    }

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
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.note_alt_rounded, color: Colors.purple.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'অন্যান্য খসড়া নিশ্চিতকরণ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('বিবরণ: $name', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              'টাকার পরিমাণ: ${KhosraMoney.formatPaisa(amountPaisa)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
            ),
            if (noteText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('নোট: $noteText', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 10),
            const Text('এই এন্ট্রিটি খসড়া খাতায় যুক্ত করতে চান?', style: TextStyle(fontSize: 12.5, color: Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
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

    HapticFeedback.mediumImpact();
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final created = await provider.addOther(
      name: name,
      amountPaisa: amountPaisa,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      userId: user.id,
      userName: user.name,
    );

    setState(() {
      _nameCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
    });

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          'নোট যোগ হয়েছে: ${created.name} — ${KhosraMoney.formatPaisa(created.amountPaisa)}',
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
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'বিবরণ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'নোট (ঐচ্ছিক)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveOther,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'খসড়া যোগ করুন',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
