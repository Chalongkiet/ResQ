import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:res_q/core/auth/citizen_identity_service.dart';
import 'package:res_q/core/constants/emergency_request_status.dart';
import 'package:res_q/core/constants/mission_status.dart';
import 'package:res_q/core/location/live_location_write_budget.dart';
import 'package:res_q/core/location/location_service.dart';
import 'package:res_q/data/models/emergency_request_model.dart';
import 'package:res_q/data/models/rescue_mission_model.dart';
import 'package:res_q/data/models/rescue_mission_monitor_model.dart';
import 'package:res_q/data/services/emergency_request_service.dart';
import 'package:res_q/data/services/rescue_mission_monitor_service.dart';
import 'package:res_q/features/emergency_tracking/controllers/emergency_tracking_controller.dart';
import 'package:res_q/features/rescue_disaster_event/controllers/rescue_accepted_mission_controller.dart';

void main() {
  test(
    'victim marker updates immediately while Firestore writes stay throttled',
    () async {
      final requestService = _FakeEmergencyRequestService();
      final locationService = _FakeLocationService();
      var now = DateTime(2026, 10, 14, 10);
      final controller = EmergencyTrackingController(
        requestId: 'request-1',
        requestService: requestService,
        identityService: _FakeIdentityService(),
        missionMonitorService: _FakeMissionMonitorService(),
        locationService: locationService,
        liveLocationWriteBudget: LiveLocationWriteBudget(
          store: _MemoryBudgetStore(),
          maximumWritesPerWindow: 10,
        ),
        clock: () => now,
      );

      addTearDown(controller.dispose);
      addTearDown(requestService.dispose);
      addTearDown(locationService.dispose);

      await controller.initialize();
      requestService.emit(
        _request(
          latitude: 19,
          longitude: 100,
          status: EmergencyRequestStatus.waiting,
        ),
      );
      await _flushEvents();

      locationService.emit(_position(19.001, 100.001));
      await _flushEvents();

      expect(controller.victimLatitude, 19.001);
      expect(controller.victimLongitude, 100.001);
      expect(requestService.locationWrites, hasLength(1));

      locationService.emit(_position(19.002, 100.002));
      await _flushEvents();

      expect(controller.victimLatitude, 19.002);
      expect(requestService.locationWrites, hasLength(1));

      now = now.add(const Duration(seconds: 31));
      locationService.emit(_position(19.003, 100.003));
      await _flushEvents();

      expect(requestService.locationWrites, hasLength(2));
    },
  );

  test(
    'rescue active mission receives victim request location updates',
    () async {
      final requestService = _FakeEmergencyRequestService();
      final missionService = _FakeMissionMonitorService();
      final controller = RescueAcceptedMissionController(
        service: missionService,
        requestService: requestService,
        liveLocationWriteBudget: LiveLocationWriteBudget(
          store: _MemoryBudgetStore(),
          maximumWritesPerWindow: 10,
        ),
      );

      addTearDown(controller.dispose);
      addTearDown(requestService.dispose);
      addTearDown(missionService.dispose);

      controller.watch(eventId: 'event-1', deploymentId: 'deployment-1');
      final initialAssignment = RescueMissionAssignment(
        request: _request(latitude: 19, longitude: 100),
        mission: const RescueMission(
          missionId: 'mission-1',
          missionName: 'mission',
          missionStatus: MissionStatus.onTheWay,
          deploymentId: 'deployment-1',
        ),
      );
      missionService.emitAssignments([initialAssignment]);
      await _flushEvents();

      requestService.emit(_request(latitude: 19.004, longitude: 100.004));
      await _flushEvents();

      expect(controller.activeAssignment?.request.latitude, 19.004);
      expect(controller.activeAssignment?.request.longitude, 100.004);

      missionService.emitAssignments([initialAssignment]);
      await _flushEvents();

      expect(controller.activeAssignment?.request.latitude, 19.004);
    },
  );
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

EmergencyRequest _request({
  required double latitude,
  required double longitude,
  String status = EmergencyRequestStatus.accepted,
}) {
  return EmergencyRequest(
    requestId: 'request-1',
    userId: 'citizen-1',
    disasterEventId: 'event-1',
    requestType: 'อุทกภัย',
    latitude: latitude,
    longitude: longitude,
    requestDetail: 'รอความช่วยเหลือ',
    requestStatus: status,
    safeStatus: false,
  );
}

Position _position(double latitude, double longitude) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 10, 14),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _FakeLocationService extends LocationService {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  @override
  Stream<Position> watchLiveLocation() => _controller.stream;

  void emit(Position position) => _controller.add(position);

  Future<void> dispose() => _controller.close();
}

class _FakeEmergencyRequestService extends EmergencyRequestService {
  _FakeEmergencyRequestService()
    : super(
        firestore: _UnusedFirestore(),
        identityService: _FakeIdentityService(),
      );

  final StreamController<EmergencyRequest?> _controller =
      StreamController<EmergencyRequest?>.broadcast();
  final List<(double, double)> locationWrites = <(double, double)>[];

  @override
  Stream<EmergencyRequest?> watchById(String requestId) => _controller.stream;

  @override
  Future<void> updateLiveLocation({
    required String requestId,
    required double latitude,
    required double longitude,
  }) async {
    locationWrites.add((latitude, longitude));
  }

  void emit(EmergencyRequest request) => _controller.add(request);

  Future<void> dispose() => _controller.close();
}

class _FakeMissionMonitorService extends RescueMissionMonitorService {
  _FakeMissionMonitorService() : super(firestore: _UnusedFirestore());

  final StreamController<List<RescueMissionAssignment>> _controller =
      StreamController<List<RescueMissionAssignment>>.broadcast();

  @override
  Stream<List<RescueMissionAssignment>> watchAssignmentsForDeployment(
    String deploymentId,
  ) => _controller.stream;

  void emitAssignments(List<RescueMissionAssignment> assignments) {
    _controller.add(assignments);
  }

  Future<void> dispose() => _controller.close();
}

class _FakeIdentityService extends CitizenIdentityService {
  _FakeIdentityService() : super(auth: _UnusedFirebaseAuth());

  @override
  Future<User> ensureIdentity() async => _FakeUser();
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'citizen-1';
}

class _MemoryBudgetStore implements LiveLocationBudgetStore {
  final Map<String, int> values = <String, int>{};

  @override
  Future<int?> getInt(String key) async => values[key];

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }
}

class _UnusedFirestore extends Fake implements FirebaseFirestore {}

class _UnusedFirebaseAuth extends Fake implements FirebaseAuth {}
