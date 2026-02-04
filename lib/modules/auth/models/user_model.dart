import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;
  final List<Permission> permissions; // Permissions for sub-admins

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    required this.isActive,
    this.permissions = const [],
  });

  // Master admin has all permissions
  bool get isMasterAdmin => role == UserRole.masterAdmin;

  // Check if user has specific permission
  bool hasPermission(Permission permission) {
    if (isMasterAdmin) return true; // Master admin has all permissions
    return permissions.contains(permission);
  }

  // Get all permissions (Master admin gets all)
  List<Permission> get allPermissions {
    if (isMasterAdmin) return Permission.values;
    return permissions;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Parse role - handle both string and direct values
    UserRole role;
    final roleValue = json['role'];
    if (roleValue is String) {
      role = UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == roleValue || e.name == roleValue,
        orElse: () => UserRole.subAdmin,
      );
    } else {
      role = UserRole.subAdmin;
    }

    // Parse permissions
    List<Permission> permissions = [];
    if (role == UserRole.subAdmin && json['permissions'] != null) {
      final permissionsList = json['permissions'] as List<dynamic>;
      permissions = permissionsList
          .map((p) {
            final pString = p.toString();
            return Permission.values.firstWhere(
              (e) => e.toString().split('.').last == pString || e.name == pString,
              orElse: () => Permission.customers,
            );
          })
          .toList();
    }

    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: role,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isActive: json['isActive'] as bool? ?? true,
      permissions: permissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'permissions': permissions.map((p) => p.toString().split('.').last).toList(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
    List<Permission>? permissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
    );
  }
}
