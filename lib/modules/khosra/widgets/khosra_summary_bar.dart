import 'package:flutter/material.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';

class KhosraSummaryBar extends StatelessWidget {
  final KhosraProvider provider;
  final VoidCallback onOpenOlderPending;

  const KhosraSummaryBar({
    super.key,
    required this.provider,
    required this.onOpenOlderPending,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.olderPendingCount > 0 && provider.isTodaySelected)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber.shade900,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'পুরনো দিনের ${provider.olderPendingCount} টি খসড়া বাকি আছে',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.brown.shade900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenOlderPending,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: Colors.indigo.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'তারিখ: ${provider.selectedBusinessDate}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo.shade900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => provider.selectBusinessDate(
                    KhosraEntry.todayBusinessDate(),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('আজকে ফিরুন', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: _CompactStat(
                  label: 'বিক্রি',
                  amountPaisa: provider.totalSellPaisa,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactStat(
                  label: 'বকেয়া',
                  amountPaisa: provider.totalNewBakiPaisa,
                  color: Colors.deepOrange.shade700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactStat(
                  label: 'খরচ',
                  amountPaisa: provider.totalKhorochPaisa,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactStat(
                  label: 'আদায়',
                  amountPaisa: provider.totalAdayPaisa,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final int amountPaisa;
  final Color color;

  const _CompactStat({
    required this.label,
    required this.amountPaisa,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              KhosraMoney.formatPaisa(amountPaisa),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
