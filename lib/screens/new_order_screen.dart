import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/storage/secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api/api_service.dart';
import 'customer_details_screen.dart';
import '../services/common_methods.dart';
import 'orders_screen.dart';
import 'new_order_products.dart';
import '../db/database_helper.dart';
import 'app_initialization_screen.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'draft_orders.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({Key? key}) : super(key: key);

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {

  String customerCode = "";
  String customerName = "";
  String creditLimit = "";
  String terms = "";
  Map<String, dynamic> customerDetailsData = {};
  Map<String, dynamic> customerOrderData = {};
  String userName = "";
  String userEmail = "";
  Uint8List? userImageBytes;
  late FocusNode customerFocusNode;
  late TextEditingController customerController;
  final ScrollController _scrollController = ScrollController();

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

  Map<String, String> customers = {}; // key=Customer code, value=Name
  bool isLoading = false; // loader

  @override
  void initState() {
    super.initState();
    loadUserData();

    customerFocusNode = FocusNode();
    customerController = TextEditingController();

    /// 👇 Open dropdown automatically when textbox gets focus
    customerFocusNode.addListener(() {
      if (customerFocusNode.hasFocus) {
        setState(() {}); // rebuild so Autocomplete opens with all values
      }
    });
  }

  Future<void> loadCustomersDetails({
    required String customerCode
  }) async {
    setState(() {
      isLoading = true;
    });
    var creditLimit = '',
        terms = '';
    var connectivityResult = await Connectivity().checkConnectivity();

    bool isOnline = (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi));


    if (isOnline) {
      final data = await apiCall(
          endpoint: "/get-customer-data",
          method: "POST",
          body: {
            "operator": "OPS01",
            "CustomerCode": customerCode
          }
      );
      creditLimit = data["CustomerDetails"]?["CustomerDetail"]?["CreditLimit"];
      terms = data["CustomerDetails"]?["CustomerDetail"]?["Terms"];

      setState(() {
        customerDetailsData = data;
        this.creditLimit = creditLimit;
        this.terms = terms;
        isLoading = false;
      });
    }else{
      final db = await DatabaseHelper.instance.database;

      final result = await db.query(
        'customerDetails',
        columns: ['customer_id', 'apiResponse', 'addressDetails', 'shippingDiscounts'],
        where: 'customer_id = ?',
        whereArgs: [customerCode],
      );

      if (result.isNotEmpty) {
        final row = result.first;

        /// ✅ Decode main API response
        Map<String, dynamic> apiResponse =
        jsonDecode(row['apiResponse'].toString());

        /// ✅ Decode optional fields
        var addressDetails = row['addressDetails'];
        var shippingDiscounts = row['shippingDiscounts'];

        if (addressDetails != null) {
          apiResponse["CustomerDetails"]["CustomerDetail"]["Addresses"] = jsonDecode(addressDetails.toString());
        }else{
          apiResponse["CustomerDetails"]["CustomerDetail"]["Addresses"]["AddressLineDetail"] = [{}];
        }

        if (shippingDiscounts != null) {
          apiResponse["CustomerDetails"]["CustomerDetail"]["ShippingDiscounts"] = jsonDecode(shippingDiscounts.toString());
        }

        /// ✅ Extract safely
        String creditLimit = apiResponse["CustomerDetails"]?["CustomerDetail"]?["CreditLimit"] ?? '';
        String terms = apiResponse["CustomerDetails"]?["CustomerDetail"]?["Terms"] ?? '';

        /// ✅ Update UI
        setState(() {
          customerDetailsData = apiResponse;
          this.creditLimit = creditLimit;
          this.terms = terms;
          isLoading = false;
        });
      }
    }
  }

  Future<void> loadProducts ({
    required String customerCode
  }) async {
    setState(() {
      isLoading = true;   // 👈 show loader
    });

    var connectivityResult = await Connectivity().checkConnectivity();
    bool isOnline = (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi));


    if (isOnline) {
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
    }else{

      final db = await DatabaseHelper.instance.database;

      final result = await db.query(
        'customerFormData',
        columns: ['customer_id', 'apiResponse', 'addressDetails'],
        where: 'customer_id = ?',
        whereArgs: [customerCode],
      );

      if (result.isNotEmpty) {
        final row = result.first;

        /// ✅ Decode main API response
        Map<String, dynamic> apiResponse = jsonDecode(row['apiResponse'].toString());

        // Ensure Addresses exists
        apiResponse["CustomerDetails"]["CustomerDetail"] ??= {};
        apiResponse["CustomerDetails"]["CustomerDetail"]["Addresses"] ??= {};

        /// ✅ Decode optional fields
        var addressDetails = row['addressDetails'];
        if (addressDetails != null) {
          apiResponse["CustomerDetails"]["CustomerDetail"]["Addresses"]["AddressLineDetail"] = jsonDecode(addressDetails.toString());
        }else{
          apiResponse["CustomerDetails"]["CustomerDetail"]["Addresses"]["AddressLineDetail"] = '';
        }

        await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_id ON customerProductData(customer_id)');
        final products = await db.query(
          'customerProductData',
          columns: [
            'customer_id',
            'stockCode',
            'description',
            'mass',
            'volume',
            'supplier',
            'productClass',
            'taxCode',
            'taxPercent',
            'kitType',
            'stockOnHold',
            'stockOnHoldReason',
            'salesOnHold',
            'productGroup',
            'onHoldReason',
            'warehouse',
            'selectionArea',
            'discountPercentage',
            'sellingPrice',
            'discountAmount',
            'sellingPriceLessDiscount',
            'stock',
            'weight',
            'productLength',
            'productWidth',
            'productHeight',
            'unitBarcode',
            'hazardous',
            'webProduct',
          ],
          where: 'customer_id = ?',
          whereArgs: [customerCode],
        );

        List<Map<String, dynamic>> productList = [];

        if (products.isNotEmpty) {

            productList = products.map((row) => {
              "StockCode": row["stockCode"],
              "Description": row["description"],
              "Mass": row["mass"],
              "Volume": row["volume"],
              "Supplier": row["supplier"],
              "ProductClass": row["productClass"],
              "TaxCode": row["taxCode"],
              "TaxPercent": row["taxPercent"],
              "KitType": row["kitType"],
              "StockOnHold": row["stockOnHold"],
              "StockOnHoldReason": row["stockOnHoldReason"],
              "SalesOnHold": row["salesOnHold"],
              "ProductGroup": row["productGroup"],
              "OnHoldReason": row["onHoldReason"],
              "Warehouse": row["warehouse"],
              "SelectionArea": row["selectionArea"],
              "DiscountPercentage": row["discountPercentage"],
              "SellingPrice": row["sellingPrice"],
              "DiscountAmount": row["discountAmount"], // ⚠️ check key (see below)
              "SellingPriceLessDiscount": row["sellingPriceLessDiscount"],
              "Stock": row["stock"],
              "Weight": row["weight"],
              "ProductLength": row["productLength"],
              "ProductWidth": row["productWidth"],
              "ProductHeight": row["productHeight"],
              "UnitBarcode": row["unitBarcode"],
              "Hazardous": row["hazardous"],
              "WebProduct": row["webProduct"],
            }).toList();
        }

        /// ✅ Inject products into apiResponse
        apiResponse["CustomerDetails"]["CustomerDetail"]["Products"] = {
          "Product": productList
        };

        /// ✅ Update UI
        setState(() {
          customerOrderData = apiResponse;
          isLoading = false;
        });
      }


    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF002c4c),
        iconTheme: IconThemeData(color: Colors.white),
        leadingWidth: 30,
        title: Image.asset(
          "assets/images/peregrine-portal.png",
          height: 45,
        ),

        actions: [
          IconButton(
            icon: Icon(Icons.power_settings_new, color: Colors.white),
            onPressed: () => CommonMethods.logout(context),
          ),
        ],
      ),

      // 👇 Drawer added here
      drawer: Drawer(
        child: Column(
          children: [
            // 🔵 Drawer Header
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF002c4c),
              ),
              child: Row(
                  children: [

                    /// User Image
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

                    /// Name + Email (one column)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          /// User Name
                          Text(
                            userName.isEmpty ? "User" : userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          /// User Email (below name)
                          Text(
                            userEmail.isEmpty ? "" : userEmail,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),

                        ],
                      ),
                    ),
                  ]
              ),
            ),

            // 🆕 New Order
            ListTile(
              leading: Icon(Icons.add_shopping_cart),
              title: Text("New Order"),
              onTap: () {
                Navigator.pop(context); // close drawer
              },
            ),

            // 📦 Orders
            ListTile(
              leading: Icon(Icons.list_alt),
              title: Text("Orders"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => OrderScreen()),
                );
              },
            ),

            // 📦 Orders
            ListTile(
              leading: Icon(Icons.save_as),
              title: Text("Draft Orders"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => DraftOrderScreen()),
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

      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child:SingleChildScrollView(
          controller: _scrollController,
          child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// Title
                  Text(
                    "NEW ORDER",
                    style: TextStyle(
                      color: Color(0xFF002c4c),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 15),

                  /// Customer Search (Built-in Autocomplete)
                  DropdownSearch<MapEntry<String, String>>(
                    asyncItems: (String? filter) async {

                      List<dynamic> table = [];

                      final data = await DatabaseHelper.instance.getApiResponse();

                      /// ✅ Base data (API cache)
                      table = data?['Result']?['Table'] ?? [];

                      var connectivityResult = await Connectivity().checkConnectivity();

                      bool isOffline = !(connectivityResult.contains(ConnectivityResult.mobile) ||
                          connectivityResult.contains(ConnectivityResult.wifi));

                      /// 🔴 OFFLINE → load from DB
                      if (isOffline) {
                        final db = await DatabaseHelper.instance.database;

                        final result = await db.query(
                          'customerFormData',
                          columns: ['customer_id', 'customer_name'],
                        );

                        table = result.map((row) {
                          return {
                            "Customer": row['customer_id'].toString(),
                            "Name": row['customer_name'].toString(),
                          };
                        }).toList();
                      }

                      /// 🔍 Optional filter (search)
                      if (filter != null && filter.isNotEmpty) {
                        table = table.where((item) {
                          return item['Name']
                              .toString()
                              .toLowerCase()
                              .contains(filter.toLowerCase()) ||
                              item['Customer']
                                  .toString()
                                  .toLowerCase()
                                  .contains(filter.toLowerCase());
                        }).toList();
                      }

                      /// ✅ Convert to MapEntry list
                      return table.map<MapEntry<String, String>>((item) {
                        return MapEntry(
                          item['Customer'].toString(),
                          item['Name'].toString(),
                        );
                      }).toList();
                    },

                    itemAsString: (entry) => entry.value,

                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchDelay: Duration(milliseconds: 200),
                    ),

                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        hintText: "Select customer...",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    onChanged: (entry) {
                      if (entry == null) return;

                      setState(() {
                        customerCode = entry.key;
                        customerName = entry.value;
                        creditLimit = "...";
                        terms = "...";
                      });

                      loadCustomersDetails(customerCode: entry.key);
                    },
                  ),

                  SizedBox(height: 20),

                  /// Customer Info Table (Built-in Table)
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(3),
                    },
                    children: [

                      TableRow(
                          decoration: BoxDecoration(
                            color: Color(0xFFebe7e7),
                          ),
                          children: [
                            CommonMethods.cell("Customer Code"),
                            CommonMethods.cell(customerCode),
                          ]
                      ),

                      TableRow(
                          decoration: BoxDecoration(
                            color: Color(0xFFfafafa),
                          ),
                          children: [
                            CommonMethods.cell("Customer Name"),
                            CommonMethods.cell(customerName),
                          ]
                      ),

                      TableRow(
                          decoration: BoxDecoration(
                            color: Color(0xFFebe7e7),
                          ),
                          children: [
                            CommonMethods.cell("Credit Limit"),
                            CommonMethods.cell(creditLimit),
                          ]
                      ),

                      TableRow(
                          decoration: BoxDecoration(
                            color: Color(0xFFfafafa),
                          ),
                          children: [
                            CommonMethods.cell("Terms"),
                            CommonMethods.cell(terms),
                          ]
                      ),

                      TableRow(
                          decoration: BoxDecoration(
                            color: Color(0xFFebe7e7),
                          ),
                          children: [
                            CommonMethods.cell("PO Number"),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: TextField(
                                controller: customerController,
                                decoration: InputDecoration(
                                  hintText: "Enter PO Number",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 4,
                                  ),
                                ),
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ]
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  if (customerCode.isNotEmpty)
                    Row(
                      children: [

                        /// View Details (left button)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CustomerDetailsScreen(customerData: customerDetailsData),
                                ),
                              );
                            },
                            icon: Icon(Icons.visibility_outlined, size: 22),
                            label: Text("View Details"),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Color(0xFF002c4c),
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 48), // height = 48
                            ),
                          ),
                        ),

                        /// gap between buttons (8px looks best on mobile)
                        SizedBox(width: 8),

                        /// Next Step (right button)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await loadProducts(customerCode: customerCode);

                              if (!mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NewOrderProductScreen(
                                    customerData: customerOrderData,
                                    poNumber: customerController.text,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Color(0xFF002c4c),
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 48),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Next"),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_right_alt_rounded, size: 28),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            /// ---------------- FULL SCREEN LOADER ----------------
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
          ),
        ),
      ),
    );
  }
}