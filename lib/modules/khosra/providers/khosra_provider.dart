import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/utils/app_time.dart';
import '../models/khosra_entry.dart';
import '../services/khosra_service.dart';

class KhosraProvider extends ChangeNotifier {
  final KhosraService _service;

  KhosraProvider({KhosraService? service})
    : _service = service ?? KhosraService();

  StreamSubscription<List<KhosraEntry>>? _entriesSub;

  String _selectedBusinessDate = KhosraEntry.todayBusinessDate();
  List<KhosraEntry> _entries = [];
  List<KhosraEntry> _olderPendingEntries = [];
  bool _isLoading = false;
  bool _isCommitting = false;
  String? _error;

  String get selectedBusinessDate => _selectedBusinessDate;
  bool get isTodaySelected =>
      _selectedBusinessDate == KhosraEntry.todayBusinessDate();

  List<KhosraEntry> get entries => _entries;
  List<KhosraEntry> get olderPendingEntries => _olderPendingEntries;
  int get olderPendingCount => _olderPendingEntries.length;

  bool get isLoading => _isLoading;
  bool get isCommitting => _isCommitting;
  String? get error => _error;

  /// Pending or failed entries for the currently selected business date.
  List<KhosraEntry> get pendingEntries => _entries
      .where(
        (e) =>
            e.status == KhosraEntryStatus.pending ||
            e.status == KhosraEntryStatus.failed,
      )
      .toList();

  int get pendingCount => pendingEntries.length;

  /// True if any entry in the current view is waiting in the local offline queue.
  bool get hasUnsyncedEntries => _entries.any((e) => e.hasPendingWrites);

  // Temporary totals for active (pending + committed today) entries on selected date
  int get totalSellPaisa => _entries
      .where(
        (e) =>
            e.type == KhosraEntryType.sale &&
            e.status != KhosraEntryStatus.discarded,
      )
      .fold<int>(0, (sum, e) => sum + e.amountPaisa);

  int get totalNewBakiPaisa => _entries
      .where(
        (e) =>
            e.type == KhosraEntryType.baki &&
            e.status != KhosraEntryStatus.discarded,
      )
      .fold<int>(0, (sum, e) => sum + e.amountPaisa);

  int get totalKhorochPaisa => _entries
      .where(
        (e) =>
            e.type == KhosraEntryType.khoroch &&
            e.status != KhosraEntryStatus.discarded,
      )
      .fold<int>(0, (sum, e) => sum + e.amountPaisa);

  int get totalAdayPaisa => _entries
      .where(
        (e) =>
            e.type == KhosraEntryType.aday &&
            e.status != KhosraEntryStatus.discarded,
      )
      .fold<int>(0, (sum, e) => sum + e.amountPaisa);

  void init({String? businessDate}) {
    final targetDate = businessDate ?? KhosraEntry.todayBusinessDate();
    _selectedBusinessDate = targetDate;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _entriesSub?.cancel();
    _entriesSub = _service.watchEntriesForDate(targetDate).listen(
      (list) {
        _entries = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    refreshOlderPendingEntries();
  }

  Future<void> selectBusinessDate(String businessDate) async {
    if (_selectedBusinessDate == businessDate && _entriesSub != null) return;
    init(businessDate: businessDate);
  }

  Future<void> refreshOlderPendingEntries() async {
    try {
      final today = KhosraEntry.todayBusinessDate();
      _olderPendingEntries = await _service.getPendingEntriesBeforeDate(today);
      notifyListeners();
    } catch (_) {
      // Ignore offline errors when checking older days
    }
  }

  /// 1-tap quick action sale (e.g. Sale ৳20/30/40/50 or Photocopy ৳5/10/15/20).
  Future<KhosraEntry> addQuickSale(
    KhosraQuickAction action, {
    int quantity = 1,
    required String userId,
    required String userName,
  }) async {
    final qty = quantity < 1 ? 1 : quantity;
    final totalPaisa = action.unitPricePaisa * qty;
    final now = _defaultEntryTimeForSelectedDate();
    final created = await _service.addSaleEntry(
      name: qty > 1 ? '${action.defaultName} ×$qty' : action.defaultName,
      amountPaisa: totalPaisa,
      quantity: qty,
      unitPricePaisa: action.unitPricePaisa,
      quickActionKey: action.key,
      paidPaisa: totalPaisa,
      duePaisa: 0,
      costPaisa: action.isService ? 0 : null,
      details: {'itemType': action.isService ? 'service' : 'non_inventory'},
      createdAt: now,
      businessDate: _selectedBusinessDate,
      createdBy: userId,
      createdByName: userName,
    );
    return created.first;
  }

  Future<List<KhosraEntry>> addSale({
    required String name,
    String? customerId,
    required int amountPaisa,
    int quantity = 1,
    int? unitPricePaisa,
    required int paidPaisa,
    required int duePaisa,
    int? costPaisa,
    String? note,
    Map<String, dynamic>? details,
    DateTime? createdAt,
    required String userId,
    required String userName,
  }) async {
    final entryTime = createdAt ?? _defaultEntryTimeForSelectedDate();
    final bDate = KhosraEntry.formatBusinessDate(
      AppTime.toBusiness(entryTime),
    );
    return _service.addSaleEntry(
      name: name,
      customerId: customerId,
      amountPaisa: amountPaisa,
      quantity: quantity,
      unitPricePaisa: unitPricePaisa,
      paidPaisa: paidPaisa,
      duePaisa: duePaisa,
      costPaisa: costPaisa,
      note: note,
      details: details,
      createdAt: entryTime,
      businessDate: bDate,
      createdBy: userId,
      createdByName: userName,
    );
  }

  Future<KhosraEntry> addBaki({
    required String name,
    String? customerId,
    required int amountPaisa,
    required String dueType, // 'product' | 'cash_balance'
    String? note,
    Map<String, dynamic>? details,
    DateTime? createdAt,
    required String userId,
    required String userName,
  }) async {
    final entryTime = createdAt ?? _defaultEntryTimeForSelectedDate();
    final bDate = KhosraEntry.formatBusinessDate(
      AppTime.toBusiness(entryTime),
    );
    final entry = KhosraEntry(
      id: '',
      businessDate: bDate,
      createdAt: entryTime,
      updatedAt: AppTime.utcNow(),
      type: KhosraEntryType.baki,
      name: name.trim(),
      customerId: customerId,
      amountPaisa: amountPaisa,
      dueType: dueType,
      note: note,
      details: details,
      status: KhosraEntryStatus.pending,
      createdBy: userId,
      createdByName: userName,
    );
    final saved = await _service.addGenericEntry(entry);
    await refreshOlderPendingEntries();
    return saved;
  }

  Future<KhosraEntry> addAday({
    required String customerName,
    required String customerId,
    required String dueRecordId,
    required String dueCategory, // 'product' | 'cash_balance'
    required String rawDueType,
    required int amountPaisa,
    int? originalDuePaisa,
    int? potentialProfitPaisa,
    String? saleId,
    String? note,
    DateTime? createdAt,
    required String userId,
    required String userName,
  }) async {
    final entryTime = createdAt ?? _defaultEntryTimeForSelectedDate();
    final bDate = KhosraEntry.formatBusinessDate(
      AppTime.toBusiness(entryTime),
    );
    final entry = KhosraEntry(
      id: '',
      businessDate: bDate,
      createdAt: entryTime,
      updatedAt: AppTime.utcNow(),
      type: KhosraEntryType.aday,
      name: customerName.trim(),
      customerId: customerId,
      amountPaisa: amountPaisa,
      dueType: dueCategory,
      dueRecordId: dueRecordId,
      dueTransactionId: dueRecordId,
      note: note,
      details: {
        'rawDueType': rawDueType,
        if (originalDuePaisa != null) 'originalDuePaisa': originalDuePaisa,
        if (potentialProfitPaisa != null)
          'potentialProfitPaisa': potentialProfitPaisa,
        if (saleId != null) 'saleId': saleId,
      },
      status: KhosraEntryStatus.pending,
      createdBy: userId,
      createdByName: userName,
    );
    final saved = await _service.addGenericEntry(entry);
    await refreshOlderPendingEntries();
    return saved;
  }

  Future<KhosraEntry> addKhoroch({
    required String description,
    required int amountPaisa,
    required String expenseCategory,
    String? note,
    DateTime? createdAt,
    required String userId,
    required String userName,
  }) async {
    final entryTime = createdAt ?? _defaultEntryTimeForSelectedDate();
    final bDate = KhosraEntry.formatBusinessDate(
      AppTime.toBusiness(entryTime),
    );
    final entry = KhosraEntry(
      id: '',
      businessDate: bDate,
      createdAt: entryTime,
      updatedAt: AppTime.utcNow(),
      type: KhosraEntryType.khoroch,
      name: description.trim().isEmpty ? 'দোকান খরচ' : description.trim(),
      amountPaisa: amountPaisa,
      expenseCategory: expenseCategory,
      note: note,
      status: KhosraEntryStatus.pending,
      createdBy: userId,
      createdByName: userName,
    );
    final saved = await _service.addGenericEntry(entry);
    await refreshOlderPendingEntries();
    return saved;
  }

  Future<KhosraEntry> addOther({
    required String name,
    required int amountPaisa,
    String? note,
    DateTime? createdAt,
    required String userId,
    required String userName,
  }) async {
    final entryTime = createdAt ?? _defaultEntryTimeForSelectedDate();
    final bDate = KhosraEntry.formatBusinessDate(
      AppTime.toBusiness(entryTime),
    );
    final entry = KhosraEntry(
      id: '',
      businessDate: bDate,
      createdAt: entryTime,
      updatedAt: AppTime.utcNow(),
      type: KhosraEntryType.other,
      name: name.trim().isEmpty ? 'Other' : name.trim(),
      amountPaisa: amountPaisa,
      note: note,
      status: KhosraEntryStatus.pending,
      createdBy: userId,
      createdByName: userName,
    );
    final saved = await _service.addGenericEntry(entry);
    await refreshOlderPendingEntries();
    return saved;
  }

  Future<void> updateEntry(KhosraEntry updated) async {
    await _service.updateEntryWithSync(updated);
    await refreshOlderPendingEntries();
  }

  Future<List<KhosraEntry>> deleteEntry(String entryId) async {
    final originals = await _service.discardEntryWithSync(entryId);
    await refreshOlderPendingEntries();
    return originals;
  }

  Future<void> restoreDeletedEntries(List<KhosraEntry> originals) async {
    await _service.restoreEntries(originals);
    await refreshOlderPendingEntries();
  }

  Future<KhosraCommitSummary> commitSelectedEntries({
    required List<String> entryIds,
    required String userId,
    required String userName,
    Future<void> Function({
      required String action,
      required String module,
      String? details,
    })?
    logAction,
  }) async {
    if (_isCommitting) {
      return const KhosraCommitSummary(
        committedIds: [],
        failedEntries: {},
        skippedIds: [],
      );
    }
    _isCommitting = true;
    _error = null;
    notifyListeners();

    try {
      final summary = await _service.commitEntries(
        entryIds: entryIds,
        userId: userId,
        userName: userName,
        logActionOverride: logAction,
      );
      await refreshOlderPendingEntries();
      return summary;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isCommitting = false;
      notifyListeners();
    }
  }

  DateTime _defaultEntryTimeForSelectedDate() {
    final nowUtc = AppTime.utcNow();
    final today = KhosraEntry.todayBusinessDate();
    if (_selectedBusinessDate == today) {
      return nowUtc;
    }
    final parts = _selectedBusinessDate.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]) ?? 2026;
      final m = int.tryParse(parts[1]) ?? 1;
      final d = int.tryParse(parts[2]) ?? 1;
      final bNow = AppTime.businessNow();
      final customBusiness = DateTime.utc(
        y,
        m,
        d,
        bNow.hour,
        bNow.minute,
        bNow.second,
      );
      return AppTime.toUtcFromBusiness(customBusiness);
    }
    return nowUtc;
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    super.dispose();
  }
}

