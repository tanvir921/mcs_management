import 'package:flutter/material.dart';
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

class App extends StatelessWidget {
  const App({super.key});

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
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
