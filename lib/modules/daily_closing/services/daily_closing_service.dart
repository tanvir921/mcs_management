import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_closing_model.dart';
import '../../wallet/models/wallet.dart';
import '../../wallet/models/wallet_type.dart';
import '../../wallet/models/wallet_transaction.dart';
import '../../sales/services/sales_service.dart';
import '../../../core/errors/app_exceptions.dart';

class DailyClosingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SalesService _salesService = SalesService();
  static const String _closingCollection = 'daily_closing';

  /// Calculate today's sales total and profit
  Future<(double total, double profit)> calculateTodaysSalesSummary(
    String userId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final sales = await _salesService.getAllSales(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      double totalSales = 0;
      double totalProfit = 0;
      for (final sale in sales) {
        if (sale.createdBy != userId) continue;
        totalSales += sale.finalAmount;
        totalProfit += sale.totalProfit;
      }

      return (totalSales, totalProfit);
    } catch (e) {
      throw ValidationException('Failed to calculate today sales summary: $e');
    }
  }

  /// Calculate today's MSF recharge from due_transactions
  Future<double> calculateTodaysMSFRecharge(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

      debugPrint('🔍 MSF: Querying from $startOfDay to $endOfDay');

      final snapshot = await _firestore
          .collection('due_transactions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      debugPrint('🔍 MSF: Found ${snapshot.docs.length} documents');

      double totalMSF = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('🔍 MSF: Doc ID=${doc.id}, data=$data');
        
        // Safe access with null checks
        final dueType = data['dueType'];
        final amount = data['amount'];
        final isAddition = data['isAddition'];
        
        debugPrint('🔍 MSF: dueType=$dueType (${dueType.runtimeType}), amount=$amount (${amount.runtimeType}), isAddition=$isAddition (${isAddition.runtimeType})');

        if (dueType is String && amount is num) {
          // Today's MSF/Recharge dues
          if (dueType == 'msfRecharge') {
            totalMSF += amount.toDouble();
            debugPrint('✅ MSF: Added ${amount.toDouble()} to totalMSF');
          }
        }
      }

      debugPrint('✅ MSF: Final totalMSF = $totalMSF');
      return totalMSF;
    } catch (e, stackTrace) {
      debugPrint('❌ MSF ERROR: $e');
      debugPrint('❌ MSF STACK: $stackTrace');
      throw ValidationException('Failed to calculate today MSF recharge: $e');
    }
  }

  /// Calculate today's cash borrow due from due_transactions
  Future<double> calculateTodaysCashBorrowDue(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

      debugPrint('🔍 CashBorrow: Querying from $startOfDay to $endOfDay');

      final snapshot = await _firestore
          .collection('due_transactions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      debugPrint('🔍 CashBorrow: Found ${snapshot.docs.length} documents');

      double totalCashBorrow = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Safe access with null checks
        final dueType = data['dueType'];
        final amount = data['amount'];
        final isAddition = data['isAddition'];

        if (dueType is String && amount is num) {
          // Today's Cash Borrow dues
          if (dueType == 'cashBorrow') {
            totalCashBorrow += amount.toDouble();
            debugPrint('✅ CashBorrow: Added ${amount.toDouble()}');
          }
        }
      }

      debugPrint('✅ CashBorrow: Final total = $totalCashBorrow');
      return totalCashBorrow;
    } catch (e, stackTrace) {
      debugPrint('❌ CashBorrow ERROR: $e');
      debugPrint('❌ CashBorrow STACK: $stackTrace');
      throw ValidationException(
        'Failed to calculate today cash borrow due: $e',
      );
    }
  }

  /// Calculate today's expenses
  Future<double> calculateTodaysExpenses(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

      Query query = _firestore
          .collection('expenses')
          .where('isActive', isEqualTo: true);

      query = query.where('expenseDate', isGreaterThanOrEqualTo: startOfDay);
      query = query.where('expenseDate', isLessThanOrEqualTo: endOfDay);

      final snapshot = await query.get();

      double totalExpenses = 0;
      for (var doc in snapshot.docs) {
        totalExpenses += (doc['amount'] as num?)?.toDouble() ?? 0;
      }

      return totalExpenses;
    } catch (e) {
      throw ValidationException('Failed to calculate today expenses: $e');
    }
  }

  /// Calculate today's total due collections (payments received from customers)
  Future<double> calculateTotalDueCollections(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

      final snapshot = await _firestore
          .collection('due_transactions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      double totalCollections = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = data['amount'];
        final isAddition = data['isAddition'];

        // Collections: payments received (isAddition=false)
        if (amount is num && isAddition == false) {
          totalCollections += amount.toDouble();
        }
      }

      debugPrint('✅ TotalDueCollections: $totalCollections');
      return totalCollections;
    } catch (e) {
      throw ValidationException('Failed to calculate total due collections: $e');
    }
  }

  /// Get all wallet balances for user with breakdown
  Future<(double, double)> calculateWalletBalances(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('wallets')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      double permanentTotal = 0;
      double temporaryTotal = 0;

      for (var doc in snapshot.docs) {
        final wallet = Wallet.fromJson(doc.data());
        permanentTotal += wallet.permanentBalance;
        temporaryTotal += wallet.temporaryBalance;
      }

      return (permanentTotal, temporaryTotal);
    } catch (e) {
      throw ValidationException('Failed to calculate wallet balances: $e');
    }
  }

  /// Get wallet breakdown - individual wallet permanent balances
  Future<List<BreakdownItem>> getWalletBreakdown(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('wallets')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      List<BreakdownItem> breakdown = [];
      for (var doc in snapshot.docs) {
        final wallet = Wallet.fromJson(doc.data());
        if (wallet.permanentBalance > 0) {
          breakdown.add(
            BreakdownItem(
              id: doc.id,
              label: wallet.displayName,
              amount: wallet.permanentBalance,
              category: 'wallet',
              description: 'Permanent balance',
            ),
          );
        }
      }
      return breakdown;
    } catch (e) {
      throw ValidationException('Failed to get wallet breakdown: $e');
    }
  }

  /// Get temporary balance breakdown - individual wallet temporary balances
  Future<List<BreakdownItem>> getTemporaryBalanceBreakdown(
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('wallets')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      List<BreakdownItem> breakdown = [];
      for (var doc in snapshot.docs) {
        final wallet = Wallet.fromJson(doc.data());
        if (wallet.temporaryBalance > 0) {
          breakdown.add(
            BreakdownItem(
              id: doc.id,
              label: wallet.displayName,
              amount: wallet.temporaryBalance,
              category: 'temporary',
              description: 'Temporary balance',
            ),
          );
        }
      }
      return breakdown;
    } catch (e) {
      throw ValidationException(
        'Failed to get temporary balance breakdown: $e',
      );
    }
  }

  /// Get MSF breakdown - individual customer MSF transactions for today
  Future<List<BreakdownItem>> getMSFBreakdown(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final customersSnapshot = await _firestore
          .collection('customers')
          .where('userId', isEqualTo: userId)
          .get();

      List<BreakdownItem> breakdown = [];

      for (var customerDoc in customersSnapshot.docs) {
        final customerData = customerDoc.data();
        final customerName = customerData['name'] ?? 'Unknown';

        final dueTransactions = await customerDoc.reference
            .collection('due_transactions')
            .where('type', isEqualTo: 'msfRecharge')
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where('date', isLessThanOrEqualTo: endOfDay)
            .get();

        for (var transaction in dueTransactions.docs) {
          final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
          if (amount > 0) {
            breakdown.add(
              BreakdownItem(
                id: transaction.id,
                label: customerName,
                amount: amount,
                category: 'msf',
                description: 'MSF Recharge',
              ),
            );
          }
        }
      }

      return breakdown;
    } catch (e) {
      throw ValidationException('Failed to get MSF breakdown: $e');
    }
  }

  /// Get cash borrow breakdown - individual customer cash borrow transactions for today
  Future<List<BreakdownItem>> getCashBorrowBreakdown(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final customersSnapshot = await _firestore
          .collection('customers')
          .where('userId', isEqualTo: userId)
          .get();

      List<BreakdownItem> breakdown = [];

      for (var customerDoc in customersSnapshot.docs) {
        final customerData = customerDoc.data();
        final customerName = customerData['name'] ?? 'Unknown';

        final dueTransactions = await customerDoc.reference
            .collection('due_transactions')
            .where('type', isEqualTo: 'cashBorrow')
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where('date', isLessThanOrEqualTo: endOfDay)
            .get();

        for (var transaction in dueTransactions.docs) {
          final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
          if (amount > 0) {
            breakdown.add(
              BreakdownItem(
                id: transaction.id,
                label: customerName,
                amount: amount,
                category: 'cashBorrow',
                description: 'Cash Borrow',
              ),
            );
          }
        }
      }

      return breakdown;
    } catch (e) {
      throw ValidationException('Failed to get cash borrow breakdown: $e');
    }
  }

  /// Get expense breakdown - individual expense items for today
  Future<List<BreakdownItem>> getExpenseBreakdown(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('expenses')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThanOrEqualTo: endOfDay)
          .get();

      List<BreakdownItem> breakdown = [];

      for (var doc in snapshot.docs) {
        final amount = (doc['amount'] as num?)?.toDouble() ?? 0;
        final category = doc['category'] ?? 'Other';
        final description = doc['description'] ?? '';

        if (amount > 0) {
          breakdown.add(
            BreakdownItem(
              id: doc.id,
              label: category,
              amount: amount,
              category: 'expense',
              description: description,
            ),
          );
        }
      }

      return breakdown;
    } catch (e) {
      throw ValidationException('Failed to get expense breakdown: $e');
    }
  }

  /// Get yesterday's daily closing to compare
  Future<DailyClosing?> getYesterdaysClosing(String userId) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final startOfDay = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
      );
      final endOfDay = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        23,
        59,
        59,
      );

      final snapshot = await _firestore
          .collection(_closingCollection)
          .where('userId', isEqualTo: userId)
          .where('closingDate', isGreaterThanOrEqualTo: startOfDay)
          .where('closingDate', isLessThanOrEqualTo: endOfDay)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return DailyClosing.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw ValidationException('Failed to get yesterday closing: $e');
    }
  }

  /// Create draft daily closing with calculations
  Future<DailyClosing> createDraftClosing({
    required String userId,
    required double todaysHandCash,
    required List<ProfitEntry> profitEntries,
  }) async {
    try {
      // Get all required data
      final todaysMSF = await calculateTodaysMSFRecharge(userId);
      final todaysCashBorrow = await calculateTodaysCashBorrowDue(userId);
      final todaysExpenses = await calculateTodaysExpenses(userId);
      final totalDueCollections = await calculateTotalDueCollections(userId);
      final (todaysSalesTotal, todaysSalesProfit) =
          await calculateTodaysSalesSummary(userId);
      final (walletPermanent, walletTemporary) = await calculateWalletBalances(
        userId,
      );
      final yesterdayClosing = await getYesterdaysClosing(userId);

      // Get breakdowns for detailed reporting
      final walletBreakdown = await getWalletBreakdown(userId);
      final temporaryBalanceBreakdown = await getTemporaryBalanceBreakdown(
        userId,
      );
      final msfBreakdown = await getMSFBreakdown(userId);
      final cashBorrowBreakdown = await getCashBorrowBreakdown(userId);
      final expenseBreakdown = await getExpenseBreakdown(userId);

      // Calculate subtotal using new formula:
      // Subtotal = (Wallets + HandCash + MSF Due + CashBorrow Due + Expenses) 
      //          - (Temporary + Sales + Collections)
      // Note: Sales deduction is temporary for balancing with yesterday's subtotal
      final subtotal =
          (walletPermanent +
          todaysHandCash +
          todaysMSF +
          todaysCashBorrow +
          todaysExpenses) -
          (walletTemporary +
          todaysSalesTotal +
          totalDueCollections);

      // Calculate remaining cash
      final yesterdaySubtotal = yesterdayClosing?.subtotal ?? 0;
      final remainingCash = subtotal - yesterdaySubtotal;

      // Calculate total profit
      final optionalProfit = profitEntries.fold<double>(
        0,
        (sum, entry) => sum + entry.amount,
      );
      final totalProfit = todaysSalesProfit + optionalProfit;

      // Final closing balance includes sales (sales deduction is only for subtotal balancing)
      final finalClosingBalanceBase = 
          (walletPermanent +
          todaysHandCash +
          todaysMSF +
          todaysCashBorrow +
          todaysExpenses) -
          (walletTemporary + totalDueCollections);

      // Create model (not yet uploaded to server)
      final closing = DailyClosing(
        id: _firestore.collection(_closingCollection).doc().id,
        userId: userId,
        closingDate: DateTime.now(),
        createdAt: DateTime.now(),
        todaysHandCash: todaysHandCash,
        todaysSalesTotal: todaysSalesTotal,
        todaysSalesProfit: todaysSalesProfit,
        todaysMSFRecharge: todaysMSF,
        todaysCashBorrowDue: todaysCashBorrow,
        todaysExpenses: todaysExpenses,
        totalDueCollections: totalDueCollections,
        walletBalancesTotal: walletPermanent,
        temporaryBalancesTotal: walletTemporary,
        subtotal: subtotal,
        yesterdaySubtotal: yesterdaySubtotal,
        remainingCash: remainingCash,
        profitEntries: profitEntries,
        totalProfit: totalProfit,
        deductedProfit: 0,
        finalClosingBalance: finalClosingBalanceBase,  // Correct balance without sales deduction
        walletBreakdown: walletBreakdown,
        temporaryBalanceBreakdown: temporaryBalanceBreakdown,
        msfBreakdown: msfBreakdown,
        cashBorrowBreakdown: cashBorrowBreakdown,
        expenseBreakdown: expenseBreakdown,
      );

      return closing;
    } catch (e) {
      throw ValidationException('Failed to create draft closing: $e');
    }
  }

  /// Update deducted profit and calculate final balance
  Future<DailyClosing> updateDeductedProfit(
    DailyClosing closing,
    double deductedProfit,
  ) async {
    final finalBalance = closing.subtotal - deductedProfit;
    return closing.copyWith(
      deductedProfit: deductedProfit,
      finalClosingBalance: finalBalance,
    );
  }

  /// Upload/approve and save daily closing to server
  Future<void> saveDailyClosing({
    required DailyClosing closing,
    required String approvedBy,
    required String approvedByName,
    String? remarks,
  }) async {
    try {
      final updatedClosing = closing.copyWith(
        isApproved: true,
        isUploaded: true,
        approvedBy: approvedBy,
        approvedAt: DateTime.now(),
        remarks: remarks,
      );

      await _firestore
          .collection(_closingCollection)
          .doc(closing.id)
          .set(updatedClosing.toJson());

      // Track profit deduction in wallet (even if 0)
      await _trackProfitDeductionInWallet(
        userId: closing.userId,
        amount: closing.deductedProfit,
        date: closing.closingDate,
        notes: remarks,
        approvedByName: approvedByName,
      );

      // Add profit to reports - will be aggregated in reports section
      await _addProfitToReports(
        userId: closing.userId,
        closingDate: closing.closingDate,
        totalProfit: closing.totalProfit,
        closingId: closing.id,
      );
    } catch (e) {
      throw ValidationException('Failed to save daily closing: $e');
    }
  }

  /// Track profit deduction in Profit Deduction Tracking wallet
  Future<void> _trackProfitDeductionInWallet({
    required String userId,
    required double amount,
    required DateTime date,
    String? notes,
    required String approvedByName,
  }) async {
    try {
      // Get or create profit deduction wallet
      final profitWalletQuery = await _firestore
          .collection('wallets')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'profitDeduction')
          .limit(1)
          .get();

      String profitWalletId;
      if (profitWalletQuery.docs.isEmpty) {
        // Create new profit deduction wallet
        profitWalletId = _firestore.collection('wallets').doc().id;
        final newWallet = Wallet(
          id: profitWalletId,
          userId: userId,
          type: WalletType.profitDeduction,
          customName: null,
          permanentBalance: amount,
          temporaryBalance: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );
        await _firestore
            .collection('wallets')
            .doc(profitWalletId)
            .set(newWallet.toJson());
      } else {
        profitWalletId = profitWalletQuery.docs.first.id;
        // Add to existing wallet permanent balance
        final wallet = Wallet.fromJson(profitWalletQuery.docs.first.data());
        final newBalance = wallet.permanentBalance + amount;
        await _firestore.collection('wallets').doc(profitWalletId).update({
          'permanentBalance': newBalance,
          'updatedAt': DateTime.now(),
        });
      }

      // Create balance history record
      final historyId = _firestore
          .collection('wallets')
          .doc(profitWalletId)
          .collection('balance_history')
          .doc()
          .id;
      final existingWallet = await _firestore
          .collection('wallets')
          .doc(profitWalletId)
          .get();
      final previousBalance =
          (existingWallet['permanentBalance'] as num?)?.toDouble() ?? 0;

      final history = BalanceHistory(
        id: historyId,
        walletId: profitWalletId,
        balanceType: 'permanent',
        previousBalance: previousBalance - amount,
        newBalance: previousBalance,
        change: amount,
        note: notes ?? 'Profit deduction from daily closing',
        changedAt: date,
        changedBy: 'system',
        changedByName: 'System (Daily Closing - $approvedByName)',
      );

      await _firestore
          .collection('wallets')
          .doc(profitWalletId)
          .collection('balance_history')
          .doc(historyId)
          .set(history.toJson());
    } catch (e) {
      throw ValidationException('Failed to track profit deduction: $e');
    }
  }

  /// Add profit amount to reports profit section
  Future<void> _addProfitToReports({
    required String userId,
    required DateTime closingDate,
    required double totalProfit,
    required String closingId,
  }) async {
    try {
      final reportId =
          'profit_${closingDate.year}_${closingDate.month}_${closingDate.day}';

      final reportRef = _firestore
          .collection('reports')
          .doc(userId)
          .collection('profits')
          .doc(reportId);

      final existing = await reportRef.get();
      if (existing.exists) {
        // Add to existing profit
        final existingAmount =
            (existing.data()?['amount'] as num?)?.toDouble() ?? 0;
        await reportRef.update({
          'amount': existingAmount + totalProfit,
          'closingIds': FieldValue.arrayUnion([closingId]),
          'lastUpdated': DateTime.now(),
        });
      } else {
        // Create new profit record
        await reportRef.set({
          'date': closingDate,
          'amount': totalProfit,
          'userId': userId,
          'closingIds': [closingId],
          'createdAt': DateTime.now(),
          'lastUpdated': DateTime.now(),
        });
      }
    } catch (e) {
      throw ValidationException('Failed to add profit to reports: $e');
    }
  }

  /// Get daily closing by ID
  Future<DailyClosing?> getClosingById(String closingId) async {
    try {
      final doc = await _firestore
          .collection(_closingCollection)
          .doc(closingId)
          .get();
      if (!doc.exists) return null;
      return DailyClosing.fromJson(doc.data()!);
    } catch (e) {
      throw ValidationException('Failed to get closing: $e');
    }
  }

  /// Get all daily closings for a user (for history)
  Future<List<DailyClosing>> getUserClosingHistory(
    String userId, {
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_closingCollection)
          .where('userId', isEqualTo: userId)
          .where('isUploaded', isEqualTo: true)
          .orderBy('closingDate', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => DailyClosing.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw ValidationException('Failed to get closing history: $e');
    }
  }

  /// Check if closing already exists for today
  Future<DailyClosing?> getTodaysClosing(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection(_closingCollection)
          .where('userId', isEqualTo: userId)
          .where('closingDate', isGreaterThanOrEqualTo: startOfDay)
          .where('closingDate', isLessThanOrEqualTo: endOfDay)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return DailyClosing.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw ValidationException('Failed to check today closing: $e');
    }
  }

  /// Generate PDF report URL (placeholder - integrate with actual PDF service)
  Future<String> generatePdfReport(DailyClosing closing) async {
    try {
      // TODO: Integrate with PDF generation service (e.g., Firebase Functions)
      // For now, return placeholder URL
      return 'https://reports.mcs-management.com/closing/${closing.id}.pdf';
    } catch (e) {
      throw ValidationException('Failed to generate PDF: $e');
    }
  }

  /// Withdraw amount from profit deduction for personal use
  Future<void> withdrawFromProfitDeduction({
    required String userId,
    required double amount,
    String? notes,
    required String withdrawnByName,
  }) async {
    try {
      // Get profit deduction wallet
      final profitWalletQuery = await _firestore
          .collection('wallets')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'profitDeduction')
          .limit(1)
          .get();

      if (profitWalletQuery.docs.isEmpty) {
        throw ValidationException('No profit deduction wallet found');
      }

      final profitWalletId = profitWalletQuery.docs.first.id;
      final wallet = Wallet.fromJson(profitWalletQuery.docs.first.data());

      // Check if sufficient balance
      if (wallet.permanentBalance < amount) {
        throw ValidationException(
          'Insufficient profit deduction balance. Available: ${wallet.permanentBalance}',
        );
      }

      // Deduct from wallet
      final newBalance = wallet.permanentBalance - amount;
      await _firestore.collection('wallets').doc(profitWalletId).update({
        'permanentBalance': newBalance,
        'updatedAt': DateTime.now(),
      });

      // Create balance history record (negative change for withdrawal)
      final historyId = _firestore
          .collection('wallets')
          .doc(profitWalletId)
          .collection('balance_history')
          .doc()
          .id;

      final history = BalanceHistory(
        id: historyId,
        walletId: profitWalletId,
        balanceType: 'permanent',
        previousBalance: wallet.permanentBalance,
        newBalance: newBalance,
        change: -amount, // Negative for withdrawal
        note: notes ?? 'Personal withdrawal from profit deduction',
        changedAt: DateTime.now(),
        changedBy: 'system',
        changedByName: 'System (Personal Withdrawal - $withdrawnByName)',
      );

      await _firestore
          .collection('wallets')
          .doc(profitWalletId)
          .collection('balance_history')
          .doc(historyId)
          .set(history.toJson());
    } catch (e) {
      throw ValidationException('Failed to withdraw from profit deduction: $e');
    }
  }
}
