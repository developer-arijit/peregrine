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
    CustomerSyncService.startAutoSync();
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