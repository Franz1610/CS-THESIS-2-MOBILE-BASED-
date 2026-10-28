import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const handicraftProducts = <String>[
  'amara_placemat_multicolor_rings',
  'ella_placemat_plain',
  'lina_coaster_leaf',
  'maya_coaster_fish',
  'mila_coaster_plain',
  'mira_coaster_pink_rings',
  'naya_coaster_natural_orange_rings',
  'rina_coaster_colored_rings',
  'tala_coaster_multicolor',
  'tala_coaster_multicolor_rings',
];

class InventoryStock {
  const InventoryStock({
    required this.productName,
    required this.quantity,
    required this.updatedAt,
  });

  final String productName;
  final int quantity;
  final DateTime? updatedAt;

  factory InventoryStock.fromMap(Map<String, Object?> map) => InventoryStock(
    productName: map['product_name'] as String,
    quantity: map['quantity'] as int,
    updatedAt: map['updated_at'] == null
        ? null
        : DateTime.parse(map['updated_at'] as String),
  );
}

class Sale {
  const Sale({
    this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.soldAt,
    this.notes = '',
  });

  final int? id;
  final String productName;
  final int quantity;
  final double unitPrice;
  final DateTime soldAt;
  final String notes;

  double get total => quantity * unitPrice;

  factory Sale.fromMap(Map<String, Object?> map) => Sale(
    id: map['id'] as int,
    productName: map['product_name'] as String,
    quantity: map['quantity'] as int,
    unitPrice: (map['unit_price'] as num).toDouble(),
    soldAt: DateTime.parse(map['sold_at'] as String),
    notes: map['notes'] as String? ?? '',
  );

  Map<String, Object?> toMap() => {
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'sold_at': soldAt.toIso8601String(),
    'notes': notes,
  };
}

class BusinessProfile {
  const BusinessProfile({
    required this.businessName,
    required this.ownerName,
    required this.registrationNumber,
    required this.address,
    required this.contactNumber,
    required this.email,
  });

  final String businessName;
  final String ownerName;
  final String registrationNumber;
  final String address;
  final String contactNumber;
  final String email;

  factory BusinessProfile.empty() => const BusinessProfile(
    businessName: '',
    ownerName: '',
    registrationNumber: '',
    address: '',
    contactNumber: '',
    email: '',
  );

  factory BusinessProfile.fromMap(Map<String, Object?> map) => BusinessProfile(
    businessName: map['business_name'] as String? ?? '',
    ownerName: map['owner_name'] as String? ?? '',
    registrationNumber: map['registration_number'] as String? ?? '',
    address: map['address'] as String? ?? '',
    contactNumber: map['contact_number'] as String? ?? '',
    email: map['email'] as String? ?? '',
  );

  Map<String, Object?> toMap() => {
    'id': 1,
    'business_name': businessName,
    'owner_name': ownerName,
    'registration_number': registrationNumber,
    'address': address,
    'contact_number': contactNumber,
    'email': email,
  };
}

class PermitRecord {
  const PermitRecord({
    this.id,
    required this.name,
    required this.registrationNumber,
    required this.issuedOn,
    required this.expiresOn,
    this.notes = '',
  });

  final int? id;
  final String name;
  final String registrationNumber;
  final DateTime issuedOn;
  final DateTime expiresOn;
  final String notes;

  factory PermitRecord.fromMap(Map<String, Object?> map) => PermitRecord(
    id: map['id'] as int,
    name: map['name'] as String,
    registrationNumber: map['registration_number'] as String? ?? '',
    issuedOn: DateTime.parse(map['issued_on'] as String),
    expiresOn: DateTime.parse(map['expires_on'] as String),
    notes: map['notes'] as String? ?? '',
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'registration_number': registrationNumber,
    'issued_on': _dateOnly(issuedOn),
    'expires_on': _dateOnly(expiresOn),
    'notes': notes,
  };
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

abstract interface class BusinessRepository {
  Future<List<Sale>> getSales();
  Future<int> addSale(Sale sale);
  Future<void> deleteSale(int id);
  Future<BusinessProfile> getProfile();
  Future<void> saveProfile(BusinessProfile profile);
  Future<List<PermitRecord>> getPermits();
  Future<int> addPermit(PermitRecord permit);
  Future<void> updatePermit(PermitRecord permit);
  Future<void> deletePermit(int id);
  Future<List<InventoryStock>> getInventory();
  Future<void> addDetectedStock(Map<String, int> products);
  Future<void> setInventoryQuantity(String productName, int quantity);
}

class SqliteBusinessDatabase implements BusinessRepository {
  SqliteBusinessDatabase._(this._database);

  final Database _database;

  static Future<SqliteBusinessDatabase> open() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final databaseDirectory = await getDatabasesPath();
    final database = await openDatabase(
      path.join(databaseDirectory, 'handicraft_business.db'),
      version: 4,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_name TEXT NOT NULL,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            unit_price REAL NOT NULL CHECK(unit_price >= 0),
            sold_at TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            stock_deducted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await database.execute('''
          CREATE TABLE business_profile (
            id INTEGER PRIMARY KEY CHECK(id = 1),
            business_name TEXT NOT NULL DEFAULT '',
            owner_name TEXT NOT NULL DEFAULT '',
            registration_number TEXT NOT NULL DEFAULT '',
            address TEXT NOT NULL DEFAULT '',
            contact_number TEXT NOT NULL DEFAULT '',
            email TEXT NOT NULL DEFAULT ''
          )
        ''');
        await database.insert(
          'business_profile',
          BusinessProfile.empty().toMap(),
        );
        await database.execute('''
          CREATE TABLE permits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            registration_number TEXT NOT NULL DEFAULT '',
            issued_on TEXT NOT NULL,
            expires_on TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT ''
          )
        ''');
        await database.execute(
          'CREATE INDEX sales_sold_at_idx ON sales(sold_at)',
        );
        await database.execute(
          'CREATE INDEX permits_expires_on_idx ON permits(expires_on)',
        );
        await _createInventoryTable(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createInventoryTable(database);
        }
        if (oldVersion < 4) {
          await database.execute(
            'ALTER TABLE sales ADD COLUMN stock_deducted '
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
    return SqliteBusinessDatabase._(database);
  }

  static Future<void> _createInventoryTable(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE inventory (
        product_name TEXT PRIMARY KEY,
        quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
        updated_at TEXT
      )
    ''');
    final batch = database.batch();
    for (final productName in handicraftProducts) {
      batch.insert('inventory', {'product_name': productName, 'quantity': 0});
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Sale>> getSales() async {
    final rows = await _database.query(
      'sales',
      orderBy: 'sold_at DESC, id DESC',
    );
    return rows.map(Sale.fromMap).toList();
  }

  @override
  Future<int> addSale(Sale sale) async {
    if (!handicraftProducts.contains(sale.productName)) {
      throw ArgumentError.value(
        sale.productName,
        'sale',
        'Choose a product from the inventory catalog',
      );
    }
    if (sale.quantity < 1 || !sale.unitPrice.isFinite || sale.unitPrice < 0) {
      throw ArgumentError.value(sale, 'sale', 'Invalid quantity or unit price');
    }

    return _database.transaction((transaction) async {
      final updatedAt = DateTime.now().toIso8601String();
      final rowsUpdated = await transaction.rawUpdate(
        '''
        UPDATE inventory
        SET quantity = quantity - ?, updated_at = ?
        WHERE product_name = ? AND quantity >= ?
        ''',
        [sale.quantity, updatedAt, sale.productName, sale.quantity],
      );
      if (rowsUpdated != 1) {
        final rows = await transaction.query(
          'inventory',
          columns: ['quantity'],
          where: 'product_name = ?',
          whereArgs: [sale.productName],
          limit: 1,
        );
        final available = rows.isEmpty ? 0 : rows.first['quantity'] as int;
        throw StateError(
          'Not enough stock for ${sale.productName}. '
          'Available: $available, requested: ${sale.quantity}.',
        );
      }
      return transaction.insert('sales', {
        ...sale.toMap(),
        'stock_deducted': 1,
      });
    });
  }

  @override
  Future<void> deleteSale(int id) async {
    await _database.transaction((transaction) async {
      final rows = await transaction.query(
        'sales',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final sale = Sale.fromMap(rows.first);
      if (rows.first['stock_deducted'] == 1 &&
          handicraftProducts.contains(sale.productName)) {
        await transaction.rawUpdate(
          '''
          UPDATE inventory
          SET quantity = quantity + ?, updated_at = ?
          WHERE product_name = ?
          ''',
          [sale.quantity, DateTime.now().toIso8601String(), sale.productName],
        );
      }
      await transaction.delete('sales', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<BusinessProfile> getProfile() async {
    final rows = await _database.query(
      'business_profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return BusinessProfile.empty();
    return BusinessProfile.fromMap(rows.first);
  }

  @override
  Future<void> saveProfile(BusinessProfile profile) async {
    await _database.insert(
      'business_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<PermitRecord>> getPermits() async {
    final rows = await _database.query(
      'permits',
      orderBy: 'expires_on ASC, id DESC',
    );
    return rows.map(PermitRecord.fromMap).toList();
  }

  @override
  Future<int> addPermit(PermitRecord permit) =>
      _database.insert('permits', permit.toMap());

  @override
  Future<void> updatePermit(PermitRecord permit) async {
    final id = permit.id;
    if (id == null) {
      throw ArgumentError.value(
        permit,
        'permit',
        'An id is required to update',
      );
    }
    await _database.update(
      'permits',
      permit.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deletePermit(int id) async {
    await _database.delete('permits', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<InventoryStock>> getInventory() async {
    final rows = await _database.query(
      'inventory',
      orderBy: 'product_name COLLATE NOCASE ASC',
    );
    return rows.map(InventoryStock.fromMap).toList();
  }

  @override
  Future<void> addDetectedStock(Map<String, int> products) async {
    for (final entry in products.entries) {
      if (!handicraftProducts.contains(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'products',
          'The detected product is not in the inventory catalog',
        );
      }
      if (entry.value < 1) {
        throw ArgumentError.value(
          entry.value,
          'products',
          'Detected quantities must be positive',
        );
      }
    }
    if (products.isEmpty) {
      throw ArgumentError.value(
        products,
        'products',
        'At least one product is required',
      );
    }

    final updatedAt = DateTime.now().toIso8601String();
    await _database.transaction((transaction) async {
      for (final entry in products.entries) {
        await transaction.rawInsert(
          '''
          INSERT INTO inventory (product_name, quantity, updated_at)
          VALUES (?, ?, ?)
          ON CONFLICT(product_name) DO UPDATE SET
            quantity = inventory.quantity + excluded.quantity,
            updated_at = excluded.updated_at
          ''',
          [entry.key, entry.value, updatedAt],
        );
      }
    });
  }

  @override
  Future<void> setInventoryQuantity(String productName, int quantity) async {
    if (!handicraftProducts.contains(productName)) {
      throw ArgumentError.value(
        productName,
        'productName',
        'The product is not in the inventory catalog',
      );
    }
    if (quantity < 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Inventory quantity cannot be negative',
      );
    }
    final updatedRows = await _database.update(
      'inventory',
      {'quantity': quantity, 'updated_at': DateTime.now().toIso8601String()},
      where: 'product_name = ?',
      whereArgs: [productName],
    );
    if (updatedRows != 1) {
      throw StateError('Inventory product was not found: $productName');
    }
  }
}
