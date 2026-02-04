import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/action_log.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/app_exceptions.dart';

String _getPermissionDisplayName(Permission p) {
  switch (p) {
    case Permission.customers:
      return 'Customer Management';
    case Permission.msfTransactions:
      return 'MSF Transactions';
    case Permission.products:
      return 'Product Management';
    case Permission.services:
      return 'Service Management';
    case Permission.reports:
      return 'Reports';
    case Permission.dailyClosing:
      return 'Daily Closing';
    case Permission.userManagement:
      return 'User Management';
  }
}

String _getRoleDisplayName(UserRole role) {
  switch (role) {
    case UserRole.masterAdmin:
      return 'Master Admin';
    case UserRole.subAdmin:
      return 'Sub Admin';
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _logsCollection = 'action_logs';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserModel> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw ValidationException('User profile not found');
      }

      final userData = UserModel.fromJson(userDoc.data()!);

      if (!userData.isActive) {
        await _auth.signOut();
        throw PermissionException('Account is disabled');
      }

      await _logAction(
        userId: userData.id,
        userName: userData.name,
        action: 'LOGIN',
        module: 'Auth',
      );

      return userData;
    } on FirebaseAuthException catch (e) {
      throw ValidationException(_getAuthErrorMessage(e.code));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    final user = currentUser;
    if (user != null) {
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = UserModel.fromJson(userDoc.data()!);
        await _logAction(
          userId: userData.id,
          userName: userData.name,
          action: 'LOGOUT',
          module: 'Auth',
        );
      }
    }
    await _auth.signOut();
  }

  /// Get current user data
  Future<UserModel?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    final userDoc = await _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return null;

    return UserModel.fromJson(userDoc.data()!);
  }

  /// Create a new admin user (only master admin can do this)
  Future<void> createAdminUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String createdByUserId,
    required String createdByUserName,
    List<Permission>? permissions, // Permissions for sub-admin
  }) async {
    try {
      // Create auth user (this will automatically log in the new user)
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile
      final userModel = UserModel(
        id: credential.user!.uid,
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
        isActive: true,
        permissions: role == UserRole.subAdmin && permissions != null
            ? permissions
            : [],
      );

      await _firestore
          .collection(_usersCollection)
          .doc(userModel.id)
          .set(userModel.toJson());

      // Sign out the newly created user
      await _auth.signOut();

      // Note: The master admin will need to re-login through the auth state listener
      // The AuthProvider will detect the sign out and prompt for login
      // We cannot re-login programmatically without the master admin's password

      await _logAction(
        userId: createdByUserId,
        userName: createdByUserName,
        action: 'CREATE_USER',
        module: 'Auth',
        details:
            'Created ${_getRoleDisplayName(role)}: $name ($email)${role == UserRole.subAdmin ? " with ${permissions?.length ?? 0} permissions" : ""}',
      );
    } on FirebaseAuthException catch (e) {
      throw ValidationException(_getAuthErrorMessage(e.code));
    }
  }

  /// Update user permissions (Master Admin only)
  Future<void> updateUserPermissions({
    required String userId,
    required List<Permission> permissions,
    required String updatedByUserId,
    required String updatedByUserName,
  }) async {
    try {
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        throw ValidationException('User not found');
      }

      final userData = UserModel.fromJson(userDoc.data()!);

      if (userData.role == UserRole.masterAdmin) {
        throw ValidationException('Cannot modify master admin permissions');
      }

      await _firestore.collection(_usersCollection).doc(userId).update({
        'permissions': permissions.map((p) => p.toString().split('.').last).toList(),
      });

      await _logAction(
        userId: updatedByUserId,
        userName: updatedByUserName,
        action: 'UPDATE_PERMISSIONS',
        module: 'Auth',
        details:
            'Updated permissions for ${userData.name}: ${permissions.map((p) => _getPermissionDisplayName(p)).join(", ")}',
      );
    } catch (e) {
      if (e is ValidationException) rethrow;
      throw ValidationException('Failed to update permissions: $e');
    }
  }

  /// Log admin action
  Future<void> logAction({
    required String userId,
    required String userName,
    required String action,
    required String module,
    String? details,
  }) async {
    await _logAction(
      userId: userId,
      userName: userName,
      action: action,
      module: module,
      details: details,
    );
  }

  Future<void> _logAction({
    required String userId,
    required String userName,
    required String action,
    required String module,
    String? details,
  }) async {
    final log = ActionLog(
      id: _firestore.collection(_logsCollection).doc().id,
      userId: userId,
      userName: userName,
      action: action,
      module: module,
      details: details,
      timestamp: DateTime.now(),
    );

    await _firestore.collection(_logsCollection).doc(log.id).set(log.toJson());
  }

  /// Get action logs
  Future<List<ActionLog>> getActionLogs({
    String? userId,
    String? module,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    Query query = _firestore.collection(_logsCollection);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (module != null) {
      query = query.where('module', isEqualTo: module);
    }

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    query = query.orderBy('timestamp', descending: true).limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ActionLog.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak';
      default:
        return 'Authentication error: $code';
    }
  }
}
