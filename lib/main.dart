import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/customer_sync_service.dart';
import 'db/database_helper.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async{
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database before app starts
  await DatabaseHelper.instance.database;

  /// 🔴 Check connectivity BEFORE sync
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult.contains(ConnectivityResult.mobile) ||
      connectivityResult.contains(ConnectivityResult.wifi)) {
    CustomerSyncService.startSync(); // 👈 safe call
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