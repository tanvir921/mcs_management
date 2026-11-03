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

  Future<void> _promptAndConfirmSelected(
    BuildContext context,
    KhosraProvider provider,
    int selectedCount,
    int totalSellPaisa,
    int newBakiPaisa,
    int collectedPaisa,
    int expensePaisa,
  ) async {
    if (selectedCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.verified_outlined, color: Colors.indigo.shade800, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('হিসাব কনফার্মেশন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'নির্বাচিত $selectedCount টি খসড়া এন্ট্রি মূল সেলস, কাস্টমার বাকি, আদায় ও খরচে যুক্ত করা হবে।',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _confirmRow('মোট বিক্রি:', KhosraMoney.formatPaisa(totalSellPaisa), Colors.teal.shade800),
                  const SizedBox(height: 5),
                  _confirmRow('নতুন বাকি:', KhosraMoney.formatPaisa(newBakiPaisa), Colors.deepOrange.shade800),
                  const SizedBox(height: 5),
                  _confirmRow('বাকি আদায়:', KhosraMoney.formatPaisa(collectedPaisa), Colors.blue.shade800),
                  const SizedBox(height: 5),
                  _confirmRow('মোট খরচ:', KhosraMoney.formatPaisa(expensePaisa), Colors.red.shade800),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'কনফার্ম করার পর এগুলো মূল লেজারে হিসাবভুক্ত হবে। আপনি কি নিশ্চিত?',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ফিরে যান'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.indigo.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('হ্যাঁ, কনফার্ম করুন'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _confirmSelected(provider);
    }
  }

  static Widget _confirmRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
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
          if (pending.isNotEmpty) ...[
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: FilledButton.tonal(
                onPressed: (selectedEntries.isEmpty || provider.isCommitting || !canConfirm)
                    ? null
                    : () => _promptAndConfirmSelected(
                          context,
                          provider,
                          selectedEntries.length,
                          totalSellPaisa,
                          newBakiPaisa,
                          collectedPaisa,
                          expensePaisa,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: provider.isCommitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Confirm (${selectedEntries.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: pending.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, size: 56, color: Colors.green.shade600),
                      const SizedBox(height: 10),
                      const Text(
                        'সব খসড়া এন্ট্রি মূল হিসাবে যোগ করা হয়েছে!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('খসড়া খাতায় ফিরে যান'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    // Top Action & Summary Banner (Replaces bottom confirm button)
                    _buildTopConfirmHeader(
                      context,
                      provider: provider,
                      canConfirm: canConfirm,
                      selectedCount: selectedEntries.length,
                      totalCount: pending.length,
                      totalSellPaisa: totalSellPaisa,
                      cashReceivedPaisa: cashReceivedPaisa,
                      newBakiPaisa: newBakiPaisa,
                      collectedPaisa: collectedPaisa,
                      expensePaisa: expensePaisa,
                    ),
                    const SizedBox(height: 14),

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
        ),
      ),
    );
  }

  Widget _buildTopConfirmHeader(
    BuildContext context, {
    required KhosraProvider provider,
    required bool canConfirm,
    required int selectedCount,
    required int totalCount,
    required int totalSellPaisa,
    required int cashReceivedPaisa,
    required int newBakiPaisa,
    required int collectedPaisa,
    required int expensePaisa,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.summarize_rounded, color: Colors.indigo.shade800, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'নির্বাচিত: $selectedCount / $totalCount টি এন্ট্রি',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: (provider.isCommitting || selectedCount == 0 || !canConfirm)
                    ? null
                    : () => _promptAndConfirmSelected(
                          context,
                          provider,
                          selectedCount,
                          totalSellPaisa,
                          newBakiPaisa,
                          collectedPaisa,
                          expensePaisa,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: provider.isCommitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.done_all_rounded, size: 18),
                label: Text(
                  !canConfirm
                      ? 'অনুমতি নেই'
                      : 'Confirm & Add ($selectedCount)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _metricChip('বিক্রি', KhosraMoney.formatPaisa(totalSellPaisa), Colors.teal.shade800),
              _metricChip('নগদ জমা', KhosraMoney.formatPaisa(cashReceivedPaisa), Colors.green.shade800),
              _metricChip('নতুন বাকি', KhosraMoney.formatPaisa(newBakiPaisa), Colors.deepOrange.shade800),
              _metricChip('বাকি আদায়', KhosraMoney.formatPaisa(collectedPaisa), Colors.blue.shade800),
              _metricChip('খরচ', KhosraMoney.formatPaisa(expensePaisa), Colors.red.shade800),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
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

    final subtotal = entries.fold<int>(0, (s, e) => s + e.amountPaisa);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      type.labelBn,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${entries.length}', style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                Text(
                  KhosraMoney.formatPaisa(subtotal),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          ...entries.map((entry) {
            final isSelected = _selectedIds.contains(entry.id);
            final needsCustomerLink =
                (entry.type == KhosraEntryType.baki || entry.type == KhosraEntryType.aday) &&
                (entry.customerId == null || entry.customerId!.isEmpty);

            return Column(
              children: [
                const Divider(height: 1),
                Row(
                  children: [
                    Checkbox(
                      value: isSelected,
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
                              if (entry.quantity > 1)
                                Text(' ×${entry.quantity}', style: const TextStyle(fontSize: 11.5)),
                              if (entry.linkedEntryId != null) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.link, size: 14, color: Colors.deepOrange),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                DateFormat('hh:mm a').format(AppTime.toBusiness(entry.createdAt)),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              if (entry.note != null && entry.note!.isNotEmpty)
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
                    padding: const EdgeInsets.only(left: 36, bottom: 6),
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
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text('ধরন পরিবর্তন: ${targetType.shortLabel}'),
                                    content: Text('"${entry.name}" (${KhosraMoney.formatPaisa(entry.amountPaisa)}) এন্ট্রিটিকে "${targetType.shortLabel}" হিসেবে রূপান্তর করতে চান?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('হ্যাঁ, রূপান্তর করুন'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  context.read<KhosraProvider>().updateEntry(
                                    entry.copyWith(
                                      type: targetType,
                                      paidPaisa: targetType == KhosraEntryType.sale ? entry.amountPaisa : 0,
                                      dueType: targetType == KhosraEntryType.baki ? 'product' : entry.dueType,
                                      expenseCategory: targetType == KhosraEntryType.khoroch ? 'other' : entry.expenseCategory,
                                    ),
                                  );
                                }
                              },
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
