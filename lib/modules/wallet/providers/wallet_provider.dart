import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();

  List<Wallet> _wallets = [];
  bool _isLoading = false;
  String? _error;

  List<Wallet> get wallets => _wallets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserWallets(
    String userId, {
    bool includeInactive = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _wallets = await _walletService.getUserWallets(
        userId,
        includeInactive: includeInactive,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createWallet(Wallet wallet) async {
    try {
      await _walletService.createWallet(wallet);
      await loadUserWallets(wallet.userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBalance({
    required String walletId,
    required String balanceType, // 'permanent' or 'temporary'
    required double newBalance,
    required String note,
    required String userId,
    required String userName,
  }) async {
    try {
      await _walletService.updateBalance(
        walletId: walletId,
        balanceType: balanceType,
        newBalance: newBalance,
        note: note,
        userId: userId,
        userName: userName,
      );
      // Reload wallets to get updated balance
      final wallet = await _walletService.getWalletById(walletId);
      if (wallet != null) {
        final index = _wallets.indexWhere((w) => w.id == walletId);
        if (index >= 0) {
          _wallets[index] = wallet;
          notifyListeners();
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<BalanceHistory>> getBalanceHistory(String walletId) async {
    try {
      return await _walletService.getBalanceHistory(walletId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteWallet(String id) async {
    try {
      await _walletService.deleteWallet(id);
      await loadUserWallets(_wallets.firstWhere((w) => w.id == id).userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
