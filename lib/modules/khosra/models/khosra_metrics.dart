import 'package:flutter/material.dart';
import 'khosra_entry.dart';

/// Represents a slice in category breakdowns (e.g. for Donut/Bar charts).
class CategorySlice {
  final String key;
  final String label;
  final String labelEn;
  final int amountPaisa;
  final int count;
  final Color color;
  final IconData icon;

  const CategorySlice({
    required this.key,
    required this.label,
    required this.labelEn,
    required this.amountPaisa,
    required this.count,
    required this.color,
    required this.icon,
  });

  double get amountTaka => KhosraMoney.paisaToTaka(amountPaisa);
  String get formattedTaka => KhosraMoney.formatPaisa(amountPaisa);
}

/// Represents an hourly/period bucket for timeline activity graphs.
class HourlyBucket {
  final String label;
  final String timeRange;
  final int startHour;
  final int endHour;
  final int amountPaisa;
  final int count;
  final bool isPeak;

  const HourlyBucket({
    required this.label,
    required this.timeRange,
    required this.startHour,
    required this.endHour,
    required this.amountPaisa,
    required this.count,
    this.isPeak = false,
  });

  double get amountTaka => KhosraMoney.paisaToTaka(amountPaisa);
  String get formattedTaka => KhosraMoney.formatPaisa(amountPaisa);
}

/// Comprehensive metrics & analytical computations for Khosra ledger.
class KhosraMetrics {
  // Sales Metrics
  final int totalSellPaisa;
  final int sellCount;
  final int cashFromSellPaisa;
  final int dueFromSellPaisa;

  // Due / Bokeya Metrics
  final int totalNewBakiPaisa;
  final int newBakiCount;
  final int allNewDuePaisa; // Dues from direct baki entries + dues from partial sales

  // Collection / Aday Metrics
  final int totalAdayPaisa;
  final int adayCount;
  final int totalAdayDiscountPaisa;

  // Expense / Khoroch Metrics
  final int totalKhorochPaisa;
  final int khorochCount;

  // Other Entries
  final int totalOtherPaisa;
  final int otherCount;

  // Cashflow & Performance KPIs
  final int netCashInHandPaisa;
  final int totalTransactionsCount;
  final int averageTicketPaisa;
  final int maxSingleSalePaisa;
  final double cashToDueRatio; // Percentage of sales collected in cash (0..100)

  // Chart Slices & Distributions
  final List<CategorySlice> salesBreakdown;
  final List<CategorySlice> expenseBreakdown;
  final List<CategorySlice> dueBreakdown;
  final List<HourlyBucket> timelineBuckets;

  const KhosraMetrics({
    required this.totalSellPaisa,
    required this.sellCount,
    required this.cashFromSellPaisa,
    required this.dueFromSellPaisa,
    required this.totalNewBakiPaisa,
    required this.newBakiCount,
    required this.allNewDuePaisa,
    required this.totalAdayPaisa,
    required this.adayCount,
    required this.totalAdayDiscountPaisa,
    required this.totalKhorochPaisa,
    required this.khorochCount,
    required this.totalOtherPaisa,
    required this.otherCount,
    required this.netCashInHandPaisa,
    required this.totalTransactionsCount,
    required this.averageTicketPaisa,
    required this.maxSingleSalePaisa,
    required this.cashToDueRatio,
    required this.salesBreakdown,
    required this.expenseBreakdown,
    required this.dueBreakdown,
    required this.timelineBuckets,
  });

  factory KhosraMetrics.fromEntries(List<KhosraEntry> rawEntries) {
    // Exclude discarded entries
    final entries = rawEntries
        .where((e) => e.status != KhosraEntryStatus.discarded)
        .toList();

    int totalSell = 0;
    int sellCount = 0;
    int cashFromSell = 0;
    int dueFromSell = 0;
    int maxSale = 0;

    int totalNewBaki = 0;
    int newBakiCount = 0;

    int totalAday = 0;
    int adayCount = 0;
    int totalAdayDiscount = 0;

    int totalKhoroch = 0;
    int khorochCount = 0;

    int totalOther = 0;
    int otherCount = 0;

    // Sales breakdown buckets
    int telecomPaisa = 0;
    int telecomCount = 0;
    int photocopyPaisa = 0;
    int photocopyCount = 0;
    int photoPaisa = 0;
    int photoCount = 0;
    int generalProductPaisa = 0;
    int generalProductCount = 0;
    int otherServicePaisa = 0;
    int otherServiceCount = 0;

    // Expense breakdown buckets
    final Map<String, int> expenseSums = {};
    final Map<String, int> expenseCounts = {};

    // Due breakdown buckets
    final Map<String, int> dueSums = {};
    final Map<String, int> dueCounts = {};

    // Timeline buckets: 08-11, 11-14, 14-17, 17-20, 20-23+
    final List<int> bucketPaisa = [0, 0, 0, 0, 0];
    final List<int> bucketCount = [0, 0, 0, 0, 0];

    for (final e in entries) {
      final hour = e.createdAt.toLocal().hour;
      int timeSlot = 0;
      if (hour < 11) {
        timeSlot = 0;
      } else if (hour < 14) {
        timeSlot = 1;
      } else if (hour < 17) {
        timeSlot = 2;
      } else if (hour < 20) {
        timeSlot = 3;
      } else {
        timeSlot = 4;
      }

      switch (e.type) {
        case KhosraEntryType.sale:
          totalSell += e.amountPaisa;
          sellCount++;
          cashFromSell += e.paidPaisa;
          dueFromSell += e.duePaisa;
          if (e.amountPaisa > maxSale) maxSale = e.amountPaisa;

          bucketPaisa[timeSlot] += e.amountPaisa;
          bucketCount[timeSlot]++;

          // Category classification
          final key = e.quickActionKey ?? '';
          final nameLower = e.name.toLowerCase();
          if (key.startsWith('telecom_') || nameLower.contains('telecom')) {
            telecomPaisa += e.amountPaisa;
            telecomCount++;
          } else if (key.startsWith('photocopy_') ||
              nameLower.contains('photocopy') ||
              e.name.contains('ফটোকপি')) {
            photocopyPaisa += e.amountPaisa;
            photocopyCount++;
          } else if (key.startsWith('photo_') ||
              nameLower.contains('photo') ||
              e.name.contains('ছবি')) {
            photoPaisa += e.amountPaisa;
            photoCount++;
          } else if (e.isServiceSale) {
            otherServicePaisa += e.amountPaisa;
            otherServiceCount++;
          } else {
            generalProductPaisa += e.amountPaisa;
            generalProductCount++;
          }
          break;

        case KhosraEntryType.baki:
          totalNewBaki += e.amountPaisa;
          newBakiCount++;
          final rawDueType = e.details?['rawDueType']?.toString() ??
              e.dueType ??
              'product';
          dueSums[rawDueType] = (dueSums[rawDueType] ?? 0) + e.amountPaisa;
          dueCounts[rawDueType] = (dueCounts[rawDueType] ?? 0) + 1;
          break;

        case KhosraEntryType.aday:
          totalAday += e.amountPaisa;
          adayCount++;
          final disc = e.details?['discountPaisa'];
          if (disc is int) {
            totalAdayDiscount += disc;
          } else if (disc is num) {
            totalAdayDiscount += disc.toInt();
          }
          break;

        case KhosraEntryType.khoroch:
          totalKhoroch += e.amountPaisa;
          khorochCount++;
          final cat = e.expenseCategory ?? 'shop';
          expenseSums[cat] = (expenseSums[cat] ?? 0) + e.amountPaisa;
          expenseCounts[cat] = (expenseCounts[cat] ?? 0) + 1;
          break;

        case KhosraEntryType.other:
          totalOther += e.amountPaisa;
          otherCount++;
          break;
      }
    }

    // Cashflow & Ratio
    final netCashInHand = (cashFromSell + totalAday) - totalKhoroch;
    final allNewDue = totalNewBaki + dueFromSell;
    final avgTicket = sellCount > 0 ? (totalSell ~/ sellCount) : 0;
    final cashRatio = totalSell > 0
        ? ((cashFromSell / totalSell) * 100).clamp(0.0, 100.0)
        : 100.0;

    // Build Sales Breakdown Slices
    final List<CategorySlice> salesBreakdown = [];
    if (telecomPaisa > 0) {
      salesBreakdown.add(CategorySlice(
        key: 'telecom',
        label: 'টেলিকম কার্ড',
        labelEn: 'Telecom Card',
        amountPaisa: telecomPaisa,
        count: telecomCount,
        color: const Color(0xFF0284C7), // Sky Blue
        icon: Icons.sim_card_outlined,
      ));
    }
    if (photocopyPaisa > 0) {
      salesBreakdown.add(CategorySlice(
        key: 'photocopy',
        label: 'ফটোকপি',
        labelEn: 'Photocopy',
        amountPaisa: photocopyPaisa,
        count: photocopyCount,
        color: const Color(0xFF0D9488), // Teal
        icon: Icons.print_rounded,
      ));
    }
    if (photoPaisa > 0) {
      salesBreakdown.add(CategorySlice(
        key: 'photo',
        label: 'ছবি প্রিন্ট',
        labelEn: 'Photo Print',
        amountPaisa: photoPaisa,
        count: photoCount,
        color: const Color(0xFF7C3AED), // Violet
        icon: Icons.photo_camera_rounded,
      ));
    }
    if (generalProductPaisa > 0) {
      salesBreakdown.add(CategorySlice(
        key: 'product',
        label: 'পণ্য বিক্রি',
        labelEn: 'Products',
        amountPaisa: generalProductPaisa,
        count: generalProductCount,
        color: const Color(0xFF10B981), // Emerald
        icon: Icons.shopping_bag_outlined,
      ));
    }
    if (otherServicePaisa > 0) {
      salesBreakdown.add(CategorySlice(
        key: 'service',
        label: 'অন্যান্য সার্ভিস',
        labelEn: 'Other Services',
        amountPaisa: otherServicePaisa,
        count: otherServiceCount,
        color: const Color(0xFFF59E0B), // Amber
        icon: Icons.miscellaneous_services_rounded,
      ));
    }

    // Build Expense Breakdown Slices
    final List<CategorySlice> expenseBreakdown = [];
    final expenseColors = {
      'shop': const Color(0xFFEF4444),
      'stock_purchase': const Color(0xFFF97316),
      'electricity_wifi': const Color(0xFFEAB308),
      'personal': const Color(0xFF8B5CF6),
      'other': const Color(0xFF64748B),
    };
    final expenseLabels = {
      'shop': 'দোকান খরচ',
      'stock_purchase': 'মালামাল ক্রয়',
      'electricity_wifi': 'বিদ্যুৎ ও ওয়াইফাই',
      'personal': 'ব্যক্তিগত',
      'other': 'অন্যান্য',
    };
    expenseSums.forEach((cat, amt) {
      if (amt > 0) {
        expenseBreakdown.add(CategorySlice(
          key: cat,
          label: expenseLabels[cat] ?? cat,
          labelEn: cat,
          amountPaisa: amt,
          count: expenseCounts[cat] ?? 1,
          color: expenseColors[cat] ?? Colors.red.shade400,
          icon: Icons.receipt_long_rounded,
        ));
      }
    });

    // Build Due Breakdown Slices
    final List<CategorySlice> dueBreakdown = [];
    final dueLabels = {
      'product': 'পণ্য বাকি',
      'service': 'সার্ভিস বাকি',
      'msfRecharge': 'MSF/রিচার্জ',
      'cashBorrow': 'নগদ ধার',
      'previousDue': 'পূর্ববর্তী বাকি',
    };
    final dueColors = {
      'product': const Color(0xFFEA580C),
      'service': const Color(0xFFF97316),
      'msfRecharge': const Color(0xFF0284C7),
      'cashBorrow': const Color(0xFFDC2626),
      'previousDue': const Color(0xFF64748B),
    };
    dueSums.forEach((dueType, amt) {
      if (amt > 0) {
        dueBreakdown.add(CategorySlice(
          key: dueType,
          label: dueLabels[dueType] ?? dueType,
          labelEn: dueType,
          amountPaisa: amt,
          count: dueCounts[dueType] ?? 1,
          color: dueColors[dueType] ?? Colors.deepOrange.shade400,
          icon: Icons.person_add_alt_1_rounded,
        ));
      }
    });

    // Build Timeline Buckets
    int maxBucketPaisa = 0;
    for (final p in bucketPaisa) {
      if (p > maxBucketPaisa) maxBucketPaisa = p;
    }

    final timelineBuckets = [
      HourlyBucket(
        label: 'সকাল',
        timeRange: '০৮:০০ - ১১:০০',
        startHour: 8,
        endHour: 11,
        amountPaisa: bucketPaisa[0],
        count: bucketCount[0],
        isPeak: maxBucketPaisa > 0 && bucketPaisa[0] == maxBucketPaisa,
      ),
      HourlyBucket(
        label: 'দুপুর',
        timeRange: '১১:০০ - ১৪:০০',
        startHour: 11,
        endHour: 14,
        amountPaisa: bucketPaisa[1],
        count: bucketCount[1],
        isPeak: maxBucketPaisa > 0 && bucketPaisa[1] == maxBucketPaisa,
      ),
      HourlyBucket(
        label: 'বিকাল',
        timeRange: '১৪:০০ - ১৭:০০',
        startHour: 14,
        endHour: 17,
        amountPaisa: bucketPaisa[2],
        count: bucketCount[2],
        isPeak: maxBucketPaisa > 0 && bucketPaisa[2] == maxBucketPaisa,
      ),
      HourlyBucket(
        label: 'সন্ধ্যা',
        timeRange: '১৭:০০ - ২০:০০',
        startHour: 17,
        endHour: 20,
        amountPaisa: bucketPaisa[3],
        count: bucketCount[3],
        isPeak: maxBucketPaisa > 0 && bucketPaisa[3] == maxBucketPaisa,
      ),
      HourlyBucket(
        label: 'রাত',
        timeRange: '২০:০০ - ২৩:০০+',
        startHour: 20,
        endHour: 23,
        amountPaisa: bucketPaisa[4],
        count: bucketCount[4],
        isPeak: maxBucketPaisa > 0 && bucketPaisa[4] == maxBucketPaisa,
      ),
    ];

    return KhosraMetrics(
      totalSellPaisa: totalSell,
      sellCount: sellCount,
      cashFromSellPaisa: cashFromSell,
      dueFromSellPaisa: dueFromSell,
      totalNewBakiPaisa: totalNewBaki,
      newBakiCount: newBakiCount,
      allNewDuePaisa: allNewDue,
      totalAdayPaisa: totalAday,
      adayCount: adayCount,
      totalAdayDiscountPaisa: totalAdayDiscount,
      totalKhorochPaisa: totalKhoroch,
      khorochCount: khorochCount,
      totalOtherPaisa: totalOther,
      otherCount: otherCount,
      netCashInHandPaisa: netCashInHand,
      totalTransactionsCount: entries.length,
      averageTicketPaisa: avgTicket,
      maxSingleSalePaisa: maxSale,
      cashToDueRatio: cashRatio,
      salesBreakdown: salesBreakdown,
      expenseBreakdown: expenseBreakdown,
      dueBreakdown: dueBreakdown,
      timelineBuckets: timelineBuckets,
    );
  }
}

