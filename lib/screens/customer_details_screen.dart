import 'package:flutter/material.dart';
import '../services/common_methods.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> customerData;

  const CustomerDetailsScreen({
    super.key,
    required this.customerData,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  String selectedSection = "Customer Details";

  @override
  Widget build(BuildContext context) {
    var data =
    widget.customerData['CustomerDetails']['CustomerDetail'];

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

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// Title
            const Text(
              "Customer Details",
              style: TextStyle(
                color: Color(0xFF002c4c),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            /// Dropdown
            DropdownButton<String>(
              value: selectedSection,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: "Customer Details",
                  child: Text("Basic Details"),
                ),
                DropdownMenuItem(
                  value: "Address",
                  child: Text("Address Details"),
                ),
                DropdownMenuItem(
                  value: "Shipping Discount",
                  child: Text("Shipping Discount"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedSection = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            /// Show table based on dropdown
            if (selectedSection == "Customer Details")
              customerDetailsTable(data),

            if (selectedSection == "Address")
              addressTable(data),

            if (selectedSection == "Shipping Discount")
              shippingDiscountTable(data),

          ],
        ),
      ),
    );
  }

  /// ---------------- CUSTOMER DETAILS TABLE ----------------
  Widget customerDetailsTable(var data) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
      },
      children: [

        _row("Customer Code", data["Customer"], true),
        _row("Customer Name", data["Name"], false),
        _row("Credit Limit", data["CreditLimit"], true),
        _row("Terms", data["Terms"], false),
        _row("Contact", data["Contact"], true),
        _row("Telephone", data["Telephone"], false),
        _row("Email", data["Email"], true),
        _row("Salesperson", data["Salesperson"], false),
        _row("Currency", data["Currency"], true),
        _row("Company Tax Number", data["CompanyTaxNumber"], false),
        _row("Tax Exempt Number", data["TaxExemptNumber"], true),
        _row("Terms Code", data["TermsCode"], false),
        _row("User Field 1", data["UserField1"], true),
        _row("User Field 2", data["UserField2"], false),
        _row("Area", data["Area"], true),
        _row("Sold To Addr 1", data["SoldToAddr1"], false),
        _row("Sold To Addr 2", data["SoldToAddr2"], true),
        _row("Sold To Addr 3", data["SoldToAddr3"], false),
        _row("City", data["SoldToAddr4"], true),
        _row("Sold Postal Code", data["SoldPostalCode"], false),
        _row("Ship To Addr 1", data["ShipToAddr1"], true),
        _row("Ship To Addr 2", data["ShipToAddr2"], false),
        _row("Ship To Addr 3", data["ShipToAddr3"], true),
        _row("City", data["ShipToAddr4"], false),
        _row("Ship Postal Code", data["ShipPostalCode"], true),

      ],
    );
  }

  /// ---------------- ADDRESS TABLE ----------------
  Widget addressTable(var customerData) {

    var addresses =
    customerData['Addresses']['AddressLineDetail'];

    /// If API returns NULL
    if (addresses == null) {
      return const Text(
        "No Address Available",
        style: TextStyle(fontSize: 16),
      );
    }

    /// If API returns single object instead of list
    if (addresses is Map) {
      addresses = [addresses];
    }

    /// If empty list
    if (addresses.isEmpty) {
      return const Text(
        "No Address Available",
        style: TextStyle(fontSize: 16),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(addresses.length, (index) {

        var address = addresses[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// Heading
            Text(
              "Address ${index + 1}",
              style: const TextStyle(
                color: Color(0xFF002c4c),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            /// Table
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              children: [

                _row("Address Code", address["AddressCode"], true),
                _row("Ship To Name", address["ShipToName"], false),
                _row("Address 1", address["ShipToAddr1"], true),
                _row("Address 2", address["ShipToAddr2"], false),
                _row("Address 3", address["ShipToAddr3"], true),
                _row("City", address["ShipToAddr3Loc"], false),
                _row("State", address["ShipToAddr4"], true),
                _row("Country", address["Area"], false),
                _row("Postal Code", address["ShipPostalCode"], true),
                _row("Email", address["Email"], false),
                _row("Address Type", address["AddressType"], true),

              ],
            ),

            const SizedBox(height: 25),

          ],
        );
      }),
    );
  }

  /// ---------------- SHIPPING DISCOUNT TABLE ----------------
  Widget shippingDiscountTable(var data) {

    var discounts =
    data['ShippingDiscounts']['ShippingDiscount'];

    /// If null OR empty → show message
    /// If API returns NULL
    if (discounts == null) {
      return const Text(
        "No Address Available",
        style: TextStyle(fontSize: 16),
      );
    }

    /// If API returns single object instead of list
    if (discounts is Map) {
      discounts = [discounts];
    }

    /// If empty list
    if (discounts.isEmpty) {
      return const Text(
        "No Address Available",
        style: TextStyle(fontSize: 16),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(discounts.length, (index) {

        var discount = discounts[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// Heading
            Text(
              "Discount ${index + 1}",
              style: const TextStyle(
                color: Color(0xFF002c4c),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            /// Table
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              children: [
                _row("ShippingCode", discount["ShippingCode"], true),
                _row("ThresholdVal", discount["ThresholdVal"], false),
                _row("DiscountPct", discount["DiscountPct"], true)
              ],
            ),

            const SizedBox(height: 25),

          ],
        );
      }),
    );
  }

  /// ---------------- COMMON ROW FUNCTION ----------------
  TableRow _row(String title, dynamic value, bool isGrey) {
    return TableRow(
      decoration: BoxDecoration(
        color: isGrey ? const Color(0xFFebe7e7) : const Color(0xFFfafafa),
      ),
      children: [
        CommonMethods.cell(title),
        CommonMethods.cell(value ?? ""),
      ],
    );
  }
}