import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  // Get database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app.db');
    return _database!;
  }

  // Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Create tables
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
          apiResponse TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customerDetails (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id TEXT,
        apiResponse TEXT,
        addressDetails Text,
        shippingDiscounts Text
      )
    ''');

    await db.execute('''
      CREATE TABLE customerFormData (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id TEXT,
        customer_name TEXT,
        apiResponse TEXT,
        addressDetails Text
      )
    ''');

    await db.execute('''
      CREATE TABLE customerProductData (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id TEXT,
        productDetail Text
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        external_order_id TEXT,        
        customer_id TEXT,
        customer_name TEXT,
        po_number TEXT,
        fulfillment_type TEXT,
        no_of_products INTEGER,
        total_tax REAL,
        order_value REAL,
        shipping_amount REAL,
        order_grand_total REAL,
        order_status TEXT,
        shipping_address TEXT,
        order_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT,        
        product_id TEXT,
        product_name TEXT,        
        qty INTEGER,
        trade REAL,
        discount REAL,
        net REAL,
        subtotal REAL,
        tax REAL
      )
    ''');

  }

  Future<bool> isApiResponseExist() async {
    final db = await instance.database;

    final result = await db.query('customers');

    return result.isNotEmpty;
  }

  Future<void> insertOrUpdateApiResponse(Map<String, dynamic> apiData) async {
    final db = await instance.database;

    final result = await db.query('customers');

    if (result.isEmpty) {
      /// Insert first time
      await db.insert(
        'customers',
        {
          'apiResponse': jsonEncode(apiData),
        },
      );
    } else {
      /// Update existing row
      await db.update(
        'customers',
        {
          'apiResponse': jsonEncode(apiData),
        },
      );
    }
  }

  /// Get stored API response
  Future<Map<String, dynamic>?> getApiResponse() async {
    final db = await instance.database;

    final result = await db.query('customers');

    if (result.isNotEmpty) {
      final jsonString = result.first['apiResponse'] as String;
      return jsonDecode(jsonString);
    }

    return null;
  }

  /// Insert a record into any table
  Future<int> insertRecord({
    required String tableName,
    required Map<String, dynamic> values,
  }) async {
    final db = await instance.database;

    // Ensure tableName is provided
    if (tableName.isEmpty || values.isEmpty) {
      throw ArgumentError("Table name and values cannot be empty");
    }

    return await db.insert(
      tableName,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace, // replaces if primary key exists
    );
  }

  /// Update a record in any table
  Future<int> updateRecord({
    required String tableName,
    required Map<String, dynamic> values,
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await instance.database;

    if (tableName.isEmpty || values.isEmpty || where.isEmpty || whereArgs.isEmpty) {
      throw ArgumentError("Table name, values, and where clause cannot be empty");
    }

    return await db.update(
      tableName,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Delete all data from a table (truncate)
  Future<void> truncateTable({required String tableName}) async {
    final db = await instance.database;

    // Make sure tableName is not empty to prevent accidental deletion
    if (tableName.isEmpty) return;

    await db.delete(tableName);
  }

  Future<void> insertMultipleProducts(
      String customerCode, List productsList) async {

    final db = await database;
    Batch batch = db.batch();

    for (var singleProductDetails in productsList) {
      batch.insert(
        "customerProductData",
        {
          "customer_id": customerCode,
          "productDetail": jsonEncode(singleProductDetails),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get records with pagination + where + order by
  Future<List<Map<String, dynamic>>> getRecords({
    required String tableName,
    String? whereCondition,
    List<dynamic>? whereArgs,
    int pageNumber = 1,
    int pageSize = 20,
    String? orderByField,
    String order = "DESC",
  }) async {

    final db = await instance.database;

    if (tableName.isEmpty) {
      throw ArgumentError("Table name cannot be empty");
    }

    /// Pagination offset
    int offset = (pageNumber - 1) * pageSize;

    return await db.query(
      tableName,
      where: whereCondition,
      whereArgs: whereArgs,
      orderBy: orderByField != null ? "$orderByField $order" : null,
      limit: pageSize,
      offset: offset,
    );
  }

  Future<int> getTotalCount({
    required String tableName,
    String? whereCondition,
    List<dynamic>? whereArgs,
  }) async {
    final db = await instance.database;

    var result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM $tableName ${whereCondition != null ? "WHERE $whereCondition" : ""}",
      whereArgs,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteCustomer(String customerId) async {
    final db = await database;

    await db.delete(
      "customerDetails",
      where: "customer_id = ?",
      whereArgs: [customerId],
    );

    await db.delete(
      "customerFormData",
      where: "customer_id = ?",
      whereArgs: [customerId],
    );

    await db.delete(
      "customerProductData",
      where: "customer_id = ?",
      whereArgs: [customerId],
    );
  }

}