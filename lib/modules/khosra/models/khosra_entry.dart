import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/app_time.dart';
import '../../customer/models/customer_model.dart';
import '../../customer/models/due_transaction.dart';

enum KhosraEntryType { sale, baki, khoroch, aday, other }

extension KhosraEntryTypeExtension on KhosraEntryType {
  String get value {
    switch (this) {
      case KhosraEntryType.sale:
        return 'sale';
      case KhosraEntryType.baki:
        return 'baki';
      case KhosraEntryType.khoroch:
        return 'khoroch';
      case KhosraEntryType.aday:
        return 'aday';
      case KhosraEntryType.other:
        return 'other';
    }
  }

  String get labelBn {
    switch (this) {
      case KhosraEntryType.sale:
        return 'বিক্রি (Sell)';
      case KhosraEntryType.baki:
        return 'বকেয়া (Baki)';
      case KhosraEntryType.khoroch:
        return 'খরচ (Khoroch)';
      case KhosraEntryType.aday:
        return 'আদায় (Aday)';
      case KhosraEntryType.other:
        return 'অন্যান্য (Other)';
    }
  }

  String get shortLabel {
    switch (this) {
      case KhosraEntryType.sale:
        return 'Sell';
      case KhosraEntryType.baki:
        return 'Bokeya';
      case KhosraEntryType.khoroch:
        return 'Khoroch';
      case KhosraEntryType.aday:
        return 'Aday';
      case KhosraEntryType.other:
        return 'Other';
    }
  }

  static KhosraEntryType fromString(String? raw) {
    switch (raw) {
      case 'sale':
        return KhosraEntryType.sale;
      case 'baki':
        return KhosraEntryType.baki;
      case 'khoroch':
        return KhosraEntryType.khoroch;
      case 'aday':
        return KhosraEntryType.aday;
      case 'other':
      default:
        return KhosraEntryType.other;
    }
  }
}

enum KhosraEntryStatus { pending, committed, failed, discarded }

extension KhosraEntryStatusExtension on KhosraEntryStatus {
  String get value {
    switch (this) {
      case KhosraEntryStatus.pending:
        return 'pending';
      case KhosraEntryStatus.committed:
        return 'committed';
      case KhosraEntryStatus.failed:
        return 'failed';
      case KhosraEntryStatus.discarded:
        return 'discarded';
    }
  }

  static KhosraEntryStatus fromString(String? raw) {
    switch (raw) {
      case 'committed':
        return KhosraEntryStatus.committed;
      case 'failed':
        return KhosraEntryStatus.failed;
      case 'discarded':
        return KhosraEntryStatus.discarded;
      case 'pending':
      default:
        return KhosraEntryStatus.pending;
    }
  }
}

/// Quick action configuration card for 1-tap Khosra sales.
class KhosraQuickAction {
  final String key;
  final String defaultName;
  final String labelBn;
  final int unitPricePaisa;
  final bool isService;

  const KhosraQuickAction({
    required this.key,
    required this.defaultName,
    required this.labelBn,
    required this.unitPricePaisa,
    required this.isService,
  });

  int get unitPriceTaka => unitPricePaisa ~/ 100;
}

class KhosraConstants {
  KhosraConstants._();

  static const List<KhosraQuickAction> generalSaleActions = [
    KhosraQuickAction(
      key: 'sale_20',
      defaultName: 'Sale',
      labelBn: 'বিক্রি ৳২০',
      unitPricePaisa: 2000,
      isService: false,
    ),
    KhosraQuickAction(
      key: 'sale_30',
      defaultName: 'Sale',
      labelBn: 'বিক্রি ৳৩০',
      unitPricePaisa: 3000,
      isService: false,
    ),
    KhosraQuickAction(
      key: 'sale_40',
      defaultName: 'Sale',
      labelBn: 'বিক্রি ৳৪০',
      unitPricePaisa: 4000,
      isService: false,
    ),
    KhosraQuickAction(
      key: 'sale_50',
      defaultName: 'Sale',
      labelBn: 'বিক্রি ৳৫০',
      unitPricePaisa: 5000,
      isService: false,
    ),
  ];

  static const List<KhosraQuickAction> photocopyActions = [
    KhosraQuickAction(
      key: 'photocopy_5',
      defaultName: 'Photocopy',
      labelBn: 'ফটোকপি ৳৫',
      unitPricePaisa: 500,
      isService: true,
    ),
    KhosraQuickAction(
      key: 'photocopy_10',
      defaultName: 'Photocopy',
      labelBn: 'ফটোকপি ৳১০',
      unitPricePaisa: 1000,
      isService: true,
    ),
    KhosraQuickAction(
      key: 'photocopy_15',
      defaultName: 'Photocopy',
      labelBn: 'ফটোকপি ৳১৫',
      unitPricePaisa: 1500,
      isService: true,
    ),
    KhosraQuickAction(
      key: 'photocopy_20',
      defaultName: 'Photocopy',
      labelBn: 'ফটোকপি ৳২০',
      unitPricePaisa: 2000,
      isService: true,
    ),
  ];

  static const List<({String id, String labelBn, String labelEn})>
  expenseCategories = [
    (id: 'shop', labelBn: 'দোকান (Shop)', labelEn: 'Shop Expense'),
    (
      id: 'stock_purchase',
      labelBn: 'মালামাল (Stock)',
      labelEn: 'Stock Purchase',
    ),
    (
      id: 'electricity_wifi',
      labelBn: 'বিদ্যুৎ ও ওয়াইফাই',
      labelEn: 'Electricity & WiFi',
    ),
    (id: 'personal', labelBn: 'ব্যক্তিগত (Personal)', labelEn: 'Personal'),
    (id: 'other', labelBn: 'অন্যান্য (Other)', labelEn: 'Other'),
  ];
}

/// Pure integer poisha (1 BDT = 100 poisha) money helpers.
class KhosraMoney {
  KhosraMoney._();

  static int takaToPaisa(num taka) => (taka * 100).round();

  static double paisaToTaka(int paisa) => paisa / 100.0;

  /// Parses user string input (e.g. "30", "30.5", "30.50") into integer poisha
  /// without floating-point inaccuracy.
  static int parseToPaisa(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll('৳', '');
    if (cleaned.isEmpty) return 0;
    final negative = cleaned.startsWith('-');
    final unsigned = negative ? cleaned.substring(1) : cleaned;
    final parts = unsigned.split('.');
    if (parts.length > 2) return 0;
    final takaPart = parts[0].isEmpty ? 0 : int.tryParse(parts[0]);
    if (takaPart == null) return 0;

    int paisaPart = 0;
    if (parts.length == 2 && parts[1].isNotEmpty) {
      final frac = parts[1];
      if (frac.length == 1) {
        final d = int.tryParse(frac);
        if (d == null) return 0;
        paisaPart = d * 10;
      } else {
        final d2 = int.tryParse(frac.substring(0, 2));
        if (d2 == null) return 0;
        paisaPart = d2;
        if (frac.length >= 3) {
          final d3 = int.tryParse(frac.substring(2, 3)) ?? 0;
          if (d3 >= 5) paisaPart += 1;
        }
      }
    }

    final total = (takaPart * 100) + paisaPart;
    return negative ? -total : total;
  }

  static String formatPaisa(int paisa, {bool showDecimalsIfZero = false}) {
    final isNeg = paisa < 0;
    final absPaisa = paisa.abs();
    final taka = absPaisa ~/ 100;
    final rem = absPaisa % 100;
    final prefix = isNeg ? '-৳' : '৳';
    if (rem == 0 && !showDecimalsIfZero) {
      return '$prefix$taka';
    }
    return '$prefix$taka.${rem.toString().padLeft(2, '0')}';
  }

  static String paisaToInputString(int paisa) {
    if (paisa <= 0) return '';
    final taka = paisa ~/ 100;
    final rem = paisa % 100;
    if (rem == 0) return '$taka';
    return '$taka.${rem.toString().padLeft(2, '0')}';
  }

  /// Calculates paidPaisa and duePaisa for a sale entry.
  static ({int paidPaisa, int duePaisa}) splitSalePayment({
    required int amountPaisa,
    required bool isBokeya,
    required bool isFullBokeya,
    int? partialPaidPaisa,
  }) {
    if (amountPaisa <= 0) {
      return (paidPaisa: 0, duePaisa: 0);
    }
    if (!isBokeya) {
      return (paidPaisa: amountPaisa, duePaisa: 0);
    }
    if (isFullBokeya) {
      return (paidPaisa: 0, duePaisa: amountPaisa);
    }
    final paid = (partialPaidPaisa ?? 0).clamp(0, amountPaisa);
    final due = amountPaisa - paid;
    return (paidPaisa: paid, duePaisa: due);
  }
}

/// View model representing an open due record from the existing due system,
/// adjusted in-memory by uncommitted pending Khosra `aday` entries.
class OpenDueRecord {
  final String id; // DueTransaction.id or synthetic bucket id
  final String customerId;
  final String dueCategory; // 'product' or 'cash_balance'
  final String
  rawDueType; // 'product' | 'service' | 'msfRecharge' | 'cashBorrow' | 'previousDue'
  final int originalPaisa;
  final int committedRemainingPaisa;
  final int pendingAdayPaisa;
  final int potentialProfitPaisa;
  final DateTime date;
  final String? note;
  final String? saleId;

  const OpenDueRecord({
    required this.id,
    required this.customerId,
    required this.dueCategory,
    required this.rawDueType,
    required this.originalPaisa,
    required this.committedRemainingPaisa,
    required this.pendingAdayPaisa,
    this.potentialProfitPaisa = 0,
    required this.date,
    this.note,
    this.saleId,
  });

  int get effectiveRemainingPaisa =>
      (committedRemainingPaisa - pendingAdayPaisa).clamp(
        0,
        committedRemainingPaisa,
      );

  String get typeLabelBn {
    switch (rawDueType) {
      case 'product':
        return 'পণ্য বকেয়া (Product Due)';
      case 'service':
        return 'সার্ভিস বকেয়া (Service Due)';
      case 'msfRecharge':
        return 'MSF/রিচার্জ বকেয়া';
      case 'cashBorrow':
        return 'নগদ/ব্যালেন্স বকেয়া (Cash/Balance)';
      case 'previousDue':
        return 'পূর্ববর্তী বকেয়া (Previous Due)';
      default:
        return rawDueType;
    }
  }

  /// Computes open due records for [customer] from existing [dueHistory] and
  /// subtracts any pending (uncommitted) Khosra `aday` entries so the user
  /// cannot over-collect.
  static List<OpenDueRecord> computeOpenDueRecords({
    required Customer customer,
    required List<DueTransaction> dueHistory,
    required List<KhosraEntry> pendingEntries,
  }) {
    final Map<String, int> bucketTargetPaisa = {
      'product': KhosraMoney.takaToPaisa(customer.productDue),
      'service': KhosraMoney.takaToPaisa(customer.serviceDue),
      'msfRecharge': KhosraMoney.takaToPaisa(customer.msfRechargeDue),
      'cashBorrow': KhosraMoney.takaToPaisa(customer.cashBorrowDue),
      'previousDue': KhosraMoney.takaToPaisa(customer.previousDue),
    };

    // Pending aday entries for this customer
    final pendingAdays = pendingEntries.where(
      (e) =>
          e.type == KhosraEntryType.aday &&
          e.status == KhosraEntryStatus.pending &&
          e.customerId == customer.id,
    );

    final List<OpenDueRecord> result = [];

    for (final entry in bucketTargetPaisa.entries) {
      final rawType = entry.key;
      final totalOpenForType = entry.value;
      if (totalOpenForType <= 0) continue;

      final dueCategory = (rawType == 'product' || rawType == 'service')
          ? 'product'
          : 'cash_balance';

      // Addition transactions for this rawType, newest first so most recent open dues match totalOpenForType
      final additions =
          dueHistory
              .where((t) => t.dueType == rawType && t.isAddition)
              .toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
                a.createdAt ?? DateTime(2000),
              ),
            );

      int remainingToAllocate = totalOpenForType;
      final List<OpenDueRecord> typeRecords = [];

      for (final tx in additions) {
        if (remainingToAllocate <= 0) break;
        final origPaisa = KhosraMoney.takaToPaisa(tx.amount);
        if (origPaisa <= 0) continue;
        final openForTx = origPaisa < remainingToAllocate
            ? origPaisa
            : remainingToAllocate;
        remainingToAllocate -= openForTx;

        final pendingForTx = pendingAdays
            .where((a) => a.dueRecordId == tx.id || a.dueTransactionId == tx.id)
            .fold<int>(0, (acc, a) => acc + a.amountPaisa);

        typeRecords.add(
          OpenDueRecord(
            id: tx.id,
            customerId: customer.id,
            dueCategory: dueCategory,
            rawDueType: rawType,
            originalPaisa: origPaisa,
            committedRemainingPaisa: openForTx,
            pendingAdayPaisa: pendingForTx,
            potentialProfitPaisa: KhosraMoney.takaToPaisa(tx.potentialProfit),
            date: tx.createdAt ?? customer.updatedAt,
            note: tx.note,
            saleId: tx.saleId,
          ),
        );
      }

      // If customer has remaining due balance not covered by addition tx rows (e.g. initial balance)
      if (remainingToAllocate > 0) {
        final bucketId = 'bucket_${customer.id}_$rawType';
        final pendingForBucket = pendingAdays
            .where(
              (a) =>
                  a.dueRecordId == bucketId ||
                  a.dueTransactionId == bucketId ||
                  ((a.dueRecordId == null || a.dueRecordId!.isEmpty) &&
                      a.details?['rawDueType'] == rawType),
            )
            .fold<int>(0, (acc, a) => acc + a.amountPaisa);

        typeRecords.add(
          OpenDueRecord(
            id: bucketId,
            customerId: customer.id,
            dueCategory: dueCategory,
            rawDueType: rawType,
            originalPaisa: totalOpenForType,
            committedRemainingPaisa: remainingToAllocate,
            pendingAdayPaisa: pendingForBucket,
            potentialProfitPaisa: 0,
            date: customer.updatedAt,
            note: 'পূর্বের বকেয়া ব্যালেন্স',
          ),
        );
      }

      result.addAll(typeRecords);
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }
}

class KhosraEntry {
  final String id;
  final String businessDate; // yyyy-MM-dd in Asia/Dhaka business time
  final DateTime createdAt; // Editable by user to backdate
  final DateTime updatedAt;
  final KhosraEntryType type; // sale | baki | khoroch | aday | other
  final String name; // Customer or item name, free text
  final String? customerId;
  final int amountPaisa; // Always integer poisha
  final int quantity; // Default 1
  final int? unitPricePaisa;
  final String? quickActionKey; // e.g. "sale_30", "photocopy_10"

  // Sale only
  final int paidPaisa;
  final int duePaisa;
  final int? costPaisa;

  // Baki only
  final String? dueType; // "product" | "cash_balance"
  final String? linkedEntryId;

  // Aday only
  final String? dueRecordId;
  final String? dueTransactionId;

  // Khoroch only
  final String? expenseCategory;

  final String? note;
  final Map<String, dynamic>? details;

  final KhosraEntryStatus status; // pending | committed | failed | discarded
  final DateTime? committedAt;
  final Map<String, dynamic>? committedRefs;
  final String? lastError;

  final String createdBy;
  final String createdByName;

  /// Transient local metadata flag indicating Firestore has not yet synced this entry.
  final bool hasPendingWrites;

  const KhosraEntry({
    required this.id,
    required this.businessDate,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    required this.name,
    this.customerId,
    required this.amountPaisa,
    this.quantity = 1,
    this.unitPricePaisa,
    this.quickActionKey,
    this.paidPaisa = 0,
    this.duePaisa = 0,
    this.costPaisa,
    this.dueType,
    this.linkedEntryId,
    this.dueRecordId,
    this.dueTransactionId,
    this.expenseCategory,
    this.note,
    this.details,
    this.status = KhosraEntryStatus.pending,
    this.committedAt,
    this.committedRefs,
    this.lastError,
    required this.createdBy,
    required this.createdByName,
    this.hasPendingWrites = false,
  });

  double get amountTaka => KhosraMoney.paisaToTaka(amountPaisa);
  double get paidTaka => KhosraMoney.paisaToTaka(paidPaisa);
  double get dueTaka => KhosraMoney.paisaToTaka(duePaisa);
  double? get costTaka =>
      costPaisa != null ? KhosraMoney.paisaToTaka(costPaisa!) : null;

  bool get isServiceSale =>
      (quickActionKey?.startsWith('photocopy_') ?? false) ||
      details?['itemType'] == 'service';

  static String formatBusinessDate(DateTime businessDateTime) {
    final y = businessDateTime.year.toString().padLeft(4, '0');
    final m = businessDateTime.month.toString().padLeft(2, '0');
    final d = businessDateTime.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String todayBusinessDate() {
    return formatBusinessDate(AppTime.businessNow());
  }

  factory KhosraEntry.fromMap(
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    DateTime parseDate(dynamic raw, DateTime fallback) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw) ?? fallback;
      return fallback;
    }

    DateTime? parseNullableDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    final now = AppTime.utcNow();
    final createdAt = parseDate(map['createdAt'], now);
    final updatedAt = parseDate(map['updatedAt'], createdAt);
    final dueRecId =
        (map['dueRecordId'] ?? map['dueTransactionId']) as String?;

    return KhosraEntry(
      id: (map['id'] ?? '') as String,
      businessDate:
          (map['businessDate'] as String?) ??
          formatBusinessDate(AppTime.toBusiness(createdAt)),
      createdAt: createdAt,
      updatedAt: updatedAt,
      type: KhosraEntryTypeExtension.fromString(map['type'] as String?),
      name: (map['name'] ?? '') as String,
      customerId: map['customerId'] as String?,
      amountPaisa: (map['amountPaisa'] as num?)?.round() ?? 0,
      quantity: (map['quantity'] as num?)?.round() ?? 1,
      unitPricePaisa: (map['unitPricePaisa'] as num?)?.round(),
      quickActionKey: map['quickActionKey'] as String?,
      paidPaisa: (map['paidPaisa'] as num?)?.round() ?? 0,
      duePaisa: (map['duePaisa'] as num?)?.round() ?? 0,
      costPaisa: (map['costPaisa'] as num?)?.round(),
      dueType: map['dueType'] as String?,
      linkedEntryId: map['linkedEntryId'] as String?,
      dueRecordId: dueRecId,
      dueTransactionId: (map['dueTransactionId'] as String?) ?? dueRecId,
      expenseCategory: map['expenseCategory'] as String?,
      note: map['note'] as String?,
      details: map['details'] != null
          ? Map<String, dynamic>.from(map['details'] as Map)
          : null,
      status: KhosraEntryStatusExtension.fromString(map['status'] as String?),
      committedAt: parseNullableDate(map['committedAt']),
      committedRefs: map['committedRefs'] != null
          ? Map<String, dynamic>.from(map['committedRefs'] as Map)
          : null,
      lastError: map['lastError'] as String?,
      createdBy: (map['createdBy'] ?? '') as String,
      createdByName: (map['createdByName'] ?? '') as String,
      hasPendingWrites: hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessDate': businessDate,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
      'type': type.value,
      'name': name,
      'customerId': customerId,
      'amountPaisa': amountPaisa,
      'quantity': quantity,
      'unitPricePaisa': unitPricePaisa,
      'quickActionKey': quickActionKey,
      'paidPaisa': paidPaisa,
      'duePaisa': duePaisa,
      'costPaisa': costPaisa,
      'dueType': dueType,
      'linkedEntryId': linkedEntryId,
      'dueRecordId': dueRecordId,
      'dueTransactionId': dueTransactionId ?? dueRecordId,
      'expenseCategory': expenseCategory,
      'note': note,
      'details': details,
      'status': status.value,
      'committedAt': committedAt != null
          ? Timestamp.fromDate(committedAt!.toUtc())
          : null,
      'committedRefs': committedRefs,
      'lastError': lastError,
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }

  KhosraEntry copyWith({
    String? id,
    String? businessDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    KhosraEntryType? type,
    String? name,
    String? customerId,
    bool clearCustomerId = false,
    int? amountPaisa,
    int? quantity,
    int? unitPricePaisa,
    bool clearUnitPricePaisa = false,
    String? quickActionKey,
    int? paidPaisa,
    int? duePaisa,
    int? costPaisa,
    bool clearCostPaisa = false,
    String? dueType,
    String? linkedEntryId,
    bool clearLinkedEntryId = false,
    String? dueRecordId,
    String? dueTransactionId,
    String? expenseCategory,
    String? note,
    bool clearNote = false,
    Map<String, dynamic>? details,
    KhosraEntryStatus? status,
    DateTime? committedAt,
    Map<String, dynamic>? committedRefs,
    String? lastError,
    bool clearLastError = false,
    String? createdBy,
    String? createdByName,
    bool? hasPendingWrites,
  }) {
    return KhosraEntry(
      id: id ?? this.id,
      businessDate: businessDate ?? this.businessDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      name: name ?? this.name,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      amountPaisa: amountPaisa ?? this.amountPaisa,
      quantity: quantity ?? this.quantity,
      unitPricePaisa: clearUnitPricePaisa
          ? null
          : (unitPricePaisa ?? this.unitPricePaisa),
      quickActionKey: quickActionKey ?? this.quickActionKey,
      paidPaisa: paidPaisa ?? this.paidPaisa,
      duePaisa: duePaisa ?? this.duePaisa,
      costPaisa: clearCostPaisa ? null : (costPaisa ?? this.costPaisa),
      dueType: dueType ?? this.dueType,
      linkedEntryId: clearLinkedEntryId
          ? null
          : (linkedEntryId ?? this.linkedEntryId),
      dueRecordId: dueRecordId ?? this.dueRecordId,
      dueTransactionId: dueTransactionId ?? this.dueTransactionId,
      expenseCategory: expenseCategory ?? this.expenseCategory,
      note: clearNote ? null : (note ?? this.note),
      details: details ?? this.details,
      status: status ?? this.status,
      committedAt: committedAt ?? this.committedAt,
      committedRefs: committedRefs ?? this.committedRefs,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }
}

