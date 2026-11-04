import 'package:flutter/material.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';

class KhosraSummaryBar extends StatelessWidget {
  final KhosraProvider provider;
  final VoidCallback onOpenOlderPending;
  final bool showStats;

  const KhosraSummaryBar({
    super.key,
    required this.provider,
    required this.onOpenOlderPending,
    this.showStats = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.olderPendingCount > 0 && provider.isTodaySelected)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber.shade900,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'পুরনো দিনের ${provider.olderPendingCount} টি খসড়া বাকি আছে',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.brown.shade900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onOpenOlderPending,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade200,
                    foregroundColor: Colors.brown.shade900,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'দেখুন',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        if (!provider.isTodaySelected)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: Colors.indigo.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'নির্বাচিত তারিখ: ${provider.selectedBusinessDate}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo.shade900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => provider.selectBusinessDate(
                    KhosraEntry.todayBusinessDate(),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.today_rounded, size: 14),
                  label: const Text('আজকের দিন', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        if (showStats)
          Row(
            children: [
              Expanded(
                child: _CompactStat(
                  label: 'বিক্রি',
                  icon: Icons.point_of_sale_rounded,
                  amountPaisa: provider.totalSellPaisa,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactStat(
                  label: 'নতুন বাকি',
                  icon: Icons.person_add_alt_1_rounded,
                  amountPaisa: provider.totalNewBakiPaisa,
                  color: Colors.deepOrange.shade700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactStat(
                  label: 'খরচ',
                  icon: Icons.receipt_long_rounded,
                  amountPaisa: provider.totalKhorochPaisa,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactStat(
                  label: 'আদায়',
                  icon: Icons.payments_rounded,
                  amountPaisa: provider.totalAdayPaisa,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final IconData icon;
  final int amountPaisa;
  final Color color;

  const _CompactStat({
    required this.label,
    required this.icon,
    required this.amountPaisa,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              KhosraMoney.formatPaisa(amountPaisa),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
