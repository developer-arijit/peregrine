import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/common_methods.dart';
import '../core/storage/secure_storage.dart';
import 'new_order_screen.dart';
import 'app_initialization_screen.dart';
import '../db/database_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'draft_orders.dart';
import '../api/api_service.dart';
import 'place_draft_order.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({Key? key}) : super(key: key);

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  String userName = "";
  String userEmail = "";
  Uint8List? userImageBytes;
  int pageSize = 20;
  int totalPages = 1;
  String terms = "";

  List orders = [];
  int page = 1;
  bool isLoading = false;
  bool hasMore = true;
  Map<String, dynamic> customerDetailsData = {};
  Map<String, dynamic> customerOrderData = {};

  /// Load user info
  Future<void> loadUserData() async {
    final name = await SecureStorage.getUserName();
    final image = await SecureStorage.getUserImage();
    final email = await SecureStorage.getUserEmail();

    if (image != null) {
      userImageBytes = base64Decode(image);   // decode only once
    }

    if (!mounted) return;

    setState(() {
      userName = name ?? "";
      userEmail = email ?? "";
    });
  }

  /// Get placed orders
  Future<List<Map<String, dynamic>>> getPlacedOrders({
    required String userId,
    required int page,
  }) async {
    return await DatabaseHelper.instance.getRecords(
      tableName: "orders",
     // whereCondition: "user_id = ? AND order_status = ?",
     // whereArgs: [userId, "Placed"],
      pageNumber: page,
      pageSize: pageSize,
      orderByField: "id",
      order: "DESC",
    );
  }

  Future<void> loadCustomersDetails({
    required String customerCode
  }) async {
    setState(() {
      isLoading = true;
    });
    var creditLimit = '',
        Terms = '';
    final data = await apiCall(
        endpoint: "/get-customer-data",
        method: "POST",
        body: {
          "operator": "OPS01",
          "CustomerCode": customerCode
        }
    );
    creditLimit = data["CustomerDetails"]?["CustomerDetail"]?["CreditLimit"];
    Terms = data["CustomerDetails"]?["CustomerDetail"]?["Terms"];
    setState(() {
      customerDetailsData = data;
      creditLimit = creditLimit;
      terms = Terms;
      isLoading = false;
    });
  }

  Future<void> loadProducts ({
    required String customerCode
  }) async {
    setState(() {
      isLoading = true;   // 👈 show loader
    });

    final data = await apiCall(
        endpoint: "/get-order-form-data",
        method: "POST",
        body: {
          "operator": "OPS01",
          "Customer": customerCode
        }
    );
    if (!mounted) return;

    setState(() {
      isLoading = false;
      customerOrderData = data;
    });
  }

  Future<void> loadOrders() async {
    if (isLoading || !hasMore) return;

    setState(() => isLoading = true);

    String? userId = await SecureStorage.getUserId();
    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    int totalRecords = await DatabaseHelper.instance.getTotalCount(
      tableName: "orders",
      whereCondition: "user_id = ? AND order_status = ?",
      whereArgs: [userId, "Draft"],
    );

    int totalPages = (totalRecords / pageSize).ceil();

    var newOrders = await getPlacedOrders(
        userId: userId,
        page: page
    );

    // ✅ Always add data
    orders.addAll(newOrders);

    // ✅ Decide if more pages exist
    if (page >= totalPages) {
      hasMore = false;
    } else {
      page++;
    }

    setState(() => isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002c4c),
        iconTheme: const IconThemeData(color: Colors.white),
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

      /// Drawer
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF002c4c)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: userImageBytes != null
                        ? ClipOval(
                      child: Image.memory(
                        userImageBytes!,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                      ),
                    ) : const Icon(Icons.person, size: 40, color: Colors.grey),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          userName.isEmpty ? "User" : userName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.add_shopping_cart),
              title: const Text("New Order"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const NewOrderScreen()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text("Orders"),
              onTap: () => Navigator.pop(context),
            ),

            ListTile(
              leading: const Icon(Icons.save_as),
              title: const Text("Draft Orders"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DraftOrderScreen()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text("Sync Status"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppInitializationScreen(),
                  ),
                );
              },
            )
          ],
        ),
      ),

      /// Body
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "PLACED ORDERS",
              style: TextStyle(
                color: Color(0xFF002c4c),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            /// Order list
            Expanded(
              child: isLoading && orders.isEmpty
                  ? const Center(child: CircularProgressIndicator())

                  : orders.isEmpty
                  ? const Center(
                child: Text(
                  "No orders placed yet.",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              )

                  : ListView.builder(
                itemCount: orders.length + 1,
                itemBuilder: (context, index) {

                  if (index == orders.length) {
                    if (!hasMore) return const SizedBox();

                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : loadOrders,

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,        // button background
                            foregroundColor: Colors.white,       // text + icon color
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                          icon: isLoading
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white, // loader color
                            ),
                          )
                              : const Icon(Icons.expand_more), // 👈 your icon

                          label: Text(
                            isLoading ? "Loading..." : "Load More Orders",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ),
                    );
                  }

                  return orderCard(orders[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getFullAddress(Map shippingAddress) {
    String firstName = shippingAddress["first_name"] ?? "";
    String lastName  = shippingAddress["last_name"] ?? "";
    String address1  = shippingAddress["address_1"] ?? "";
    String address2  = shippingAddress["address_2"] ?? "";
    String address3  = shippingAddress["address_3"] ?? "";
    String postcode  = shippingAddress["postcode"] ?? "";
    String state     = shippingAddress["state"] ?? "";
    String country = shippingAddress["country"] ?? "";

    return "$firstName $lastName, "
        "$address1 $address2 $address3, "
        "Country: $country, State: $state, Postcode: $postcode";
  }

  /// Order Card UI
  Widget orderCard(Map order) {
    bool isDelivery = order["fulfillment_type"] == "Delivery";
    String dispatchDate = "";
    String deliveryDate = "";
    String courier = "";
    Map? shippingAddress;
    if (order["shipping_address"] != null &&
        order["shipping_address"].toString().isNotEmpty) {
      shippingAddress = jsonDecode(order["shipping_address"]);

      dispatchDate = DateFormat('MM/dd/yyyy').format(DateTime.parse(shippingAddress?["dispatch_date"] ?? "")) ;
      deliveryDate = DateFormat('MM/dd/yyyy').format(DateTime.parse(shippingAddress?["delivery_date"] ?? ""));
      courier = shippingAddress?["courier_name"] ?? "--";
    }

    if(order['order_status'] == 'Draft'){
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.blue, width: 1.2),
        ),
        color: Colors.lightBlue.shade600,

        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// TOP ROW → Delivery / Collection badge only
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                            children: [
                              Text(
                                "Placed on: ",
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                "${order["order_date"]}",
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ]
                        ),
                      ]
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Draft" ,
                      style: TextStyle(
                        color:  Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(
                color: Colors.white54,
                thickness: 1,
                height: 20,
              ),

              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                        children: [
                          /// ORDER ID
                          const Text(
                            "Order ID: ",
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight(700)),
                          ),

                          Text(
                            "#${order["id"]}" ?? "-",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ]
                    )
                  ]
              ),

              Row(
                  children: [
                    Text(
                      "PO Number: ",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight(700)),
                    ),
                    Text(
                      "${order["po_number"] ?? ""}",
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ]
              ),

              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: "Customer: ",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:  order["customer_name"] ?? "",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              if (isDelivery && shippingAddress != null)
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Courier: ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: courier,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),

              if (isDelivery && shippingAddress != null)
                Row(
                    children: [
                      Text(
                        "Dispatch Date: ",
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight(700)),
                      ),
                      Text(
                        dispatchDate,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ]
                ),

              if (isDelivery && shippingAddress != null)
                Row(
                    children: [
                      Text(
                        "Delivery Date: ",
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight(700)),
                      ),
                      Text(
                        deliveryDate,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ]
                ),

              const SizedBox(height: 8),

              /// Address (only for delivery)
              if (isDelivery && shippingAddress != null)
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Shipping Address: ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text:  getFullAddress(shippingAddress),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(
                color: Colors.white54,
                thickness: 1,
                height: 20,
              ),

              Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    /// ORDER DETAILS heading (professional look)
                    const Text(
                      "Order Summary",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ]
              ),

              const SizedBox(height: 8),

              /// Items total / Shipping / Tax → in ONE ROW
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Subtotal", style: TextStyle(color: Colors.white, fontWeight: FontWeight(700), fontSize: 12 )),
                        Text(
                          "£${order["order_value"] ?? "0"}",
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Shipping", style: TextStyle(color: Colors.white, fontWeight: FontWeight(700), fontSize: 12 )),
                        Text(
                          "£${order["shipping_amount"] ?? "0"}",
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Vat", style: TextStyle(color: Colors.white, fontWeight: FontWeight(700), fontSize: 12 )),
                        Text(
                          "£${order["total_tax"] ?? "0"}",
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Total", style: TextStyle(color: Colors.white, fontWeight: FontWeight(700), fontSize: 12 )),
                        Text(
                          "£${order["order_grand_total"] ?? "0"}",
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              /// Button with icon
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    showProductsPopup(
                        context,
                        int.parse(order["id"].toString()),
                        ""
                    );
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label:  Text(
                    "View ${order["no_of_products"] == 1 ? "1 Product" : "${order["no_of_products"] ?? 0} Products"}",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    var connectivityResult = await Connectivity().checkConnectivity();

                    if (connectivityResult.contains(ConnectivityResult.mobile) ||
                        connectivityResult.contains(ConnectivityResult.wifi)) {
                      setState(() {
                        isLoading: true;
                      });

                      await loadCustomersDetails(customerCode: order["customer_id"]);
                      await loadProducts(customerCode: order["customer_id"]);

                      List<Map<String, dynamic>> items = [];
                      var products = await DatabaseHelper.instance.getRecords(
                        tableName: "order_items",
                        whereCondition: "order_id = ?",
                        whereArgs: [order["id"]],
                      );
                      int id = 1;

                      for (final line in products) {

                        items.add({
                          "id": id,
                          "sku": line["product_id"],
                          "description": line["product_name"],
                          "quantity": line["qty"],
                          "price": line["trade"],
                          "discount": line["discount"],
                          "net": line["net"],
                          "subtotal": line["subtotal"],
                          "subtotal_tax": line["tax"],
                          "total": double.parse((line["subtotal"] + line["tax"]).toStringAsFixed(2)),
                          "total_tax": line["tax"],
                        });

                        id++;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DraftOrderShippingScreen(
                                  customerData: customerDetailsData,
                                  orderItems: items,
                                  orderTotal: order["order_value"],
                                  totalTax: order["total_tax"],
                                  poNumber: order["po_number"],
                                  orderId: order["id"],
                                  totalProducts: order["no_of_products"]
                              ),
                        ),
                      );


                    }else{
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: const [
                              Icon(Icons.wifi_off, color: Colors.red),
                              SizedBox(width: 8),
                              Text("No Internet"),
                            ],
                          ),
                          content: const Text("Please check your internet connection."),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.reorder),
                  label:  Text(
                    "Place Order",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }else{
      return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.blue, width: 1.2),
      ),
      color: Colors.lightBlue.shade600,

      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// TOP ROW → Delivery / Collection badge only
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Placed on: ",
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          "${order["order_date"]}",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ]
                    ),
                  ]
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDelivery ? "Delivery" : "Collection",
                    style: TextStyle(
                      color: isDelivery ? Colors.green : Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(
              color: Colors.white54,
              thickness: 1,
              height: 20,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                    children: [
                        /// ORDER ID
                        const Text(
                          "Order ID: ",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight(700)),
                        ),

                        Text(
                          "#${order["external_order_id"]}" ?? "-",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ]
                )
              ]
            ),

            Row(
                children: [
                  Text(
                    "PO Number: ",
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight(700)),
                  ),
                  Text(
                    "${order["po_number"] ?? ""}",
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ]
            ),

            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: "Customer: ",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:  order["customer_name"] ?? "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            if (isDelivery && shippingAddress != null)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: "Courier: ",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: courier,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

            if (isDelivery && shippingAddress != null)
              Row(
                  children: [
                    Text(
                      "Dispatch Date: ",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight(700)),
                    ),
                    Text(
                      dispatchDate,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ]
              ),

            if (isDelivery && shippingAddress != null)
              Row(
                  children: [
                    Text(
                      "Delivery Date: ",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight(700)),
                    ),
                    Text(
                      deliveryDate,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ]
              ),

            const SizedBox(height: 8),

            /// Address (only for delivery)
            if (isDelivery && shippingAddress != null)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: "Shipping Address: ",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:  getFullAddress(shippingAddress),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(
              color: Colors.white54,
              thickness: 1,
              height: 20,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                /// ORDER DETAILS heading (professional look)
                const Text(
                  "Order Summary",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ]
            ),

            const SizedBox(height: 8),

            /// Items total / Shipping / Tax → in ONE ROW
            Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Subtotal", style: TextStyle(color: Colors.white, fontWeight: FontWeight(700), fontSize: 12 )),
                          Text(
                            "£${order["order_value"] ?? "0"}",
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Shipping", style: TextStyle(color: Colors.white, fontWeight: FontWeight(700), fontSize: 12 )),
                          Text(
                            "£${order["shipping_amount"] ?? "0"}",
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Vat", style: TextStyle(color: Colors.white, fontWeight: FontWeight(700), fontSize: 12 )),
                          Text(
                            "£${order["total_tax"] ?? "0"}",
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total", style: TextStyle(color: Colors.white, fontWeight: FontWeight(700), fontSize: 12 )),
                          Text(
                            "£${order["order_grand_total"] ?? "0"}",
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                ),
            ),

            const SizedBox(height: 12),

            /// Button with icon
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  showProductsPopup(
                      context,
                      int.parse(order["id"].toString()),
                      order["external_order_id"]
                  );
                },
                icon: const Icon(Icons.shopping_bag_outlined),
                label:  Text(
                  "View ${order["no_of_products"] == 1 ? "1 Product" : "${order["no_of_products"] ?? 0} Products"}",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    }
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