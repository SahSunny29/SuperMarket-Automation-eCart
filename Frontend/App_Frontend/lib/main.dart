import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/navigation_controller.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/search_provider.dart';
import 'screens/cart_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/search_screen.dart';
import 'screens/synced_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/unscanned_alert_modal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartTrolleyApp());
}

/// Root Application Widget with MultiProvider setup
class SmartTrolleyApp extends StatelessWidget {
  const SmartTrolleyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => NavigationController()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'e-Cart Smart Trolley',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            // If user is authenticated, route to MainNavigationShell; otherwise WelcomeScreen
            home: auth.isAuthenticated
                ? const MainNavigationShell()
                : const WelcomeScreen(),
          );
        },
      ),
    );
  }
}

/// Shell hosting Bottom Navigation Bar and active screen with PopScope root enforcement
class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context) {
    final navController = context.watch<NavigationController>();
    final cart = context.watch<CartProvider>();

    // When cart is paired, root tab is SyncedScreen; when unpaired, HomeScreen
    final rootScreen = cart.isSynced ? const SyncedScreen() : const HomeScreen();

    // Trigger security alert modal and return to Home/QR Pairing screen if an UNSCANNED_DROP anomaly is active
    if (cart.hasActiveAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (cart.hasActiveAlert && context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          if (navController.currentIndex != 0) {
            navController.setIndex(0);
          }
          UnscannedAlertModal.show(context);
        }
      });
    }

    final screens = [
      rootScreen,
      const SearchScreen(),
      const ScanScreen(),
      const CartScreen(),
      const HistoryScreen(),
    ];

    return PopScope(
      canPop: !navController.canPopHistory,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Route back step-by-step in preserved state
          navController.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: navController.currentIndex,
          children: screens,
        ),
      ),
    );
  }
}
