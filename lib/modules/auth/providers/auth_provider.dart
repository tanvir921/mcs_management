import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../../../core/constants/enums.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        _currentUser = await _authService.getCurrentUserData();
      } else {
        _currentUser = null;
      }
      if (_isInitializing) {
        _isInitializing = false;
      }
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(email, password);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logAction({
    required String action,
    required String module,
    String? details,
  }) async {
    if (_currentUser == null) return;

    await _authService.logAction(
      userId: _currentUser!.id,
      userName: _currentUser!.name,
      action: action,
      module: module,
      details: details,
    );
  }

  Future<void> createAdminUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required List<Permission> permissions,
  }) async {
    if (_currentUser == null) {
      throw Exception('Not authenticated');
    }

    // Save current user info before creating new user
    final currentUserId = _currentUser!.id;
    final currentUserName = _currentUser!.name;
    final currentUserData = _currentUser;

    try {
      await _authService.createAdminUser(
        email: email,
        password: password,
        name: name,
        role: role,
        createdByUserId: currentUserId,
        createdByUserName: currentUserName,
        permissions: permissions,
      );

      // Restore current user after the new user creation logs us out
      _currentUser = currentUserData;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateUserPermissions({
    required String userId,
    required List<Permission> permissions,
  }) async {
    if (_currentUser == null) {
      throw Exception('Not authenticated');
    }

    try {
      await _authService.updateUserPermissions(
        userId: userId,
        permissions: permissions,
        updatedByUserId: _currentUser!.id,
        updatedByUserName: _currentUser!.name,
      );
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
