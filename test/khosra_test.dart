import 'package:flutter_test/flutter_test.dart';
import 'package:mcs_management/modules/customer/models/customer_model.dart';
import 'package:mcs_management/modules/customer/models/due_transaction.dart';
import 'package:mcs_management/modules/expense/models/expense.dart';
import 'package:mcs_management/modules/khosra/models/khosra_entry.dart';
import 'package:mcs_management/modules/khosra/services/khosra_service.dart';
import 'package:mcs_management/modules/sales/models/sale.dart';

class FakeKhosraCommitGateway implements KhosraCommitGateway {
  final List<Sale> committedSales = [];
  final List<Map<String, dynamic>> addedDues = [];
  final List<Map<String, dynamic>> collectedDues = [];
  final List<Expense> committedExpenses = [];
  final List<String> loggedActions = [];
  final Map<String, Customer> customers = {};
  bool failNextExpense = false;

  int _seq = 0;

  @override
  Future<({String saleId, String saleNumber})> commitSale(Sale sale) async {
    _seq++;
    final id = 'sale_$_seq';
    final numStr = 'SAL-202610-000$_seq';
    committedSales.add(sale.copyWith(id: id, saleNumber: numStr));
    return (saleId: id, saleNumber: numStr);
  }

  @override
  Future<void> deductInventoryStock(
    String inventoryItemId,
    double quantity,
  ) async {}

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
  }) async {
    _seq++;
    final txId = 'due_tx_$_seq';
    addedDues.add({
      'id': txId,
      'customerId': customerId,
      'dueType': dueType,
      'amount': amount,
      'isAddition': isAddition,
      'saleId': saleId,
      'potentialProfit': potentialProfit,
      'createdAt': createdAt,
    });
    return txId;
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
  }) async {
    _seq++;
    final txId = 'aday_tx_$_seq';
    collectedDues.add({
      'id': txId,
      'customerId': customerId,
      'dueType': dueType,
      'amount': amount,
      'realizedProfit': realizedProfit,
      'createdAt': createdAt,
    });
    return txId;
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
  }) async {}

  @override
  Future<Customer?> getCustomerById(String customerId) async {
    return customers[customerId];
  }

  @override
  Future<String> commitExpense(Expense expense) async {
    if (failNextExpense) {
      throw Exception('Simulated network error on expense');
    }
    _seq++;
    final id = 'exp_$_seq';
    committedExpenses.add(expense.copyWith(id: id));
    return id;
  }

  @override
  Future<void> logAction({
    required String action,
    required String module,
    String? details,
  }) async {
    loggedActions.add('$module:$action');
  }
}

void main() {
  group('1. Poisha math (KhosraMoney)', () {
    test('converts and parses Taka to exact integer poisha without float drift', () {
      expect(KhosraMoney.takaToPaisa(30), 3000);
      expect(KhosraMoney.takaToPaisa(19.99), 1999);
      expect(KhosraMoney.paisaToTaka(2550), 25.5);

      expect(KhosraMoney.parseToPaisa('50'), 5000);
      expect(KhosraMoney.parseToPaisa('৳ 30.5'), 3050);
      expect(KhosraMoney.parseToPaisa('1,250.75'), 125075);
      expect(KhosraMoney.parseToPaisa(''), 0);
      expect(KhosraMoney.parseToPaisa('invalid'), 0);

      expect(KhosraMoney.formatPaisa(3000), '৳30');
      expect(KhosraMoney.formatPaisa(3050), '৳30.50');
    });
  });

  group('2. Partial baki split (KhosraMoney.splitSalePayment)', () {
    test('splits full cash, full bokeya, and partial bokeya accurately', () {
      final cashSplit = KhosraMoney.splitSalePayment(
        amountPaisa: 10000,
        isBokeya: false,
        isFullBokeya: false,
      );
      expect(cashSplit.paidPaisa, 10000);
      expect(cashSplit.duePaisa, 0);

      final fullDueSplit = KhosraMoney.splitSalePayment(
        amountPaisa: 10000,
        isBokeya: true,
        isFullBokeya: true,
      );
      expect(fullDueSplit.paidPaisa, 0);
      expect(fullDueSplit.duePaisa, 10000);

      final partialSplit = KhosraMoney.splitSalePayment(
        amountPaisa: 10000,
        isBokeya: true,
        isFullBokeya: false,
        partialPaidPaisa: 4000,
      );
      expect(partialSplit.paidPaisa, 4000);
      expect(partialSplit.duePaisa, 6000);

      // Clamps paid if user enters more than total
      final clampedSplit = KhosraMoney.splitSalePayment(
        amountPaisa: 5000,
        isBokeya: true,
        isFullBokeya: false,
        partialPaidPaisa: 8000,
      );
      expect(clampedSplit.paidPaisa, 5000);
      expect(clampedSplit.duePaisa, 0);
    });
  });

  group('3. Linked entry sync (sale <-> baki)', () {
    late InMemoryKhosraStore store;
    late FakeKhosraCommitGateway gateway;
    late KhosraService service;

    setUp(() {
      store = InMemoryKhosraStore();
      gateway = FakeKhosraCommitGateway();
      service = KhosraService(store: store, gateway: gateway);
    });

    test('creating a sale with due > 0 auto-creates a linked baki entry and syncs edits/deletes', () async {
      final created = await service.addSaleEntry(
        name: 'Rahim',
        customerId: 'cust_1',
        amountPaisa: 10000, // ৳100
        paidPaisa: 3000, // ৳30
        duePaisa: 7000, // ৳70
        createdBy: 'u1',
        createdByName: 'Admin',
      );

      expect(created.length, 2);
      final sale = created[0];
      final baki = created[1];

      expect(sale.type, KhosraEntryType.sale);
      expect(baki.type, KhosraEntryType.baki);
      expect(sale.linkedEntryId, baki.id);
      expect(baki.linkedEntryId, sale.id);
      expect(baki.amountPaisa, 7000);
      expect(baki.dueType, 'product');

      // Edit the baki amount to ৳50 (5000 poisha) -> should update linked sale's duePaisa & paidPaisa
      await service.updateEntryWithSync(baki.copyWith(amountPaisa: 5000));
      final updatedSale = await store.getEntryById(sale.id);
      expect(updatedSale!.duePaisa, 5000);
      expect(updatedSale.paidPaisa, 5000);

      // Discard sale -> should discard both sale and linked baki, and restore both on Undo
      final originals = await service.discardEntryWithSync(sale.id);
      expect(originals.length, 2);
      expect((await store.getEntryById(sale.id))!.status, KhosraEntryStatus.discarded);
      expect((await store.getEntryById(baki.id))!.status, KhosraEntryStatus.discarded);

      await service.restoreEntries(originals);
      expect((await store.getEntryById(sale.id))!.status, KhosraEntryStatus.pending);
      expect((await store.getEntryById(baki.id))!.status, KhosraEntryStatus.pending);
    });
  });

  group('4. Commit idempotency, order & failure retry', () {
    late InMemoryKhosraStore store;
    late FakeKhosraCommitGateway gateway;
    late KhosraService service;

    setUp(() {
      store = InMemoryKhosraStore();
      gateway = FakeKhosraCommitGateway();
      service = KhosraService(store: store, gateway: gateway);
    });

    test('never commits linked baki twice or already-committed entries on double confirm', () async {
      final pair = await service.addSaleEntry(
        name: 'Karim',
        customerId: 'cust_karim',
        amountPaisa: 20000, // ৳200
        paidPaisa: 5000, // ৳50
        duePaisa: 15000, // ৳150
        costPaisa: 12000, // ৳120
        createdBy: 'u1',
        createdByName: 'Admin',
      );
      final saleId = pair[0].id;
      final linkedBakiId = pair[1].id;

      final exp = await service.addGenericEntry(
        KhosraEntry(
          id: '',
          businessDate: '2026-10-23',
          createdAt: DateTime.utc(2026, 10, 23, 6, 0),
          updatedAt: DateTime.utc(2026, 10, 23, 6, 0),
          type: KhosraEntryType.khoroch,
          name: 'Tea',
          amountPaisa: 2000,
          expenseCategory: 'shop',
          createdBy: 'u1',
          createdByName: 'Admin',
        ),
      );

      // First commit with both saleId and linkedBakiId selected
      final summary1 = await service.commitEntries(
        entryIds: [linkedBakiId, exp.id, saleId],
        userId: 'u1',
        userName: 'Admin',
      );

      expect(summary1.hasFailures, isFalse);
      // Only 1 sale created and 1 due transaction created (linked baki was NOT committed a second time!)
      expect(gateway.committedSales.length, 1);
      expect(gateway.addedDues.length, 1);
      expect(gateway.committedExpenses.length, 1);

      final committedSaleEntry = await store.getEntryById(saleId);
      final committedBakiEntry = await store.getEntryById(linkedBakiId);
      expect(committedSaleEntry!.status, KhosraEntryStatus.committed);
      expect(committedBakiEntry!.status, KhosraEntryStatus.committed);
      expect(committedSaleEntry.committedRefs!['saleId'], isNotEmpty);

      // Second commit call with same IDs (simulating double-tap / retry) -> idempotent no-op
      final summary2 = await service.commitEntries(
        entryIds: [saleId, linkedBakiId, exp.id],
        userId: 'u1',
        userName: 'Admin',
      );
      expect(summary2.committedCount, 0);
      expect(summary2.skippedIds.length, 3);
      expect(gateway.committedSales.length, 1);
      expect(gateway.addedDues.length, 1);
      expect(gateway.committedExpenses.length, 1);
    });

    test('records failed entry without stopping other commits and succeeds on retry', () async {
      gateway.failNextExpense = true;

      final saleList = await service.addSaleEntry(
        name: 'Photocopy',
        amountPaisa: 1000,
        paidPaisa: 1000,
        duePaisa: 0,
        quickActionKey: 'photocopy_10',
        createdBy: 'u1',
        createdByName: 'Admin',
      );
      final exp = await service.addGenericEntry(
        KhosraEntry(
          id: '',
          businessDate: '2026-10-23',
          createdAt: DateTime.utc(2026, 10, 23, 7, 0),
          updatedAt: DateTime.utc(2026, 10, 23, 7, 0),
          type: KhosraEntryType.khoroch,
          name: 'Wifi Bill',
          amountPaisa: 50000,
          expenseCategory: 'electricity_wifi',
          createdBy: 'u1',
          createdByName: 'Admin',
        ),
      );

      final summary1 = await service.commitEntries(
        entryIds: [saleList.first.id, exp.id],
        userId: 'u1',
        userName: 'Admin',
      );
      expect(summary1.committedIds, [saleList.first.id]);
      expect(summary1.failedEntries.containsKey(exp.id), isTrue);
      expect((await store.getEntryById(exp.id))!.status, KhosraEntryStatus.failed);

      // Retry after fixing network error
      gateway.failNextExpense = false;
      final summary2 = await service.commitEntries(
        entryIds: [exp.id],
        userId: 'u1',
        userName: 'Admin',
      );
      expect(summary2.hasFailures, isFalse);
      expect(summary2.committedIds, [exp.id]);
      expect((await store.getEntryById(exp.id))!.status, KhosraEntryStatus.committed);
    });
  });

  group('5. Aday remaining calculation with pending entries', () {
    test('reduces displayed remaining due by uncommitted pending aday entries without touching real customer due', () {
      final now = DateTime.utc(2026, 10, 23, 8, 0);
      final customer = Customer(
        id: 'cust_10',
        name: 'Jamal',
        createdAt: now,
        updatedAt: now,
        isActive: true,
        productDue: 500.0, // ৳500 (50,000 poisha)
        cashBorrowDue: 300.0, // ৳300 (30,000 poisha)
      );

      final dueHistory = [
        DueTransaction(
          id: 'tx_prod_1',
          customerId: 'cust_10',
          dueType: 'product',
          amount: 500.0,
          isAddition: true,
          potentialProfit: 100.0,
          createdAt: now,
          createdBy: 'u1',
          createdByName: 'Admin',
        ),
        DueTransaction(
          id: 'tx_cash_1',
          customerId: 'cust_10',
          dueType: 'cashBorrow',
          amount: 300.0,
          isAddition: true,
          createdAt: now,
          createdBy: 'u1',
          createdByName: 'Admin',
        ),
      ];

      final pendingEntries = [
        KhosraEntry(
          id: 'aday_pending_1',
          businessDate: '2026-10-23',
          createdAt: now,
          updatedAt: now,
          type: KhosraEntryType.aday,
          name: 'Jamal',
          customerId: 'cust_10',
          amountPaisa: 20000, // ৳200 pending collection against tx_prod_1
          dueRecordId: 'tx_prod_1',
          dueTransactionId: 'tx_prod_1',
          status: KhosraEntryStatus.pending,
          createdBy: 'u1',
          createdByName: 'Admin',
        ),
      ];

      final records = OpenDueRecord.computeOpenDueRecords(
        customer: customer,
        dueHistory: dueHistory,
        pendingEntries: pendingEntries,
      );

      final prodRecord = records.firstWhere((r) => r.id == 'tx_prod_1');
      final cashRecord = records.firstWhere((r) => r.id == 'tx_cash_1');

      // Real committed remaining is still ৳500 (50000 poisha), but effective remaining is ৳300 (30000 poisha)
      expect(prodRecord.committedRemainingPaisa, 50000);
      expect(prodRecord.pendingAdayPaisa, 20000);
      expect(prodRecord.effectiveRemainingPaisa, 30000);

      // Cash record has no pending aday -> full ৳300 (30000 poisha) remaining
      expect(cashRecord.committedRemainingPaisa, 30000);
      expect(cashRecord.effectiveRemainingPaisa, 30000);
    });
  });
}

