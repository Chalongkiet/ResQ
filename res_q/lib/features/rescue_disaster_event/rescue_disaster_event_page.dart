import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/emergency_request_status.dart';
import '../../core/constants/mission_status.dart';
import '../../core/location/location_service.dart';
import '../../data/models/disaster_event_model.dart';
import '../../data/models/emergency_request_model.dart';
import '../../data/models/rescue_mission_monitor_model.dart';

import 'controllers/rescue_disaster_event_controller.dart';
import 'controllers/rescue_emergency_request_controller.dart';

import 'flows/join_disaster_event_flow.dart';
import 'controllers/rescue_emergency_detail_controller.dart';
import 'controllers/leave_disaster_event_controller.dart';
import 'controllers/accept_rescue_mission_controller.dart';
import 'controllers/rescue_accepted_mission_controller.dart';
import 'controllers/cancel_rescue_mission_controller.dart';
import 'controllers/complete_rescue_mission_controller.dart';
import 'services/exceptions/rescue_mission_action_exception.dart';
import 'services/mission_arrival_proximity.dart';
import 'services/rescue_mission_action_service.dart';
import 'services/rescue_operational_event_storage.dart';
import 'widgets/leave/leave_disaster_event_popup.dart';
import 'widgets/mission/cancel_rescue_mission_popup.dart';
import 'widgets/mission/complete_rescue_mission_popup.dart';
import 'widgets/emergency_detail/emergency_request_detail_dialog.dart';
import 'widgets/map/rescue_disaster_map_section.dart';
import 'widgets/operational/rescue_operational_panel.dart';
import 'widgets/rescue_disaster_event_list.dart';
import 'widgets/rescue_location_state.dart';
import 'package:latlong2/latlong.dart';

class RescueDisasterEventPage extends StatefulWidget {
  const RescueDisasterEventPage({super.key});

  @override
  State<RescueDisasterEventPage> createState() =>
      _RescueDisasterEventPageState();
}

class _RescueDisasterEventPageState extends State<RescueDisasterEventPage>
    with WidgetsBindingObserver {
  // ==================================================
  // Controllers
  // ==================================================

  late final RescueDisasterEventController _controller;

  late final RescueEmergencyRequestController _emergencyController;

  late final RescueEmergencyDetailController _detailController;
  late final AcceptRescueMissionController _acceptMissionController;

  late final RescueAcceptedMissionController _acceptedMissionController;

  late final RescueMissionActionService _missionActionService;

  final LocationService _liveLocationService = const LocationService();

  StreamSubscription<Position>? _liveLocationSubscription;

  bool _appIsForeground = true;

  bool _isVisible = true;

  bool _isUpdatingMissionStatus = false;

  // ==================================================
  // Operational State
  // ==================================================

  String? _operationalEventId;

  final RescueOperationalEventStorage _operationalEventStorage =
      RescueOperationalEventStorage();

  String? _restoredOperationalTeamId;

  DisasterEvent? _focusedEvent;

  // ==================================================
  // Selected Emergency Request
  // ==================================================

  String? _selectedEmergencyRequestId;

  int _emergencyRequestFocusVersion = 0;

  // ==================================================
  // Lifecycle
  // ==================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _controller = RescueDisasterEventController();

    _emergencyController = RescueEmergencyRequestController();

    _controller.addListener(_handleRescueControllerChanged);

    _emergencyController.addListener(_handleEmergencyControllerChanged);

    _detailController = RescueEmergencyDetailController();

    _acceptMissionController = AcceptRescueMissionController();

    _acceptedMissionController = RescueAcceptedMissionController();

    _missionActionService = RescueMissionActionService();

    _acceptedMissionController.addListener(_handleAcceptedMissionChanged);

    _controller.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isVisible = TickerMode.valuesOf(context).enabled;
    if (_isVisible == isVisible) return;

    _isVisible = isVisible;
    _syncLiveLocationTracking();
    if (isVisible && _appIsForeground) {
      _controller.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _stopLiveLocationTracking();

    _controller.removeListener(_handleRescueControllerChanged);

    _emergencyController.removeListener(_handleEmergencyControllerChanged);

    _acceptMissionController.dispose();

    _acceptedMissionController.removeListener(_handleAcceptedMissionChanged);

    _acceptedMissionController.dispose();

    _detailController.dispose();

    _emergencyController.dispose();

    _controller.dispose();

    super.dispose();
  }

  // ==================================================
  // App Lifecycle
  // ==================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appIsForeground = true;
        _controller.onAppResumed();
        _syncLiveLocationTracking();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _appIsForeground = false;
        _stopLiveLocationTracking();
        break;
    }
  }

  // ==================================================
  // Controller Listener
  // ==================================================

  void _handleRescueControllerChanged() {
    if (!mounted) {
      return;
    }

    _restoreOperationalEventIfNeeded();

    _syncEmergencyRequestWatch();

    _syncAcceptedMissionWatch();

    _syncLiveLocationTracking();

    setState(() {});
  }

  void _restoreOperationalEventIfNeeded() {
    final teamId = _controller.rescueTeamId;
    if (teamId == null ||
        teamId.trim().isEmpty ||
        teamId == _restoredOperationalTeamId) {
      return;
    }

    _restoredOperationalTeamId = teamId;
    unawaited(_restoreOperationalEvent(teamId));
  }

  Future<void> _restoreOperationalEvent(String teamId) async {
    final eventId = await _operationalEventStorage.load(teamId);
    if (!mounted ||
        _controller.rescueTeamId != teamId ||
        _operationalEventId != null ||
        eventId == null) {
      return;
    }

    setState(() => _operationalEventId = eventId);
    _syncEmergencyRequestWatch();
    _syncAcceptedMissionWatch();
  }

  void _rememberOperationalEvent(String eventId) {
    final teamId = _controller.rescueTeamId;
    if (teamId == null || teamId.trim().isEmpty) return;
    unawaited(_operationalEventStorage.save(teamId, eventId));
  }

  void _handleEmergencyControllerChanged() {
    if (!mounted) {
      return;
    }

    // ==================================================
    // Clear Stale Selected Request
    // ==================================================

    final selectedId = _selectedEmergencyRequestId;

    if (selectedId != null &&
        !_emergencyController.containsRequest(selectedId)) {
      debugPrint(
        '[EMERGENCY SELECT] '
        'clear stale request=$selectedId',
      );

      _selectedEmergencyRequestId = null;
    }

    setState(() {});
  }

  void _handleAcceptedMissionChanged() {
    if (mounted) {
      _syncLiveLocationTracking();
      _publishActiveMissionLocation();
      setState(() {});
    }
  }

  void _publishActiveMissionLocation() {
    final position = _controller.mapController.userPosition;

    if (position == null || !_acceptedMissionController.hasActiveMission) {
      return;
    }

    _acceptedMissionController.publishCurrentLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  // ==================================================
  // Foreground Live Location
  // ==================================================

  void _syncLiveLocationTracking() {
    final map = _controller.mapController;
    final shouldTrack =
        _appIsForeground &&
        (_isVisible || _acceptedMissionController.hasActiveMission) &&
        map.canShowMap &&
        map.userPosition != null;

    if (!shouldTrack) {
      _stopLiveLocationTracking();
      return;
    }

    if (_liveLocationSubscription != null) {
      return;
    }

    _liveLocationSubscription = _liveLocationService.watchLiveLocation().listen(
      _handleLivePosition,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[LIVE LOCATION] stream failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _stopLiveLocationTracking();
      },
      onDone: () {
        _liveLocationSubscription = null;
      },
    );
  }

  void _handleLivePosition(Position position) {
    if (!mounted ||
        !_appIsForeground ||
        (!_isVisible && !_acceptedMissionController.hasActiveMission)) {
      return;
    }

    _controller.mapController.applyLivePosition(position);

    if (_acceptedMissionController.hasActiveMission) {
      _acceptedMissionController.publishCurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }

  void _stopLiveLocationTracking() {
    final subscription = _liveLocationSubscription;

    if (subscription == null) {
      return;
    }

    _liveLocationSubscription = null;
    unawaited(subscription.cancel());
  }

  // ==================================================
  // Resolve Operational Event
  // ==================================================

  DisasterEvent? _resolveOperationalEvent() {
    final map = _controller.mapController;

    final operationalId = _operationalEventId;

    // ==================================================
    // Selected Operational Event
    // ==================================================

    if (operationalId != null) {
      for (final event in map.visibleEvents) {
        if (event.id == operationalId && _controller.isJoinedEvent(event.id)) {
          return event;
        }
      }
    }

    // ==================================================
    // Restore After App Restart
    //
    // Auto enter เฉพาะเมื่อมี joined event เดียว
    // ==================================================

    final joinedEvents = map.visibleEvents
        .where((event) => _controller.isJoinedEvent(event.id))
        .toList(growable: false);

    if (joinedEvents.length == 1) {
      return joinedEvents.first;
    }

    return null;
  }

  // ==================================================
  // Emergency Request Watch
  // ==================================================

  void _syncEmergencyRequestWatch() {
    final event = _resolveOperationalEvent();

    if (event == null) {
      _emergencyController.stopWatching();

      return;
    }

    _emergencyController.watchEvent(disasterEventId: event.id);
  }

  void _syncAcceptedMissionWatch() {
    final event = _resolveOperationalEvent();

    if (event == null) {
      _acceptedMissionController.stopWatching();
      return;
    }

    final deployment = _controller.activeDeploymentForEvent(event.id);

    if (deployment == null || !deployment.isActive) {
      _acceptedMissionController.stopWatching();
      return;
    }

    _acceptedMissionController.watch(
      eventId: event.id,
      deploymentId: deployment.deploymentId,
    );
  }

  // ==================================================
  // Select Event
  // ==================================================

  void _handleEventTap(DisasterEvent event) {
    final map = _controller.mapController;

    map.selectEvent(event.id);

    final isJoined = _controller.isJoinedEvent(event.id);

    setState(() {
      _focusedEvent = event;

      if (isJoined) {
        _operationalEventId = event.id;
      }
    });

    if (isJoined) _rememberOperationalEvent(event.id);

    _syncEmergencyRequestWatch();

    _syncAcceptedMissionWatch();
  }

  // ==================================================
  // Join Event
  // ==================================================

  Future<void> _handleJoinEvent(DisasterEvent event) async {
    final result = await JoinDisasterEventFlow.run(
      context: context,
      event: event,
      rescueController: _controller,
    );

    if (!mounted || result == null) {
      return;
    }

    // ==================================================
    // Enter Operational Mode
    // ==================================================

    setState(() {
      _operationalEventId = result.event.id;

      _focusedEvent = result.event;
    });

    _rememberOperationalEvent(result.event.id);

    // ==================================================
    // Map Selection
    // ==================================================

    _controller.mapController.selectEvent(result.event.id);

    // ==================================================
    // Start Emergency Request Stream
    // ==================================================

    _syncEmergencyRequestWatch();

    _syncAcceptedMissionWatch();
  }

  // ==================================================
  // Emergency Marker Tap
  //
  // LER6 จะทำ Callout / Detail
  // ==================================================

  // ==================================================
  // Emergency Request Tap
  //
  // ใช้ร่วมกันทั้ง:
  // - Emergency Request Card
  // - Emergency Request Marker
  // ==================================================

  void _handleEmergencyRequestTap(EmergencyRequest request) {
    debugPrint(
      '[EMERGENCY SELECT] '
      'request=${request.requestId}',
    );

    setState(() {
      _selectedEmergencyRequestId = request.requestId;

      // สำคัญ:
      // แม้กด Request เดิมซ้ำ
      // Map ก็ต้อง Focus ใหม่ได้
      _emergencyRequestFocusVersion++;
    });
  }

  // ==================================================
  // View Emergency Request Detail
  //
  // LER7 จะเชื่อม EmergencyInfo จริง
  // ==================================================

  Future<void> _handleViewEmergencyRequestDetail(
    EmergencyRequest request,
  ) async {
    debugPrint(
      '[EMERGENCY DETAIL] open '
      'request=${request.requestId} '
      'user=${request.userId}',
    );

    await showEmergencyRequestDetailDialog(
      context: context,
      request: request,
      controller: _detailController,

      onAcceptMission: () async {
        return _handleAcceptRescueMission(request);
      },
    );
  }

  // ==================================================
  // Leave Disaster Event
  // ==================================================

  Future<void> _handleLeavePressed() async {
    if (_acceptedMissionController.hasAssignedMissions) {
      _showMessage(
        'ยังมีภารกิจที่กำลังดำเนินการหรืออยู่ในคิว '
        'กรุณาจบหรือยกเลิกภารกิจให้เรียบร้อยก่อนถอนกำลัง',
      );
      return;
    }

    // ==================================================
    // 1. Resolve Current Operational Event
    // ==================================================

    final event = _resolveOperationalEvent();

    if (event == null) {
      _showMessage('ไม่พบเหตุการณ์ที่กำลังปฏิบัติงาน');

      return;
    }

    // ==================================================
    // 2. Resolve Active Deployment
    // ==================================================

    final deployment = _controller.activeDeploymentForEvent(event.id);

    if (deployment == null) {
      _showMessage('ไม่พบข้อมูลการเข้าร่วมเหตุการณ์');

      return;
    }

    debugPrint('================================');

    debugPrint('[LEAVE PAGE] OPEN');

    debugPrint(
      '[LEAVE PAGE] '
      'event=${event.id}',
    );

    debugPrint(
      '[LEAVE PAGE] '
      'deployment=${deployment.deploymentId}',
    );

    debugPrint(
      '[LEAVE PAGE] '
      'team=${deployment.rescueTeamId}',
    );

    // ==================================================
    // 3. Create Leave Controller
    //
    // สร้างใหม่ทุกครั้งที่เปิด Popup
    // เพื่อไม่ให้รูป/ข้อความจากครั้งก่อนค้าง
    // ==================================================

    final leaveController = LeaveDisasterEventController();

    try {
      // ==================================================
      // 4. Open Leave Popup
      // ==================================================

      final success = await showLeaveDisasterEventPopup(
        context: context,
        eventId: event.id,
        deploymentId: deployment.deploymentId,
        rescueTeamId: deployment.rescueTeamId,
        controller: leaveController,
      );

      if (!mounted || !success) {
        debugPrint('[LEAVE PAGE] cancelled / failed');

        return;
      }

      // ==================================================
      // Firestore สำเร็จ ณ จุดนี้แล้ว
      //
      // Deployment:
      // ACTIVE -> LEFT
      //
      // RescueOrganization:
      // operationalStatus -> false
      // ==================================================

      debugPrint('[LEAVE PAGE] Firestore success');

      // ==================================================
      // 5. Stop Emergency Request Realtime
      // ==================================================

      _emergencyController.stopWatching();

      _acceptedMissionController.stopWatching();

      // ==================================================
      // 6. Clear Local Active Deployment
      // ==================================================

      _controller.clearDeploymentForEvent(event.id);

      final teamId = _controller.rescueTeamId;
      if (teamId != null) {
        unawaited(_operationalEventStorage.clear(teamId));
      }

      // ==================================================
      // 7. Exit Operational Mode
      // ==================================================

      if (mounted) {
        setState(() {
          _operationalEventId = null;

          _focusedEvent = null;

          _selectedEmergencyRequestId = null;

          // Reset request focus trigger
          _emergencyRequestFocusVersion = 0;
        });
      }

      // ==================================================
      // 8. Success Message
      // ==================================================

      _showMessage('ถอนกำลังเรียบร้อยแล้ว');

      debugPrint('[LEAVE PAGE] COMPLETE');
    } finally {
      // ==================================================
      // Controller ใช้เฉพาะ Popup ครั้งนี้
      // ==================================================

      leaveController.dispose();

      debugPrint('[LEAVE PAGE] FINISHED');

      debugPrint('================================');
    }
  }

  // ==================================================
  // Accept Rescue Mission
  // ==================================================

  Future<bool> _handleAcceptRescueMission(EmergencyRequest request) async {
    // ==================================================
    // 1. Resolve Operational Event
    // ==================================================

    final event = _resolveOperationalEvent();

    if (event == null) {
      _showMessage('ไม่พบเหตุการณ์ที่กำลังปฏิบัติงาน');

      return false;
    }

    // ==================================================
    // 2. ป้องกัน Request คนละ Disaster Event
    // ==================================================

    if (request.disasterEventId != event.id) {
      _showMessage('คำร้องนี้ไม่ได้อยู่ในเหตุการณ์ที่กำลังปฏิบัติงาน');

      return false;
    }

    // ==================================================
    // 3. Resolve Active Deployment
    // ==================================================

    final deployment = _controller.activeDeploymentForEvent(event.id);

    if (deployment == null || !deployment.isActive) {
      _showMessage('ไม่พบชุดปฏิบัติการที่กำลังทำงาน');

      return false;
    }

    // ==================================================
    // 4. Build Mission Name
    //
    // ตาม Requirement:
    // ชื่อภัยพิบัติ + สถานที่เกิดภัยพิบัติ
    // ==================================================

    final missionName =
        '${event.eventName} - '
        '${event.areaDescription}';

    // ==================================================
    // 5. Confirm
    // ==================================================

    final confirmed = await _showAcceptMissionConfirmation(
      missionName: missionName,
      willQueue: _acceptedMissionController.hasActiveMission,
    );

    if (!mounted || !confirmed) {
      return false;
    }

    // ==================================================
    // 6. Accept
    // ==================================================

    final mission = await _acceptMissionController.accept(
      requestId: request.requestId,
      deploymentId: deployment.deploymentId,
      missionName: missionName,
    );

    if (!mounted) {
      return false;
    }

    // ==================================================
    // Failed
    // ==================================================

    if (mission == null) {
      _showMessage(
        _acceptMissionController.errorMessage ?? 'ไม่สามารถรับภารกิจได้',
      );

      return false;
    }

    // ==================================================
    // Success
    // ==================================================

    debugPrint(
      '[ACCEPT MISSION PAGE] '
      'accepted mission=${mission.missionId}',
    );

    // Firestore สำเร็จแล้ว จึงเข้า Mission Mode ได้ทันทีโดยไม่ต้องรอ
    // collectionGroup snapshot รอบถัดไป ส่วน realtime watcher ยังคงทำหน้าที่
    // sync ข้อมูลจาก server และรองรับการเปิดแอปกลับเข้ามาภายหลัง
    _acceptedMissionController.activateMissionLocally(
      RescueMissionAssignment(
        request: request.copyWith(
          requestStatus: EmergencyRequestStatus.accepted,
          updatedAt: DateTime.now(),
        ),
        mission: mission,
      ),
    );
    _emergencyController.removeAcceptedRequestLocally(request.requestId);

    setState(() {
      _selectedEmergencyRequestId = null;
      _emergencyRequestFocusVersion++;
    });

    _showMessage(
      mission.missionStatus == MissionStatus.queued
          ? 'รับคำร้องเข้าคิวภารกิจเรียบร้อยแล้ว'
          : 'เข้าร่วมภารกิจเรียบร้อยแล้ว',
    );

    return true;
  }

  Future<bool> _showAcceptMissionConfirmation({
    required String missionName,
    required bool willQueue,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            willQueue ? 'ยืนยันเพิ่มเข้าคิวภารกิจ' : 'ยืนยันเข้าร่วมภารกิจ',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                willQueue
                    ? 'ภารกิจปัจจุบันยังไม่เสร็จ คำร้องนี้จะอยู่ในคิวถัดไป'
                    : 'คุณต้องการรับคำร้องนี้เป็นภารกิจหรือไม่?',
              ),

              const SizedBox(height: 12),

              Text(
                missionName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('ยกเลิก'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ==================================================
  // Mission Status / Cancellation
  // ==================================================

  Future<bool> _handleUpdateMissionStatus(
    RescueMissionAssignment assignment,
    String newStatus,
  ) async {
    if (_isUpdatingMissionStatus) return false;

    setState(() => _isUpdatingMissionStatus = true);

    try {
      if (newStatus == MissionStatus.arrived) {
        final locationResult = await _liveLocationService.refreshLocation();
        final position = locationResult.position;

        if (!locationResult.isSuccess || position == null) {
          if (mounted) {
            _showMessage(
              locationResult.message ??
                  'ไม่สามารถตรวจสอบตำแหน่งปัจจุบันเพื่อยืนยันการถึงพื้นที่ได้',
            );
          }
          return false;
        }

        _controller.mapController.applyLivePosition(position);

        final distanceMeters = MissionArrivalProximity.distanceMeters(
          rescueLatitude: position.latitude,
          rescueLongitude: position.longitude,
          requestLatitude: assignment.request.latitude,
          requestLongitude: assignment.request.longitude,
        );

        if (distanceMeters > MissionArrivalProximity.maximumDistanceMeters) {
          if (mounted) {
            _showMessage(
              'ยังไม่สามารถยืนยันว่าถึงพื้นที่ได้ '
              'ขณะนี้อยู่ห่างจากจุดคำร้องประมาณ ${distanceMeters.ceil()} เมตร '
              'กรุณาเข้าใกล้ไม่เกิน '
              '${MissionArrivalProximity.maximumDistanceMeters.toInt()} เมตร',
            );
          }
          return false;
        }
      }

      await _missionActionService.updateStatus(
        requestId: assignment.request.requestId,
        missionId: assignment.mission.missionId,
        deploymentId: assignment.mission.deploymentId,
        newStatus: newStatus,
      );

      _acceptedMissionController.applyMissionStatusLocally(
        missionId: assignment.mission.missionId,
        missionStatus: newStatus,
      );

      if (mounted) _showMessage('อัปเดตสถานะภารกิจเรียบร้อยแล้ว');
      return true;
    } on RescueMissionActionException catch (error) {
      if (mounted) _showMessage(error.message);
      return false;
    } catch (error, stackTrace) {
      debugPrint('[MISSION STATUS PAGE] $error');
      debugPrint('$stackTrace');
      if (mounted) _showMessage('ไม่สามารถอัปเดตสถานะภารกิจได้');
      return false;
    } finally {
      if (mounted) setState(() => _isUpdatingMissionStatus = false);
    }
  }

  Future<void> _handleCancelMission(RescueMissionAssignment assignment) async {
    final controller = CancelRescueMissionController(
      missionService: _missionActionService,
    );

    try {
      final success = await showCancelRescueMissionPopup(
        context: context,
        requestId: assignment.request.requestId,
        missionId: assignment.mission.missionId,
        deploymentId: assignment.mission.deploymentId,
        controller: controller,
      );

      if (mounted && success) {
        // Transaction สำเร็จแล้ว:
        // - Mission -> CANCELLED
        // - Request -> WAITING
        //
        // Reset Mission Mode ทันที แล้วเริ่มอ่านรายการ WAITING ใหม่
        // เพื่อให้ทีมพร้อมรับภารกิจถัดไปโดยไม่ต้องออกจากหน้านี้
        _acceptedMissionController.removeCancelledMissionLocally(
          assignment.mission.missionId,
        );
        _emergencyController.restoreWaitingRequestLocally(assignment.request);

        setState(() {
          _selectedEmergencyRequestId = null;
          _emergencyRequestFocusVersion++;
        });

        final promotedNextMission =
            MissionStatus.isActive(assignment.mission.missionStatus) &&
            _acceptedMissionController.hasActiveMission;
        _showMessage(
          promotedNextMission
              ? 'ยกเลิกภารกิจเรียบร้อย และเริ่มภารกิจถัดไปแล้ว'
              : 'ยกเลิกภารกิจเรียบร้อย คำร้องกลับเข้าสู่หน้ารอกู้ภัยแล้ว',
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _handleCompleteMission(
    RescueMissionAssignment assignment,
  ) async {
    final controller = CompleteRescueMissionController(
      missionService: _missionActionService,
    );

    try {
      final success = await showCompleteRescueMissionPopup(
        context: context,
        assignment: assignment,
        controller: controller,
      );

      if (mounted && success) {
        _acceptedMissionController.removeMissionLocally(
          assignment.mission.missionId,
        );
        setState(() {
          _selectedEmergencyRequestId = null;
          _emergencyRequestFocusVersion++;
        });
        _showMessage(
          _acceptedMissionController.hasActiveMission
              ? 'จบภารกิจเรียบร้อย และเริ่มภารกิจถัดไปแล้ว'
              : 'จบภารกิจเรียบร้อย พร้อมรับภารกิจใหม่',
        );
      }
    } finally {
      controller.dispose();
    }
  }

  // ==================================================
  // Message
  // ==================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final map = _controller.mapController;

    // ==================================================
    // Location State
    //
    // canShowMap อย่างเดียวไม่เพียงพอ
    // ต้องตรวจ userPosition ด้วย
    // ==================================================

    final position = map.userPosition;

    if (!map.canShowMap || position == null) {
      return SafeArea(child: RescueLocationState(controller: map));
    }

    // ==================================================
    // Rescue Current Position
    // ==================================================

    final rescuePosition = LatLng(position.latitude, position.longitude);
    if (!map.canShowMap) {
      return SafeArea(child: RescueLocationState(controller: map));
    }

    // ==================================================
    // Close Emergency Request Callout
    // ==================================================

    void handleCloseEmergencyRequestCallout() {
      if (_selectedEmergencyRequestId == null) {
        return;
      }

      setState(() {
        _selectedEmergencyRequestId = null;
      });
    }

    // ==================================================
    // Operational Mode
    // ==================================================

    final operationalEvent = _resolveOperationalEvent();

    final isOperationalMode = operationalEvent != null;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ==================================================
          // Bottom Area Height
          // ==================================================

          final bottomAreaHeight = isOperationalMode
              ? constraints.maxHeight * 0.34
              : constraints.maxHeight * 0.32;

          return Stack(
            children: [
              // ==================================================
              // Map
              // ==================================================
              Positioned.fill(
                child: RescueDisasterMapSection(
                  mapState: map,

                  operationalEvent: operationalEvent,

                  focusedEvent: _focusedEvent,

                  emergencyRequests: _emergencyController.requests,

                  activeMissionRequest:
                      _acceptedMissionController.activeAssignment?.request,

                  bottomOverlayHeight: bottomAreaHeight,

                  selectedEmergencyRequestId: _selectedEmergencyRequestId,

                  focusRequestVersion: _emergencyRequestFocusVersion,

                  onEmergencyRequestTap: _handleEmergencyRequestTap,

                  onViewEmergencyRequestDetail:
                      _handleViewEmergencyRequestDetail,
                  onCloseEmergencyRequestCallout:
                      handleCloseEmergencyRequestCallout,
                ),
              ),

              // ==================================================
              // Bottom Area
              // ==================================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,

                height: bottomAreaHeight,

                child: isOperationalMode
                    ? RescueOperationalPanel(
                        emergencyController: _emergencyController,

                        rescuePosition: rescuePosition,

                        onLeavePressed: _handleLeavePressed,

                        onEmergencyRequestTap: _handleEmergencyRequestTap,

                        activeMission:
                            _acceptedMissionController.activeAssignment,

                        queuedMissions:
                            _acceptedMissionController.queuedAssignments,

                        isMissionLoading: _acceptedMissionController.isLoading,

                        missionErrorMessage:
                            _acceptedMissionController.errorMessage,

                        onRetryMission: _acceptedMissionController.retry,

                        onUpdateMissionStatus: _handleUpdateMissionStatus,

                        onCancelMission: _handleCancelMission,

                        onCompleteMission: _handleCompleteMission,

                        isUpdatingMissionStatus: _isUpdatingMissionStatus,
                      )
                    : RescueDisasterEventList(
                        mapController: map,

                        rescueController: _controller,

                        onEventTap: _handleEventTap,

                        onJoin: _handleJoinEvent,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
