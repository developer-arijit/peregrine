import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../core/storage/secure_storage.dart';
import '../api/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../db/database_helper.dart';

class CommonMethods {
  static void logout(BuildContext context) async {
    // Show confirmation dialog
    bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Logout"),
          content: Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // User pressed No
              child: Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // User pressed Yes
              child: Text("Yes"),
            ),
          ],
        );
      },
    );

    // If user confirmed logout
    if (shouldLogout ?? false) {
      await SecureStorage.logout();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  /// Simple table cell
  static Widget cell(String text) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  static Future<Map<String, dynamic>> placeOrder({
    int? draftOrderId,
    required Map<String, dynamic> customerDetails,
    required List<Map<String, dynamic>> products,
    required String shippingType, // Delivery or Collection
    Map<String, dynamic>? selectedAddress,
    Map<String, dynamic>? shippingDetails,
    required double subTotal,
    required double total,
    required double totalTax,
    required String poNumber
  }) async {

    /// Default response
    Map<String, dynamic> response = {
      "orderPlaced": false,
      "apiResponse": {}
    };

    final userId = await SecureStorage.getUserId();
    int orderId = 0;

    if(draftOrderId == null) {
       orderId = await DatabaseHelper.instance.insertRecord(
          tableName: "orders",
          values: {
            "customer_id": customerDetails["CustomerDetails"]["CustomerDetail"]["Customer"],
            "user_id": userId,
            "customer_name": customerDetails["CustomerDetails"]["CustomerDetail"]["Name"],
            "po_number": poNumber,
            "no_of_products": products.length,
            "total_tax": totalTax.toStringAsFixed(2),
            "order_value": subTotal.toStringAsFixed(2),
            "order_grand_total": total.toStringAsFixed(2),
            "order_status": "Draft",
            "order_date": DateFormat('MM/dd/yyyy').format(DateTime.now())
          }
       );

       if(orderId > 0){
         for (var product in products) {
           await DatabaseHelper.instance.insertRecord(
             tableName: "order_items",
             values: {
               "order_id": orderId,
               "product_id": product["sku"],
               "product_name": product["description"],
               "qty": product["quantity"],
               "trade": product["price"],
               "discount": product["discount"],
               "net": product["net"],
               "subtotal": product["subtotal"],
               "tax": product["total_tax"]
             },
           );

           // 🔴 remove keys after insert
           product.remove("description");
           product.remove("net");
         }
         response["draft_id"] = orderId;
       }else{
         response["orderPlaced"] = false;
         response["apiResponse"] = {
           "error": "Data insertion failed"
         };
         response["orderFunctionExecuted"] = true;
         return response;
       }

    }else{
       orderId = draftOrderId;
    }

    /// Check internet connectivity
    var connectivityResult = await Connectivity().checkConnectivity();
    String currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {

      try {
        Map<String, dynamic> orderData = {
          "operator": "OPS01",
          "id": "",
          "syspro_id": "",
          "account_code": customerDetails["CustomerDetails"]["CustomerDetail"]["Customer"],
          "po_number": poNumber,
          "currency": customerDetails["CustomerDetails"]["CustomerDetail"]["Currency"],
          "date_created": currentDateTime,
          "total": total,
          "total_tax": totalTax,
          "validate_shipping": "N",
          "customer_note": "",
          "syspro_order_type": "P",
          "website": "portal.examplecompany.co.uk",
          "line_items": products
        };

        if(shippingType == "Delivery"){
          /// Prepare order data
          orderData["shipping"] = {
            "first_name": selectedAddress!["ShipToName"],
            "last_name": "",
            "company": "",
            "address_1": selectedAddress["ShipToAddr1"],
            "address_2": selectedAddress["ShipToAddr2"],
            "address_3": selectedAddress["ShipToAddr3"],
            "city": selectedAddress["ShipToAddr3Loc"],
            "state": selectedAddress["ShipToAddr4"],
            "postcode": selectedAddress["ShipPostalCode"],
            "country": selectedAddress["Nationality"] ?? "GB",
            "shipping_property_type": selectedAddress["AddressType"],
            "shipping_code": shippingDetails!["ShippingCode"],
            "address_code": selectedAddress["AddressCode"],
            "shipping_name": selectedAddress["ShipToName"],
            "shipping_fullprice": shippingDetails["FullPrice"],
            "shipping_discount": shippingDetails["DiscountAmount"],
            "shipping_price": shippingDetails["Price"],
            "dispatch_date": shippingDetails["ShipDate"],
            "delivery_date": shippingDetails["DeliveryDate"]
          };
        }

        final apiResponse = await apiCall(
            endpoint: "/create-order",
            method: "POST",
            body: orderData
        );

        response["orderPlaced"] = true;
        var salesOrders = apiResponse["SalesOrders"];
        var order = salesOrders["Order"];

        if(
            order["SalesOrder"] != null &&
            order["SalesOrder"].toString().isNotEmpty
        ){
          orderData["shipping"]["courier_name"] = shippingDetails!["ShippingDesc"];
          await DatabaseHelper.instance.updateRecord(
              tableName: "orders",
              values: {
                "external_order_id" : salesOrders['Order']?['SalesOrder'],
                "fulfillment_type" : shippingType,
                "shipping_amount": orderData["shipping"]["shipping_price"] ??  0,
                "order_status" : "Placed",
                "shipping_address": jsonEncode(orderData["shipping"] ?? ""),
                "order_date": DateFormat('MM/dd/yyyy').format(DateTime.now()),
                "total_tax": totalTax.toStringAsFixed(2),
                "order_value": subTotal.toStringAsFixed(2),
                "order_grand_total": total.toStringAsFixed(2),
              },
              where : "id = ?",
              whereArgs:[orderId]
          );

          response["orderPlaced"] = true;
        }
        response["apiResponse"] = apiResponse;

      } catch (e) {

        response["orderPlaced"] = false;
        response["apiResponse"] = {
          "error": e.toString()
        };

      }

    }

    response["orderFunctionExecuted"] = true;
    return response;
  }
}

void printFullObject(data) {
  const encoder = JsonEncoder.withIndent('  ');
  debugPrint(encoder.convert(data));
}