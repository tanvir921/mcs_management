import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/providers/customer_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';
import '../widgets/khosra_aday_tab.dart';
import '../widgets/khosra_baki_tab.dart';
import '../widgets/khosra_entry_list.dart';
import '../widgets/khosra_khoroch_other_tab.dart';
import '../widgets/khosra_sell_tab.dart';
import '../widgets/khosra_summary_bar.dart';

class KhosraHomeScreen extends StatefulWidget {
  const KhosraHomeScreen({super.key});

  @override
  State<KhosraHomeScreen> createState() => _KhosraHomeScreenState();
}

class _KhosraHomeScreenState extends State<KhosraHomeScreen> {
  KhosraEntryType _activeSection = KhosraEntryType.sale;
  bool _filterByActiveTab = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<KhosraProvider>().init();
      context.read<CustomerProvider>().loadCustomers();
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<InventoryProvider>().loadItems(user.id);
      }
    });
  }

  void _openOlderPendingSheet(KhosraProvider provider) {
    final groupedByDate = <String, int>{};
    for (final e in provider.olderPendingEntries) {
      groupedByDate[e.businessDate] = (groupedByDate[e.businessDate] ?? 0) + 1;
    }
    final dates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'পুরনো দিনের খসড়া',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...dates.map(
                  (d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.deepOrange,
                    ),
                    title: Text(
                      d,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${groupedByDate[d]} টি খসড়া বাকি আছে'),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(ctx);
                        provider.selectBusinessDate(d);
                      },
                      child: const Text('খুলুন'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveSectionForm() {
    switch (_activeSection) {
      case KhosraEntryType.sale:
        return const KhosraSellTab();
      case KhosraEntryType.baki:
        return const KhosraBakiTab();
      case KhosraEntryType.khoroch:
        return const KhosraKhorochTab();
      case KhosraEntryType.aday:
        return const KhosraAdayTab();
      case KhosraEntryType.other:
        return const KhosraOtherTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KhosraProvider>(
      builder: (context, provider, _) {
        final showOnlyTab =
            _filterByActiveTab || _activeSection == KhosraEntryType.baki;
        final visibleEntries = showOnlyTab
            ? provider.entries
                  .where((e) => e.type == _activeSection)
                  .toList()
            : provider.entries;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: Text(
              provider.isTodaySelected
                  ? 'খসড়া খাতা'
                  : 'খসড়া (${provider.selectedBusinessDate})',
            ),
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (provider.hasUnsyncedEntries)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: 'অফলাইন — ইন্টারনেট এলে সিঙ্ক হবে',
                    child: Icon(Icons.cloud_upload_outlined, size: 20),
                  ),
                ),
              IconButton(
                tooltip: 'Review & Confirm',
                icon: Badge(
                  isLabelVisible: provider.pendingCount > 0,
                  label: Text('${provider.pendingCount}'),
                  child: const Icon(Icons.fact_check_outlined),
                ),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.khosraReview),
              ),
            ],
          ),
          body: Column(
            children: [
              KhosraSummaryBar(
                provider: provider,
                onOpenOlderPending: () => _openOlderPendingSheet(provider),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    _TabPill(
                      label: 'বিক্রি',
                      color: Colors.teal.shade700,
                      isSelected: _activeSection == KhosraEntryType.sale,
                      onTap: () => setState(
                        () => _activeSection = KhosraEntryType.sale,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _TabPill(
                      label: 'বকেয়া',
                      color: Colors.deepOrange.shade700,
                      isSelected: _activeSection == KhosraEntryType.baki,
                      onTap: () => setState(
                        () => _activeSection = KhosraEntryType.baki,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _TabPill(
                      label: 'খরচ',
                      color: Colors.red.shade700,
                      isSelected: _activeSection == KhosraEntryType.khoroch,
                      onTap: () => setState(
                        () => _activeSection = KhosraEntryType.khoroch,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _TabPill(
                      label: 'আদায়',
                      color: Colors.blue.shade700,
                      isSelected: _activeSection == KhosraEntryType.aday,
                      onTap: () => setState(
                        () => _activeSection = KhosraEntryType.aday,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _TabPill(
                      label: 'অন্যান্য',
                      color: Colors.purple.shade700,
                      isSelected: _activeSection == KhosraEntryType.other,
                      onTap: () => setState(
                        () => _activeSection = KhosraEntryType.other,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  children: [
                    _buildActiveSectionForm(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          showOnlyTab
                              ? 'আজকের ${_activeSection.shortLabel} (${visibleEntries.length})'
                              : 'আজকের এন্ট্রি (${visibleEntries.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (_activeSection != KhosraEntryType.baki &&
                            provider.entries.isNotEmpty)
                          InkWell(
                            onTap: () => setState(
                              () => _filterByActiveTab = !_filterByActiveTab,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                _filterByActiveTab
                                    ? 'সব দেখুন (${provider.entries.length})'
                                    : 'শুধু ${_activeSection.shortLabel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    KhosraEntryList(entries: visibleEntries),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.khosraReview),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.task_alt_rounded, size: 20),
                label: Text(
                  'দিন শেষ — Review & Confirm (${provider.pendingCount})',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? color : Colors.white,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
