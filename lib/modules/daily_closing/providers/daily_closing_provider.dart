import 'package:flutter/foundation.dart';
import '../models/daily_closing_model.dart';
import '../services/daily_closing_service.dart';

class DailyClosingProvider extends ChangeNotifier {
  final DailyClosingService _service = DailyClosingService();

  // Draft closing (not yet uploaded)
  DailyClosing? _draftClosing;
  List<DailyClosing> _closingHistory = [];
  bool _isLoading = false;
  String? _error;
  bool _isLoadingHistory = false;

  DailyClosing? get draftClosing => _draftClosing;
  List<DailyClosing> get closingHistory => _closingHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Create a draft daily closing with real-time calculations
  Future<void> createDraftClosing({
    required String userId,
    required double todaysHandCash,
    required List<ProfitEntry> profitEntries,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _draftClosing = await _service.createDraftClosing(
        userId: userId,
        todaysHandCash: todaysHandCash,
        profitEntries: profitEntries,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update deducted profit in draft
  void updateDeductedProfit(double deductedProfit) {
    if (_draftClosing == null) return;

    _draftClosing = _draftClosing!.copyWith(
      deductedProfit: deductedProfit,
      finalClosingBalance: _draftClosing!.subtotal - deductedProfit,
    );
    notifyListeners();
  }

  /// Update profit entries in draft
  void updateProfitEntries(List<ProfitEntry> profitEntries) {
    if (_draftClosing == null) return;

    final optionalProfit = profitEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final totalProfit = _draftClosing!.todaysSalesProfit + optionalProfit;

    _draftClosing = _draftClosing!.copyWith(
      profitEntries: profitEntries,
      totalProfit: totalProfit,
    );

    notifyListeners();
  }

  /// Update hand cash in draft
  void updateHandCash(double amount) {
    if (_draftClosing == null) return;

    final difference = amount - _draftClosing!.todaysHandCash;
    final newSubtotal = _draftClosing!.subtotal + difference;
    final newRemainingCash = newSubtotal - _draftClosing!.yesterdaySubtotal;

    _draftClosing = _draftClosing!.copyWith(
      todaysHandCash: amount,
      subtotal: newSubtotal,
      remainingCash: newRemainingCash,
      finalClosingBalance: newSubtotal - _draftClosing!.deductedProfit,
    );

    notifyListeners();
  }

  /// Save daily closing to server (upload)
  Future<void> saveDailyClosing({
    required String userId,
    required String approvedByName,
    String? remarks,
  }) async {
    if (_draftClosing == null) {
      _error = 'No draft closing to save';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.saveDailyClosing(
        closing: _draftClosing!,
        approvedBy: userId,
        approvedByName: approvedByName,
        remarks: remarks,
      );

      // Load history after saving
      await loadClosingHistory(userId);
      _draftClosing = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Load closing history
  Future<void> loadClosingHistory(String userId) async {
    // Guard: prevent multiple simultaneous loads
    if (_isLoadingHistory) return;
    
    _isLoadingHistory = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _closingHistory = await _service.getUserClosingHistory(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Get today's closing if it exists
  Future<DailyClosing?> getTodaysClosing(String userId) async {
    try {
      return await _service.getTodaysClosing(userId);
    } catch (e) {
      _error = e.toString();
      // Don't notify listeners for non-critical checks
      return null;
    }
  }

  /// Clear draft
  void clearDraft() {
    _draftClosing = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
