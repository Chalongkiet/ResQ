import 'package:geolocator/geolocator.dart';

class MissionArrivalProximity {
  const MissionArrivalProximity._();

  /// ระยะสูงสุดจากพิกัดคำร้องที่อนุญาตให้ยืนยันว่าเดินทางถึงพื้นที่แล้ว
  static const double maximumDistanceMeters = 100;

  static double distanceMeters({
    required double rescueLatitude,
    required double rescueLongitude,
    required double requestLatitude,
    required double requestLongitude,
  }) {
    return Geolocator.distanceBetween(
      rescueLatitude,
      rescueLongitude,
      requestLatitude,
      requestLongitude,
    );
  }

  static bool isWithinRange({
    required double rescueLatitude,
    required double rescueLongitude,
    required double requestLatitude,
    required double requestLongitude,
  }) {
    return distanceMeters(
          rescueLatitude: rescueLatitude,
          rescueLongitude: rescueLongitude,
          requestLatitude: requestLatitude,
          requestLongitude: requestLongitude,
        ) <=
        maximumDistanceMeters;
  }
}
