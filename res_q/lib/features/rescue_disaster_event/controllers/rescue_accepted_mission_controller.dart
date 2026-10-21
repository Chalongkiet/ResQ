import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/live_location_write_budget.dart';
import '../../../core/constants/mission_status.dart';
import '../../../data/models/emergency_request_model.dart';
import '../../../data/models/rescue_mission_monitor_model.dart';
import '../../../data/services/emergency_request_service.dart';
import '../../../data/services/rescue_mission_monitor_service.dart';

class RescueAcceptedMissionController extends ChangeNotifier {
  RescueAcceptedMissionController({
    RescueMissionMonitorService? service,
    EmergencyRequestService? requestService,
    LiveLocationWriteBudget? liveLocationWriteBudget,
    DateTime Function()? clock,
  }) : _service = service ?? RescueMissionMonitorService(),
       _requestService = requestService ?? EmergencyRequestService(),
       _liveLocationWriteBudget =
           liveLocationWriteBudget ?? LiveLocationWriteBudget(),
       _clock = clock ?? DateTime.now;

  final RescueMissionMonitorService _service;
  final EmergencyRequestService _requestService;
  final LiveLocationWriteBudget _liveLocationWriteBudget;
  final DateTime Function() _clock;

  static const Duration minimumLocationPublishInterval = Duration(seconds: 30);
  static const double minimumLocationPublishDistanceMeters = 20;

  StreamSubscription<List<RescueMissionAssignment>>? _subscription;
  StreamSubscription<EmergencyRequest?>? _activeRequestSubscription;
  String? _activeRequestId;
  EmergencyRequest? _latestActiveRequest;

  String? _eventId;
  String? _deploymentId;
  List<RescueMissionAssignment> _assignments =
      const <RescueMissionAssignment>[];
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;
  bool _isPublishingLocation = false;
  double? _lastPublishedLatitude;
  double? _lastPublishedLongitude;
  DateTime? _lastPublishedAt;
  String? _locationMissionId;
  bool _hasLoggedLocationQuotaLimit = false;

  List<RescueMissionAssignment> get assignments =>
      List<RescueMissionAssignment>.unmodifiable(_assignments);

  RescueMissionAssignment? get activeAssignment {
    for (final assignment in _assignments) {
      if (MissionStatus.isActive(assignment.mission.missionStatus)) {
        return assignment;
      }
    }
    return null;
  }

  List<RescueMissionAssignment> get queuedAssignments => _assignments
      .where(
        (assignment) =>
            MissionStatus.isQueued(assignment.mission.missionStatus),
      )
      .toList(growable: false);

  bool get hasActiveMission => activeAssignment != null;
  bool get hasAssignedMissions => _assignments.isNotEmpty;
  bool get canQueueMore => queuedAssignments.length < 2;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void watch({required String eventId, required String deploymentId}) {
    if (_disposed) {
      return;
    }

    final normalizedEventId = eventId.trim();
    final normalizedDeploymentId = deploymentId.trim();

    if (normalizedEventId.isEmpty || normalizedDeploymentId.isEmpty) {
      stopWatching();
      return;
    }

    if (_eventId == normalizedEventId &&
        _deploymentId == normalizedDeploymentId &&
        _subscription != null) {
      return;
    }

    _startWatch(
      eventId: normalizedEventId,
      deploymentId: normalizedDeploymentId,
    );
  }

  void _startWatch({required String eventId, required String deploymentId}) {
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_activeRequestSubscription?.cancel());
    _activeRequestSubscription = null;
    _activeRequestId = null;
    _latestActiveRequest = null;
    _eventId = eventId;
    _deploymentId = deploymentId;
    _assignments = const <RescueMissionAssignment>[];
    _isLoading = true;
    _errorMessage = null;
    _notify();

    _subscription = _service
        .watchAssignmentsForDeployment(deploymentId)
        .listen(
          (assignments) {
            if (_disposed ||
                _eventId != eventId ||
                _deploymentId != deploymentId) {
              return;
            }

            _assignments =
                assignments
                    .where(
                      (assignment) =>
                          assignment.request.disasterEventId == eventId,
                    )
                    .map((assignment) {
                      final latestRequest = _latestActiveRequest;
                      if (latestRequest == null ||
                          latestRequest.requestId !=
                              assignment.request.requestId) {
                        return assignment;
                      }

                      return RescueMissionAssignment(
                        request: latestRequest,
                        mission: assignment.mission,
                      );
                    })
                    .toList(growable: false)
                  ..sort(_compareAssignments);
            _syncActiveRequestWatch();
            _isLoading = false;
            _errorMessage = null;
            _notify();
          },
          onError: (Object error) {
            if (_disposed) {
              return;
            }

            debugPrint('[MISSION MONITOR] stream failed: $error');
            _isLoading = false;
            _errorMessage = 'ไม่สามารถโหลดภารกิจที่รับไว้ได้';
            _subscription = null;
            _notify();
          },
        );
  }

  void retry() {
    final eventId = _eventId;
    final deploymentId = _deploymentId;

    if (_disposed || eventId == null || deploymentId == null) {
      return;
    }

    _startWatch(eventId: eventId, deploymentId: deploymentId);
  }

  void activateMissionLocally(RescueMissionAssignment assignment) {
    if (_disposed) return;

    _assignments = <RescueMissionAssignment>[
      assignment,
      ..._assignments.where(
        (item) => item.mission.missionId != assignment.mission.missionId,
      ),
    ]..sort(_compareAssignments);
    _isLoading = false;
    _errorMessage = null;
    _syncActiveRequestWatch();
    _notify();
  }

  void applyMissionStatusLocally({
    required String missionId,
    required String missionStatus,
  }) {
    if (_disposed) return;

    var changed = false;
    _assignments =
        _assignments
            .map((assignment) {
              if (assignment.mission.missionId != missionId) return assignment;

              changed = true;
              return RescueMissionAssignment(
                request: assignment.request,
                mission: assignment.mission.copyWith(
                  missionStatus: missionStatus,
                  clearQueuePosition: MissionStatus.isActive(missionStatus),
                ),
              );
            })
            .toList(growable: false)
          ..sort(_compareAssignments);

    if (changed) {
      _syncActiveRequestWatch();
      _notify();
    }
  }

  void removeMissionLocally(String missionId) {
    if (_disposed) return;

    final removedWasActive = _assignments.any(
      (assignment) =>
          assignment.mission.missionId == missionId &&
          MissionStatus.isActive(assignment.mission.missionStatus),
    );

    var remaining = _assignments
        .where((assignment) => assignment.mission.missionId != missionId)
        .toList(growable: false);

    if (remaining.length == _assignments.length) return;

    if (removedWasActive &&
        !remaining.any(
          (assignment) =>
              MissionStatus.isActive(assignment.mission.missionStatus),
        )) {
      var promoted = false;
      remaining = remaining
          .map((assignment) {
            if (promoted ||
                !MissionStatus.isQueued(assignment.mission.missionStatus)) {
              return assignment;
            }

            promoted = true;
            return RescueMissionAssignment(
              request: assignment.request,
              mission: assignment.mission.copyWith(
                missionStatus: MissionStatus.onTheWay,
                clearQueuePosition: true,
              ),
            );
          })
          .toList(growable: false);
    }

    var nextQueuePosition = 1;
    remaining = remaining
        .map((assignment) {
          if (!MissionStatus.isQueued(assignment.mission.missionStatus)) {
            return assignment;
          }

          return RescueMissionAssignment(
            request: assignment.request,
            mission: assignment.mission.copyWith(
              queuePosition: nextQueuePosition++,
            ),
          );
        })
        .toList(growable: false);

    _assignments = remaining..sort(_compareAssignments);
    _isLoading = false;
    _errorMessage = null;
    _syncActiveRequestWatch();
    _notify();
  }

  void removeCancelledMissionLocally(String missionId) {
    removeMissionLocally(missionId);
  }

  // ==================================================
  // Active Victim Location
  //
  // collection-group listener ด้านบนเปลี่ยนเมื่อ RescueMission เปลี่ยน แต่
  // parent emergency request เปลี่ยนพิกัดแล้วไม่ทำให้ stream นั้น emit ใหม่
  // จึงต้องฟัง request ที่กำลังปฏิบัติภารกิจแยกต่างหาก
  // ==================================================

  void _syncActiveRequestWatch() {
    if (_disposed) {
      return;
    }

    final requestId = activeAssignment?.request.requestId;

    if (requestId == _activeRequestId && _activeRequestSubscription != null) {
      return;
    }

    unawaited(_activeRequestSubscription?.cancel());
    _activeRequestSubscription = null;
    _activeRequestId = requestId;
    _latestActiveRequest = null;

    if (requestId == null || requestId.isEmpty) {
      return;
    }

    _activeRequestSubscription = _requestService
        .watchById(requestId)
        .listen(
          (request) {
            if (_disposed || request == null || _activeRequestId != requestId) {
              return;
            }

            _latestActiveRequest = request;
            var changed = false;
            _assignments = _assignments
                .map((assignment) {
                  if (assignment.request.requestId != requestId) {
                    return assignment;
                  }

                  changed = true;
                  return RescueMissionAssignment(
                    request: request,
                    mission: assignment.mission,
                  );
                })
                .toList(growable: false);

            if (changed) {
              _notify();
            }
          },
          onError: (Object error) {
            if (_disposed || _activeRequestId != requestId) {
              return;
            }

            debugPrint(
              '[MISSION MONITOR] active request stream failed: $error',
            );
            _activeRequestSubscription = null;
          },
        );
  }

  Future<void> publishCurrentLocation({
    required double latitude,
    required double longitude,
  }) async {
    final eventId = _eventId;
    final deploymentId = _deploymentId;
    final missionId = activeAssignment?.mission.missionId;

    if (_disposed ||
        !hasActiveMission ||
        _isPublishingLocation ||
        eventId == null ||
        deploymentId == null ||
        missionId == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return;
    }

    if (_locationMissionId != missionId) {
      _locationMissionId = missionId;
      _lastPublishedLatitude = null;
      _lastPublishedLongitude = null;
      _lastPublishedAt = null;
      _hasLoggedLocationQuotaLimit = false;
    }

    final previousLatitude = _lastPublishedLatitude;
    final previousLongitude = _lastPublishedLongitude;
    final previousPublishedAt = _lastPublishedAt;
    final now = _clock();

    if (previousPublishedAt != null &&
        now.difference(previousPublishedAt) < minimumLocationPublishInterval) {
      return;
    }

    if (previousLatitude != null && previousLongitude != null) {
      final movedDistance = Geolocator.distanceBetween(
        previousLatitude,
        previousLongitude,
        latitude,
        longitude,
      );

      if (movedDistance < minimumLocationPublishDistanceMeters) {
        return;
      }
    }

    _isPublishingLocation = true;

    try {
      final hasWriteBudget = await _liveLocationWriteBudget.tryReserve(
        deploymentId: deploymentId,
      );

      if (!hasWriteBudget) {
        if (!_hasLoggedLocationQuotaLimit) {
          _hasLoggedLocationQuotaLimit = true;
          debugPrint(
            '[MISSION MONITOR] live-location write budget reached '
            'deployment=$deploymentId',
          );
        }

        return;
      }

      await _service.updateDeploymentLocation(
        disasterEventId: eventId,
        deploymentId: deploymentId,
        latitude: latitude,
        longitude: longitude,
      );
      _lastPublishedLatitude = latitude;
      _lastPublishedLongitude = longitude;
      _lastPublishedAt = now;
    } catch (error) {
      debugPrint('[MISSION MONITOR] location update failed: $error');
    } finally {
      _isPublishingLocation = false;
    }
  }

  void stopWatching() {
    if (_disposed) {
      return;
    }

    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_activeRequestSubscription?.cancel());
    _activeRequestSubscription = null;
    _activeRequestId = null;
    _latestActiveRequest = null;
    _eventId = null;
    _deploymentId = null;
    _assignments = const <RescueMissionAssignment>[];
    _lastPublishedLatitude = null;
    _lastPublishedLongitude = null;
    _lastPublishedAt = null;
    _locationMissionId = null;
    _hasLoggedLocationQuotaLimit = false;
    _isLoading = false;
    _errorMessage = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  static int _compareAssignments(
    RescueMissionAssignment first,
    RescueMissionAssignment second,
  ) {
    final firstActive = MissionStatus.isActive(first.mission.missionStatus);
    final secondActive = MissionStatus.isActive(second.mission.missionStatus);
    if (firstActive != secondActive) return firstActive ? -1 : 1;

    final firstPosition = first.mission.queuePosition ?? 1 << 20;
    final secondPosition = second.mission.queuePosition ?? 1 << 20;
    final positionComparison = firstPosition.compareTo(secondPosition);
    if (positionComparison != 0) return positionComparison;

    final firstDate =
        first.mission.missionAcceptedDate ?? first.mission.missionStartDate;
    final secondDate =
        second.mission.missionAcceptedDate ?? second.mission.missionStartDate;
    if (firstDate == null && secondDate == null) {
      return first.mission.missionId.compareTo(second.mission.missionId);
    }
    if (firstDate == null) return 1;
    if (secondDate == null) return -1;
    return firstDate.compareTo(secondDate);
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    _activeRequestSubscription?.cancel();
    _activeRequestSubscription = null;
    _latestActiveRequest = null;
    super.dispose();
  }
}
