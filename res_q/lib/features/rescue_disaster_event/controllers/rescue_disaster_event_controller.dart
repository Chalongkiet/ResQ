import 'package:flutter/foundation.dart';

import '../../../core/auth/rescue_session_storage.dart';
import '../../home/controllers/home_map_controller.dart';
import '../models/rescue_deployment.dart';
import '../services/join_disaster_event_service.dart';
import '../../../data/models/disaster_event_model.dart';

class RescueDisasterEventController extends ChangeNotifier {
  RescueDisasterEventController({
    HomeMapController? mapController,
    RescueSessionStorage? sessionStorage,
    JoinDisasterEventService? joinService,
  }) : _mapController = mapController ?? HomeMapController(),
       _sessionStorage = sessionStorage ?? RescueSessionStorage(),
       _joinService = joinService ?? JoinDisasterEventService();

  final HomeMapController _mapController;

  final RescueSessionStorage _sessionStorage;

  final JoinDisasterEventService _joinService;

  // ==================================================
  // Session
  // ==================================================

  String? _rescueTeamId;

  bool _isSessionLoading = true;

  // ==================================================
  // Deployment
  //
  // eventId -> ACTIVE Deployment
  // ==================================================

  final Map<String, RescueDeployment> _activeDeploymentsByEventId = {};

  // ==================================================
  // Join Status
  // ==================================================

  final Set<String> _checkedJoinEventIds = {};

  final Set<String> _checkingJoinEventIds = {};

  // ป้องกัน sync ซ้อนกันหลายชุด
  bool _isSyncingJoinStatuses = false;

  bool _disposed = false;

  // ==================================================
  // Getters
  // ==================================================

  HomeMapController get mapController => _mapController;

  String? get rescueTeamId => _rescueTeamId;

  bool get isSessionLoading => _isSessionLoading;

  bool get hasRescueTeamId {
    final id = _rescueTeamId?.trim();

    return id != null && id.isNotEmpty;
  }

  // ==================================================
  // Initialize
  // ==================================================

  Future<void> initialize() async {
    _mapController.addListener(_handleMapControllerChanged);

    _mapController.initialize();

    await _loadSession();
  }

  // ==================================================
  // Session
  // ==================================================

  Future<void> _loadSession() async {
    debugPrint('[RESCUE EVENT] loading session...');

    try {
      final session = await _sessionStorage.load();

      if (_disposed) {
        return;
      }

      final teamId = session?.rescueTeamId?.trim();

      debugPrint(
        '[RESCUE EVENT] session account='
        '${session?.accountId}',
      );

      debugPrint(
        '[RESCUE EVENT] session username='
        '${session?.username}',
      );

      debugPrint(
        '[RESCUE EVENT] session teamId='
        '$teamId',
      );

      if (teamId != null && teamId.isNotEmpty) {
        _rescueTeamId = teamId;
      } else {
        _rescueTeamId = null;
      }
    } catch (error, stackTrace) {
      debugPrint('[RESCUE EVENT] load session ERROR');

      debugPrint('[RESCUE EVENT] $error');

      debugPrint('[RESCUE EVENT] $stackTrace');

      _rescueTeamId = null;
    } finally {
      if (!_disposed) {
        _isSessionLoading = false;

        notifyListeners();
      }
    }

    await syncJoinStatuses();
  }

  // ==================================================
  // Map Listener
  // ==================================================

  void _handleMapControllerChanged() {
    if (_disposed) {
      return;
    }

    notifyListeners();

    // Event อาจโหลดเข้ามาหลัง Session
    //
    // syncJoinStatuses มี guard ป้องกัน
    // การ query ซ้อนอยู่แล้ว
    Future.microtask(syncJoinStatuses);
  }

  // ==================================================
  // App Resumed
  // ==================================================

  void onAppResumed() {
    _mapController.onAppResumed();

    Future.microtask(refreshJoinStatuses);
  }

  // ==================================================
  // Refresh Join Status
  // ==================================================

  Future<void> refreshJoinStatuses() async {
    if (_disposed || !hasRescueTeamId) {
      return;
    }

    debugPrint('[JOIN STATUS] force refresh');

    _checkedJoinEventIds.clear();

    await syncJoinStatuses();
  }

  // ==================================================
  // Sync Join Status
  // ==================================================

  Future<void> syncJoinStatuses() async {
    if (_disposed) {
      return;
    }

    // ป้องกัน sync หลายรอบซ้อนกัน
    if (_isSyncingJoinStatuses) {
      return;
    }

    final teamId = _rescueTeamId?.trim();

    if (teamId == null || teamId.isEmpty) {
      return;
    }

    final visibleEvents = _mapController.visibleEvents;

    if (visibleEvents.isEmpty) {
      return;
    }

    final eventsToCheck = visibleEvents.where((event) {
      final checked = _checkedJoinEventIds.contains(event.id);

      final checking = _checkingJoinEventIds.contains(event.id);

      return !checked && !checking;
    }).toList();

    if (eventsToCheck.isEmpty) {
      return;
    }

    _isSyncingJoinStatuses = true;

    debugPrint(
      '[JOIN STATUS] syncing '
      '${eventsToCheck.length} events',
    );

    for (final event in eventsToCheck) {
      _checkingJoinEventIds.add(event.id);
    }

    _safeNotifyListeners();

    try {
      // ==================================================
      // Query พร้อมกัน
      //
      // ถ้ามี 4 Events ไม่ต้องรอ
      // Event 1 -> 2 -> 3 -> 4 ทีละตัว
      // ==================================================

      final futures = eventsToCheck.map((event) async {
        debugPrint(
          '[JOIN STATUS] checking '
          'event=${event.id}',
        );

        try {
          final deployment = await _joinService.getActiveDeployment(
            eventId: event.id,
            rescueTeamId: teamId,
          );

          return _JoinStatusResult(eventId: event.id, deployment: deployment);
        } catch (error, stackTrace) {
          debugPrint(
            '[JOIN STATUS] ERROR '
            'event=${event.id}',
          );

          debugPrint('[JOIN STATUS] $error');

          debugPrint('[JOIN STATUS] $stackTrace');

          return _JoinStatusResult(eventId: event.id, error: error);
        }
      });

      final results = await Future.wait(futures);

      if (_disposed) {
        return;
      }

      for (final result in results) {
        _checkingJoinEventIds.remove(result.eventId);

        // สำคัญ:
        //
        // แม้ query background จะ error
        // ให้ mark ว่าตรวจแล้วในรอบนี้
        //
        // ไม่อย่างนั้น Map notify ครั้งต่อไป
        // จะยิง query ซ้ำไม่หยุด
        _checkedJoinEventIds.add(result.eventId);

        if (result.error != null) {
          continue;
        }

        final deployment = result.deployment;

        if (deployment != null) {
          debugPrint(
            '[JOIN STATUS] ACTIVE '
            'event=${result.eventId} '
            'deployment='
            '${deployment.deploymentId}',
          );

          _activeDeploymentsByEventId[result.eventId] = deployment;
        } else {
          debugPrint(
            '[JOIN STATUS] NOT JOINED '
            'event=${result.eventId}',
          );

          _activeDeploymentsByEventId.remove(result.eventId);
        }
      }
    } finally {
      // Safety
      for (final event in eventsToCheck) {
        _checkingJoinEventIds.remove(event.id);
      }

      _isSyncingJoinStatuses = false;

      _safeNotifyListeners();

      debugPrint('[JOIN STATUS] sync finished');
    }
  }

  // ==================================================
  // Active Deployment
  // ==================================================

  RescueDeployment? activeDeploymentForEvent(String eventId) {
    return _activeDeploymentsByEventId[eventId];
  }

  bool isJoinedEvent(String eventId) {
    return _activeDeploymentsByEventId.containsKey(eventId);
  }

  bool isCheckingJoinEvent(String eventId) {
    return _checkingJoinEventIds.contains(eventId);
  }

  // ==================================================
  // Check Before Join
  //
  // สำคัญ:
  // ไม่ใช้ cache อย่างเดียว
  // กด Join จะตรวจ Firestore สดอีกครั้ง
  // ==================================================

  Future<RescueDeployment?> checkActiveDeploymentBeforeJoin({
    required String eventId,
  }) async {
    final normalizedEventId = eventId.trim();

    final teamId = _rescueTeamId?.trim();

    debugPrint('[JOIN CHECK] start');

    debugPrint(
      '[JOIN CHECK] event='
      '$normalizedEventId',
    );

    debugPrint('[JOIN CHECK] team=$teamId');

    if (_disposed) {
      return null;
    }

    if (normalizedEventId.isEmpty || teamId == null || teamId.isEmpty) {
      debugPrint('[JOIN CHECK] invalid IDs');

      return null;
    }

    _checkingJoinEventIds.add(normalizedEventId);

    _safeNotifyListeners();

    try {
      final deployment = await _joinService.getActiveDeployment(
        eventId: normalizedEventId,
        rescueTeamId: teamId,
      );

      if (_disposed) {
        return deployment;
      }

      if (deployment != null) {
        _activeDeploymentsByEventId[normalizedEventId] = deployment;

        debugPrint(
          '[JOIN CHECK] already joined '
          '${deployment.deploymentId}',
        );
      } else {
        _activeDeploymentsByEventId.remove(normalizedEventId);

        debugPrint('[JOIN CHECK] no deployment');
      }

      _checkedJoinEventIds.add(normalizedEventId);

      return deployment;
    } catch (error, stackTrace) {
      debugPrint('[JOIN CHECK] ERROR');

      debugPrint('[JOIN CHECK] $error');

      debugPrint('[JOIN CHECK] $stackTrace');

      rethrow;
    } finally {
      _checkingJoinEventIds.remove(normalizedEventId);

      _safeNotifyListeners();

      debugPrint('[JOIN CHECK] finished');
    }
  }

  // ==================================================
  // Mark Join Success
  // ==================================================

  void markJoined({
    required String eventId,
    required RescueDeployment deployment,
  }) {
    if (_disposed) {
      return;
    }

    final normalizedEventId = eventId.trim();

    if (normalizedEventId.isEmpty) {
      return;
    }

    debugPrint(
      '[JOIN STATUS] mark joined '
      'event=$normalizedEventId '
      'deployment=${deployment.deploymentId}',
    );

    _activeDeploymentsByEventId[normalizedEventId] = deployment;

    _checkedJoinEventIds.add(normalizedEventId);

    _checkingJoinEventIds.remove(normalizedEventId);

    notifyListeners();
  }

  // ==================================================
  // Leave Preparation
  // ==================================================

  void clearDeploymentForEvent(String eventId) {
    if (_disposed) {
      return;
    }

    _activeDeploymentsByEventId.remove(eventId);

    _checkedJoinEventIds.remove(eventId);

    _checkingJoinEventIds.remove(eventId);

    notifyListeners();
  }

  // ==================================================
  // Notify
  // ==================================================

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ==================================================
  // Dispose
  // ==================================================

  @override
  void dispose() {
    _disposed = true;

    _mapController.removeListener(_handleMapControllerChanged);

    _mapController.dispose();

    super.dispose();
  }

  // ==================================================
  // Operational Mode
  // ==================================================

  bool get hasActiveDeployment {
    return _activeDeploymentsByEventId.isNotEmpty;
  }

  String? get activeEventId {
    if (_activeDeploymentsByEventId.isEmpty) {
      return null;
    }

    return _activeDeploymentsByEventId.keys.first;
  }

  RescueDeployment? get activeDeployment {
    final eventId = activeEventId;

    if (eventId == null) {
      return null;
    }

    return _activeDeploymentsByEventId[eventId];
  }

  DisasterEvent? get activeDisasterEvent {
    final eventId = activeEventId;

    if (eventId == null) {
      return null;
    }

    for (final event in _mapController.visibleEvents) {
      if (event.id == eventId) {
        return event;
      }
    }

    return null;
  }
}

// ==================================================
// Internal Join Status Result
// ==================================================

class _JoinStatusResult {
  const _JoinStatusResult({required this.eventId, this.deployment, this.error});

  final String eventId;

  final RescueDeployment? deployment;

  final Object? error;
}
