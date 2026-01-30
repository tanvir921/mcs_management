import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../modules/auth/providers/auth_provider.dart';
import '../modules/auth/screens/login_screen.dart';
import '../shared/widgets/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If authenticated, show home screen
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }

        // Otherwise show login screen (handles both logout and not yet authenticated)
        return const LoginScreen();
      },
    );
  }
}
