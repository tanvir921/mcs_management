import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../modules/auth/providers/auth_provider.dart';
import '../modules/customer/providers/customer_provider.dart';
import '../modules/sales/providers/sales_provider.dart';
import '../modules/sales/providers/cart_provider.dart';
import '../modules/wallet/providers/wallet_provider.dart';
import '../modules/expense/providers/expense_provider.dart';
import '../modules/daily_closing/providers/daily_closing_provider.dart';
import '../modules/inventory/providers/inventory_provider.dart';
import 'auth_wrapper.dart';
import 'app_routes.dart';
import 'app_theme.dart';
import '../modules/customer/screens/customer_due_tracker_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String _initialRoute = '/';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Check the current URL path
      final uri = Uri.base;
      if (uri.path == '/customer-due-tracker' || uri.path == '/customer-due-tracker/') {
        _initialRoute = '/customer-due-tracker';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => DailyClosingProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ],
      child: MaterialApp(
        title: 'MCS Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        home: _initialRoute == '/customer-due-tracker' 
            ? const CustomerDueTrackerScreen()
            : const AuthWrapper(),
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
