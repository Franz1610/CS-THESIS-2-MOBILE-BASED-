import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handicraft_app/app/my_app.dart';
import 'package:handicraft_app/data/business_database.dart';

void main() {
  testWidgets('records a sale from the business dashboard', (tester) async {
    final repository = _MemoryBusinessRepository();
    await repository.addDetectedStock({'lina_coaster_leaf': 2});
    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Good day'), findsOneWidget);
    await tester.tap(find.text('Sales').last);
    await tester.pumpAndSettle();
    expect(find.text('Sales tracking'), findsOneWidget);

    await tester.tap(find.text('Record sale'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lina coaster leaf (2 in stock)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '12.50');
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();

    expect(repository.sales, hasLength(1));
    expect(repository.sales.single.productName, 'lina_coaster_leaf');
    expect(repository.sales.single.total, 12.5);
    expect(find.text('lina_coaster_leaf'), findsOneWidget);
    expect(repository.inventory['lina_coaster_leaf'], 1);
  });

  testWidgets('adds and edits a permit record', (tester) async {
    final repository = _MemoryBusinessRepository();
    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Records').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add permit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Business permit');
    await tester.enterText(find.byType(TextFormField).at(1), 'BP-100');
    await tester.tap(find.text('Save permit'));
    await tester.pumpAndSettle();

    expect(repository.permits, hasLength(1));
    expect(find.text('Business permit'), findsOneWidget);

    await tester.tap(find.text('Business permit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Renewed permit');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository.permits.single.name, 'Renewed permit');
    expect(find.text('Renewed permit'), findsOneWidget);
  });

  testWidgets('shows the complete inventory catalog', (tester) async {
    await tester.pumpWidget(MyApp(repository: _MemoryBusinessRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();

    expect(find.text('Handicraft products'), findsOneWidget);
    expect(find.text('amara placemat multicolor rings'), findsOneWidget);
    expect(find.text('0 / 10'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('tala coaster multicolor rings'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('tala coaster multicolor rings'), findsOneWidget);
  });

  test('detected stock increments the matching product quantity', () async {
    final repository = _MemoryBusinessRepository();

    await repository.addDetectedStock({
      'ella_placemat_plain': 2,
      'lina_coaster_leaf': 1,
    });

    final stock = await repository.getInventory();
    expect(
      stock
          .singleWhere((item) => item.productName == 'ella_placemat_plain')
          .quantity,
      2,
    );
    expect(
      stock
          .singleWhere((item) => item.productName == 'lina_coaster_leaf')
          .quantity,
      1,
    );

    await repository.addDetectedStock({'ella_placemat_plain': 1});
    final updatedStock = await repository.getInventory();
    expect(
      updatedStock
          .singleWhere((item) => item.productName == 'ella_placemat_plain')
          .quantity,
      3,
    );
  });

  test('deleting a sale restores the sold quantity to inventory', () async {
    final repository = _MemoryBusinessRepository();
    await repository.addDetectedStock({'ella_placemat_plain': 4});
    final saleId = await repository.addSale(
      Sale(
        productName: 'ella_placemat_plain',
        quantity: 2,
        unitPrice: 10,
        soldAt: DateTime(2026, 10, 25),
      ),
    );

    expect(repository.inventory['ella_placemat_plain'], 2);
    await repository.deleteSale(saleId);
    expect(repository.inventory['ella_placemat_plain'], 4);
    expect(repository.sales, isEmpty);
  });

  test('a sale cannot reduce stock below zero', () async {
    final repository = _MemoryBusinessRepository();
    await repository.addDetectedStock({'ella_placemat_plain': 1});

    await expectLater(
      repository.addSale(
        Sale(
          productName: 'ella_placemat_plain',
          quantity: 2,
          unitPrice: 10,
          soldAt: DateTime(2026, 10, 25),
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(repository.inventory['ella_placemat_plain'], 1);
    expect(repository.sales, isEmpty);
  });

  testWidgets('inventory can be adjusted to a corrected quantity', (
    tester,
  ) async {
    final repository = _MemoryBusinessRepository();
    await repository.addDetectedStock({'ella_placemat_plain': 1});
    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    final productCard = find.ancestor(
      of: find.text('ella placemat plain'),
      matching: find.byType(Card),
    );
    await tester.ensureVisible(productCard);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: productCard,
        matching: find.byTooltip('Adjust stock'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '5');
    await tester.tap(find.text('Save quantity'));
    await tester.pumpAndSettle();

    expect(repository.inventory['ella_placemat_plain'], 5);
  });
}

class _MemoryBusinessRepository implements BusinessRepository {
  final List<Sale> sales = [];
  final List<PermitRecord> permits = [];
  final Map<String, int> inventory = {
    for (final product in handicraftProducts) product: 0,
  };
  BusinessProfile profile = BusinessProfile.empty();
  var _nextId = 1;

  @override
  Future<int> addSale(Sale sale) async {
    final stock = inventory[sale.productName];
    if (stock == null || stock < sale.quantity) {
      throw StateError('Not enough stock for ${sale.productName}');
    }
    final id = _nextId++;
    inventory[sale.productName] = stock - sale.quantity;
    sales.add(
      Sale(
        id: id,
        productName: sale.productName,
        quantity: sale.quantity,
        unitPrice: sale.unitPrice,
        soldAt: sale.soldAt,
        notes: sale.notes,
      ),
    );
    return id;
  }

  @override
  Future<int> addPermit(PermitRecord permit) async {
    final id = _nextId++;
    permits.add(
      PermitRecord(
        id: id,
        name: permit.name,
        registrationNumber: permit.registrationNumber,
        issuedOn: permit.issuedOn,
        expiresOn: permit.expiresOn,
        notes: permit.notes,
      ),
    );
    return id;
  }

  @override
  Future<void> updatePermit(PermitRecord permit) async {
    final index = permits.indexWhere((item) => item.id == permit.id);
    if (index < 0) throw StateError('Permit not found');
    permits[index] = permit;
  }

  @override
  Future<void> deletePermit(int id) async {
    permits.removeWhere((permit) => permit.id == id);
  }

  @override
  Future<void> deleteSale(int id) async {
    final saleIndex = sales.indexWhere((sale) => sale.id == id);
    if (saleIndex < 0) return;
    final sale = sales[saleIndex];
    if (inventory.containsKey(sale.productName)) {
      inventory.update(
        sale.productName,
        (quantity) => quantity + sale.quantity,
      );
    }
    sales.removeWhere((sale) => sale.id == id);
  }

  @override
  Future<void> addDetectedStock(Map<String, int> products) async {
    for (final entry in products.entries) {
      if (!inventory.containsKey(entry.key) || entry.value < 1) {
        throw ArgumentError('Invalid detected product');
      }
      inventory.update(entry.key, (quantity) => quantity + entry.value);
    }
  }

  @override
  Future<void> setInventoryQuantity(String productName, int quantity) async {
    if (!inventory.containsKey(productName) || quantity < 0) {
      throw ArgumentError('Invalid inventory adjustment');
    }
    inventory[productName] = quantity;
  }

  @override
  Future<BusinessProfile> getProfile() async => profile;

  @override
  Future<List<PermitRecord>> getPermits() async => List.unmodifiable(permits);

  @override
  Future<List<Sale>> getSales() async => List.unmodifiable(sales);

  @override
  Future<List<InventoryStock>> getInventory() async => [
    for (final entry in inventory.entries)
      InventoryStock(
        productName: entry.key,
        quantity: entry.value,
        updatedAt: null,
      ),
  ];

  @override
  Future<void> saveProfile(BusinessProfile value) async {
    profile = value;
  }
}
