import 'package:flutter/material.dart';
import '../models/khosra_entry.dart';
import '../models/khosra_metrics.dart';

/// Top-level KPI Metrics Strip designed for both responsive desktop & mobile screens.
class KhosraKpiDashboard extends StatelessWidget {
  final KhosraMetrics metrics;
  final VoidCallback? onToggleAnalytics;
  final bool isAnalyticsVisible;

  const KhosraKpiDashboard({
    super.key,
    required this.metrics,
    this.onToggleAnalytics,
    this.isAnalyticsVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    final cards = [
      _KpiCard(
        label: 'নগদ ক্যাশ ব্যালেন্স',
        labelEn: 'Net Cash In Hand',
        amountPaisa: metrics.netCashInHandPaisa,
        subtext: 'বিক্রি ক্যাশ + আদায় - খরচ',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: const Color(0xFF047857), // Emerald
        bgColor: const Color(0xFFECFDF5),
        isPrimary: true,
      ),
      _KpiCard(
        label: 'মোট বিক্রি (Sales)',
        labelEn: 'Total Sales',
        amountPaisa: metrics.totalSellPaisa,
        subtext: '${metrics.sellCount}টি বিক্রি • গড় ৳${metrics.averageTicketPaisa ~/ 100}',
        icon: Icons.point_of_sale_rounded,
        accentColor: const Color(0xFF0F766E), // Teal
        bgColor: const Color(0xFFF0FDFA),
      ),
      _KpiCard(
        label: 'নতুন বাকি (Dues)',
        labelEn: 'New Dues',
        amountPaisa: metrics.allNewDuePaisa,
        subtext: '${metrics.newBakiCount}টি বাকি লেনদেন',
        icon: Icons.person_add_alt_1_rounded,
        accentColor: const Color(0xFFC2410C), // Deep Orange
        bgColor: const Color(0xFFFFF7ED),
      ),
      _KpiCard(
        label: 'বকেয়া আদায় (Aday)',
        labelEn: 'Due Collections',
        amountPaisa: metrics.totalAdayPaisa,
        subtext: metrics.totalAdayDiscountPaisa > 0
            ? 'ছাড়: ৳${metrics.totalAdayDiscountPaisa ~/ 100} • ${metrics.adayCount}টি আদায়'
            : '${metrics.adayCount}টি আদায় সংগ্রহ',
        icon: Icons.payments_rounded,
        accentColor: const Color(0xFF1D4ED8), // Blue
        bgColor: const Color(0xFFEFF6FF),
      ),
      _KpiCard(
        label: 'মোট খরচ (Expense)',
        labelEn: 'Total Expenses',
        amountPaisa: metrics.totalKhorochPaisa,
        subtext: '${metrics.khorochCount}টি ভাউচার/খরচ',
        icon: Icons.receipt_long_rounded,
        accentColor: const Color(0xFFBE123C), // Rose
        bgColor: const Color(0xFFFFF1F2),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: c,
          ),
        )).toList(),
      );
    }

    // Mobile / Tablet layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Net Cash Banner
        cards[0],
        const SizedBox(height: 8),
        // 2x2 Grid for the other 4 KPIs
        Row(
          children: [
            Expanded(child: cards[1]),
            const SizedBox(width: 8),
            Expanded(child: cards[2]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: cards[3]),
            const SizedBox(width: 8),
            Expanded(child: cards[4]),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String labelEn;
  final int amountPaisa;
  final String subtext;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final bool isPrimary;

  const _KpiCard({
    required this.label,
    required this.labelEn,
    required this.amountPaisa,
    required this.subtext,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isPrimary ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary ? accentColor.withValues(alpha: 0.35) : Colors.grey.shade200,
          width: isPrimary ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isPrimary ? 0.08 : 0.03),
            blurRadius: isPrimary ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              KhosraMoney.formatPaisa(amountPaisa),
              style: TextStyle(
                fontSize: isPrimary ? 19 : 17,
                fontWeight: FontWeight.bold,
                color: accentColor,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

