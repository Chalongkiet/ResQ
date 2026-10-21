import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_result.dart';

class LocationService {
  const LocationService();

  static const Duration _locationTimeout = Duration(seconds: 8);

  Future<LocationResult> getInitialLocation() async {
    return _getCurrentLocation(requestPermissionIfNeeded: true);
  }

  Future<LocationResult> refreshLocation() async {
    return _getCurrentLocation(requestPermissionIfNeeded: true);
  }

  Future<LocationResult> recheckLocation() async {
    return _getCurrentLocation(requestPermissionIfNeeded: false);
  }

  Stream<Position> watchLiveLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    );
  }

  Future<LocationResult> _getCurrentLocation({
    required bool requestPermissionIfNeeded,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return LocationResult.serviceDisabled();
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        if (!requestPermissionIfNeeded) {
          return LocationResult.permissionDenied();
        }

        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return LocationResult.permissionDenied();
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.permissionDeniedForever();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _locationTimeout,
        ),
      );

      return LocationResult.success(position);
    } on TimeoutException {
      return LocationResult.timeout();
    } catch (error, stackTrace) {
      debugPrint('LocationService error: $error');

      debugPrintStack(stackTrace: stackTrace);

      return LocationResult.error();
    }
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
