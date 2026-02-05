import 'package:flutter/material.dart';
import '../modules/auth/screens/login_screen.dart';
import '../modules/auth/screens/user_list_screen.dart';
import '../modules/auth/screens/add_user_screen.dart';
import '../modules/auth/screens/edit_user_screen.dart';
import '../modules/auth/models/user_model.dart';
import '../shared/widgets/home_screen.dart';
import '../modules/customer/screens/customer_list_screen.dart';
import '../modules/customer/screens/add_customer_screen.dart';
import '../modules/customer/screens/edit_customer_screen.dart';
import '../modules/customer/screens/customer_due_tracker_screen.dart';
import '../modules/customer/models/customer_model.dart';
import '../modules/sales/screens/sales_screen.dart';
import '../modules/sales/screens/add_sale_screen.dart';
import '../modules/sales/screens/sales_history_screen.dart';
import '../modules/wallet/screens/wallets_screen.dart';
import '../modules/expense/screens/expense_screen.dart';
import '../modules/expense/screens/add_expense_screen.dart';
import '../modules/expense/screens/expense_detail_screen.dart';
import '../modules/expense/screens/expense_history_screen.dart';
import '../modules/daily_closing/screens/daily_closing_screen.dart';
import '../modules/daily_closing/screens/profit_deduction_screen.dart';
import '../modules/inventory/screens/inventory_list_screen.dart';
import '../modules/reports/screens/reports_screen.dart';
import '../modules/admin/screens/admin_tools_screen.dart';

class AppRoutes {
  // Route names
  static const String login = '/login';
  static const String home = '/home';
  static const String customers = '/customers';
  static const String customerAdd = '/customer/add';
  static const String customerEdit = '/customer/edit';
  static const String customerDueTracker = '/customer-due-tracker';
  static const String sales = '/sales';
  static const String saleAdd = '/sale/add';
  static const String saleDetail = '/sale/detail';
  static const String salesHistory = '/sales/history';
  static const String wallets = '/wallets';
  static const String expenses = '/expenses';
  static const String expenseAdd = '/expense/add';
  static const String expenseDetail = '/expense/detail';
  static const String expenseHistory = '/expense/history';
  static const String dailyClosing = '/daily-closing';
  static const String inventory = '/inventory';
  static const String users = '/users';
  static const String userAdd = '/user/add';
  static const String userEdit = '/user/edit';
  static const String reports = '/reports';
  static const String profitDeduction = '/profit-deduction';
  static const String adminTools = '/admin/tools';

  // Route generator
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case customers:
        return MaterialPageRoute(
          builder: (_) => const CustomerListScreen(),
          settings: settings,
        );
      case customerAdd:
        return MaterialPageRoute(
          builder: (_) => const AddCustomerScreen(),
          settings: settings,
        );
      case customerEdit:
        final customer = settings.arguments as Customer?;
        if (customer == null) {
          return MaterialPageRoute(
            builder: (_) => const _PlaceholderScreen(title: 'Invalid Customer'),
          );
        }
        return MaterialPageRoute(
          builder: (_) => EditCustomerScreen(customer: customer),
          settings: settings,
        );
      case users:
        return MaterialPageRoute(
          builder: (_) => const UserListScreen(),
          settings: settings,
        );
      case userAdd:
        return MaterialPageRoute(
          builder: (_) => const AddUserScreen(),
          settings: settings,
        );
      case userEdit:
        final user = settings.arguments as UserModel?;
        if (user == null) {
          return MaterialPageRoute(
            builder: (_) => const _PlaceholderScreen(title: 'Invalid User'),
          );
        }
        return MaterialPageRoute(
          builder: (_) => EditUserScreen(user: user),
          settings: settings,
        );
      case sales:
        return MaterialPageRoute(
          builder: (_) => const SalesScreen(),
          settings: settings,
        );
      case saleAdd:
        return MaterialPageRoute(
          builder: (_) => const AddSaleScreen(),
          settings: settings,
        );
      case salesHistory:
        return MaterialPageRoute(
          builder: (_) => const SalesHistoryScreen(),
          settings: settings,
        );
      case saleDetail:
        final saleId = settings.arguments as String?;
        if (saleId == null) {
          return MaterialPageRoute(
            builder: (_) => const _PlaceholderScreen(title: 'Invalid Sale'),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const SalesHistoryScreen(),
          settings: settings,
        );
      case wallets:
        return MaterialPageRoute(
          builder: (_) => const WalletsScreen(),
          settings: settings,
        );
      case dailyClosing:
        return MaterialPageRoute(
          builder: (_) => const DailyClosingScreen(),
          settings: settings,
        );
      case reports:
        return MaterialPageRoute(
          builder: (_) => const ReportsScreen(),
          settings: settings,
        );
      case expenses:
        return MaterialPageRoute(
          builder: (_) => const ExpenseScreen(),
          settings: settings,
        );
      case expenseAdd:
        return MaterialPageRoute(
          builder: (_) => const AddExpenseScreen(),
          settings: settings,
        );
      case expenseHistory:
        return MaterialPageRoute(
          builder: (_) => const ExpenseHistoryScreen(),
          settings: settings,
        );
      case expenseDetail:
        final expenseId = settings.arguments as String?;
        if (expenseId == null) {
          return MaterialPageRoute(
            builder: (_) => const _PlaceholderScreen(title: 'Invalid Expense'),
          );
        }
        return MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(expenseId: expenseId),
          settings: settings,
        );
      case inventory:
        return MaterialPageRoute(
          builder: (_) => const InventoryListScreen(),
          settings: settings,
        );
      case adminTools:
        return MaterialPageRoute(
          builder: (_) => const AdminToolsScreen(),
          settings: settings,
        );
      case profitDeduction:
        return MaterialPageRoute(
          builder: (_) => const ProfitDeductionScreen(),
          settings: settings,
        );
      case customerDueTracker:
        return MaterialPageRoute(
          builder: (_) => const CustomerDueTrackerScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderScreen(title: 'Not Found'),
        );
    }
  }
}

// Placeholder screen for routes
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text('Coming soon'),
          ],
        ),
      ),
    );
  }
}
