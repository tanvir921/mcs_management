import 'package:cloud_firestore/cloud_firestore.dart';

/// Detailed breakdown item for wallet, expense, transaction
class BreakdownItem {
  final String id;
  final String label;
  final double amount;
  final String? category;
  final String? description;

  BreakdownItem({
    required this.id,
    required this.label,
    required this.amount,
    this.category,
    this.description,
  });

  factory BreakdownItem.fromJson(Map<String, dynamic> json) {
    return BreakdownItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'amount': amount,
      'category': category,
      'description': description,
    };
  }
}

class DailyClosing {
  final String id;
  final String userId;
  final DateTime closingDate; // Date this closing is for
  final DateTime createdAt; // When it was created

  // Cash & Balance Components
  final double todaysHandCash; // Physical cash collected today
  final double todaysSalesTotal; // Total sales amount today (after discount)
  final double todaysSalesProfit; // Total sales profit today
  final double
  todaysMSFRecharge; // Total MSF/recharge from due_transactions today
  final double todaysCashBorrowDue; // Total cash borrow due settled today
  final double todaysExpenses; // Total expenses today
  final double totalDueCollections; // Total due collections (payments received)
  final double walletBalancesTotal; // Sum of all permanent wallet balances
  final double temporaryBalancesTotal; // Sum of all temporary wallet balances

  // Detailed Breakdowns (NEW)
  final List<BreakdownItem>
  walletBreakdown; // Individual wallet permanent balances
  final List<BreakdownItem>
  temporaryBalanceBreakdown; // Individual wallet temporary balances
  final List<BreakdownItem>
  msfBreakdown; // Individual MSF/recharge transactions
  final List<BreakdownItem>
  cashBorrowBreakdown; // Individual cash borrow transactions
  final List<BreakdownItem> expenseBreakdown; // Individual expense items

  // Calculation Fields
  final double
  subtotal; // Calculated: wallets + hand cash + sales + MSF + cash borrow - expenses - temp balances
  final double yesterdaySubtotal; // Subtotal from previous day (for comparison)
  final double
  cashoutCharge; // Temporary charge (subtracted from subtotal during closing)
  final double
  remainingCash; // (subtotal - cashoutCharge) - yesterdaySubtotal (small sells)

  // Profit Section
  final List<ProfitEntry>
  profitEntries; // Optional profit from each section/wallet
  final double totalProfit; // Sales profit + optional profits
  final double deductedProfit; // Optional: profit deducted from closing balance
  final double finalClosingBalance; // subtotal - deductedProfit

  // Status
  final bool isApproved; // Has been reviewed and approved
  final bool isUploaded; // Has been uploaded to server
  final String? approvedBy; // User ID who approved
  final String? approvedByName; // User name who approved
  final DateTime? approvedAt; // When approved
  final String? pdfUrl; // URL of generated PDF report

  // Notes
  final String? remarks; // Any remarks/notes about closing

  DailyClosing({
    required this.id,
    required this.userId,
    required this.closingDate,
    required this.createdAt,
    required this.todaysHandCash,
    required this.todaysSalesTotal,
    required this.todaysSalesProfit,
    required this.todaysMSFRecharge,
    required this.todaysCashBorrowDue,
    required this.todaysExpenses,
    required this.totalDueCollections,
    required this.walletBalancesTotal,
    required this.temporaryBalancesTotal,
    required this.walletBreakdown,
    required this.temporaryBalanceBreakdown,
    required this.msfBreakdown,
    required this.cashBorrowBreakdown,
    required this.expenseBreakdown,
    required this.subtotal,
    required this.yesterdaySubtotal,
    required this.remainingCash,
    required this.profitEntries,
    required this.totalProfit,
    this.deductedProfit = 0,
    required this.finalClosingBalance,
    this.cashoutCharge = 0,
    this.isApproved = false,
    this.isUploaded = false,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.pdfUrl,
    this.remarks,
  });

  factory DailyClosing.fromJson(Map<String, dynamic> json) {
    return DailyClosing(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      closingDate: json['closingDate'] != null
          ? (json['closingDate'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      todaysHandCash: (json['todaysHandCash'] as num?)?.toDouble() ?? 0,
      todaysSalesTotal: (json['todaysSalesTotal'] as num?)?.toDouble() ?? 0,
      todaysSalesProfit: (json['todaysSalesProfit'] as num?)?.toDouble() ?? 0,
      todaysMSFRecharge: (json['todaysMSFRecharge'] as num?)?.toDouble() ?? 0,
      todaysCashBorrowDue:
          (json['todaysCashBorrowDue'] as num?)?.toDouble() ?? 0,
      todaysExpenses: (json['todaysExpenses'] as num?)?.toDouble() ?? 0,
      totalDueCollections:
          (json['totalDueCollections'] as num?)?.toDouble() ?? 0,
      walletBalancesTotal:
          (json['walletBalancesTotal'] as num?)?.toDouble() ?? 0,
      temporaryBalancesTotal:
          (json['temporaryBalancesTotal'] as num?)?.toDouble() ?? 0,
      walletBreakdown:
          (json['walletBreakdown'] as List<dynamic>?)
              ?.map((e) => BreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      temporaryBalanceBreakdown:
          (json['temporaryBalanceBreakdown'] as List<dynamic>?)
              ?.map((e) => BreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      msfBreakdown:
          (json['msfBreakdown'] as List<dynamic>?)
              ?.map((e) => BreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cashBorrowBreakdown:
          (json['cashBorrowBreakdown'] as List<dynamic>?)
              ?.map((e) => BreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      expenseBreakdown:
          (json['expenseBreakdown'] as List<dynamic>?)
              ?.map((e) => BreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      yesterdaySubtotal: (json['yesterdaySubtotal'] as num?)?.toDouble() ?? 0,
      remainingCash: (json['remainingCash'] as num?)?.toDouble() ?? 0,
      profitEntries:
          (json['profitEntries'] as List<dynamic>?)
              ?.map((e) => ProfitEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
      deductedProfit: (json['deductedProfit'] as num?)?.toDouble() ?? 0,
      finalClosingBalance:
          (json['finalClosingBalance'] as num?)?.toDouble() ?? 0,
      cashoutCharge: (json['cashoutCharge'] as num?)?.toDouble() ?? 0,
      isApproved: json['isApproved'] as bool? ?? false,
      isUploaded: json['isUploaded'] as bool? ?? false,
      approvedBy: json['approvedBy'] as String?,
      approvedByName: json['approvedByName'] as String?,
      approvedAt: json['approvedAt'] != null
          ? (json['approvedAt'] as Timestamp).toDate()
          : null,
      pdfUrl: json['pdfUrl'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'closingDate': Timestamp.fromDate(closingDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'todaysHandCash': todaysHandCash,
      'todaysSalesTotal': todaysSalesTotal,
      'todaysSalesProfit': todaysSalesProfit,
      'todaysMSFRecharge': todaysMSFRecharge,
      'todaysCashBorrowDue': todaysCashBorrowDue,
      'todaysExpenses': todaysExpenses,
      'totalDueCollections': totalDueCollections,
      'walletBalancesTotal': walletBalancesTotal,
      'temporaryBalancesTotal': temporaryBalancesTotal,
      'walletBreakdown': walletBreakdown.map((item) => item.toJson()).toList(),
      'temporaryBalanceBreakdown': temporaryBalanceBreakdown
          .map((item) => item.toJson())
          .toList(),
      'msfBreakdown': msfBreakdown.map((item) => item.toJson()).toList(),
      'cashBorrowBreakdown': cashBorrowBreakdown
          .map((item) => item.toJson())
          .toList(),
      'expenseBreakdown': expenseBreakdown
          .map((item) => item.toJson())
          .toList(),
      'subtotal': subtotal,
      'yesterdaySubtotal': yesterdaySubtotal,
      'remainingCash': remainingCash,
      'profitEntries': profitEntries.map((e) => e.toJson()).toList(),
      'totalProfit': totalProfit,
      'deductedProfit': deductedProfit,
      'finalClosingBalance': finalClosingBalance,
      'cashoutCharge': cashoutCharge,
      'isApproved': isApproved,
      'isUploaded': isUploaded,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'pdfUrl': pdfUrl,
      'remarks': remarks,
    };
  }

  DailyClosing copyWith({
    String? id,
    String? userId,
    DateTime? closingDate,
    DateTime? createdAt,
    double? todaysHandCash,
    double? todaysSalesTotal,
    double? todaysSalesProfit,
    double? todaysMSFRecharge,
    double? todaysCashBorrowDue,
    double? todaysExpenses,
    double? totalDueCollections,
    double? walletBalancesTotal,
    double? temporaryBalancesTotal,
    List<BreakdownItem>? walletBreakdown,
    List<BreakdownItem>? temporaryBalanceBreakdown,
    List<BreakdownItem>? msfBreakdown,
    List<BreakdownItem>? cashBorrowBreakdown,
    List<BreakdownItem>? expenseBreakdown,
    double? subtotal,
    double? yesterdaySubtotal,
    double? remainingCash,
    List<ProfitEntry>? profitEntries,
    double? totalProfit,
    double? deductedProfit,
    double? finalClosingBalance,
    double? cashoutCharge,
    bool? isApproved,
    bool? isUploaded,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    String? pdfUrl,
    String? remarks,
  }) {
    return DailyClosing(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      closingDate: closingDate ?? this.closingDate,
      createdAt: createdAt ?? this.createdAt,
      todaysHandCash: todaysHandCash ?? this.todaysHandCash,
      todaysSalesTotal: todaysSalesTotal ?? this.todaysSalesTotal,
      todaysSalesProfit: todaysSalesProfit ?? this.todaysSalesProfit,
      todaysMSFRecharge: todaysMSFRecharge ?? this.todaysMSFRecharge,
      todaysCashBorrowDue: todaysCashBorrowDue ?? this.todaysCashBorrowDue,
      todaysExpenses: todaysExpenses ?? this.todaysExpenses,
      totalDueCollections: totalDueCollections ?? this.totalDueCollections,
      walletBalancesTotal: walletBalancesTotal ?? this.walletBalancesTotal,
      temporaryBalancesTotal:
          temporaryBalancesTotal ?? this.temporaryBalancesTotal,
      walletBreakdown: walletBreakdown ?? this.walletBreakdown,
      temporaryBalanceBreakdown:
          temporaryBalanceBreakdown ?? this.temporaryBalanceBreakdown,
      msfBreakdown: msfBreakdown ?? this.msfBreakdown,
      cashBorrowBreakdown: cashBorrowBreakdown ?? this.cashBorrowBreakdown,
      expenseBreakdown: expenseBreakdown ?? this.expenseBreakdown,
      subtotal: subtotal ?? this.subtotal,
      yesterdaySubtotal: yesterdaySubtotal ?? this.yesterdaySubtotal,
      remainingCash: remainingCash ?? this.remainingCash,
      profitEntries: profitEntries ?? this.profitEntries,
      totalProfit: totalProfit ?? this.totalProfit,
      deductedProfit: deductedProfit ?? this.deductedProfit,
      finalClosingBalance: finalClosingBalance ?? this.finalClosingBalance,
      cashoutCharge: cashoutCharge ?? this.cashoutCharge,
      isApproved: isApproved ?? this.isApproved,
      isUploaded: isUploaded ?? this.isUploaded,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      remarks: remarks ?? this.remarks,
    );
  }
}

class ProfitEntry {
  final String id;
  final String source; // e.g., "Bkash Agent", "Photocopy", "Card Sales"
  final double amount; // Profit amount from this source
  final String? note; // Optional note about profit source

  ProfitEntry({
    required this.id,
    required this.source,
    required this.amount,
    this.note,
  });

  factory ProfitEntry.fromJson(Map<String, dynamic> json) {
    return ProfitEntry(
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'source': source, 'amount': amount, 'note': note};
  }

  ProfitEntry copyWith({
    String? id,
    String? source,
    double? amount,
    String? note,
  }) {
    return ProfitEntry(
      id: id ?? this.id,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }
}
