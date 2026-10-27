import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/app_time.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/models/customer_model.dart';
import '../../customer/providers/customer_provider.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';
import '../services/khosra_service.dart';
import '../widgets/khosra_customer_link_sheet.dart';
import '../widgets/khosra_entry_list.dart';

class KhosraReviewScreen extends StatefulWidget {
  const KhosraReviewScreen({super.key});

  @override
  State<KhosraReviewScreen> createState() => _KhosraReviewScreenState();
}

class _KhosraReviewScreenState extends State<KhosraReviewScreen> {
  final Set<String> _selectedIds = {};
  bool _initializedSelection = false;
  KhosraCommitSummary? _lastCommitSummary;

  void _syncSelection(List<KhosraEntry> pending) {
    final validIds = pending.map((e) => e.id).toSet();
    if (!_initializedSelection && pending.isNotEmpty) {
      _selectedIds.addAll(validIds);
      _initializedSelection = true;
    } else {
      _selectedIds.removeWhere((id) => !validIds.contains(id));
    }
  }

  void _toggleEntrySelection(KhosraEntry entry, List<KhosraEntry> allPending) {
    setState(() {
      if (_selectedIds.contains(entry.id)) {
        _selectedIds.remove(entry.id);
        if (entry.linkedEntryId != null) _selectedIds.remove(entry.linkedEntryId);
      } else {
        _selectedIds.add(entry.id);
        if (entry.linkedEntryId != null && allPending.any((e) => e.id == entry.linkedEntryId)) {
          _selectedIds.add(entry.linkedEntryId!);
        }
      }
    });
  }

  List<String> _computeWarnings(List<KhosraEntry> selectedEntries, List<Customer> customers) {
    final warnings = <String>[];
    final customerMap = {for (final c in customers) c.id: c};
    int bakiWithoutCustomer = 0;
    int salesWithoutCost = 0;
    int unmappedOthers = 0;
    int adayExceeding = 0;
    final seenKeys = <String, DateTime>{};
    int duplicateCount = 0;

    for (final e in selectedEntries) {
      final needsCustomer =
          e.type == KhosraEntryType.baki ||
          (e.type == KhosraEntryType.sale && e.duePaisa > 0) ||
          e.type == KhosraEntryType.aday;
      if (needsCustomer &&
          (e.customerId == null || e.customerId!.isEmpty || e.customerId == 'guest_customer')) {
        bakiWithoutCustomer++;
      }
      if (e.type == KhosraEntryType.sale &&
          !e.isServiceSale &&
          (e.costPaisa == null || e.costPaisa == 0)) {
        salesWithoutCost++;
      }
      if (e.type == KhosraEntryType.other) unmappedOthers++;
      if (e.type == KhosraEntryType.aday && e.customerId != null) {
        final cust = customerMap[e.customerId];
        if (cust != null && e.amountPaisa > KhosraMoney.takaToPaisa(cust.totalDue)) {
          adayExceeding++;
        }
      }
      final dupKey = '${e.type.value}_${e.name.toLowerCase()}_${e.amountPaisa}';
      final prevTime = seenKeys[dupKey];
      if (prevTime != null && e.createdAt.difference(prevTime).abs().inMinutes <= 5) {
        duplicateCount++;
      }
      seenKeys[dupKey] = e.createdAt;
    }

    if (bakiWithoutCustomer > 0) {
      warnings.add('$bakiWithoutCustomer টি বকেয়া/আদায় এন্ট্রিতে গ্রাহক লিংক করা নেই।');
    }
    if (adayExceeding > 0) {
      warnings.add('$adayExceeding টি আদায় গ্রাহকের বর্তমান বকেয়ার চেয়ে বেশি।');
    }
    if (salesWithoutCost > 0) {
      warnings.add('$salesWithoutCost টি বিক্রিতে কেনা দাম নেই (সম্পূর্ণ টাকা লাভ ধরা হবে)।');
    }
    if (unmappedOthers > 0) {
      warnings.add('$unmappedOthers টি "অন্যান্য" এন্ট্রির ধরন নির্ধারণ করুন।');
    }
    if (duplicateCount > 0) {
      warnings.add('$duplicateCount টি সম্ভাব্য ডুপ্লিকেট এন্ট্রি রয়েছে।');
    }
    return warnings;
  }

  Future<void> _confirmSelected(KhosraProvider provider) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null || _selectedIds.isEmpty) return;

    if (!user.hasPermission(Permission.khosra) && !user.hasPermission(Permission.dailyClosing)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('খসড়া Confirm করার অনুমতি নেই।'),
        ),
      );
      return;
    }

    try {
      final summary = await provider.commitSelectedEntries(
        entryIds: _selectedIds.toList(),
        userId: user.id,
        userName: user.name,
        logAction: auth.logAction,
      );
      if (!mounted) return;
      setState(() => _lastCommitSummary = summary);
      await context.read<CustomerProvider>().loadCustomers();

      if (!summary.hasFailures && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('${summary.committedCount} টি এন্ট্রি মূল হিসাবে যোগ হয়েছে!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red.shade700, content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _retryFailedEntries(KhosraProvider provider) async {
    final failedIds = provider.pendingEntries
        .where((e) => e.status == KhosraEntryStatus.failed)
        .map((e) => e.id)
        .toList();
    if (failedIds.isEmpty) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(failedIds);
    });
    await _confirmSelected(provider);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KhosraProvider>();
    final customers = context.watch<CustomerProvider>().customers;
    final user = context.watch<AuthProvider>().currentUser;
    final canConfirm =
        user != null &&
        (user.hasPermission(Permission.khosra) || user.hasPermission(Permission.dailyClosing));

    final pending = provider.pendingEntries;
    _syncSelection(pending);
    final selectedEntries = pending.where((e) => _selectedIds.contains(e.id)).toList();
    final warnings = _computeWarnings(selectedEntries, customers);

    final totalSellPaisa = selectedEntries
        .where((e) => e.type == KhosraEntryType.sale)
        .fold<int>(0, (s, e) => s + e.amountPaisa);
    final cashReceivedPaisa = selectedEntries
        .where((e) => e.type == KhosraEntryType.sale)
        .fold<int>(0, (s, e) => s + e.paidPaisa);
    final newBakiPaisa = selectedEntries
        .where((e) => e.type == KhosraEntryType.baki)
        .fold<int>(0, (s, e) => s + e.amountPaisa);
    final collectedPaisa = selectedEntries
        .where((e) => e.type == KhosraEntryType.aday)
        .fold<int>(0, (s, e) => s + e.amountPaisa);
    final expensePaisa = selectedEntries
        .where((e) => e.type == KhosraEntryType.khoroch)
        .fold<int>(0, (s, e) => s + e.amountPaisa);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text('দিন শেষ (${provider.selectedBusinessDate})'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (pending.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                if (_selectedIds.length == pending.length) {
                  _selectedIds.clear();
                } else {
                  _selectedIds.addAll(pending.map((e) => e.id));
                }
              }),
              child: Text(
                _selectedIds.length == pending.length ? 'সব আনচেক' : 'সব নির্বাচন',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: pending.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, size: 56, color: Colors.green.shade600),
                  const SizedBox(height: 10),
                  const Text(
                    'সব খসড়া এন্ট্রি মূল হিসাবে যোগ করা হয়েছে!',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_lastCommitSummary != null && _lastCommitSummary!.hasFailures)
                  _buildRetryBanner(provider, _lastCommitSummary!),
                if (warnings.isNotEmpty) _buildWarningsBox(warnings),
                for (final type in KhosraEntryType.values)
                  _buildTypeGroupSection(
                    context,
                    type: type,
                    entries: pending.where((e) => e.type == type).toList(),
                    allPending: pending,
                  ),
              ],
            ),
      bottomNavigationBar: pending.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text('বিক্রি: ${KhosraMoney.formatPaisa(totalSellPaisa)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('নগদ: ${KhosraMoney.formatPaisa(cashReceivedPaisa)}', style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.bold)),
                        Text('বকেয়া: ${KhosraMoney.formatPaisa(newBakiPaisa)}', style: TextStyle(fontSize: 12, color: Colors.deepOrange.shade800, fontWeight: FontWeight.bold)),
                        Text('আদায়: ${KhosraMoney.formatPaisa(collectedPaisa)}', style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                        Text('খরচ: ${KhosraMoney.formatPaisa(expensePaisa)}', style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: (provider.isCommitting || _selectedIds.isEmpty || !canConfirm)
                          ? null
                          : () => _confirmSelected(provider),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: provider.isCommitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.done_all_rounded, size: 18),
                      label: Text(
                        !canConfirm
                            ? 'Confirm করার অনুমতি নেই'
                            : 'Confirm & Add (${_selectedIds.length} টি)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRetryBanner(KhosraProvider provider, KhosraCommitSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${summary.committedCount} টি সফল, ${summary.failedCount} টি ব্যর্থ।',
              style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          FilledButton.tonal(
            onPressed: provider.isCommitting ? null : () => _retryFailedEntries(provider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsBox(List<String> warnings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: warnings
            .map(
              (w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 15, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        w,
                        style: TextStyle(fontSize: 12, color: Colors.brown.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTypeGroupSection(
    BuildContext context, {
    required KhosraEntryType type,
    required List<KhosraEntry> entries,
    required List<KhosraEntry> allPending,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final subtotalPaisa = entries.fold<int>(0, (s, e) => s + e.amountPaisa);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${type.shortLabel} (${entries.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                KhosraMoney.formatPaisa(subtotalPaisa),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const Divider(height: 10),
          ...entries.map((entry) {
            final isChecked = _selectedIds.contains(entry.id);
            final needsCustomerLink =
                (entry.customerId == null || entry.customerId!.isEmpty) &&
                (entry.type == KhosraEntryType.baki ||
                    entry.type == KhosraEntryType.aday ||
                    (entry.type == KhosraEntryType.sale && entry.duePaisa > 0) ||
                    (entry.type == KhosraEntryType.sale &&
                        entry.name != 'Walk-in' &&
                        entry.name != 'Sale' &&
                        entry.name != 'Photocopy'));
            final bTime = AppTime.toBusiness(entry.createdAt);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Checkbox(
                      visualDensity: VisualDensity.compact,
                      value: isChecked,
                      onChanged: (_) => _toggleEntrySelection(entry, allPending),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entry.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('hh:mm a').format(bTime),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          if (entry.type == KhosraEntryType.sale && entry.costPaisa != null)
                            Text(
                              'কেনা: ${KhosraMoney.formatPaisa(entry.costPaisa!)}',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          if (entry.lastError != null)
                            Text(
                              entry.lastError!,
                              style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      KhosraMoney.formatPaisa(entry.amountPaisa),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      onPressed: () => showKhosraEditSheet(context, entry),
                    ),
                  ],
                ),
                if (needsCustomerLink || entry.type == KhosraEntryType.other)
                  Padding(
                    padding: const EdgeInsets.only(left: 36, bottom: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (needsCustomerLink)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.person_add, size: 14),
                            label: const Text('গ্রাহক লিংক', style: TextStyle(fontSize: 11)),
                            onPressed: () => showKhosraCustomerLinkSheet(
                              context,
                              entry,
                              allowGuest: entry.type == KhosraEntryType.sale && entry.duePaisa == 0,
                            ),
                          ),
                        if (entry.type == KhosraEntryType.other)
                          for (final targetType in [
                            KhosraEntryType.sale,
                            KhosraEntryType.baki,
                            KhosraEntryType.khoroch,
                          ])
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text('→ ${targetType.shortLabel}', style: const TextStyle(fontSize: 11)),
                              onPressed: () => context.read<KhosraProvider>().updateEntry(
                                entry.copyWith(
                                  type: targetType,
                                  paidPaisa: targetType == KhosraEntryType.sale ? entry.amountPaisa : 0,
                                  dueType: targetType == KhosraEntryType.baki ? 'product' : entry.dueType,
                                  expenseCategory: targetType == KhosraEntryType.khoroch ? 'other' : entry.expenseCategory,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
