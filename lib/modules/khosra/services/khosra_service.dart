import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/app_time.dart';
import '../../customer/models/customer_model.dart';
import '../../customer/services/customer_service.dart';
import '../../expense/models/expense.dart';
import '../../expense/services/expense_service.dart';
import '../../inventory/services/inventory_service.dart';
import '../../sales/models/sale.dart';
import '../../sales/models/sale_item.dart';
import '../../sales/services/sales_service.dart';
import '../models/khosra_entry.dart';
import 'khosra_local_cache_stub.dart'
    if (dart.library.io) 'khosra_local_cache_io.dart';

class KhosraCommitSummary {
  final List<String> committedIds;
  final Map<String, String> failedEntries; // entryId -> error message
  final List<String> skippedIds;

  const KhosraCommitSummary({
    required this.committedIds,
    required this.failedEntries,
    required this.skippedIds,
  });

  int get committedCount => committedIds.length;
  int get failedCount => failedEntries.length;
  bool get hasFailures => failedEntries.isNotEmpty;
}

/// Storage abstraction for `khosra_entries` and `khosra_meta/commit_lock`.
abstract class KhosraStore {
  String generateId();
  Stream<List<KhosraEntry>> watchEntriesForDate(String businessDate);
  Future<List<KhosraEntry>> getPendingEntriesBeforeDate(String businessDate);
  Future<List<KhosraEntry>> getAllPendingEntries();
  Future<KhosraEntry?> getEntryById(String id);
  Future<void> saveEntry(KhosraEntry entry);
  Future<void> saveEntriesBatch(List<KhosraEntry> entries);
  Future<bool> acquireCommitLock({
    required String userId,
    required String userName,
  });
  Future<void> releaseCommitLock(String userId);
}

class FirestoreKhosraStore implements KhosraStore {
  final FirebaseFirestore _firestore;
  static const String entriesCollection = 'khosra_entries';
  static const String metaCollection = 'khosra_meta';
  static const String commitLockDoc = 'commit_lock';

  final Map<String, KhosraEntry> _localEntries = {};
  final StreamController<void> _localChanges =
      StreamController<void>.broadcast();
  bool _localLoaded = false;
  bool _firestoreBlocked = false;

  FirestoreKhosraStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> _ensureLocalLoaded() async {
    if (_localLoaded) return;
    _localLoaded = true;
    final cached = await loadLocalKhosraEntries();
    for (final entry in cached) {
      _localEntries.putIfAbsent(entry.id, () => entry);
    }
  }

  Future<void> _persistLocal() async {
    await saveLocalKhosraEntries(_localEntries.values);
    if (!_localChanges.isClosed) {
      _localChanges.add(null);
    }
  }

  List<KhosraEntry> _localForDate(String businessDate) {
    final list = _localEntries.values
        .where(
          (e) =>
              e.businessDate == businessDate &&
              e.status != KhosraEntryStatus.discarded,
        )
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  String generateId() => _firestore.collection(entriesCollection).doc().id;

  @override
  Stream<List<KhosraEntry>> watchEntriesForDate(String businessDate) {
    late final StreamController<List<KhosraEntry>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? firestoreSub;
    StreamSubscription<void>? localSub;

    void emitCurrent() {
      if (!controller.isClosed) {
        controller.add(_localForDate(businessDate));
      }
    }

    controller = StreamController<List<KhosraEntry>>.broadcast(
      onListen: () async {
        await _ensureLocalLoaded();
        emitCurrent();

        localSub = _localChanges.stream.listen((_) => emitCurrent());

        if (!_firestoreBlocked) {
          firestoreSub = _firestore
              .collection(entriesCollection)
              .where('businessDate', isEqualTo: businessDate)
              .snapshots(includeMetadataChanges: true)
              .listen(
                (snapshot) async {
                  for (final doc in snapshot.docs) {
                    final remote = KhosraEntry.fromMap(
                      doc.data(),
                      hasPendingWrites: doc.metadata.hasPendingWrites,
                    );
                    _localEntries[remote.id] = remote;
                  }
                  await saveLocalKhosraEntries(_localEntries.values);
                  emitCurrent();
                },
                onError: (Object error) {
                  if (error is FirebaseException &&
                      error.code == 'permission-denied') {
                    _firestoreBlocked = true;
                    firestoreSub?.cancel();
                    firestoreSub = null;
                  }
                  emitCurrent();
                },
              );
        }
      },
      onCancel: () async {
        await firestoreSub?.cancel();
        await localSub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<List<KhosraEntry>> getPendingEntriesBeforeDate(
    String businessDate,
  ) async {
    await _ensureLocalLoaded();
    if (!_firestoreBlocked) {
      try {
        final snapshot = await _firestore
            .collection(entriesCollection)
            .where('status', whereIn: ['pending', 'failed'])
            .get();
        for (final doc in snapshot.docs) {
          final remote = KhosraEntry.fromMap(
            doc.data(),
            hasPendingWrites: doc.metadata.hasPendingWrites,
          );
          _localEntries[remote.id] = remote;
        }
        await saveLocalKhosraEntries(_localEntries.values);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') _firestoreBlocked = true;
      } catch (_) {}
    }

    final entries = _localEntries.values
        .where(
          (e) =>
              (e.status == KhosraEntryStatus.pending ||
                  e.status == KhosraEntryStatus.failed) &&
              e.businessDate.compareTo(businessDate) < 0,
        )
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  @override
  Future<List<KhosraEntry>> getAllPendingEntries() async {
    await _ensureLocalLoaded();
    if (!_firestoreBlocked) {
      try {
        final snapshot = await _firestore
            .collection(entriesCollection)
            .where('status', whereIn: ['pending', 'failed'])
            .get();
        for (final doc in snapshot.docs) {
          final remote = KhosraEntry.fromMap(
            doc.data(),
            hasPendingWrites: doc.metadata.hasPendingWrites,
          );
          _localEntries[remote.id] = remote;
        }
        await saveLocalKhosraEntries(_localEntries.values);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') _firestoreBlocked = true;
      } catch (_) {}
    }

    final entries = _localEntries.values
        .where(
          (e) =>
              e.status == KhosraEntryStatus.pending ||
              e.status == KhosraEntryStatus.failed,
        )
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  @override
  Future<KhosraEntry?> getEntryById(String id) async {
    await _ensureLocalLoaded();
    if (!_firestoreBlocked) {
      try {
        final doc = await _firestore
            .collection(entriesCollection)
            .doc(id)
            .get();
        if (doc.exists && doc.data() != null) {
          final remote = KhosraEntry.fromMap(
            doc.data()!,
            hasPendingWrites: doc.metadata.hasPendingWrites,
          );
          _localEntries[remote.id] = remote;
          await saveLocalKhosraEntries(_localEntries.values);
          return remote;
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') _firestoreBlocked = true;
      } catch (_) {}
    }
    return _localEntries[id];
  }

  @override
  Future<void> saveEntry(KhosraEntry entry) async {
    await _ensureLocalLoaded();
    _localEntries[entry.id] = entry;
    await _persistLocal();

    if (_firestoreBlocked) return;
    try {
      await _firestore
          .collection(entriesCollection)
          .doc(entry.id)
          .set(entry.toMap())
          .timeout(const Duration(milliseconds: 1200), onTimeout: () {});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') _firestoreBlocked = true;
    } catch (_) {}
  }

  @override
  Future<void> saveEntriesBatch(List<KhosraEntry> entries) async {
    if (entries.isEmpty) return;
    await _ensureLocalLoaded();
    for (final entry in entries) {
      _localEntries[entry.id] = entry;
    }
    await _persistLocal();

    if (_firestoreBlocked) return;
    try {
      final batch = _firestore.batch();
      for (final entry in entries) {
        batch.set(
          _firestore.collection(entriesCollection).doc(entry.id),
          entry.toMap(),
        );
      }
      await batch
          .commit()
          .timeout(const Duration(milliseconds: 1200), onTimeout: () {});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') _firestoreBlocked = true;
    } catch (_) {}
  }

  @override
  Future<bool> acquireCommitLock({
    required String userId,
    required String userName,
  }) async {
    if (_firestoreBlocked) return true;
    final lockRef = _firestore.collection(metaCollection).doc(commitLockDoc);
    final now = AppTime.utcNow();
    final expiresAt = now.add(const Duration(minutes: 2));

    try {
      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(lockRef);
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final isLocked = data['isLocked'] as bool? ?? false;
          final rawExpires = data['expiresAt'] as Timestamp?;
          final lockedBy = data['lockedBy'] as String?;
          if (isLocked &&
              rawExpires != null &&
              rawExpires.toDate().isAfter(now) &&
              lockedBy != userId) {
            return false;
          }
        }
        tx.set(lockRef, {
          'isLocked': true,
          'lockedBy': userId,
          'lockedByName': userName,
          'lockedAt': Timestamp.fromDate(now),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });
        return true;
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _firestoreBlocked = true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> releaseCommitLock(String userId) async {
    if (_firestoreBlocked) return;
    final lockRef = _firestore.collection(metaCollection).doc(commitLockDoc);
    try {
      await lockRef.set({
        'isLocked': false,
        'lockedBy': userId,
        'releasedAt': Timestamp.fromDate(AppTime.utcNow()),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

/// In-memory store for unit testing without Firebase.
class InMemoryKhosraStore implements KhosraStore {
  final Map<String, KhosraEntry> _entries = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _counter = 0;
  String? _lockOwner;
  DateTime? _lockExpiresAt;

  List<KhosraEntry> get allEntries => _entries.values.toList();

  @override
  String generateId() => 'khosra_${++_counter}';

  @override
  Stream<List<KhosraEntry>> watchEntriesForDate(String businessDate) async* {
    List<KhosraEntry> current() {
      final list = _entries.values
          .where(
            (e) =>
                e.businessDate == businessDate &&
                e.status != KhosraEntryStatus.discarded,
          )
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    yield current();
    await for (final _ in _changes.stream) {
      yield current();
    }
  }

  @override
  Future<List<KhosraEntry>> getPendingEntriesBeforeDate(
    String businessDate,
  ) async {
    final list = _entries.values
        .where(
          (e) =>
              (e.status == KhosraEntryStatus.pending ||
                  e.status == KhosraEntryStatus.failed) &&
              e.businessDate.compareTo(businessDate) < 0,
        )
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<KhosraEntry>> getAllPendingEntries() async {
    final list = _entries.values
        .where(
          (e) =>
              e.status == KhosraEntryStatus.pending ||
              e.status == KhosraEntryStatus.failed,
        )
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<KhosraEntry?> getEntryById(String id) async => _entries[id];

  @override
  Future<void> saveEntry(KhosraEntry entry) async {
    _entries[entry.id] = entry;
    _changes.add(null);
  }

  @override
  Future<void> saveEntriesBatch(List<KhosraEntry> entries) async {
    for (final e in entries) {
      _entries[e.id] = e;
    }
    _changes.add(null);
  }

  @override
  Future<bool> acquireCommitLock({
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now().toUtc();
    if (_lockOwner != null &&
        _lockOwner != userId &&
        _lockExpiresAt != null &&
        _lockExpiresAt!.isAfter(now)) {
      return false;
    }
    _lockOwner = userId;
    _lockExpiresAt = now.add(const Duration(minutes: 2));
    return true;
  }

  @override
  Future<void> releaseCommitLock(String userId) async {
    if (_lockOwner == userId) {
      _lockOwner = null;
      _lockExpiresAt = null;
    }
  }
}

/// Gateway to real modules (Sales, Customer, Expense, Inventory, Audit Log).
abstract class KhosraCommitGateway {
  Future<({String saleId, String saleNumber})> commitSale(Sale sale);
  Future<void> deductInventoryStock(String inventoryItemId, double quantity);
  Future<String> addCustomerDue({
    required String customerId,
    required String dueType,
    required double amount,
    required bool isAddition,
    String? saleId,
    double potentialProfit = 0,
    String? note,
    required String createdBy,
    required String createdByName,
    required DateTime createdAt,
  });
  Future<String> collectCustomerDue({
    required String customerId,
    required double amount,
    required String dueType,
    double realizedProfit = 0,
    String? note,
    required String userId,
    required String userName,
    required DateTime createdAt,
    String? saleId,
  });
  Future<void> addCustomerPurchase({
    required String customerId,
    required String description,
    required double amount,
    required String userId,
    required String userName,
    String? note,
    required DateTime createdAt,
  });
  Future<Customer?> getCustomerById(String customerId);
  Future<String> commitExpense(Expense expense);
  Future<void> logAction({
    required String action,
    required String module,
    String? details,
  });
}

class DefaultKhosraCommitGateway implements KhosraCommitGateway {
  final SalesService _salesService;
  final CustomerService _customerService;
  final ExpenseService _expenseService;
  final InventoryService _inventoryService;
  final Future<void> Function({
    required String action,
    required String module,
    String? details,
  })?
  _actionLogger;

  DefaultKhosraCommitGateway({
    SalesService? salesService,
    CustomerService? customerService,
    ExpenseService? expenseService,
    InventoryService? inventoryService,
    Future<void> Function({
      required String action,
      required String module,
      String? details,
    })?
    actionLogger,
  }) : _salesService = salesService ?? SalesService(),
       _customerService = customerService ?? CustomerService(),
       _expenseService = expenseService ?? ExpenseService(),
       _inventoryService = inventoryService ?? InventoryService(),
       _actionLogger = actionLogger;

  @override
  Future<({String saleId, String saleNumber})> commitSale(Sale sale) async {
    final saleId = await _salesService.createSale(
      sale,
      preserveCreatedAt: true,
    );
    final created = await _salesService.getSaleById(saleId);
    return (saleId: saleId, saleNumber: created?.saleNumber ?? saleId);
  }

  @override
  Future<void> deductInventoryStock(
    String inventoryItemId,
    double quantity,
  ) async {
    await _inventoryService.updateStock(
      inventoryItemId,
      quantity,
      isDecrement: true,
    );
  }

  @override
  Future<String> addCustomerDue({
    required String customerId,
    required String dueType,
    required double amount,
    required bool isAddition,
    String? saleId,
    double potentialProfit = 0,
    String? note,
    required String createdBy,
    required String createdByName,
    required DateTime createdAt,
  }) {
    return _customerService.addDueTransaction(
      customerId: customerId,
      dueType: dueType,
      amount: amount,
      isAddition: isAddition,
      saleId: saleId,
      potentialProfit: potentialProfit,
      note: note,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: createdAt,
    );
  }

  @override
  Future<String> collectCustomerDue({
    required String customerId,
    required double amount,
    required String dueType,
    double realizedProfit = 0,
    String? note,
    required String userId,
    required String userName,
    required DateTime createdAt,
    String? saleId,
  }) {
    return _customerService.updateDue(
      customerId: customerId,
      amount: amount,
      dueType: dueType,
      isAddition: false,
      realizedProfit: realizedProfit,
      note: note,
      userId: userId,
      userName: userName,
      createdAt: createdAt,
      saleId: saleId,
    );
  }

  @override
  Future<void> addCustomerPurchase({
    required String customerId,
    required String description,
    required double amount,
    required String userId,
    required String userName,
    String? note,
    required DateTime createdAt,
  }) {
    return _customerService.addPurchase(
      customerId: customerId,
      description: description,
      amount: amount,
      userId: userId,
      userName: userName,
      note: note,
      createdAt: createdAt,
    );
  }

  @override
  Future<Customer?> getCustomerById(String customerId) {
    return _customerService.getCustomerById(customerId);
  }

  @override
  Future<String> commitExpense(Expense expense) {
    return _expenseService.createExpense(expense, preserveCreatedAt: true);
  }

  @override
  Future<void> logAction({
    required String action,
    required String module,
    String? details,
  }) async {
    if (_actionLogger != null) {
      await _actionLogger(action: action, module: module, details: details);
    }
  }
}

class KhosraService {
  final KhosraStore store;
  final KhosraCommitGateway gateway;

  KhosraService({KhosraStore? store, KhosraCommitGateway? gateway})
    : store = store ?? FirestoreKhosraStore(),
      gateway = gateway ?? DefaultKhosraCommitGateway();

  Stream<List<KhosraEntry>> watchEntriesForDate(String businessDate) =>
      store.watchEntriesForDate(businessDate);

  Future<List<KhosraEntry>> getPendingEntriesBeforeDate(String businessDate) =>
      store.getPendingEntriesBeforeDate(businessDate);

  Future<List<KhosraEntry>> getAllPendingEntries() =>
      store.getAllPendingEntries();

  /// Adds a Sale entry. If `duePaisa > 0`, automatically creates a linked
  /// `baki` entry (`dueType = "product"`, `linkedEntryId` cross-linked).
  /// Returns `[saleEntry, if (bakiEntry != null) bakiEntry]`.
  Future<List<KhosraEntry>> addSaleEntry({
    required String name,
    String? customerId,
    required int amountPaisa,
    int quantity = 1,
    int? unitPricePaisa,
    String? quickActionKey,
    required int paidPaisa,
    required int duePaisa,
    int? costPaisa,
    String? note,
    Map<String, dynamic>? details,
    DateTime? createdAt,
    String? businessDate,
    required String createdBy,
    required String createdByName,
  }) async {
    final now = AppTime.utcNow();
    final entryTime = createdAt ?? now;
    final bDate =
        businessDate ??
        KhosraEntry.formatBusinessDate(AppTime.toBusiness(entryTime));

    final saleId = store.generateId();
    final String? bakiId = duePaisa > 0 ? store.generateId() : null;

    final saleEntry = KhosraEntry(
      id: saleId,
      businessDate: bDate,
      createdAt: entryTime,
      updatedAt: now,
      type: KhosraEntryType.sale,
      name: name.trim().isEmpty ? 'Walk-in' : name.trim(),
      customerId: customerId,
      amountPaisa: amountPaisa,
      quantity: quantity,
      unitPricePaisa: unitPricePaisa ?? (amountPaisa ~/ (quantity > 0 ? quantity : 1)),
      quickActionKey: quickActionKey,
      paidPaisa: paidPaisa,
      duePaisa: duePaisa,
      costPaisa: costPaisa,
      linkedEntryId: bakiId,
      note: note,
      details: details,
      status: KhosraEntryStatus.pending,
      createdBy: createdBy,
      createdByName: createdByName,
    );

    final entriesToSave = <KhosraEntry>[saleEntry];

    if (bakiId != null) {
      final bakiName =
          (details?['customerName'] as String?)?.trim().isNotEmpty == true
          ? (details!['customerName'] as String).trim()
          : saleEntry.name;
      final bakiEntry = KhosraEntry(
        id: bakiId,
        businessDate: bDate,
        createdAt: entryTime,
        updatedAt: now,
        type: KhosraEntryType.baki,
        name: bakiName,
        customerId: customerId,
        amountPaisa: duePaisa,
        quantity: 1,
        dueType: 'product',
        linkedEntryId: saleId,
        note: note ?? 'বিক্রি থেকে বকেয়া (${saleEntry.name})',
        details: {
          if (details != null) ...details,
          'fromSale': true,
          'saleAmountPaisa': amountPaisa,
          'salePaidPaisa': paidPaisa,
        },
        status: KhosraEntryStatus.pending,
        createdBy: createdBy,
        createdByName: createdByName,
      );
      entriesToSave.add(bakiEntry);
    }

    await store.saveEntriesBatch(entriesToSave);
    return entriesToSave;
  }

  /// Adds a standalone Baki, Aday, Khoroch, or Other entry.
  Future<KhosraEntry> addGenericEntry(KhosraEntry entry) async {
    final id = entry.id.isEmpty ? store.generateId() : entry.id;
    final withId = entry.copyWith(id: id);
    await store.saveEntry(withId);
    return withId;
  }

  /// Updates an existing entry and keeps its linked partner (`sale` <-> `baki`)
  /// synchronized automatically.
  Future<List<KhosraEntry>> updateEntryWithSync(KhosraEntry updated) async {
    final now = AppTime.utcNow();
    final bDate = KhosraEntry.formatBusinessDate(
      AppTime.toBusiness(updated.createdAt),
    );
    var primary = updated.copyWith(updatedAt: now, businessDate: bDate);
    final toSave = <KhosraEntry>[];

    if (primary.type == KhosraEntryType.sale) {
      final existingLinkedId = primary.linkedEntryId;
      KhosraEntry? existingBaki = existingLinkedId != null
          ? await store.getEntryById(existingLinkedId)
          : null;

      if (primary.duePaisa > 0) {
        final bakiId = existingBaki?.id ?? store.generateId();
        primary = primary.copyWith(linkedEntryId: bakiId);
        final bakiName =
            (primary.details?['customerName'] as String?)?.trim().isNotEmpty ==
                true
            ? (primary.details!['customerName'] as String).trim()
            : (existingBaki != null &&
                      existingBaki.name != 'Walk-in' &&
                      primary.name == 'Walk-in'
                  ? existingBaki.name
                  : primary.name);

        final syncedBaki = (existingBaki ??
                KhosraEntry(
                  id: bakiId,
                  businessDate: bDate,
                  createdAt: primary.createdAt,
                  updatedAt: now,
                  type: KhosraEntryType.baki,
                  name: bakiName,
                  amountPaisa: primary.duePaisa,
                  dueType: 'product',
                  linkedEntryId: primary.id,
                  createdBy: primary.createdBy,
                  createdByName: primary.createdByName,
                ))
            .copyWith(
              businessDate: bDate,
              createdAt: primary.createdAt,
              updatedAt: now,
              name: bakiName,
              customerId: primary.customerId,
              clearCustomerId: primary.customerId == null,
              amountPaisa: primary.duePaisa,
              dueType: 'product',
              linkedEntryId: primary.id,
              note: primary.note ?? existingBaki?.note,
              status: primary.status == KhosraEntryStatus.discarded
                  ? KhosraEntryStatus.discarded
                  : KhosraEntryStatus.pending,
            );
        toSave.add(primary);
        toSave.add(syncedBaki);
      } else {
        // Due became 0: discard linked baki if it existed
        primary = primary.copyWith(clearLinkedEntryId: true);
        toSave.add(primary);
        if (existingBaki != null) {
          toSave.add(
            existingBaki.copyWith(
              status: KhosraEntryStatus.discarded,
              updatedAt: now,
            ),
          );
        }
      }
    } else if (primary.type == KhosraEntryType.baki &&
        primary.linkedEntryId != null) {
      final linkedSale = await store.getEntryById(primary.linkedEntryId!);
      toSave.add(primary);
      if (linkedSale != null &&
          linkedSale.status != KhosraEntryStatus.committed) {
        final newDue = primary.amountPaisa.clamp(0, linkedSale.amountPaisa);
        final newPaid = (linkedSale.amountPaisa - newDue).clamp(
          0,
          linkedSale.amountPaisa,
        );
        final updatedDetails = <String, dynamic>{
          if (linkedSale.details != null) ...linkedSale.details!,
          'customerName': primary.name,
        };
        final syncedSale = linkedSale.copyWith(
          businessDate: bDate,
          createdAt: primary.createdAt,
          updatedAt: now,
          customerId: primary.customerId,
          clearCustomerId: primary.customerId == null,
          name: linkedSale.name == 'Walk-in' ? primary.name : linkedSale.name,
          duePaisa: newDue,
          paidPaisa: newPaid,
          note: primary.note ?? linkedSale.note,
          details: updatedDetails,
        );
        toSave.add(syncedSale);
      }
    } else {
      toSave.add(primary);
    }

    await store.saveEntriesBatch(toSave);
    return toSave;
  }

  /// Soft-discards an entry (and its linked entry if any). Returns the original
  /// entries prior to discard so an "Undo" snackbar can restore them.
  Future<List<KhosraEntry>> discardEntryWithSync(String entryId) async {
    final target = await store.getEntryById(entryId);
    if (target == null) return [];

    final now = AppTime.utcNow();
    final originals = <KhosraEntry>[target];
    final discarded = <KhosraEntry>[
      target.copyWith(status: KhosraEntryStatus.discarded, updatedAt: now),
    ];

    if (target.linkedEntryId != null) {
      final partner = await store.getEntryById(target.linkedEntryId!);
      if (partner != null && partner.status != KhosraEntryStatus.committed) {
        originals.add(partner);
        discarded.add(
          partner.copyWith(status: KhosraEntryStatus.discarded, updatedAt: now),
        );
      }
    }

    await store.saveEntriesBatch(discarded);
    return originals;
  }

  /// Restores previously discarded/created entries (for Undo snackbar).
  Future<void> restoreEntries(List<KhosraEntry> originals) async {
    if (originals.isEmpty) return;
    final restored = originals
        .map(
          (e) => e.copyWith(
            status: KhosraEntryStatus.pending,
            updatedAt: AppTime.utcNow(),
          ),
        )
        .toList();
    await store.saveEntriesBatch(restored);
  }

  /// Commits the selected Khosra entries in strict order:
  /// 1. Sales -> 2. Standalone Bakis -> 3. Adays -> 4. Khoroch (Expenses).
  /// Acquires `khosra_meta/commit_lock` to prevent concurrent commits across devices,
  /// and checks per-entry status before committing for idempotency.
  Future<KhosraCommitSummary> commitEntries({
    required List<String> entryIds,
    required String userId,
    required String userName,
    Future<void> Function({
      required String action,
      required String module,
      String? details,
    })?
    logActionOverride,
  }) async {
    final locked = await store.acquireCommitLock(
      userId: userId,
      userName: userName,
    );
    if (!locked) {
      throw Exception(
        'অন্য একটি ডিভাইস থেকে এখন খসড়া Confirm হচ্ছে। অনুগ্রহ করে কিছুক্ষণ পর চেষ্টা করুন।',
      );
    }

    final committedIds = <String>[];
    final failedEntries = <String, String>{};
    final skippedIds = <String>[];

    try {
      // Load fresh copies of all requested entries
      final loaded = <KhosraEntry>[];
      for (final id in entryIds.toSet()) {
        final e = await store.getEntryById(id);
        if (e != null) loaded.add(e);
      }

      // Sort by commit phase: sale (0) -> baki (1) -> aday (2) -> khoroch (3) -> other (4)
      int phaseOf(KhosraEntryType t) {
        switch (t) {
          case KhosraEntryType.sale:
            return 0;
          case KhosraEntryType.baki:
            return 1;
          case KhosraEntryType.aday:
            return 2;
          case KhosraEntryType.khoroch:
            return 3;
          case KhosraEntryType.other:
            return 4;
        }
      }

      loaded.sort((a, b) {
        final p = phaseOf(a.type).compareTo(phaseOf(b.type));
        if (p != 0) return p;
        return a.createdAt.compareTo(b.createdAt);
      });

      for (final item in loaded) {
        // Re-read latest entry state from store for idempotency
        // (e.g. a linked baki may have just been marked committed by its parent sale)
        final current = await store.getEntryById(item.id);
        if (current == null ||
            current.status == KhosraEntryStatus.committed ||
            current.status == KhosraEntryStatus.discarded) {
          skippedIds.add(item.id);
          continue;
        }

        try {
          switch (current.type) {
            case KhosraEntryType.sale:
              final committedPair = await _commitSingleSale(
                current,
                userId: userId,
                userName: userName,
                logActionOverride: logActionOverride,
              );
              committedIds.addAll(committedPair);
              break;
            case KhosraEntryType.baki:
              final id = await _commitSingleBaki(
                current,
                userId: userId,
                userName: userName,
                logActionOverride: logActionOverride,
              );
              committedIds.add(id);
              break;
            case KhosraEntryType.aday:
              final id = await _commitSingleAday(
                current,
                userId: userId,
                userName: userName,
                logActionOverride: logActionOverride,
              );
              committedIds.add(id);
              break;
            case KhosraEntryType.khoroch:
              final id = await _commitSingleKhoroch(
                current,
                userId: userId,
                userName: userName,
                logActionOverride: logActionOverride,
              );
              committedIds.add(id);
              break;
            case KhosraEntryType.other:
              throw Exception(
                '"Other" এন্ট্রিটি আগে বিক্রি/বকেয়া/খরচ/আদায় যেকোনো একটিতে রূপান্তর করুন।',
              );
          }
        } catch (e) {
          final errMsg = e.toString().replaceAll('Exception: ', '');
          failedEntries[current.id] = errMsg;
          await store.saveEntry(
            current.copyWith(
              status: KhosraEntryStatus.failed,
              lastError: errMsg,
              updatedAt: AppTime.utcNow(),
            ),
          );
        }
      }
    } finally {
      await store.releaseCommitLock(userId);
    }

    return KhosraCommitSummary(
      committedIds: committedIds,
      failedEntries: failedEntries,
      skippedIds: skippedIds,
    );
  }

  Future<List<String>> _commitSingleSale(
    KhosraEntry entry, {
    required String userId,
    required String userName,
    Future<void> Function({
      required String action,
      required String module,
      String? details,
    })?
    logActionOverride,
  }) async {
    if (entry.duePaisa > 0 &&
        (entry.customerId == null ||
            entry.customerId!.isEmpty ||
            entry.customerId == 'guest_customer')) {
      throw Exception(
        'বকেয়া বিক্রির জন্য একজন নির্দিষ্ট গ্রাহক (Customer) যুক্ত করা আবশ্যক।',
      );
    }

    final totalSelling = entry.amountTaka;
    final paidAmount = entry.paidTaka;
    final dueAmount = entry.dueTaka;
    final discountPaisa = (entry.details?['discountPaisa'] as num?)?.round() ?? 0;
    final discountAmount = KhosraMoney.paisaToTaka(discountPaisa);

    // Determine cost: for service/photocopy default is 0 (profit = full amount) unless costPaisa provided
    final totalCost = entry.costTaka ?? 0.0;

    final profitSplit = SalesService.calculateProfitSplit(
      totalSelling: totalSelling,
      totalCost: totalCost,
      discountAmount: discountAmount,
      paidAmount: paidAmount,
    );

    // Build SaleItems: use custom items from details if provided, otherwise single non-inventory/service item
    final List<SaleItem> saleItems = [];
    final rawItems = entry.details?['items'] as List<dynamic>?;
    if (rawItems != null && rawItems.isNotEmpty) {
      for (final raw in rawItems) {
        if (raw is Map) {
          saleItems.add(SaleItem.fromMap(Map<String, dynamic>.from(raw)));
        }
      }
    }
    if (saleItems.isEmpty) {
      final qty = entry.quantity > 0 ? entry.quantity.toDouble() : 1.0;
      final unitSelling = totalSelling / qty;
      final unitCost = totalCost / qty;
      saleItems.add(
        SaleItem(
          id: 'khosra_${entry.id}',
          inventoryItemId: entry.details?['inventoryItemId'] as String?,
          itemType: entry.isServiceSale ? 'service' : 'non_inventory',
          itemName: entry.name.isEmpty ? 'Sale' : entry.name,
          quantity: qty,
          unit: (entry.details?['unit'] as String?) ?? 'pcs',
          costPrice: unitCost,
          sellingPrice: unitSelling,
          totalCost: totalCost,
          totalSelling: totalSelling,
          profit: totalSelling - totalCost,
          notes: entry.note,
        ),
      );
    }

    final customerName =
        (entry.details?['customerName'] as String?) ??
        (entry.customerId != null ? entry.name : 'Walk-in');

    final sale = Sale(
      id: '',
      saleNumber: '',
      saleDate: AppTime.toBusiness(entry.createdAt),
      items: saleItems,
      totalCost: totalCost,
      totalSelling: totalSelling,
      totalProfit: profitSplit.finalProfit,
      discountAmount: discountAmount,
      discountPercent: 0,
      paymentMethod:
          (entry.details?['paymentMethod'] as String?) ??
          (dueAmount > 0 ? 'credit' : 'cash'),
      paidAmount: paidAmount,
      dueAmount: dueAmount,
      realizedProfit: profitSplit.realizedProfit,
      potentialProfit: profitSplit.potentialProfit,
      customerId: entry.customerId ?? 'guest_customer',
      customerName: customerName,
      notes: entry.note,
      createdBy: entry.createdBy.isNotEmpty ? entry.createdBy : userId,
      createdByName: entry.createdByName.isNotEmpty
          ? entry.createdByName
          : userName,
      createdAt: entry.createdAt.toUtc(),
      isActive: true,
    );

    final createdSale = await gateway.commitSale(sale);

    // Deduct stock ONLY for real inventory product items
    for (final item in saleItems) {
      if (item.inventoryItemId != null &&
          item.inventoryItemId!.isNotEmpty &&
          item.itemType == 'product') {
        await gateway.deductInventoryStock(item.inventoryItemId!, item.quantity);
      }
    }

    String? dueTxId;
    if (dueAmount > 0 &&
        entry.customerId != null &&
        entry.customerId != 'guest_customer') {
      dueTxId = await gateway.addCustomerDue(
        customerId: entry.customerId!,
        dueType: 'product',
        amount: dueAmount,
        isAddition: true,
        saleId: createdSale.saleId,
        potentialProfit: profitSplit.potentialProfit,
        note: entry.note != null && entry.note!.isNotEmpty
            ? 'Product sale due - ${createdSale.saleNumber} (${entry.note})'
            : 'Product sale due - ${createdSale.saleNumber}',
        createdBy: sale.createdBy,
        createdByName: sale.createdByName,
        createdAt: entry.createdAt.toUtc(),
      );
    }

    if (entry.customerId != null && entry.customerId!.isNotEmpty) {
      final itemsList = saleItems.map((i) => i.itemName).join(', ');
      await gateway.addCustomerPurchase(
        customerId: entry.customerId!,
        description: 'Sale ${createdSale.saleNumber}: $itemsList',
        amount: totalSelling - discountAmount,
        userId: sale.createdBy,
        userName: sale.createdByName,
        note: dueAmount > 0
            ? 'Paid: ৳${paidAmount.toStringAsFixed(2)}, Due: ৳${dueAmount.toStringAsFixed(2)}'
            : 'Fully paid',
        createdAt: entry.createdAt.toUtc(),
      );
    }

    final now = AppTime.utcNow();
    final refs = <String, dynamic>{
      'saleId': createdSale.saleId,
      'saleNumber': createdSale.saleNumber,
      if (dueTxId != null) 'dueTransactionId': dueTxId,
    };

    final entriesToUpdate = <KhosraEntry>[
      entry.copyWith(
        status: KhosraEntryStatus.committed,
        committedAt: now,
        committedRefs: refs,
        clearLastError: true,
        updatedAt: now,
      ),
    ];
    final committedIds = <String>[entry.id];

    // Mark linked baki entry as committed together with the sale so it is never committed twice
    if (entry.linkedEntryId != null) {
      final linkedBaki = await store.getEntryById(entry.linkedEntryId!);
      if (linkedBaki != null) {
        entriesToUpdate.add(
          linkedBaki.copyWith(
            status: KhosraEntryStatus.committed,
            committedAt: now,
            committedRefs: refs,
            clearLastError: true,
            updatedAt: now,
          ),
        );
        committedIds.add(linkedBaki.id);
      }
    }

    await store.saveEntriesBatch(entriesToUpdate);

    await _log(
      logActionOverride,
      action: 'COMMIT_SALE',
      details:
          'Committed khosra sale (${entry.name}) -> ${createdSale.saleNumber}, Total: ৳${totalSelling.toStringAsFixed(2)}, Due: ৳${dueAmount.toStringAsFixed(2)}',
    );

    return committedIds;
  }

  Future<String> _commitSingleBaki(
    KhosraEntry entry, {
    required String userId,
    required String userName,
    Future<void> Function({
      required String action,
      required String module,
      String? details,
    })?
    logActionOverride,
  }) async {
    // If linked to a sale that was already committed, mark committed and do not duplicate
    if (entry.linkedEntryId != null) {
      final parentSale = await store.getEntryById(entry.linkedEntryId!);
      if (parentSale != null &&
          parentSale.status == KhosraEntryStatus.committed) {
        final now = AppTime.utcNow();
        await store.saveEntry(
          entry.copyWith(
            status: KhosraEntryStatus.committed,
            committedAt: now,
            committedRefs: parentSale.committedRefs,
            clearLastError: true,
            updatedAt: now,
          ),
        );
        return entry.id;
      }
    }

    if (entry.customerId == null ||
        entry.customerId!.isEmpty ||
        entry.customerId == 'guest_customer') {
      throw Exception('বকেয়া এন্ট্রির জন্য একজন গ্রাহক (Customer) নির্বাচন করুন।');
    }

    final rawDueType =
        (entry.details?['rawDueType'] as String?) ??
        (entry.dueType == 'cash_balance' ? 'cashBorrow' : 'product');

    final txId = await gateway.addCustomerDue(
      customerId: entry.customerId!,
      dueType: rawDueType,
      amount: entry.amountTaka,
      isAddition: true,
      note: entry.note?.isNotEmpty == true ? entry.note : 'খসড়া বকেয়া (${entry.name})',
      createdBy: entry.createdBy.isNotEmpty ? entry.createdBy : userId,
      createdByName: entry.createdByName.isNotEmpty
          ? entry.createdByName
          : userName,
      createdAt: entry.createdAt.toUtc(),
    );

    final now = AppTime.utcNow();
    await store.saveEntry(
      entry.copyWith(
        status: KhosraEntryStatus.committed,
        committedAt: now,
        committedRefs: {'dueTransactionId': txId},
        clearLastError: true,
        updatedAt: now,
      ),
    );

    await _log(
      logActionOverride,
      action: 'COMMIT_BAKI',
      details:
          'Committed khosra baki for ${entry.name}: ৳${entry.amountTaka.toStringAsFixed(2)} ($rawDueType)',
    );

    return entry.id;
  }

  Future<String> _commitSingleAday(
    KhosraEntry entry, {
    required String userId,
    required String userName,
    Future<void> Function({
      required String action,
      required String module,
      String? details,
    })?
    logActionOverride,
  }) async {
    if (entry.customerId == null || entry.customerId!.isEmpty) {
      throw Exception('আদায় এন্ট্রির জন্য গ্রাহক নির্বাচন করা আবশ্যক।');
    }

    final customer = await gateway.getCustomerById(entry.customerId!);
    if (customer == null) {
      throw Exception('গ্রাহক খুঁজে পাওয়া যায়নি (${entry.name})।');
    }

    final rawDueType =
        (entry.details?['rawDueType'] as String?) ??
        (entry.dueType == 'cash_balance' ? 'cashBorrow' : 'product');

    final double currentCategoryDue;
    switch (rawDueType) {
      case 'product':
        currentCategoryDue = customer.productDue;
        break;
      case 'service':
        currentCategoryDue = customer.serviceDue;
        break;
      case 'msfRecharge':
        currentCategoryDue = customer.msfRechargeDue;
        break;
      case 'cashBorrow':
        currentCategoryDue = customer.cashBorrowDue;
        break;
      case 'previousDue':
        currentCategoryDue = customer.previousDue;
        break;
      default:
        currentCategoryDue = customer.totalDue;
    }

    final currentDuePaisa = KhosraMoney.takaToPaisa(currentCategoryDue);
    if (entry.amountPaisa > currentDuePaisa) {
      throw Exception(
        'আদায়ের পরিমাণ (${KhosraMoney.formatPaisa(entry.amountPaisa)}) বর্তমান বকেয়ার (${KhosraMoney.formatPaisa(currentDuePaisa)}) চেয়ে বেশি।',
      );
    }

    // Calculate proportional realized profit if the due record had potentialProfit
    double realizedProfit = 0;
    final origPaisa = (entry.details?['originalDuePaisa'] as num?)?.round() ?? 0;
    final potProfitPaisa =
        (entry.details?['potentialProfitPaisa'] as num?)?.round() ?? 0;
    if (origPaisa > 0 && potProfitPaisa > 0) {
      final ratio = (entry.amountPaisa / origPaisa).clamp(0.0, 1.0);
      realizedProfit = KhosraMoney.paisaToTaka((potProfitPaisa * ratio).round());
    }

    final txId = await gateway.collectCustomerDue(
      customerId: entry.customerId!,
      amount: entry.amountTaka,
      dueType: rawDueType,
      realizedProfit: realizedProfit,
      note: entry.note?.isNotEmpty == true
          ? entry.note
          : 'খসড়া বকেয়া আদায় (${entry.name})',
      userId: entry.createdBy.isNotEmpty ? entry.createdBy : userId,
      userName: entry.createdByName.isNotEmpty
          ? entry.createdByName
          : userName,
      createdAt: entry.createdAt.toUtc(),
      saleId: entry.details?['saleId'] as String?,
    );

    final now = AppTime.utcNow();
    await store.saveEntry(
      entry.copyWith(
        status: KhosraEntryStatus.committed,
        committedAt: now,
        committedRefs: {'collectionId': txId, 'dueTransactionId': txId},
        clearLastError: true,
        updatedAt: now,
      ),
    );

    await _log(
      logActionOverride,
      action: 'COMMIT_ADAY',
      details:
          'Committed khosra aday from ${entry.name}: ৳${entry.amountTaka.toStringAsFixed(2)} ($rawDueType)',
    );

    return entry.id;
  }

  Future<String> _commitSingleKhoroch(
    KhosraEntry entry, {
    required String userId,
    required String userName,
    Future<void> Function({
      required String action,
      required String module,
      String? details,
    })?
    logActionOverride,
  }) async {
    final category = entry.expenseCategory ?? 'other';
    final expense = Expense(
      id: '',
      expenseNumber: '',
      expenseDate: AppTime.toBusiness(entry.createdAt),
      category: category,
      amount: entry.amountTaka,
      description: entry.name.isEmpty ? 'Shop Expense' : entry.name,
      paymentMethod: (entry.details?['paymentMethod'] as String?) ?? 'cash',
      notes: entry.note,
      receiptPhotos: const [],
      createdBy: entry.createdBy.isNotEmpty ? entry.createdBy : userId,
      createdByName: entry.createdByName.isNotEmpty
          ? entry.createdByName
          : userName,
      createdAt: entry.createdAt.toUtc(),
      isActive: true,
    );

    final expenseId = await gateway.commitExpense(expense);

    final now = AppTime.utcNow();
    await store.saveEntry(
      entry.copyWith(
        status: KhosraEntryStatus.committed,
        committedAt: now,
        committedRefs: {'expenseId': expenseId},
        clearLastError: true,
        updatedAt: now,
      ),
    );

    await _log(
      logActionOverride,
      action: 'COMMIT_EXPENSE',
      details:
          'Committed khosra expense (${entry.name}): ৳${entry.amountTaka.toStringAsFixed(2)} ($category)',
    );

    return entry.id;
  }

  Future<void> _log(
    Future<void> Function({
      required String action,
      required String module,
      String? details,
    })?
    overrideLogger, {
    required String action,
    String? details,
  }) async {
    if (overrideLogger != null) {
      await overrideLogger(action: action, module: 'Khosra', details: details);
    } else {
      await gateway.logAction(
        action: action,
        module: 'Khosra',
        details: details,
      );
    }
  }
}

