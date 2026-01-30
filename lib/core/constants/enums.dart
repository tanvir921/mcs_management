enum UserRole { masterAdmin, subAdmin }

enum CustomerDueType { product, service, msfRecharge, cashBorrow, previousDue }

enum Permission {
  customers,
  msfTransactions,
  products,
  services,
  reports,
  dailyClosing,
  userManagement,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.masterAdmin:
        return 'Master Admin';
      case UserRole.subAdmin:
        return 'Sub Admin';
    }
  }
}

extension CustomerDueTypeExtension on CustomerDueType {
  String get displayName {
    switch (this) {
      case CustomerDueType.product:
        return 'Product Due';
      case CustomerDueType.service:
        return 'Service Due';
      case CustomerDueType.msfRecharge:
        return 'MSF/Recharge Due';
      case CustomerDueType.cashBorrow:
        return 'Cash Borrow';
      case CustomerDueType.previousDue:
        return 'Previous Due';
    }
  }
}

extension PermissionExtension on Permission {
  String get displayName {
    switch (this) {
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

  String get description {
    switch (this) {
      case Permission.customers:
        return 'View, add, edit, and manage customers';
      case Permission.msfTransactions:
        return 'Manage MSF/Recharge transactions';
      case Permission.products:
        return 'Manage products and inventory';
      case Permission.services:
        return 'Manage services';
      case Permission.reports:
        return 'View and generate reports';
      case Permission.dailyClosing:
        return 'Perform daily closing operations';
      case Permission.userManagement:
        return 'Manage sub-admin users and permissions';
    }
  }
}
