import 'package:flutter_test/flutter_test.dart';
import 'package:handicraft_app/data/business_database.dart';

void main() {
  test('sale total is calculated from quantity and unit price', () {
    final sale = Sale(
      productName: 'Handwoven placemat',
      quantity: 3,
      unitPrice: 125.5,
      soldAt: DateTime(2026, 10, 25),
    );

    expect(sale.total, 376.5);
  });

  test('permit dates are stored as calendar dates', () {
    final permit = PermitRecord(
      name: 'Business permit',
      registrationNumber: 'BP-001',
      issuedOn: DateTime(2026, 1, 2, 14),
      expiresOn: DateTime(2027, 1, 2, 9),
    );

    expect(permit.toMap()['issued_on'], '2026-01-02');
    expect(permit.toMap()['expires_on'], '2027-01-02');
  });

  test('business profile round trips through its database map', () {
    const profile = BusinessProfile(
      businessName: 'Handmade Studio',
      ownerName: 'Taylor',
      registrationNumber: 'REG-42',
      address: 'Market Street',
      contactNumber: '555-0100',
      email: 'hello@example.com',
    );

    expect(
      BusinessProfile.fromMap(profile.toMap()).businessName,
      profile.businessName,
    );
    expect(
      BusinessProfile.fromMap(profile.toMap()).registrationNumber,
      profile.registrationNumber,
    );
  });

  test('inventory catalog matches the trained product labels', () {
    expect(handicraftProducts, [
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
    ]);
  });
}
