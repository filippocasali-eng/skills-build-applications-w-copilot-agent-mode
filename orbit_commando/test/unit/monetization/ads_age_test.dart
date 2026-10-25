import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:orbit_commando/core/ads/google_ads.dart';
import 'package:orbit_commando/core/monetization/catalog.dart';

void main() {
  test('ad treatment follows US (COPPA) age rules', () {
    expect(treatmentFor(9), AgeRestrictedTreatment.child);
    expect(treatmentFor(12), AgeRestrictedTreatment.child);
    expect(treatmentFor(13), AgeRestrictedTreatment.teen);
    expect(treatmentFor(17), AgeRestrictedTreatment.teen);
    expect(treatmentFor(0), AgeRestrictedTreatment.teen); // not answered
    expect(treatmentFor(18), AgeRestrictedTreatment.unspecified);
  });

  test('prices show in dollars, euros only in the eurozone', () {
    Catalog.setCountry('US');
    expect(Catalog.money(499), r'$4.99');
    Catalog.setCountry(null);
    expect(Catalog.money(1999), r'$19.99');
    Catalog.setCountry('IT');
    expect(Catalog.money(499), '€4,99');
    Catalog.setCountry('US');
  });
}
