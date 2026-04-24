import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api/api_service.dart';
import '../services/common_methods.dart';
import 'orders_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'new_order_screen.dart';
import 'draft_orders.dart';
import '../db/database_helper.dart';

class DraftOrderShippingScreen extends StatefulWidget {
  final Map<String, dynamic> customerData;
  final List<Map<String, dynamic>> orderItems;
  final double orderTotal;
  final double totalTax;
  final String poNumber;
  final int orderId;
  final int totalProducts;

  const DraftOrderShippingScreen({
    super.key,
    required this.customerData,
    required this.orderItems,
    required this.orderTotal,
    required this.totalTax,
    required this.poNumber,
    required this.orderId,
    required this.totalProducts
  });

  @override
  State<DraftOrderShippingScreen> createState() => _DraftOrderShippingScreenState();
}

class _DraftOrderShippingScreenState extends State<DraftOrderShippingScreen> {

  Map<String, dynamic> customerShippingData = {};
  bool isLoading = false; // loader
  List<Map<String, dynamic>> shippingOptions = [];
  String orderType = "Delivery";
  Map<String, dynamic>? selectedAddress;
  List<dynamic> shippingMethods = [];
  String? selectedShippingCode;
  Map<String, List<dynamic>> groupedShipping = {};
  String? selectedDeliveryDate;
  Map<String, dynamic>  selectedShippingObj = {};
  bool isOffline = false;
  double subTotal = 0;
  double shipping = 0;
  double vat = 0;
  double total = 0;

  @override
  void initState() {
    super.initState();
    final addressData = widget.customerData["CustomerDetails"]["CustomerDetail"]["Addresses"]["AddressLineDetail"];

    if (addressData is List) {
      shippingOptions = List<Map<String, dynamic>>.from(addressData);
    } else if (addressData is Map) {
      shippingOptions = [Map<String, dynamic>.from(addressData)];
    } else {
      shippingOptions = [];
    }

    setState(() {
      subTotal = widget.orderTotal;
      vat = widget.totalTax;
      total = widget.orderTotal + widget.totalTax;
    });
  }

  Future<void> loadShipping({
    required String customerCode,
    required String shippingAddressCode,
    required String orderValue
  }) async {

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {

      List<Map<String, dynamic>> orderLines = [];

      for (var item in widget.orderItems) {
        orderLines.add({
          "orderLine": {
            "stockCode": item["sku"],
            "quantity": item["quantity"].toString(),
            "unitOfMeasure": "EA"
          }
        });
      }

      final data = await apiCall(
          endpoint: "/get-shipping-options",
          method: "POST",
          body: {
            "operator": "OPS01",
            "customerCode": customerCode,
            "shippingAddressCode": shippingAddressCode,
            "salesOrderLines": orderLines,
            "orderValue": orderValue
          }
      );
      var table = data["Options"]?["Result"]?["Table"];

      if (table != null && table is List) {
        setState(() {
          shippingMethods = List.from(table);
          groupedShipping.clear();

          for (var item in shippingMethods) {
            String date = item["DeliveryDay"] ?? "Unknown";

            if (!groupedShipping.containsKey(date)) {
              groupedShipping[date] = [];
            }

            bool alreadyExists = groupedShipping[date]!
                .any((existing) => existing["ShippingCode"] == item["ShippingCode"]);

            if (!alreadyExists) {
              groupedShipping[date]!.add(item);
            }
          }

          /// sort by DeliveryDate (ASC)
          var sortedKeys = groupedShipping.keys.toList()
            ..sort((a, b) {
              DateTime dateA = DateTime.parse(groupedShipping[a]![0]["DeliveryDate"]);
              DateTime dateB = DateTime.parse(groupedShipping[b]![0]["DeliveryDate"]);
              return dateA.compareTo(dateB);
            });

          /// rebuild map in sorted order
          final sortedMap = <String, List<dynamic>>{};

          for (var key in sortedKeys) {
            sortedMap[key] = groupedShipping[key]!;
          }

          groupedShipping = sortedMap;

          groupedShipping.forEach((key, list) {
            /// remove items where price is 0
            list.removeWhere((item) {
              double price = double.tryParse(item["Price"].toString()) ?? 0;
              return price == 0;
            });

            /// sort by price ASC
            list.sort((a, b) {
              double priceA = double.tryParse(a["Price"].toString()) ?? 0;
              double priceB = double.tryParse(b["Price"].toString()) ?? 0;
              return priceA.compareTo(priceB);
            });
          });

          groupedShipping.removeWhere((key, list) => list.isEmpty);

          /// auto select nearest date
          selectedDeliveryDate = sortedKeys.first;

          isLoading = false;
        });

      } else {
        setState(() {
          shippingMethods = [];
          isLoading = false;
        });
      }
    }else{
      setState(() {
        shippingMethods = [];
        isLoading = false;
        isOffline = true;
      });
    }
  }
  String formatDeliveryDate(String date) {
    DateTime d = DateTime.parse(date);

    String dayName = [
      "Mon","Tue","Wed","Thu","Fri","Sat","Sun"
    ][d.weekday - 1];

    String monthName = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ][d.month - 1];

    String suffix = "th";
    if (d.day == 1 || d.day == 21 || d.day == 31) suffix = "st";
    if (d.day == 2 || d.day == 22) suffix = "nd";
    if (d.day == 3 || d.day == 23) suffix = "rd";

    return "$dayName ${d.day}$suffix $monthName ${d.year}";
  }

  String getCourierImage(String? courier) {
    switch (courier) {
      case "DX":
        return "assets/images/delivery-partner-icons/dx.png";

      case "Royal Mail":
        return "assets/images/delivery-partner-icons/rm.png";

      case "APC":
        return "assets/images/delivery-partner-icons/apc.png";

      case "Collection":
        return "assets/images/delivery-partner-icons/kings.png";

      case "Kings":
        return "assets/images/delivery-partner-icons/kings.png";

      default:
        return "assets/images/delivery-partner-icons/default.jpeg"; // optional
    }
  }

  void showDeliveryPopup() {
    selectedShippingObj = {};
    selectedShippingCode = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.95,
              child: Column(
                children: [

                  /// Header with close icon
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Select Delivery Date",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  /// Dropdown
                  if (groupedShipping.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: selectedDeliveryDate,
                        items: groupedShipping.keys.map((day) {
                          String realDate =
                          groupedShipping[day]![0]["DeliveryDate"];

                          return DropdownMenuItem(
                            value: day,
                            child: Text(formatDeliveryDate(realDate)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedDeliveryDate = value;
                          });
                        },
                      ),
                    ),

                  SizedBox(height: 10),

                  /// Scrollable shipping options
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      children: (groupedShipping[selectedDeliveryDate] ?? [])
                          .map<Widget>((item) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedShippingObj = item; // this forces rebuild
                              selectedShippingCode = item["ShippingCode"] ?? "";

                              double price = double.tryParse(item["Price"] ?? "0") ?? 0;
                              shipping = price;
                              vat += price * 0.20;
                              total = widget.orderTotal + shipping + vat;
                            });
                            setModalState(() {
                            });
                            Future.delayed(Duration(milliseconds: 300), () {
                              Navigator.pop(context, item);
                            });
                          },
                          child: Stack(
                            children: [

                              /// Main Card
                              Card(
                                margin: EdgeInsets.symmetric(vertical: 6),
                                color: Color(0xFFF1F4F9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: selectedShippingCode == item["ShippingCode"]
                                        ? Colors.green
                                        : Colors.black54,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [

                                      /// Text content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${item["ShippingDesc"] ?? ""}",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                  fontSize: 16
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "${item["ShippingCode"] ?? ""}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [

                                                /// Dispatch + Delivery text
                                                Text("Dispatch on: ${formatDeliveryDate(item["ShipDate"]) ?? ""}"),
                                                Text("Expected Delivery: ${formatDeliveryDate(item["DeliveryDate"]) ?? ""}"),

                                                SizedBox(height: 6),

                                                /// Full width line
                                                Divider(
                                                  thickness: 1,
                                                  color: Colors.black26,
                                                  height: 10,
                                                ),

                                                /// Price
                                                Text(
                                                  "${item["Price"] ?? ""} ${item["Currency"] ?? ""}",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      /// Courier image (right side)
                                      Image.asset(
                                        getCourierImage(item["Courier"]),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              /// Floating green tick (top-right corner)
                              if (selectedShippingCode == item["ShippingCode"])
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.check, color: Colors.white, size: 16),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF002c4c),
          iconTheme: const IconThemeData(color: Colors.white),
          leadingWidth: 30,
          title: Image.asset(
            "assets/images/peregrine-portal.png",
            height: 45,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.power_settings_new, color: Colors.white),
              onPressed: () => CommonMethods.logout(context),
            ),
          ],
        ),


        body: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          "ORDER: #${widget.orderId}",
                          style: TextStyle(
                            color: Color(0xFF002c4c),
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          "Customer: ${widget.customerData["CustomerDetails"]["CustomerDetail"]["Customer"]}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: orderType == "Collection"
                                ? Colors.white
                                : Color(0xFF002c4c),
                          ),
                        ),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () async {
                              showProductsPopup(
                                  context,
                                  int.parse(widget.orderId.toString()),
                                  widget.orderId.toString()
                              );

                            },
                            icon: const Icon(Icons.remove_red_eye),
                            label: Text(
                              "View ${widget.totalProducts == 1 ? "1 Product" : "${widget.totalProducts ?? 0} Products"}",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        SizedBox(height: 6),

                        Text(
                          "Choose Shipping Option:",
                          style: TextStyle(
                            color: Color(0xFF002c4c),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 4),

                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    orderType = "Delivery";

                                    subTotal = widget.orderTotal;
                                    shipping = 0;
                                    vat = widget.totalTax;
                                    total = widget.orderTotal + widget.totalTax;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: orderType == "Delivery"
                                        ? Color(0xFF002c4c)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Color(0xFF002c4c)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (orderType == "Delivery")
                                        Icon(Icons.check_circle, color: Colors.lightGreenAccent, size: 18, ),

                                      if (orderType == "Delivery") SizedBox(width: 6),

                                      Text(
                                        "Delivery",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: orderType == "Delivery"
                                              ? Colors.white
                                              : Color(0xFF002c4c),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(width: 12),

                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedShippingObj = {};
                                    groupedShipping.clear();
                                    orderType = "Collection";
                                    selectedAddress = null;

                                    subTotal = widget.orderTotal;
                                    shipping = 0;
                                    vat = widget.totalTax;
                                    total = widget.orderTotal + widget.totalTax;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: orderType == "Collection"
                                        ? Color(0xFF002c4c)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Color(0xFF002c4c)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (orderType == "Collection")
                                        Icon(Icons.check_circle, color: Colors.lightGreenAccent, size: 18),

                                      if (orderType == "Collection") SizedBox(width: 6),

                                      Text(
                                        "Collection",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: orderType == "Collection"
                                              ? Colors.white
                                              : Color(0xFF002c4c),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 6),

                        if (orderType == "Delivery")
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownSearch<Map<String, dynamic>>(
                                  items: shippingOptions,

                                  itemAsString: (item) =>
                                  "${item["AddressCode"]} | ${item["ShipToName"]}",

                                  popupProps: PopupProps.menu(
                                    showSearchBox: true,
                                    searchFieldProps: TextFieldProps(
                                      decoration: InputDecoration(
                                        hintText: "Search delivery address...",
                                        contentPadding:
                                        EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ),

                                  dropdownDecoratorProps: DropDownDecoratorProps(
                                    dropdownSearchDecoration: InputDecoration(
                                      hintText: "Select delivery address",
                                      contentPadding:
                                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),

                                  onChanged: (value) {
                                    setState(() {
                                      isLoading = true;
                                      selectedShippingObj = {};
                                      selectedAddress = value;
                                      groupedShipping.clear();
                                      loadShipping(
                                          customerCode: widget
                                              .customerData["CustomerDetails"]["CustomerDetail"]["Customer"],
                                          shippingAddressCode: selectedAddress!["AddressCode"],
                                          orderValue: widget.orderTotal.toStringAsFixed(2)
                                      );
                                      subTotal = widget.orderTotal;
                                      shipping = 0;
                                      vat = widget.totalTax;
                                      total = widget.orderTotal + widget.totalTax;
                                    });

                                  },
                                ),
                                SizedBox(height: 10),
                              ]
                          ),


                        if (groupedShipping.isNotEmpty)
                          SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                subTotal = widget.orderTotal;
                                shipping = 0;
                                vat = widget.totalTax;
                                total = widget.orderTotal + widget.totalTax;
                                selectedShippingObj = {};
                              });
                              showDeliveryPopup();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.list_alt),  // 👈 icon before text
                            label: const Text(
                              "Choose Delivery Option",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,),
                            ),
                          ),
                        ),

                        SizedBox(height: 10),

                        if (selectedShippingObj.containsKey("ShippingCode"))
                          SizedBox(
                            width: double.infinity,
                            child: Card(
                              margin: EdgeInsets.zero, // removes default card margin
                              color: Color(0xFFF1F4F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.green, width: 1),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  children: [

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedShippingObj["ShippingDesc"] +
                                                " (${selectedShippingObj["ShippingCode"]})",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            "Delivery: ${formatDeliveryDate(selectedShippingObj["DeliveryDate"])}",
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            "Shipping: ${selectedShippingObj["Price"]} ${selectedShippingObj["Currency"]}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Image.asset(
                                      getCourierImage(selectedShippingObj["Courier"]),
                                      width: 40,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        SizedBox(height: 10),

                        Table(
                          border: TableBorder.all(color: Colors.black26),
                          children: [

                            /// Row 1 (Titles)
                            TableRow(
                              decoration: BoxDecoration(color: Color(0xFFF1F4F9)),
                              children: [
                                _tableCell("Subtotal"),
                                _tableCell("Shipping"),
                                _tableCell("VAT"),
                                _tableCell("Total"),
                              ],
                            ),

                            /// Row 2 (Values)
                            TableRow(
                              children: [
                                _tableCell("£${subTotal.toStringAsFixed(2)}" ),
                                _tableCell("£${shipping.toStringAsFixed(2)}"),
                                _tableCell("£${vat.toStringAsFixed(2)}"),
                                _tableCell("£${total.toStringAsFixed(2)}"),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ]
        ),

        bottomNavigationBar: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Color(0xFFa80000),

          child: Row(

            children: [
              /// Order Total
              Expanded(
                  child: Text(
                    "Order Total:\n ${total.toStringAsFixed(2)} ${widget.customerData['CustomerDetails']['CustomerDetail']['Currency']}",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  )
              ),

              SizedBox(height: 6),

              /// Total Products
              if (orderType == "Collection" ||
                  (orderType == "Delivery" && selectedAddress != null && selectedShippingObj["ShippingCode"] != null) || (orderType == "Delivery" && isOffline== true))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() {
                        isLoading = true;
                      });
                      var result = await CommonMethods.placeOrder(
                          draftOrderId: widget.orderId,
                          customerDetails: widget.customerData,
                          products: widget.orderItems,
                          shippingType: orderType,
                          selectedAddress: selectedAddress,
                          shippingDetails: selectedShippingObj,
                          subTotal: subTotal,
                          total : double.parse(total.toStringAsFixed(2)),
                          totalTax: double.parse(vat.toStringAsFixed(2)),
                          poNumber: widget.poNumber
                      );

                      if(result['orderFunctionExecuted'] == true){
                        setState(() {
                          isLoading = false;
                          widget.orderItems.clear();        // remove all products
                          selectedAddress = null;           // clear selected address
                          selectedShippingObj = {};       // clear shipping details
                          orderType = "Delivery";         // reset default value
                        });

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          barrierColor: Colors.grey.withOpacity(0.8),

                          builder: (context) {
                            return Dialog(
                              insetPadding: EdgeInsets.symmetric(horizontal: 16),
                              backgroundColor: Color(0xFFd7d7c0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Color(0xFF002c4c), // 👈 border color
                                  width: 1,                 // 👈 border thickness
                                ),
                              ),

                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    /// Message
                                    Text(
                                      result["orderPlaced"] == true
                                          ? "Order placed successfully."
                                          : "Failed to place order. Check your internet connect and continue when online.",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: result["orderPlaced"] ? Colors.green : Colors.red,
                                      ),
                                    ),

                                    SizedBox(height: 8),

                                    Text(
                                      result["orderPlaced"] == true
                                          ? "Order id: ${result['apiResponse']?['SalesOrders']?['Order']?['SalesOrder'] ?? ''}"
                                          : "Order id: ${result["draft_id"]}",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: result["orderPlaced"] ? Colors.green : Colors.red,
                                      ),
                                    ),

                                    SizedBox(height: 6),

                                    /// Button 1
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(builder: (_) => NewOrderScreen()),
                                                (route) => false,
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        child: Text("Place Another Order"),
                                      ),
                                    ),

                                    SizedBox(height: 10),

                                    /// Button 2
                                    if(result["orderPlaced"] == true)
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(builder: (_) => OrderScreen()),
                                                  (route) => false,
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: Text("View Orders"),
                                        ),
                                      ),

                                    if(result["orderPlaced"] == false)
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(builder: (_) => DraftOrderScreen()),
                                                  (route) => false,
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: Text("View Draft Orders"),
                                        ),
                                      ),

                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Color(0xFF002c4c),
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                      side: BorderSide(color: Colors.white, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Place Order"),
                        SizedBox(width: 2)
                      ],
                    ),
                  ),
                ),
            ],
          ),
        )

    );
  }

  /// Product popup
  void showProductsPopup(
      BuildContext context,
      int orderId,
      String extOrderId
      ) async {

    var products = await DatabaseHelper.instance.getRecords(
      tableName: "order_items",
      whereCondition: "order_id = ?",
      whereArgs: [orderId],
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero, // removes side/top/bottom gap
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [

                      /// Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Order: #$extOrderId\nProducts",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          )
                        ],
                      ),

                      const Divider(),

                      /// Product list
                      Expanded(
                        child: ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (context, index) {

                            var p = products[index];

                            return Card(
                              margin: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                              color: const Color(0xFF002c4c),
                              child: DefaultTextStyle(
                                style: const TextStyle(color: Colors.white),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [

                                      /// Product Name
                                      Text(
                                        "Product: ${p["product_name"] ?? ""}",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 15),

                                      /// Qty / Trade / Discount
                                      Row(
                                        children: [

                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("Qty", style: TextStyle(color: Colors.white70)),
                                              const SizedBox(height: 4),
                                              Text("${p["qty"] ?? 0}"),
                                            ],
                                          ),

                                          const SizedBox(width: 25),

                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("Trade", style: TextStyle(color: Colors.white70)),
                                              const SizedBox(height: 4),
                                              Text("£${p["trade"] ?? "0"}"),
                                            ],
                                          ),

                                          const SizedBox(width: 25),

                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("Discount %", style: TextStyle(color: Colors.white70)),
                                              const SizedBox(height: 4),
                                              Text("${p["discount"] ?? "0"}%"),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 15),

                                      /// Net / Subtotal / Tax
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Net: ${p["net"] ?? "0"}"),
                                          Text("Subtotal: ${p["subtotal"] ?? "0"}"),
                                          Text("Tax: ${p["tax"] ?? "0"}"),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}
Widget _tableCell(String text) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Center(
      child: Text(
        text,
        style: TextStyle(fontSize:14),
      ),
    ),
  );
}
