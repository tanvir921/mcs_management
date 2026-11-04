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
import '../widgets/khosra_charts.dart';
import '../widgets/khosra_entry_list.dart';
import '../widgets/khosra_khoroch_other_tab.dart';
import '../widgets/khosra_kpi_dashboard.dart';
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
  String _desktopRightView = 'entries'; // 'entries' | 'analytics' | 'split'
  bool _mobileShowAnalytics = false;
  final TextEditingController _listSearchCtrl = TextEditingController();

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

  @override
  void dispose() {
    _listSearchCtrl.dispose();
    super.dispose();
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'বিক্রি',
            icon: Icons.point_of_sale_rounded,
            color: const Color(0xFF0F766E),
            isSelected: _activeSection == KhosraEntryType.sale,
            onTap: () => setState(() => _activeSection = KhosraEntryType.sale),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'বকেয়া',
            icon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFFC2410C),
            isSelected: _activeSection == KhosraEntryType.baki,
            onTap: () => setState(() => _activeSection = KhosraEntryType.baki),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'খরচ',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFBE123C),
            isSelected: _activeSection == KhosraEntryType.khoroch,
            onTap: () => setState(() => _activeSection = KhosraEntryType.khoroch),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'আদায়',
            icon: Icons.payments_rounded,
            color: const Color(0xFF1D4ED8),
            isSelected: _activeSection == KhosraEntryType.aday,
            onTap: () => setState(() => _activeSection = KhosraEntryType.aday),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'অন্যান্য',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF7C3AED),
            isSelected: _activeSection == KhosraEntryType.other,
            onTap: () => setState(() => _activeSection = KhosraEntryType.other),
          ),
        ],
      ),
    );
  }

  List<KhosraEntry> _getFilteredEntries(List<KhosraEntry> entries) {
    var result = entries;
    if (_filterByActiveTab || _activeSection == KhosraEntryType.baki) {
      result = result.where((e) => e.type == _activeSection).toList();
    }
    final q = _listSearchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((e) {
        return e.displayName.toLowerCase().contains(q) ||
            (e.details?['customerName']?.toString().toLowerCase().contains(q) ?? false) ||
            (e.note?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return result;
  }

  Widget _buildEntriesHeader(
    KhosraProvider provider,
    List<KhosraEntry> visibleEntries,
    bool showOnlyTab,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.list_alt_rounded, size: 16, color: Colors.black87),
                ),
                const SizedBox(width: 8),
                Text(
                  showOnlyTab
                      ? 'আজকের ${_activeSection.shortLabel} (${visibleEntries.length})'
                      : 'আজকের এন্ট্রি তালিকা (${visibleEntries.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            if (_activeSection != KhosraEntryType.baki && provider.entries.isNotEmpty)
              InkWell(
                onTap: () => setState(() => _filterByActiveTab = !_filterByActiveTab),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _filterByActiveTab ? Colors.teal.shade50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _filterByActiveTab ? Colors.teal.shade300 : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    _filterByActiveTab
                        ? 'সব দেখুন (${provider.entries.length})'
                        : 'শুধু ${_activeSection.shortLabel}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (provider.entries.length > 5) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: TextField(
              controller: _listSearchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'তালিকা থেকে খুঁজুন...',
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: _listSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => setState(() => _listSearchCtrl.clear()),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KhosraProvider>(
      builder: (context, provider, _) {
        final visibleEntries = _getFilteredEntries(provider.entries);
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 960;
        final metrics = provider.metrics;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.dashboard_customize_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  provider.isTodaySelected
                      ? 'খসড়া ড্যাশবোর্ড'
                      : 'খসড়া (${provider.selectedBusinessDate})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
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
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.khosraReview),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F766E),
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
              ? _buildDesktopLayout(provider, metrics, visibleEntries)
              : _buildMobileLayout(provider, metrics, visibleEntries),
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    KhosraProvider provider,
    dynamic metrics,
    List<KhosraEntry> visibleEntries,
  ) {
    final showOnlyTab = _filterByActiveTab || _activeSection == KhosraEntryType.baki;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top KPI Strip
              KhosraKpiDashboard(metrics: metrics),
              const SizedBox(height: 14),

              // Main Workspace: Left (Form) & Right (Entries / Analytics / Split)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Entry Form & Notices
                    SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            KhosraSummaryBar(
                              provider: provider,
                              onOpenOlderPending: () => _openOlderPendingSheet(provider),
                              showStats: false,
                            ),
                            _buildTabPills(),
                            const SizedBox(height: 12),
                            _buildActiveSectionForm(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Right Column: Tabbed View (Entries List, Visual Charts, or Split)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                            // View Switcher Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'entries',
                                      label: Text('আজকের তালিকা', style: TextStyle(fontSize: 12)),
                                      icon: Icon(Icons.list_alt_rounded, size: 16),
                                    ),
                                    ButtonSegment(
                                      value: 'analytics',
                                      label: Text('চার্ট ও গ্রাফ', style: TextStyle(fontSize: 12)),
                                      icon: Icon(Icons.pie_chart_outline_rounded, size: 16),
                                    ),
                                    ButtonSegment(
                                      value: 'split',
                                      label: Text('পাশাপাশি (Split)', style: TextStyle(fontSize: 12)),
                                      icon: Icon(Icons.view_agenda_outlined, size: 16),
                                    ),
                                  ],
                                  selected: {_desktopRightView},
                                  onSelectionChanged: (val) {
                                    setState(() => _desktopRightView = val.first);
                                  },
                                  style: ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Dynamic Content based on selected view
                            Expanded(
                              child: _desktopRightView == 'analytics'
                                  ? SingleChildScrollView(
                                      child: KhosraAnalyticsPanel(metrics: metrics),
                                    )
                                  : (_desktopRightView == 'split'
                                      ? Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Split Left: Analytics
                                            Expanded(
                                              flex: 5,
                                              child: SingleChildScrollView(
                                                child: KhosraAnalyticsPanel(metrics: metrics),
                                              ),
                                            ),
                                            const VerticalDivider(width: 24),
                                            // Split Right: Entries List
                                            Expanded(
                                              flex: 5,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  _buildEntriesHeader(provider, visibleEntries, showOnlyTab),
                                                  const SizedBox(height: 10),
                                                  Expanded(
                                                    child: SingleChildScrollView(
                                                      child: KhosraEntryList(entries: visibleEntries),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            _buildEntriesHeader(provider, visibleEntries, showOnlyTab),
                                            const SizedBox(height: 10),
                                            Expanded(
                                              child: SingleChildScrollView(
                                                child: KhosraEntryList(entries: visibleEntries),
                                              ),
                                            ),
                                          ],
                                        )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
    dynamic metrics,
    List<KhosraEntry> visibleEntries,
  ) {
    final showOnlyTab = _filterByActiveTab || _activeSection == KhosraEntryType.baki;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
            // Notice Banners if any
            KhosraSummaryBar(
              provider: provider,
              onOpenOlderPending: () => _openOlderPendingSheet(provider),
              showStats: false,
            ),

            // Top KPI Strip
            KhosraKpiDashboard(metrics: metrics),
            const SizedBox(height: 10),

            // Expandable Analytics & Charts Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _mobileShowAnalytics ? const Color(0xFF0F766E).withValues(alpha: 0.4) : Colors.grey.shade200,
                  width: _mobileShowAnalytics ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _mobileShowAnalytics,
                  onExpansionChanged: (val) => setState(() => _mobileShowAnalytics = val),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pie_chart_outline_rounded, size: 18, color: Color(0xFF0F766E)),
                  ),
                  title: const Text(
                    'আজকের চার্ট ও অ্যানালিটিক্স',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _mobileShowAnalytics ? 'ট্যাপ করে চার্ট লুকান' : 'বিক্রি গ্রাফ ও অনুপাত দেখতে ট্যাপ করুন',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: KhosraAnalyticsPanel(metrics: metrics),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Entry Type Tab Pills
            _buildTabPills(),
            const SizedBox(height: 12),

            // Active Section Form
            _buildActiveSectionForm(),
            const SizedBox(height: 18),

            // Today's Live Entries List
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
                  _buildEntriesHeader(provider, visibleEntries, showOnlyTab),
                  const SizedBox(height: 10),
                  KhosraEntryList(entries: visibleEntries),
                ],
              ),
            ),
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
