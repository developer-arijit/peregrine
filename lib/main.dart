import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/customer_sync_service.dart';
import 'db/database_helper.dart';
import 'dart:io';
import '../core/auth/token_manager.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database before app starts
  await DatabaseHelper.instance.database;

  bool loggedIn = await TokenManager.isLoggedIn();
  if (loggedIn == true){
    /// 🔴 Check connectivity BEFORE sync
    final db = await DatabaseHelper.instance.database;

    // Get the syncStatus of the first customer row
    final result = await db.query(
      'customers',
      columns: ['syncStatus'],
      limit: 1, // Only need the first row
    );

    if (result.isNotEmpty) {
      final syncStatus = result.first['syncStatus'];

      // Only start auto-sync if syncStatus is null or 0
      if (syncStatus == null || syncStatus == 0) {
        CustomerSyncService.startAutoSync();
      }
    } else {
      // No rows exist, optionally handle this case
      CustomerSyncService.startAutoSync(); // If you want to trigger when table is empty
    }
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );

  }
}