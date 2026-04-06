import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'new_order_screen.dart';
import '../services/customer_sync_service.dart';

class AppInitializationScreen extends StatefulWidget {
  const AppInitializationScreen({super.key});

  @override
  State<AppInitializationScreen> createState() =>
      _AppInitializationScreenState();
}

class _AppInitializationScreenState
    extends State<AppInitializationScreen> {

  int totalCustomers = 0;
  int processed = 0;
  double progress = 0.0;

  bool isCompleted = false;
  bool isInitializing = true;

  Timer? timer;

  @override
  void initState() {
    super.initState();
    startAutoRefresh();
  }

  /// 🔴 AUTO REFRESH FROM DB
  void startAutoRefresh() {
    timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await loadProgressFromDB();
    });
  }

  /// 🔴 LOAD DATA FROM DB
  Future<void> loadProgressFromDB() async {
    final db = await DatabaseHelper.instance.database;

    if(DatabaseHelper.isDbBusy == true){
      return;
    }
    /// TOTAL CUSTOMERS (from stored API)
    final customerTable = await db.query('customers');

    if (customerTable.isNotEmpty &&
        customerTable.first['apiResponse'] != null) {

      final data =
      jsonDecode(customerTable.first['apiResponse'].toString());

      List customerCodes = data['Result']['Table'];

      totalCustomers = customerCodes.length;
    }

    /// PROCESSED (from synced table)
    final processedResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM customerFormData",
    );

    processed = processedResult.first['count'] as int;

    /// CALCULATE PROGRESS
    if (totalCustomers > 0) {
      progress = processed / totalCustomers;
    }

    /// COMPLETED CHECK
    if (totalCustomers > 0 && processed >= totalCustomers) {
      isCompleted = true;
      timer?.cancel(); // stop refresh
    }

    if (!mounted) return;

    setState(() {
      isInitializing = false;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    /// 🔴 FULL SCREEN LOADER (FIRST LOAD)
    if (isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                "assets/images/peregrine.png",
                height: 50,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              const Text(
                "Preparing app...",
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    int remaining = totalCustomers - processed;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            /// LOGO
            Image.asset(
              "assets/images/peregrine.png",
              height: 45,
            ),

            const SizedBox(height: 30),

            /// TITLE + LOADER
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                if (!isCompleted)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),

                if (!isCompleted) const SizedBox(width: 10),

                Text(
                  isCompleted
                      ? "Sync Completed ✅"
                      : "Updating Customers...",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            /// PROGRESS BAR
            if (totalCustomers > 0)
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [

                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 25,
                        backgroundColor: Colors.grey.shade300,
                        valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),

                    Text(
                      "${(progress * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        color: progress > 0.5
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            /// LIVE VALUES
            if (totalCustomers > 0) ...[
              Text(
                "Processed: $processed",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "Remaining: $remaining",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "Total Customers: $totalCustomers",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),

              Text(
                "Sync Status: ${CustomerSyncService.isSyncing ? "Syncing..." : "Idle"}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: const Text(
                  "Note: We are preparing your app for offline use. You can continue work, this process can run in background.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              )
            ],

            const SizedBox(height: 30),

            /// BUTTON
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NewOrderScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 25, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                "Continue in Background",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}