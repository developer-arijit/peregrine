import '../api/api_service.dart';
import '../db/database_helper.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

class CustomerSyncService {

  static Future<void> startSync({
    Function(int processed, int total)? onProgress,
    Function()? onComplete,
  }) async {

    Map<String, dynamic> data;

    final db = await DatabaseHelper.instance.database;

    /// 🔴 STEP 1: Load customers (DB or API)
    final result = await db.query('customers');

    if (result.isNotEmpty && result.first['apiResponse'] != null) {
      data = jsonDecode(result.first['apiResponse'].toString());
    } else {
      data = await apiCall(endpoint: "/customers");
      await DatabaseHelper.instance.insertOrUpdateApiResponse(data);
    }

    /// 🔴 STEP 2: Extract customers (ID + Name)
    List<Map<String, String>> customers = (data['Result']['Table'] as List)
        .map((e) => {
      "id": e['Customer'].toString(),
      "name": e['Name'].toString(),
    })
        .toList();

    int totalCustomers = customers.length;

    /// 🔴 STEP 3: Get last processed from DB
    final lastRecord = await db.rawQuery(
      "SELECT customer_id FROM customerFormData ORDER BY id DESC LIMIT 1",
    );

    int startIndex = 0;

    if (lastRecord.isNotEmpty) {
      String lastCustomer = lastRecord.first['customer_id'].toString();

      int index = customers.indexWhere(
            (c) => c["id"] == lastCustomer,
      );

      if (index != -1) {
        /// ✅ Remove partial data before retry
        await DatabaseHelper.instance.deleteCustomer(lastCustomer);

        startIndex = index;
      }
    }

    /// 🔴 STEP 4: Loop
    for (int i = startIndex; i < customers.length; i++) {
      var connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi)) {
        String customerId = customers[i]["id"]!;
        String customerName = customers[i]["name"]!;

        await processCustomer(customerId, customerName);

        await Future.delayed(const Duration(milliseconds: 10));

        int processed = i + 1;

        if (onProgress != null) {
          onProgress(processed, totalCustomers);
        }
      }else{
        break;
      }
    }

    if (onComplete != null) {
      onComplete();
    }
  }

  static Future<void> processCustomer(String customerCode, String customerName) async {

    await DatabaseHelper.instance.deleteCustomer(customerCode);

    try {
      final details = await apiCall(
        endpoint: "/get-customer-data",
        method: "POST",
        body: {
          "operator": "OPS01",
          "CustomerCode": customerCode,
        },
      );

      final addresses =
      details["CustomerDetails"]["CustomerDetail"]["Addresses"];

      final shippingDiscounts =
      details["CustomerDetails"]["CustomerDetail"]["ShippingDiscounts"];

      details["CustomerDetails"]["CustomerDetail"].remove("Addresses");
      details["CustomerDetails"]["CustomerDetail"]
          .remove("ShippingDiscounts");

      await DatabaseHelper.instance.insertRecord(
        tableName: "customerDetails",
        values: {
          "customer_id": customerCode,
          "apiResponse": jsonEncode(details),
          "addressDetails": jsonEncode(addresses),
          "shippingDiscounts": jsonEncode(shippingDiscounts),
        },
      );

      final formData = await apiCall(
        endpoint: "/get-order-form-data",
        method: "POST",
        body: {
          "operator": "OPS01",
          "Customer": customerCode,
        },
      );

      final productDetails = formData["CustomerDetails"]["CustomerDetail"]["Products"]["Product"];

      List productsList = [];

      if (productDetails is List) {
        productsList = productDetails;
      } else if (productDetails is Map) {
        productsList = [productDetails];
      }

      await DatabaseHelper.instance
          .insertMultipleProducts(customerCode, productsList);

      //remove products from fromData
      formData["CustomerDetails"]["CustomerDetail"].remove("Products");

      final addressDetails = formData["CustomerDetails"]["CustomerDetail"]["Addresses"]["AddressLineDetail"];

      //remove address from fromData
      formData["CustomerDetails"]["CustomerDetail"].remove("Addresses");

      await DatabaseHelper.instance.insertRecord(
        tableName: "customerFormData",
        values: {
          "customer_id": customerCode,
          "customer_name": customerName,
          "apiResponse": jsonEncode(formData),
          "addressDetails": jsonEncode(addressDetails)
        },
      );

    } catch (e) {
      print("Error syncing $customerCode: $e");
    }
  }
}