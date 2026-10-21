import 'package:geolocator/geolocator.dart';

import 'exceptions/rescue_location_exception.dart';

class RescueLocationService {
  const RescueLocationService();

  Future<Position> getCurrentPosition() async {
    // ==================================================
    // Location service
    // ==================================================

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const RescueLocationServiceDisabledException();
    }

    // ==================================================
    // Permission
    // ==================================================

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const RescueLocationPermissionDeniedException();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const RescueLocationPermissionDeniedForeverException();
    }

    // ==================================================
    // Current GPS
    // ==================================================

    const settings = LocationSettings(accuracy: LocationAccuracy.high);

    return Geolocator.getCurrentPosition(locationSettings: settings);
  }
}
