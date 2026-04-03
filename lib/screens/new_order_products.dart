import 'package:flutter/material.dart';
import '../services/common_methods.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'new_order_shipping.dart';

class NewOrderProductScreen extends StatefulWidget {
  final Map<String, dynamic> customerData;
  final String poNumber;

  const NewOrderProductScreen({
    super.key,
    required this.customerData,
    required this.poNumber
  });

  @override
  State<NewOrderProductScreen> createState() => _NewOrderProductScreenState();
}

class _NewOrderProductScreenState extends State<NewOrderProductScreen> {

  late FocusNode customerFocusNode;
  late TextEditingController customerController;
  List<OrderLine> orderLines = [];
  List<Map<String, dynamic>> products = [];


  void calculateLine(int index) {
    final line = orderLines[index];

    if (line.product == null) return;

    double qty = double.tryParse(line.qtyController.text) ?? 0;
    double discount = double.tryParse(line.discountController.text) ?? 0;

    double discountAmount = line.trade * (discount / 100);

    line.net = line.trade - discountAmount;
    line.subtotal = line.net * qty;
    line.tax = line.subtotal * 0.20;
    line.discountFormated = discount;

    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    orderLines.add(OrderLine());

    final productData = widget.customerData["CustomerDetails"]
    ["CustomerDetail"]["Products"]["Product"];

    /// -------- Multiple products --------
    if (productData is List) {

      products = productData
          .where((product) =>
      int.tryParse(product["Stock"].toString()) != null &&
          int.parse(product["Stock"].toString()) > 0)
          .map((product) => Map<String, dynamic>.from(product))
          .toList();

    }

    /// -------- Single product --------
    else if (productData is Map) {

      int stock = int.tryParse(productData["Stock"].toString()) ?? 0;

      if (stock > 0) {
        products = [Map<String, dynamic>.from(productData)];
      } else {
        products = [];
      }

    }

    /// -------- Null / unexpected --------
    else {
      products = [];
    }
  }

  double getGrandSubtotal() {
    double total = 0;

    for (var line in orderLines) {
      total += line.subtotal;
    }

    return total;
  }

  double getGrandTaxTotal() {
    double taxTotal = 0;

    for (var line in orderLines) {
      taxTotal += line.tax;
    }

    return taxTotal;
  }

  List<Map<String, dynamic>> getOrderItems() {
    List<Map<String, dynamic>> items = [];

    int id = 0;

    for (final line in orderLines) {

      /// Skip empty rows (user did not select product)
      if (line.product == null) continue;

      /// Skip if quantity is 0
      double qty = double.tryParse(line.qtyController.text) ?? 0;
      if (qty == 0) continue;

      items.add({
        "id": id,
        "sku": line.product!["StockCode"],
        "description": line.product!["Description"],
        "quantity": line.qtyController.text,
        "price": line.trade.toStringAsFixed(2),
        "discount": line.discountFormated.toStringAsFixed(2),
        "net": line.net.toStringAsFixed(2),
        "subtotal": line.subtotal.toStringAsFixed(2),
        "subtotal_tax": line.tax.toStringAsFixed(2),
        "total": double.parse((line.subtotal + line.tax).toStringAsFixed(2)),
        "total_tax": line.tax.toStringAsFixed(2),
      });

      id++;
    }

    return items;
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

      /// 👇 floating button must be here
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFa80000),
        foregroundColor: Colors.white,
        onPressed: () {
          setState(() {
            orderLines.add(OrderLine());
          });
        },
        shape: CircleBorder(
          side: BorderSide(
            color: Colors.white,   // border color
            width: 2,              // border thickness
          ),
        ),
        child: Icon(Icons.add),
      ),

      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                "NEW ORDER",
                style: TextStyle(
                  color: Color(0xFF002c4c),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Expanded(
                child: ListView.builder(
                  itemCount: orderLines.length,
                  itemBuilder: (context, index) {
                    final line = orderLines[index];

                    return Card(
                      margin: EdgeInsets.fromLTRB(0, 6, 0, 6),
                      color: Color(0xFF002c4c),
                      child: DefaultTextStyle(
                        style: TextStyle(color: Colors.white),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Column(
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  /// Remove row (from 2nd row)
                                  if (index != 0)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          orderLines.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.cancel,
                                          color: Color(0xFFa80000),
                                          size: 22,
                                        ),
                                      ),
                                    ),

                                  SizedBox(width: 16),

                                  /// Product Dropdown
                                  Expanded(
                                    child: DropdownSearch<Map<String, dynamic>>(
                                      popupProps: PopupProps.menu(
                                        showSearchBox: true, // 👈 enables search
                                        searchFieldProps: TextFieldProps(
                                          decoration: InputDecoration(
                                            hintText: "Search product...",
                                          ),
                                        ),
                                      ),

                                      items: products,

                                      itemAsString: (item) => "${item["StockCode"]} | ${item["Description"]}",

                                      dropdownDecoratorProps: DropDownDecoratorProps(
                                        dropdownSearchDecoration: InputDecoration(
                                          hintText: "Select product",
                                          hintStyle: TextStyle(color: Colors.white),
                                          labelStyle: TextStyle(color: Colors.white),
                                        ),
                                      ),

                                      onChanged: (value) {
                                        setState(() {
                                          line.product = value;
                                          line.trade = double.parse(value!["SellingPrice"]);
                                          line.description = value["Description"];
                                          line.discountController.text = value["DiscountPercentage"];
                                          line.discountFormated = double.parse(value["DiscountPercentage"]);
                                          line.maxQty = double.parse(value["Stock"]);
                                          line.stockOnHold = value["StockOnHold"] != null &&
                                              value["StockOnHold"].toString().isNotEmpty
                                              ? double.parse(value["StockOnHold"].toString())
                                              : 0;

                                          calculateLine(index);
                                        });
                                      },
                                    ),
                                  ),

                                ],
                            ),

                            SizedBox(height: 25),

                            Row(
                              children: [

                                /// Quantity
                                SizedBox(
                                  width: 70,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [

                                      /// Label
                                      Text(
                                        "Qty",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),

                                      SizedBox(height: 6), // space between label and field

                                      /// Text Field
                                      SizedBox(
                                        width: 50,   // 👈 set your desired width
                                        child: TextField(
                                            controller: line.qtyController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly, // numbers only
                                            ],

                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white,
                                              isDense: true,

                                              contentPadding: EdgeInsets.symmetric(vertical: 4),

                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                borderSide: BorderSide.none,
                                              ),

                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                borderSide: BorderSide.none,
                                              ),

                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                borderSide: BorderSide(color: Colors.white),
                                              ),
                                            ),

                                            onChanged: (v) {
                                              int qty = int.tryParse(v) ?? 0;

                                              int maxStockqtyController = line.maxQty.round().toInt() - line.stockOnHold.round().toInt();


                                              if (qty > maxStockqtyController) {
                                                final text = maxStockqtyController.toString();

                                                line.qtyController.value = TextEditingValue(
                                                  text: text,
                                                  selection: TextSelection.collapsed(offset: text.length),
                                                );
                                              }
                                              calculateLine(index);
                                            },
                                          ),
                                      )
                                    ],
                                  ),
                                ),

                                SizedBox(width: 20),

                                /// Trade price
                                Expanded(
                                  child: TextField(
                                    readOnly: true,
                                    decoration:
                                    InputDecoration(labelText: "Trade", labelStyle: TextStyle(color: Colors.white, fontSize: 18)),
                                    controller:  TextEditingController.fromValue(
                                      TextEditingValue(text: line.trade.toStringAsFixed(2)),
                                    ),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),

                                SizedBox(width: 8),

                                /// Discount %
                                Expanded(
                                  child: TextField(
                                    readOnly: true,
                                    decoration:
                                    InputDecoration(labelText: "Discount %", labelStyle: TextStyle(color: Colors.white, fontSize: 18)),
                                    controller: TextEditingController.fromValue(
                                      TextEditingValue(text: line.discountFormated.toStringAsFixed(2)),
                                    ),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              ],
                            ),

                            SizedBox(height: 25),

                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Net: ${line.net.toStringAsFixed(2)}"),
                                Text(
                                    "Subtotal: ${line.subtotal.toStringAsFixed(2)}"
                                ),
                                Text("Tax: ${line.tax.toStringAsFixed(2)}"),
                              ],
                            )
                          ],
                        ),
                        ),
                      )
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Color(0xFFa80000),

        child: Row(
          children: [

            /// Subtotal text
            Expanded(
              child: Text(
                "Subtotal: ${getGrandSubtotal().toStringAsFixed(2)}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            /// Button
            if (getGrandSubtotal() > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final orderItems = getOrderItems();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            NewOrderShippingScreen(
                                customerData: widget.customerData,
                                orderItems: orderItems,
                                orderTotal: getGrandSubtotal(),
                                totalTax: getGrandTaxTotal(),
                                poNumber: widget.poNumber
                            ),
                      ),
                    );
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
                      Text("Next"),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_right_alt_rounded, size: 28),
                    ],
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class OrderLine {
  Map<String, dynamic>? product;

  TextEditingController qtyController = TextEditingController(text: "1");
  TextEditingController discountController = TextEditingController();

  double trade = 0;
  double net = 0;
  double subtotal = 0;
  double tax = 0;
  /// 👇 ADD THIS
  double discountFormated = 0;
  double maxQty = 0;
  double stockOnHold = 0;
  String description = '';
}