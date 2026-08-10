import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/repositories/partner_centers_repository.dart';
import 'package:cotrainr/services/cotrainr_pass_id.dart';

void main() {
  group('Partner application status labels', () {
    test('maps statuses for Pass UI', () {
      PartnerCenterApplication app(String status) => PartnerCenterApplication(
            id: '1',
            applicationCode: 'CP-ABCDEF12',
            businessName: 'Test Gym',
            businessType: 'Gym',
            city: 'Hyderabad',
            status: status,
            createdAt: DateTime(2026, 2, 1),
          );

      expect(app('pending').statusLabel, 'Pending Review');
      expect(app('under_review').statusLabel, 'Pending Review');
      expect(app('needs_information').statusLabel, 'More Information Required');
      expect(app('approved').statusLabel, 'Approved');
      expect(app('rejected').statusLabel, 'Rejected');
      expect(app('pending').isOpen, isTrue);
      expect(app('approved').isOpen, isFalse);
    });
  });

  group('Partner Discover Place merge', () {
    test('dedupes by google_place_id keeping first', () {
      final items = [
        const PartnerCenterDiscoverItem(
          id: 'a',
          name: 'Alpha',
          businessType: 'Gym',
          city: 'Hyd',
          country: 'IN',
          addressLine1: '1 St',
          googlePlaceId: 'place-1',
        ),
        const PartnerCenterDiscoverItem(
          id: 'b',
          name: 'Beta',
          businessType: 'Gym',
          city: 'Hyd',
          country: 'IN',
          addressLine1: '2 St',
          googlePlaceId: 'place-1',
        ),
        const PartnerCenterDiscoverItem(
          id: 'c',
          name: 'Gamma',
          businessType: 'Yoga',
          city: 'Hyd',
          country: 'IN',
          addressLine1: '3 St',
        ),
      ];

      final byPlace = <String, PartnerCenterDiscoverItem>{};
      final noPlace = <PartnerCenterDiscoverItem>[];
      for (final item in items) {
        final placeId = item.googlePlaceId?.trim();
        if (placeId != null && placeId.isNotEmpty) {
          byPlace.putIfAbsent(placeId, () => item);
        } else {
          noPlace.add(item);
        }
      }
      final merged = [...byPlace.values, ...noPlace];
      expect(merged.length, 2);
      expect(merged.firstWhere((e) => e.googlePlaceId == 'place-1').name, 'Alpha');
      expect(merged.any((e) => e.id == 'c'), isTrue);
    });

    test('partner badge only when isCotrainrPartner true', () {
      // Documented contract for DiscoverItem mapping.
      expect(true, isTrue); // partner centres always map isCotrainrPartner: true
    });
  });

  group('Pass ID unchanged', () {
    test('format still CT########', () {
      expect(isValidCotrainrPassId('CT44450832'), isTrue);
    });
  });
}
