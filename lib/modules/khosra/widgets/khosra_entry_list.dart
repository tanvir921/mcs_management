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
            return true;
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
            onDelete: isEditable ? () => _deleteWithUndo(context, entry) : null,
          ),
        );
      },
    );
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
              ? '"${entry.name}" এবং সংযুক্ত এন্ট্রি মুছে ফেলা হয়েছে'
              : '"${entry.name}" (${KhosraMoney.formatPaisa(entry.amountPaisa)}) মুছে ফেলা হয়েছে',
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
        return Colors.teal.shade700;
      case KhosraEntryType.baki:
        return Colors.deepOrange.shade700;
      case KhosraEntryType.khoroch:
        return Colors.red.shade700;
      case KhosraEntryType.aday:
        return Colors.blue.shade700;
      case KhosraEntryType.other:
        return Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bTime = AppTime.toBusiness(entry.createdAt);
    final timeStr = DateFormat('hh:mm a').format(bTime);
    final color = _typeColor(entry.type);
    final isCommitted = entry.status == KhosraEntryStatus.committed;
    final isFailed = entry.status == KhosraEntryStatus.failed;

    return InkWell(
      onTap: onEdit,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isCommitted
              ? Colors.green.shade50.withValues(alpha: 0.45)
              : (isFailed ? Colors.red.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFailed
                ? Colors.red.shade300
                : (isCommitted ? Colors.green.shade200 : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.type.shortLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (entry.quantity > 1)
                        Text(
                          ' ×${entry.quantity}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      if (entry.linkedEntryId != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.link_rounded, size: 14, color: Colors.deepOrange.shade600),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (entry.type == KhosraEntryType.sale && entry.duePaisa > 0)
                        Flexible(
                          child: Text(
                            ' • বাকি: ${KhosraMoney.formatPaisa(entry.duePaisa)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.deepOrange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (entry.note != null && entry.note!.isNotEmpty)
                        Flexible(
                          child: Text(
                            ' • ${entry.note!}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              KhosraMoney.formatPaisa(entry.amountPaisa),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 4),
            if (isCommitted)
              Icon(Icons.check_circle, size: 16, color: Colors.green.shade700)
            else if (onDelete != null)
              InkWell(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet for editing an existing KhosraEntry.
Future<void> showKhosraEditSheet(BuildContext context, KhosraEntry entry) async {
  final nameCtrl = TextEditingController(text: entry.name);
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
                  CustomerAutocompleteField(
                    controller: nameCtrl,
                    selectedCustomerId: selectedCustomerId,
                    onCustomerSelected: (Customer? c) => setSheetState(() => selectedCustomerId = c?.id),
                  ),
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final newAmount = KhosraMoney.parseToPaisa(amountCtrl.text);
                      if (newAmount <= 0) return;

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

                      final updated = entry.copyWith(
                        type: selectedType,
                        name: nameCtrl.text.trim().isEmpty ? entry.name : nameCtrl.text.trim(),
                        customerId: selectedCustomerId,
                        clearCustomerId: selectedCustomerId == null,
                        amountPaisa: newAmount,
                        paidPaisa: paidPaisa,
                        duePaisa: duePaisa,
                        costPaisa: costPaisa,
                        clearCostPaisa: costPaisa == null,
                        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        clearNote: noteCtrl.text.trim().isEmpty,
                        createdAt: selectedTime,
                      );
                      await sheetCtx.read<KhosraProvider>().updateEntry(updated);
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    },
                    child: const Text('সেভ করুন'),
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
