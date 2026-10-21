import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/features/rescue_disaster_event/services/mission_arrival_proximity.dart';

void main() {
  group('MissionArrivalProximity', () {
    test('allows arrival at the request location', () {
      expect(
        MissionArrivalProximity.isWithinRange(
          rescueLatitude: 18.7883,
          rescueLongitude: 98.9853,
          requestLatitude: 18.7883,
          requestLongitude: 98.9853,
        ),
        isTrue,
      );
    });

    test('allows arrival within 100 meters', () {
      final distanceMeters = MissionArrivalProximity.distanceMeters(
        rescueLatitude: 18.7883,
        rescueLongitude: 98.9853,
        requestLatitude: 18.78875,
        requestLongitude: 98.9853,
      );

      expect(distanceMeters, lessThanOrEqualTo(100));
      expect(
        MissionArrivalProximity.isWithinRange(
          rescueLatitude: 18.7883,
          rescueLongitude: 98.9853,
          requestLatitude: 18.78875,
          requestLongitude: 98.9853,
        ),
        isTrue,
      );
    });

    test('blocks arrival beyond 100 meters', () {
      final distanceMeters = MissionArrivalProximity.distanceMeters(
        rescueLatitude: 18.7883,
        rescueLongitude: 98.9853,
        requestLatitude: 18.7901,
        requestLongitude: 98.9853,
      );

      expect(distanceMeters, greaterThan(100));
      expect(
        MissionArrivalProximity.isWithinRange(
          rescueLatitude: 18.7883,
          rescueLongitude: 98.9853,
          requestLatitude: 18.7901,
          requestLongitude: 98.9853,
        ),
        isFalse,
      );
    });
  });
}
