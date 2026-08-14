import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:cotrainr/services/chat_media_storage.dart';
import 'package:cotrainr/services/coach_client_access_service.dart';
import 'package:cotrainr/services/location_permission_status.dart';
import 'package:cotrainr/services/privacy_preferences_service.dart';

void main() {
  group('PrivacyPreferences', () {
    test('activity toggle maps 1:1 to metrics sharing column', () {
      expect(
        const PrivacyPreferences(shareActivityWithTrainer: true)
            .shareMetricsWithTrainer,
        isTrue,
      );
      expect(
        const PrivacyPreferences(shareActivityWithTrainer: false)
            .shareMetricsWithTrainer,
        isFalse,
      );
    });

    test('defaults remain opt-out (true) until a business decision changes them',
        () {
      const prefs = PrivacyPreferences();
      expect(prefs.shareActivityWithTrainer, isTrue);
      expect(prefs.shareMealsWithTrainer, isTrue);
      expect(prefs.shareNutritionWithNutritionist, isTrue);
    });
  });

  group('CoachClientAccessStatus', () {
    test('trainer metrics require accepted lead and metrics flag', () {
      const allowed = CoachClientAccessStatus(
        hasAcceptedLead: true,
        providerType: 'trainer',
        shareMetricsWithTrainer: true,
      );
      expect(allowed.canViewMetrics, isTrue);

      const blocked = CoachClientAccessStatus(
        hasAcceptedLead: true,
        providerType: 'trainer',
        shareMetricsWithTrainer: false,
      );
      expect(blocked.canViewMetrics, isFalse);
    });

    test('nutritionists cannot view metrics even if flag is true', () {
      const status = CoachClientAccessStatus(
        hasAcceptedLead: true,
        providerType: 'nutritionist',
        shareMetricsWithTrainer: true,
        shareNutritionWithNutritionist: true,
      );
      expect(status.canViewMetrics, isFalse);
      expect(status.canViewMeals, isTrue);
    });

    test('trainer meal access follows meals flag', () {
      const allowed = CoachClientAccessStatus(
        hasAcceptedLead: true,
        providerType: 'trainer',
        shareMealsWithTrainer: true,
      );
      expect(allowed.canViewMeals, isTrue);

      const blocked = CoachClientAccessStatus(
        hasAcceptedLead: true,
        providerType: 'trainer',
        shareMealsWithTrainer: false,
      );
      expect(blocked.canViewMeals, isFalse);
    });
  });

  group('LocationAccessLabel', () {
    test('maps OS permission states for UI', () {
      expect(
        mapLocationAccess(
          serviceEnabled: false,
          permission: LocationPermission.whileInUse,
        ),
        LocationAccessLabel.serviceOff,
      );
      expect(
        mapLocationAccess(
          serviceEnabled: true,
          permission: LocationPermission.denied,
        ),
        LocationAccessLabel.notRequested,
      );
      expect(
        mapLocationAccess(
          serviceEnabled: true,
          permission: LocationPermission.deniedForever,
        ),
        LocationAccessLabel.denied,
      );
      expect(
        mapLocationAccess(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
        ),
        LocationAccessLabel.whileUsingApp,
      );
      expect(
        locationAccessLabelText(LocationAccessLabel.whileUsingApp),
        'While using app',
      );
    });
  });

  group('ChatMediaStorage', () {
    test('private refs vs legacy public posts URLs', () {
      final ref = ChatMediaStorage.storedRefForPath(
        'uid/chat/conv/file.jpg',
      );
      expect(ChatMediaStorage.isPrivateRef(ref), isTrue);
      expect(
        ChatMediaStorage.objectPathFromRef(ref),
        'uid/chat/conv/file.jpg',
      );
      expect(
        ChatMediaStorage.isLegacyPublicPostsUrl(
          'https://x.supabase.co/storage/v1/object/public/posts/uid/chat/a.jpg',
        ),
        isTrue,
      );
      expect(
        ChatMediaStorage.isPrivateRef(
          'https://x.supabase.co/storage/v1/object/public/posts/uid/chat/a.jpg',
        ),
        isFalse,
      );
    });
  });
}
