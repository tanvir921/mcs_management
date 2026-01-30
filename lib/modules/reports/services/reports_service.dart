import 'package:cloud_firestore/cloud_firestore.dart';
import '../../expense/services/expense_service.dart';

enum DateFilter { today, yesterday, thisMonth, thisYear }

class ReportsSummary {
  final Map<String, double>
  duesAddedByType; // product, service, msfRecharge, cashBorrow, previousDue
  final Map<String, double>
  collectionsByType; // product, service, msfRecharge, cashBorrow, previousDue
  final double totalDuesAdded;
  final double totalCollections;
  final Map<String, dynamic>? expenseStats;

  ReportsSummary({
    required this.duesAddedByType,
    required this.collectionsByType,
    required this.totalDuesAdded,
    required this.totalCollections,
    this.expenseStats,
  });
}

class ReportsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _transactionsCollection = 'due_transactions';

  /// Get start and end DateTime for the given filter (inclusive)
  Map<String, DateTime> _getRange(DateFilter filter) {
    final now = DateTime.now();
    late DateTime start;
    late DateTime end;

    switch (filter) {
      case DateFilter.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case DateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
        break;
      case DateFilter.thisMonth:
        start = DateTime(now.year, now.month, 1);
        // End of month
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        end = nextMonth.subtract(const Duration(milliseconds: 1));
        break;
      case DateFilter.thisYear:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
    }
    return {'start': start, 'end': end};
  }

  /// Fetch and aggregate due transactions for the selected date range
  Future<ReportsSummary> getSummary(DateFilter filter) async {
    final range = _getRange(filter);
    final start = range['start']!;
    final end = range['end']!;

    final snapshot = await _firestore
        .collection(_transactionsCollection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final duesAddedByType = <String, double>{
      'product': 0,
      'service': 0,
      'msfRecharge': 0,
      'cashBorrow': 0,
      'previousDue': 0,
    };

    final collectionsByType = <String, double>{
      'product': 0,
      'service': 0,
      'msfRecharge': 0,
      'cashBorrow': 0,
      'previousDue': 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final String dueType = data['dueType'] as String;
      final double amount = (data['amount'] as num).toDouble();
      final bool isAddition = data['isAddition'] as bool;

      // Dues added: include all except previousDue (requested to exclude from reports when adding)
      if (isAddition && duesAddedByType.containsKey(dueType)) {
        if (dueType != 'previousDue') {
          duesAddedByType[dueType] = (duesAddedByType[dueType] ?? 0) + amount;
        }
      }

      // Collections: include all due types when isAddition=false, and include previousDue here
      if (!isAddition && collectionsByType.containsKey(dueType)) {
        collectionsByType[dueType] = (collectionsByType[dueType] ?? 0) + amount;
      }
    }

    final totalDuesAdded = duesAddedByType.values.fold(0.0, (a, b) => a + b);
    final totalCollections = collectionsByType.values.fold(
      0.0,
      (a, b) => a + b,
    );

    // Get expense statistics for the same date range
    final expenseService = ExpenseService();
    final expenseStats = await expenseService.getExpenseStats(
      startDate: start,
      endDate: end,
    );

    return ReportsSummary(
      duesAddedByType: duesAddedByType,
      collectionsByType: collectionsByType,
      totalDuesAdded: totalDuesAdded,
      totalCollections: totalCollections,
      expenseStats: expenseStats,
    );
  }
}
