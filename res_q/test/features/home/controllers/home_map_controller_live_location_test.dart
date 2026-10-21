import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:res_q/core/cache/disaster_cache_service.dart';
import 'package:res_q/core/connectivity/connectivity_service.dart';
import 'package:res_q/core/connectivity/connectivity_status.dart';
import 'package:res_q/core/location/location_result.dart';
import 'package:res_q/core/location/location_service.dart';
import 'package:res_q/data/models/disaster_boundary_point.dart';
import 'package:res_q/data/models/disaster_event_model.dart';
import 'package:res_q/data/services/disaster_event_service.dart';
import 'package:res_q/features/home/controllers/home_map_controller.dart';

void main() {
  final event = _eventWithManyBoundaryPoints();
  final inside = _position(19.1083, 100.946705);
  final outside = _position(19.18, 100.946705);

  test('live GPS recalculates entry and exit for a large boundary', () async {
    final controller = _controller(event: event, initialPosition: outside);
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.userIsInsideDisaster, isFalse);

    controller.applyLivePosition(inside);
    expect(controller.userIsInsideDisaster, isTrue);
    expect(controller.visibleDistanceResults.single.distanceMeters, 0);

    controller.applyLivePosition(outside);
    expect(controller.userIsInsideDisaster, isFalse);
    expect(
      controller.visibleDistanceResults.single.distanceMeters,
      greaterThan(0),
    );
  });

  test('resume rechecks GPS even without visiting Settings', () async {
    final controller = _controller(
      event: event,
      initialPosition: outside,
      resumedPosition: inside,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.userIsInsideDisaster, isFalse);

    await controller.onAppResumed();
    expect(controller.userIsInsideDisaster, isTrue);
    expect(controller.userPosition?.latitude, inside.latitude);
  });
}

HomeMapController _controller({
  required DisasterEvent event,
  required Position initialPosition,
  Position? resumedPosition,
}) {
  return HomeMapController(
    locationService: _TestLocationService(
      initialPosition: initialPosition,
      resumedPosition: resumedPosition ?? initialPosition,
    ),
    connectivityService: _OfflineConnectivityService(),
    disasterEventService: DisasterEventService(firestore: _UnusedFirestore()),
    cacheService: _EventCache(event),
  );
}

DisasterEvent _eventWithManyBoundaryPoints() {
  const centerLatitude = 19.1083;
  const centerLongitude = 100.946705;
  const vertexCount = 6140;

  final boundary = List<DisasterBoundaryPoint>.generate(vertexCount, (index) {
    final angle = 2 * math.pi * index / vertexCount;
    return DisasterBoundaryPoint(
      latitude: centerLatitude + 0.05 * math.sin(angle),
      longitude: centerLongitude + 0.05 * math.cos(angle),
    );
  });

  return DisasterEvent(
    id: 'large-event',
    eventName: 'พื้นที่ทดสอบ',
    disasterType: 'อุทกภัย',
    areaDescription: 'พื้นที่ทดสอบ',
    eventDetail: '',
    eventStartDate: DateTime(2026, 9, 17),
    eventEndDate: null,
    eventStatus: true,
    disasterBoundary: [...boundary, boundary.first],
    createdAt: DateTime(2026, 9, 17),
    updatedAt: DateTime(2026, 9, 17),
  );
}

Position _position(double latitude, double longitude) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 9, 17),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _TestLocationService extends LocationService {
  _TestLocationService({
    required this.initialPosition,
    required this.resumedPosition,
  });

  final Position initialPosition;
  final Position resumedPosition;

  @override
  Future<LocationResult> getInitialLocation() async =>
      LocationResult.success(initialPosition);

  @override
  Future<LocationResult> recheckLocation() async =>
      LocationResult.success(resumedPosition);
}

class _OfflineConnectivityService extends ConnectivityService {
  @override
  Future<AppConnectivityStatus> checkStatus() async =>
      AppConnectivityStatus.offline;

  @override
  Stream<AppConnectivityStatus> watchStatus() => const Stream.empty();
}

class _EventCache extends DisasterCacheService {
  _EventCache(this.event) : super(preferences: _UnusedSharedPreferencesAsync());

  final DisasterEvent event;

  @override
  Future<List<DisasterEvent>> loadEvents() async => [event];

  @override
  Future<DateTime?> getLastUpdatedAt() async => null;
}

class _UnusedFirestore extends Fake implements FirebaseFirestore {}

class _UnusedSharedPreferencesAsync extends Fake
    implements SharedPreferencesAsync {}
