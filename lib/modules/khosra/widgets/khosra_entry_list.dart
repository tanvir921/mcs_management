import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_time.dart';
import '../../customer/models/customer_model.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';
import 'customer_autocomplete_field.dart';

class KhosraEntryList extends StatelessWidget {
  final List<KhosraEntry> entries;
  final String emptyMessage;

  const KhosraEntryList({
    super.key,
    required this.entries,
    this.emptyMessage = 'আজ এখনও কোনো খসড়া এন্ট্রি যোগ করা হয়নি',
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.edit_note_rounded, size: 38, color: Colors.grey[400]),
              const SizedBox(height: 6),
              Text(
                emptyMessage,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isEditable = entry.status != KhosraEntryStatus.committed;
        return Dismissible(
          key: ValueKey('khosra_row_${entry.id}_${entry.updatedAt.millisecondsSinceEpoch}'),
          direction: isEditable ? DismissDirection.horizontal : DismissDirection.none,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await showKhosraEditSheet(context, entry);
              return false;
            }
            return await confirmDeleteDialog(context, entry);
          },
          onDismissed: (_) => _deleteWithUndo(context, entry),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 20),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
          ),
          child: _KhosraEntryRow(
            entry: entry,
            onEdit: isEditable ? () => showKhosraEditSheet(context, entry) : null,
            onDelete: isEditable
                ? () async {
                    final ok = await confirmDeleteDialog(context, entry);
                    if (ok && context.mounted) {
                      await _deleteWithUndo(context, entry);
                    }
                  }
                : null,
          ),
        );
      },
    );
  }

  static Future<bool> confirmDeleteDialog(BuildContext context, KhosraEntry entry) async {
    final result = await showDialog<bool>(
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
              child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'এন্ট্রি মুছবেন?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          entry.linkedEntryId != null
              ? '"${entry.displayName}" (${KhosraMoney.formatPaisa(entry.amountPaisa)}) এবং এর সাথে সংযুক্ত এন্ট্রি মুছে ফেলতে চান?'
              : '"${entry.displayName}" (${KhosraMoney.formatPaisa(entry.amountPaisa)}) খসড়া এন্ট্রিটি মুছে ফেলতে চান?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteWithUndo(BuildContext context, KhosraEntry entry) async {
    final provider = context.read<KhosraProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final originals = await provider.deleteEntry(entry.id);
    if (originals.isEmpty) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          originals.length > 1
              ? '"${entry.displayName}" এবং সংযুক্ত এন্ট্রি মুছে ফেলা হয়েছে'
              : '"${entry.displayName}" (${KhosraMoney.formatPaisa(entry.amountPaisa)}) মুছে ফেলা হয়েছে',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => provider.restoreDeletedEntries(originals),
        ),
      ),
    );
  }
}

class _KhosraEntryRow extends StatelessWidget {
  final KhosraEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _KhosraEntryRow({required this.entry, this.onEdit, this.onDelete});

  Color _typeColor(KhosraEntryType t) {
    switch (t) {
      case KhosraEntryType.sale:
        return const Color(0xFF0F766E);
      case KhosraEntryType.baki:
        return const Color(0xFFC2410C);
      case KhosraEntryType.khoroch:
        return const Color(0xFFBE123C);
      case KhosraEntryType.aday:
        return const Color(0xFF1D4ED8);
      case KhosraEntryType.other:
        return const Color(0xFF7C3AED);
    }
  }

  IconData _typeIcon(KhosraEntryType t) {
    switch (t) {
      case KhosraEntryType.sale:
        return Icons.point_of_sale_rounded;
      case KhosraEntryType.baki:
        return Icons.person_add_alt_1_rounded;
      case KhosraEntryType.khoroch:
        return Icons.receipt_long_rounded;
      case KhosraEntryType.aday:
        return Icons.payments_rounded;
      case KhosraEntryType.other:
        return Icons.edit_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bTime = AppTime.toBusiness(entry.createdAt);
    final timeStr = DateFormat('hh:mm a').format(bTime);
    final color = _typeColor(entry.type);
    final isCommitted = entry.status == KhosraEntryStatus.committed;
    final isFailed = entry.status == KhosraEntryStatus.failed;
    final customerName = entry.details?['customerName']?.toString();
    final discountPaisa = entry.details?['discountPaisa'];

    return InkWell(
      onTap: onEdit,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCommitted
              ? Colors.green.shade50.withValues(alpha: 0.4)
              : (isFailed ? Colors.red.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFailed
                ? Colors.red.shade300
                : (isCommitted ? Colors.green.shade200 : Colors.grey.shade200),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Modern Type Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(entry.type), size: 18, color: color),
            ),
            const SizedBox(width: 10),

            // Item / Customer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (entry.quantity > 1)
                        Text(
                          ' ×${entry.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (entry.linkedEntryId != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.link_rounded, size: 14, color: Colors.deepOrange.shade600),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (customerName != null &&
                          customerName.isNotEmpty &&
                          customerName != entry.displayName)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '👤 $customerName',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (entry.type == KhosraEntryType.sale && entry.duePaisa > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'বাকি: ${KhosraMoney.formatPaisa(entry.duePaisa)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.deepOrange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (discountPaisa is int && discountPaisa > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ছাড়: ৳${discountPaisa ~/ 100}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.purple.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (entry.note != null && entry.note!.isNotEmpty)
                        Text(
                          '• ${entry.note!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount & Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  KhosraMoney.formatPaisa(entry.amountPaisa),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                if (isCommitted)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 2),
                      Text(
                        'Committed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        InkWell(
                          onTap: onEdit,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.edit_outlined, size: 15, color: Colors.blue.shade700),
                          ),
                        ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade600),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet for editing an existing KhosraEntry.
Future<void> showKhosraEditSheet(BuildContext context, KhosraEntry entry) async {
  final nameCtrl = TextEditingController(text: entry.displayName);
  final productNameCtrl = TextEditingController(text: entry.displayName);
  final customerCtrl = TextEditingController(
    text: entry.details?['customerName']?.toString() ?? '',
  );
  final amountCtrl = TextEditingController(text: KhosraMoney.paisaToInputString(entry.amountPaisa));
  final paidCtrl = TextEditingController(text: KhosraMoney.paisaToInputString(entry.paidPaisa));
  final costCtrl = TextEditingController(
    text: entry.costPaisa != null ? KhosraMoney.paisaToInputString(entry.costPaisa!) : '',
  );
  final noteCtrl = TextEditingController(text: entry.note ?? '');
  String? selectedCustomerId = entry.customerId;
  KhosraEntryType selectedType = entry.type;
  DateTime selectedTime = entry.createdAt;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final bTime = AppTime.toBusiness(selectedTime);
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'এডিট (${selectedType.shortLabel})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  if (entry.type == KhosraEntryType.other || selectedType != entry.type) ...[
                    DropdownButtonFormField<KhosraEntryType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'ধরন',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: KhosraEntryType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.shortLabel)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (selectedType == KhosraEntryType.sale) ...[
                    TextFormField(
                      controller: productNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'পণ্যের নাম / বিবরণ *',
                        hintText: 'উদা: খাতা, কলম, তেল...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomerAutocompleteField(
                      controller: customerCtrl,
                      selectedCustomerId: selectedCustomerId,
                      labelText: 'ক্রেতার নাম (বাকি থাকলে আবশ্যক)',
                      hintText: 'ক্রেতার নাম বা ফোন লিখুন...',
                      onCustomerSelected: (Customer? c) => setSheetState(() {
                        selectedCustomerId = c?.id;
                        if (c != null) customerCtrl.text = c.name;
                      }),
                    ),
                  ] else if (selectedType == KhosraEntryType.baki || selectedType == KhosraEntryType.aday) ...[
                    CustomerAutocompleteField(
                      controller: nameCtrl,
                      selectedCustomerId: selectedCustomerId,
                      labelText: 'কাস্টমার / গ্রাহকের নাম *',
                      hintText: 'নাম বা মোবাইল নম্বর লিখুন...',
                      onCustomerSelected: (Customer? c) => setSheetState(() {
                        selectedCustomerId = c?.id;
                        if (c != null) nameCtrl.text = c.name;
                      }),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: selectedType == KhosraEntryType.khoroch ? 'খরচের বিবরণ *' : 'বিবরণ / শিরোনাম *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'মোট টাকা (৳)',
                            prefixText: '৳ ',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (selectedType == KhosraEntryType.sale) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: paidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'নগদ জমা (৳)',
                              prefixText: '৳ ',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (selectedType == KhosraEntryType.sale) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'কেনা দাম (৳)',
                        prefixText: '৳ ',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: noteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'নোট',
                            isDense: true,
                            border: OutlineInputBorder(),
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
                            setSheetState(() => selectedTime = AppTime.toUtcFromBusiness(nextB));
                          }
                        },
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(DateFormat('hh:mm a').format(bTime)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                        onPressed: () async {
                          final ok = await KhosraEntryList.confirmDeleteDialog(sheetCtx, entry);
                          if (ok && sheetCtx.mounted) {
                            await sheetCtx.read<KhosraProvider>().deleteEntry(entry.id);
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('মুছে ফেলুন'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final newAmount = KhosraMoney.parseToPaisa(amountCtrl.text);
                            if (newAmount <= 0) return;

                            final resolvedName = selectedType == KhosraEntryType.sale
                                ? (productNameCtrl.text.trim().isEmpty ? entry.name : productNameCtrl.text.trim())
                                : (nameCtrl.text.trim().isEmpty ? entry.name : nameCtrl.text.trim());

                            final confirmSave = await showDialog<bool>(
                              context: sheetCtx,
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
                                      child: Icon(Icons.edit_note_rounded, color: Colors.teal.shade700, size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('সংশোধন নিশ্চিতকরণ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                content: Text('"$resolvedName" (${KhosraMoney.formatPaisa(newAmount)}) এন্ট্রির পরিবর্তন সংরক্ষণ করতে চান?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.teal.shade700,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('হ্যাঁ, সংরক্ষণ করুন'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmSave != true) return;

                            int paidPaisa = newAmount;
                            int duePaisa = 0;
                            if (selectedType == KhosraEntryType.sale) {
                              final rawPaid = paidCtrl.text.trim().isEmpty
                                  ? newAmount
                                  : KhosraMoney.parseToPaisa(paidCtrl.text);
                              paidPaisa = rawPaid.clamp(0, newAmount);
                              duePaisa = newAmount - paidPaisa;
                            }
                            final costPaisa = costCtrl.text.trim().isEmpty
                                ? null
                                : KhosraMoney.parseToPaisa(costCtrl.text);

                            final details = Map<String, dynamic>.from(entry.details ?? {});
                            if (selectedType == KhosraEntryType.sale) {
                              final cName = customerCtrl.text.trim();
                              if (cName.isNotEmpty) {
                                details['customerName'] = cName;
                              } else {
                                details.remove('customerName');
                              }
                            }

                            final updated = entry.copyWith(
                              type: selectedType,
                              name: resolvedName,
                              customerId: selectedCustomerId,
                              clearCustomerId: selectedCustomerId == null,
                              amountPaisa: newAmount,
                              paidPaisa: paidPaisa,
                              duePaisa: duePaisa,
                              costPaisa: costPaisa,
                              clearCostPaisa: costPaisa == null,
                              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                              clearNote: noteCtrl.text.trim().isEmpty,
                              details: details,
                              createdAt: selectedTime,
                            );
                            await sheetCtx.read<KhosraProvider>().updateEntry(updated);
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          },
                          child: const Text('সেভ করুন'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
