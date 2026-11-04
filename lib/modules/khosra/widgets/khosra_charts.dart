import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/khosra_entry.dart';
import '../models/khosra_metrics.dart';

/// Interactive Donut / Ring chart widget displaying sales & service breakdown.
class KhosraDonutChart extends StatefulWidget {
  final List<CategorySlice> slices;
  final int totalPaisa;
  final String centerTitle;

  const KhosraDonutChart({
    super.key,
    required this.slices,
    required this.totalPaisa,
    this.centerTitle = 'মোট বিক্রি',
  });

  @override
  State<KhosraDonutChart> createState() => _KhosraDonutChartState();
}

class _KhosraDonutChartState extends State<KhosraDonutChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final hasData = widget.totalPaisa > 0 && widget.slices.isNotEmpty;

    CategorySlice? activeSlice;
    if (_hoveredIndex != null &&
        _hoveredIndex! >= 0 &&
        _hoveredIndex! < widget.slices.length) {
      activeSlice = widget.slices[_hoveredIndex!];
    }

    final displayTitle = activeSlice != null ? activeSlice.label : widget.centerTitle;
    final displayAmount = activeSlice != null
        ? activeSlice.amountPaisa
        : widget.totalPaisa;
    final displayPercent = (hasData && activeSlice != null)
        ? ((activeSlice.amountPaisa / widget.totalPaisa) * 100).toStringAsFixed(1)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Donut canvas with center text
        Center(
          child: SizedBox(
            width: 210,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _DonutChartPainter(
                    slices: widget.slices,
                    totalPaisa: widget.totalPaisa,
                    selectedIndex: _hoveredIndex,
                  ),
                ),
                // Center Label
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          KhosraMoney.formatPaisa(displayAmount),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: activeSlice?.color ?? const Color(0xFF0F766E),
                          ),
                        ),
                      ),
                      if (displayPercent != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: activeSlice!.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$displayPercent%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: activeSlice.color,
                            ),
                          ),
                        ),
                      ] else if (!hasData) ...[
                        const SizedBox(height: 2),
                        Text(
                          'আজ এখনও বিক্রি নেই',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Interactive Legend Chips
        if (hasData)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(widget.slices.length, (index) {
              final slice = widget.slices[index];
              final percent = ((slice.amountPaisa / widget.totalPaisa) * 100)
                  .toStringAsFixed(0);
              final isSelected = _hoveredIndex == index;

              return InkWell(
                onTap: () {
                  setState(() {
                    _hoveredIndex = (_hoveredIndex == index) ? null : index;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? slice.color.withValues(alpha: 0.15)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? slice.color
                          : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: slice.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        slice.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '(${slice.formattedTaka})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: slice.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          )
        else
          Center(
            child: Text(
              'কোনো বিক্রির ডেটা নেই',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategorySlice> slices;
  final int totalPaisa;
  final int? selectedIndex;

  _DonutChartPainter({
    required this.slices,
    required this.totalPaisa,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 24.0;
    const selectedStrokeWidth = 29.0;

    if (totalPaisa <= 0 || slices.isEmpty) {
      final emptyPaint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - (strokeWidth / 2), emptyPaint);
      return;
    }

    double startAngle = -math.pi / 2;
    const gapAngle = 0.04; // small aesthetic gap between slices

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweepAngle = (slice.amountPaisa / totalPaisa) * (2 * math.pi);
      final isSelected = selectedIndex == i;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? selectedStrokeWidth : strokeWidth
        ..strokeCap = StrokeCap.round;

      final effectiveSweep = math.max(0.01, sweepAngle - gapAngle);
      final arcRadius = radius - ((isSelected ? selectedStrokeWidth : strokeWidth) / 2);
      final rect = Rect.fromCircle(center: center, radius: arcRadius);

      canvas.drawArc(rect, startAngle + (gapAngle / 2), effectiveSweep, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.totalPaisa != totalPaisa ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.slices != slices;
  }
}

/// Timeline / Hourly sales activity bar graph.
class KhosraTimelineBarChart extends StatelessWidget {
  final List<HourlyBucket> buckets;

  const KhosraTimelineBarChart({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxPaisa = buckets.fold<int>(0, (m, b) => b.amountPaisa > m ? b.amountPaisa : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0F766E)),
                SizedBox(width: 6),
                Text(
                  'সময়ভিত্তিক বিক্রির গ্রাফ (Sales Timeline)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (maxPaisa > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.amber.shade900),
                    const SizedBox(width: 3),
                    Text(
                      'পিক আওয়ার হাইলাইট',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Bar Chart Area
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: buckets.map((bucket) {
              final ratio = maxPaisa > 0 ? (bucket.amountPaisa / maxPaisa) : 0.0;
              final barHeight = (ratio * 80).clamp(6.0, 80.0);
              final isPeak = bucket.isPeak && bucket.amountPaisa > 0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value Tag on Top
                      if (bucket.amountPaisa > 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isPeak ? Colors.amber.shade100 : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bucket.formattedTaka,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isPeak ? Colors.brown.shade900 : Colors.teal.shade900,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 18),

                      // Animated Bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        height: barHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isPeak
                                ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
                                : (bucket.amountPaisa > 0
                                    ? [const Color(0xFF0F766E), const Color(0xFF14B8A6)]
                                    : [Colors.grey.shade200, Colors.grey.shade200]),
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          boxShadow: isPeak
                              ? [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Label
                      Text(
                        bucket.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isPeak ? FontWeight.bold : FontWeight.w600,
                          color: isPeak ? Colors.amber.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        bucket.timeRange,
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Cashflow Velocity & Health Meter showing cash in vs cash out vs credit.
class KhosraCashflowMeter extends StatelessWidget {
  final KhosraMetrics metrics;

  const KhosraCashflowMeter({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final cashIn = metrics.cashFromSellPaisa + metrics.totalAdayPaisa;
    final cashOut = metrics.totalKhorochPaisa;
    final newDue = metrics.allNewDuePaisa;
    final totalTurnover = cashIn + cashOut + newDue;

    final cashInPct = totalTurnover > 0 ? (cashIn / totalTurnover) : 0.0;
    final cashOutPct = totalTurnover > 0 ? (cashOut / totalTurnover) : 0.0;
    final newDuePct = totalTurnover > 0 ? (newDue / totalTurnover) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF047857)),
                  SizedBox(width: 6),
                  Text(
                    'ক্যাশ ফ্লো ও হিসাব সামারি (Cash Flow Velocity)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  'নগদ অনুপাত: ${metrics.cashToDueRatio.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (cashInPct > 0)
                    Expanded(
                      flex: (cashInPct * 1000).toInt(),
                      child: Container(color: const Color(0xFF10B981)), // Cash In
                    ),
                  if (newDuePct > 0)
                    Expanded(
                      flex: (newDuePct * 1000).toInt(),
                      child: Container(color: const Color(0xFFF97316)), // Due Given
                    ),
                  if (cashOutPct > 0)
                    Expanded(
                      flex: (cashOutPct * 1000).toInt(),
                      child: Container(color: const Color(0xFFEF4444)), // Expenses
                    ),
                  if (totalTurnover <= 0)
                    Expanded(
                      child: Container(color: Colors.grey.shade200),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Legend & Metrics row
          Row(
            children: [
              _MetricLegendItem(
                label: 'ক্যাশ ইন (বিক্রি+আদায়)',
                value: KhosraMoney.formatPaisa(cashIn),
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              _MetricLegendItem(
                label: 'বকেয়া ঋণ',
                value: KhosraMoney.formatPaisa(newDue),
                color: const Color(0xFFF97316),
              ),
              const SizedBox(width: 12),
              _MetricLegendItem(
                label: 'খরচ',
                value: KhosraMoney.formatPaisa(cashOut),
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricLegendItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricLegendItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone Full Analytics Panel combining charts and breakdowns.
class KhosraAnalyticsPanel extends StatelessWidget {
  final KhosraMetrics metrics;

  const KhosraAnalyticsPanel({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cashflow Velocity
        KhosraCashflowMeter(metrics: metrics),
        const SizedBox(height: 14),

        // Donut Chart & Sales Breakdown Card
        Container(
          padding: const EdgeInsets.all(16),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFF0F766E)),
                      SizedBox(width: 6),
                      Text(
                        'বিক্রি ও সার্ভিস অনুপাত (Sales Breakdown)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    'মোট ${metrics.sellCount}টি বিক্রি',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KhosraDonutChart(
                slices: metrics.salesBreakdown,
                totalPaisa: metrics.totalSellPaisa,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Timeline Bar Chart Card
        Container(
          padding: const EdgeInsets.all(16),
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
          child: KhosraTimelineBarChart(buckets: metrics.timelineBuckets),
        ),

        // Expense & Due Category Distribution if any
        if (metrics.dueBreakdown.isNotEmpty || metrics.expenseBreakdown.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (metrics.dueBreakdown.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'বকেয়া ক্যাটাগরি',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...metrics.dueBreakdown.map(
                          (slice) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: slice.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      slice.label,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                                Text(
                                  slice.formattedTaka,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: slice.color,
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
              if (metrics.dueBreakdown.isNotEmpty && metrics.expenseBreakdown.isNotEmpty)
                const SizedBox(width: 10),
              if (metrics.expenseBreakdown.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'খরচের খাতসমূহ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...metrics.expenseBreakdown.map(
                          (slice) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: slice.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      slice.label,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                                Text(
                                  slice.formattedTaka,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: slice.color,
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
            ],
          ),
        ],
      ],
    );
  }
}

