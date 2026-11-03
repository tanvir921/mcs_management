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
                const Row(
                  children: [
                    Icon(Icons.history_rounded, color: Colors.deepOrange),
                    SizedBox(width: 8),
                    Text(
                      'পুরনো দিনের খসড়া',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...dates.map(
                  (d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.deepOrange,
                        size: 20,
                      ),
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

  Widget _buildTabPills() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'বিক্রি',
            icon: Icons.point_of_sale_rounded,
            color: Colors.teal.shade700,
            isSelected: _activeSection == KhosraEntryType.sale,
            onTap: () => setState(() => _activeSection = KhosraEntryType.sale),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'বকেয়া',
            icon: Icons.person_add_alt_1_rounded,
            color: Colors.deepOrange.shade700,
            isSelected: _activeSection == KhosraEntryType.baki,
            onTap: () => setState(() => _activeSection = KhosraEntryType.baki),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'খরচ',
            icon: Icons.receipt_long_rounded,
            color: Colors.red.shade700,
            isSelected: _activeSection == KhosraEntryType.khoroch,
            onTap: () => setState(() => _activeSection = KhosraEntryType.khoroch),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'আদায়',
            icon: Icons.payments_rounded,
            color: Colors.blue.shade700,
            isSelected: _activeSection == KhosraEntryType.aday,
            onTap: () => setState(() => _activeSection = KhosraEntryType.aday),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'অন্যান্য',
            icon: Icons.edit_note_rounded,
            color: Colors.purple.shade700,
            isSelected: _activeSection == KhosraEntryType.other,
            onTap: () => setState(() => _activeSection = KhosraEntryType.other),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesHeader(
    KhosraProvider provider,
    List<KhosraEntry> visibleEntries,
    bool showOnlyTab,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.list_alt_rounded, size: 16, color: Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              showOnlyTab
                  ? 'আজকের ${_activeSection.shortLabel} (${visibleEntries.length})'
                  : 'আজকের এন্ট্রি তালিকা (${visibleEntries.length})',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ],
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
                horizontal: 8,
                vertical: 4,
              ),
              child: Text(
                _filterByActiveTab
                    ? 'সব দেখুন (${provider.entries.length})'
                    : 'শুধু ${_activeSection.shortLabel}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
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

        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 960;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FA),
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 24),
                const SizedBox(width: 8),
                Text(
                  provider.isTodaySelected
                      ? 'খসড়া খাতা'
                      : 'খসড়া (${provider.selectedBusinessDate})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (provider.hasUnsyncedEntries)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: 'অফলাইন ক্যাশ সক্রিয় — ইন্টারনেট এলে স্বয়ংক্রিয় সিঙ্ক হবে',
                    child: Icon(Icons.cloud_upload_outlined, size: 20),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.khosraReview),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal.shade900,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Badge(
                    isLabelVisible: provider.pendingCount > 0,
                    label: Text('${provider.pendingCount}'),
                    child: const Icon(Icons.fact_check_rounded, size: 18),
                  ),
                  label: const Text(
                    'Review & Confirm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          body: isDesktop
              ? _buildDesktopLayout(provider, visibleEntries, showOnlyTab)
              : _buildMobileLayout(provider, visibleEntries, showOnlyTab),
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    KhosraProvider provider,
    List<KhosraEntry> visibleEntries,
    bool showOnlyTab,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Entry Form & Summary
              SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KhosraSummaryBar(
                        provider: provider,
                        onOpenOlderPending: () => _openOlderPendingSheet(provider),
                      ),
                      const SizedBox(height: 12),
                      _buildTabPills(),
                      const SizedBox(height: 14),
                      _buildActiveSectionForm(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Right Column: Live Entries List
              Expanded(
                child: Container(
                  height: MediaQuery.of(context).size.height - 110,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildEntriesHeader(provider, visibleEntries, showOnlyTab),
                      const Divider(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: KhosraEntryList(entries: visibleEntries),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    KhosraProvider provider,
    List<KhosraEntry> visibleEntries,
    bool showOnlyTab,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
            KhosraSummaryBar(
              provider: provider,
              onOpenOlderPending: () => _openOlderPendingSheet(provider),
            ),
            const SizedBox(height: 10),
            _buildTabPills(),
            const SizedBox(height: 12),
            _buildActiveSectionForm(),
            const SizedBox(height: 16),
            _buildEntriesHeader(provider, visibleEntries, showOnlyTab),
            const SizedBox(height: 8),
            KhosraEntryList(entries: visibleEntries),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
