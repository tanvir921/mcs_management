import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../../../core/errors/app_exceptions.dart';

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _walletsCollection = 'wallets';
  static const String _balanceHistoryCollection = 'balance_history';

  /// Create a new wallet
  Future<void> createWallet(Wallet wallet) async {
    try {
      await _firestore
          .collection(_walletsCollection)
          .doc(wallet.id)
          .set(wallet.toJson());
    } catch (e) {
      throw ValidationException('Failed to create wallet: $e');
    }
  }

  /// Get all wallets for a user
  Future<List<Wallet>> getUserWallets(
    String userId, {
    bool includeInactive = false,
  }) async {
    try {
      Query query = _firestore
          .collection(_walletsCollection)
          .where('userId', isEqualTo: userId);

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      query = query.orderBy('type');

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Wallet.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ValidationException('Failed to get wallets: $e');
    }
  }

  /// Get wallet by ID
  Future<Wallet?> getWalletById(String id) async {
    try {
      final doc = await _firestore.collection(_walletsCollection).doc(id).get();
      if (!doc.exists) return null;
      return Wallet.fromJson(doc.data()!);
    } catch (e) {
      throw ValidationException('Failed to get wallet: $e');
    }
  }

  /// Update wallet
  Future<void> updateWallet(Wallet wallet) async {
    try {
      await _firestore
          .collection(_walletsCollection)
          .doc(wallet.id)
          .update(wallet.toJson());
    } catch (e) {
      throw ValidationException('Failed to update wallet: $e');
    }
  }

  /// Update wallet balance with history tracking
  Future<void> updateBalance({
    required String walletId,
    required String balanceType, // 'permanent' or 'temporary'
    required double newBalance,
    required String note,
    required String userId,
    required String userName,
  }) async {
    try {
      final wallet = await getWalletById(walletId);
      if (wallet == null) {
        throw ValidationException('Wallet not found');
      }

      double previousBalance;
      double permanentBalance = wallet.permanentBalance;
      double temporaryBalance = wallet.temporaryBalance;

      if (balanceType == 'permanent') {
        previousBalance = wallet.permanentBalance;
        permanentBalance = newBalance;
      } else if (balanceType == 'temporary') {
        previousBalance = wallet.temporaryBalance;
        temporaryBalance = newBalance;
      } else {
        throw ValidationException('Invalid balance type');
      }

      final change = newBalance - previousBalance;

      final updatedWallet = wallet.copyWith(
        permanentBalance: permanentBalance,
        temporaryBalance: temporaryBalance,
        updatedAt: DateTime.now(),
      );

      // Create balance history record
      final historyId = _firestore
          .collection(_balanceHistoryCollection)
          .doc()
          .id;
      final history = BalanceHistory(
        id: historyId,
        walletId: walletId,
        balanceType: balanceType,
        previousBalance: previousBalance,
        newBalance: newBalance,
        change: change,
        note: note,
        changedAt: DateTime.now(),
        changedBy: userId,
        changedByName: userName,
      );

      // Use batch write
      final batch = _firestore.batch();

      batch.update(
        _firestore.collection(_walletsCollection).doc(walletId),
        updatedWallet.toJson(),
      );

      batch.set(
        _firestore.collection(_balanceHistoryCollection).doc(historyId),
        history.toJson(),
      );

      await batch.commit();
    } catch (e) {
      throw ValidationException('Failed to update balance: $e');
    }
  }

  /// Get balance history
  Future<List<BalanceHistory>> getBalanceHistory(String walletId) async {
    try {
      final snapshot = await _firestore
          .collection(_balanceHistoryCollection)
          .where('walletId', isEqualTo: walletId)
          .orderBy('changedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BalanceHistory.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw ValidationException('Failed to get balance history: $e');
    }
  }

  /// Delete/deactivate wallet
  Future<void> deleteWallet(String id) async {
    try {
      final wallet = await getWalletById(id);
      if (wallet == null) {
        throw ValidationException('Wallet not found');
      }

      final updatedWallet = wallet.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );

      await updateWallet(updatedWallet);
    } catch (e) {
      throw ValidationException('Failed to delete wallet: $e');
    }
  }
}
