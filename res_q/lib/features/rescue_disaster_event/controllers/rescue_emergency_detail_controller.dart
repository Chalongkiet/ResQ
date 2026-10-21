import 'package:flutter/foundation.dart';

import '../../../data/models/emergency_info_model.dart';
import '../../../data/models/emergency_request_model.dart';
import '../../../data/models/rescue_mission_model.dart';
import '../../../data/services/emergency_info_service.dart';
import '../../../data/services/rescue_mission_monitor_service.dart';

class RescueEmergencyDetailController extends ChangeNotifier {
  RescueEmergencyDetailController({
    EmergencyInfoService? emergencyInfoService,
    RescueMissionMonitorService? missionMonitorService,
  }) : _emergencyInfoService = emergencyInfoService ?? EmergencyInfoService(),
       _missionMonitorService =
           missionMonitorService ?? RescueMissionMonitorService();

  final EmergencyInfoService _emergencyInfoService;

  final RescueMissionMonitorService _missionMonitorService;

  // ==================================================
  // State
  // ==================================================

  EmergencyRequest? _request;

  EmergencyInfo? _emergencyInfo;

  List<PreviousRescueMissionCancellation> _previousCancellations =
      const <PreviousRescueMissionCancellation>[];

  bool _isLoading = false;

  String? _errorMessage;

  bool _disposed = false;

  // ==================================================
  // Getters
  // ==================================================

  EmergencyRequest? get request => _request;

  EmergencyInfo? get emergencyInfo => _emergencyInfo;

  List<PreviousRescueMissionCancellation> get previousCancellations =>
      List<PreviousRescueMissionCancellation>.unmodifiable(
        _previousCancellations,
      );

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  bool get hasEmergencyInfo => _emergencyInfo != null;

  // ==================================================
  // Load
  // ==================================================

  Future<void> load(EmergencyRequest request) async {
    if (_disposed) {
      return;
    }

    debugPrint(
      '[EMERGENCY DETAIL] load start '
      'request=${request.requestId} '
      'user=${request.userId}',
    );

    _request = request;

    _emergencyInfo = null;

    _previousCancellations = const <PreviousRescueMissionCancellation>[];

    _errorMessage = null;

    _isLoading = true;

    _safeNotifyListeners();

    try {
      final results = await Future.wait<Object?>([
        _emergencyInfoService.getByUid(request.userId),
        _loadPreviousCancellation(request),
      ]);

      final info = results[0] as EmergencyInfo?;
      final previousCancellations =
          results[1] as List<PreviousRescueMissionCancellation>;

      if (_disposed) {
        return;
      }

      if (info == null) {
        _isLoading = false;

        _errorMessage = 'ไม่พบข้อมูลฉุกเฉินของผู้ประสบภัย';

        _safeNotifyListeners();

        debugPrint(
          '[EMERGENCY DETAIL] '
          'emergency info not found',
        );

        return;
      }

      _emergencyInfo = info;

      _previousCancellations = previousCancellations;

      _isLoading = false;

      _errorMessage = null;

      debugPrint(
        '[EMERGENCY DETAIL] load success '
        'uid=${info.uid}',
      );

      _safeNotifyListeners();
    } catch (error, stackTrace) {
      if (_disposed) {
        return;
      }

      debugPrint('[EMERGENCY DETAIL] ERROR');

      debugPrint('[EMERGENCY DETAIL] $error');

      debugPrint('[EMERGENCY DETAIL] $stackTrace');

      _isLoading = false;

      _errorMessage = 'ไม่สามารถโหลดข้อมูลผู้ประสบภัยได้';

      _safeNotifyListeners();
    }
  }

  Future<List<PreviousRescueMissionCancellation>> _loadPreviousCancellation(
    EmergencyRequest request,
  ) async {
    List<RescueMission> missions;

    try {
      missions = await _missionMonitorService.loadCancelledMissions(
        request.requestId,
      );
    } catch (error, stackTrace) {
      // ประวัติการยกเลิกเป็นข้อมูลประกอบ การโหลดส่วนนี้ล้มเหลวต้องไม่ปิดกั้น
      // การดูข้อมูลผู้ประสบภัยหรือการรับภารกิจใหม่
      debugPrint('[EMERGENCY DETAIL] cancellation history unavailable');
      debugPrint('[EMERGENCY DETAIL] $error');
      debugPrint('[EMERGENCY DETAIL] $stackTrace');
      return const <PreviousRescueMissionCancellation>[];
    }

    if (missions.isEmpty) {
      return const <PreviousRescueMissionCancellation>[];
    }

    final teamNameFutures = <String, Future<String?>>{};

    final results = await Future.wait(
      missions.map((mission) async {
        final deploymentId = mission.deploymentId.trim();
        final teamNameFuture = teamNameFutures.putIfAbsent(
          deploymentId,
          () => _loadCancelledTeamName(
            disasterEventId: request.disasterEventId,
            deploymentId: deploymentId,
          ),
        );

        return PreviousRescueMissionCancellation(
          mission: mission,
          teamName: await teamNameFuture,
        );
      }),
    );

    return List<PreviousRescueMissionCancellation>.unmodifiable(results);
  }

  Future<String?> _loadCancelledTeamName({
    required String disasterEventId,
    required String deploymentId,
  }) async {
    try {
      return await _missionMonitorService.loadTeamNameForDeployment(
        disasterEventId: disasterEventId,
        deploymentId: deploymentId,
      );
    } catch (error, stackTrace) {
      // ถ้าชื่อทีมโหลดไม่ได้ ยังต้องแสดงเหตุผลและเวลายกเลิกได้ตามปกติ
      debugPrint('[EMERGENCY DETAIL] cancelled team name unavailable');
      debugPrint('[EMERGENCY DETAIL] $error');
      debugPrint('[EMERGENCY DETAIL] $stackTrace');
      return null;
    }
  }

  // ==================================================
  // Retry
  // ==================================================

  Future<void> retry() async {
    final currentRequest = _request;

    if (currentRequest == null) {
      return;
    }

    await load(currentRequest);
  }

  // ==================================================
  // Clear
  // ==================================================

  void clear() {
    if (_disposed) {
      return;
    }

    _request = null;

    _emergencyInfo = null;

    _previousCancellations = const <PreviousRescueMissionCancellation>[];

    _isLoading = false;

    _errorMessage = null;

    _safeNotifyListeners();
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

    super.dispose();
  }
}

@immutable
class PreviousRescueMissionCancellation {
  const PreviousRescueMissionCancellation({
    required this.mission,
    this.teamName,
  });

  final RescueMission mission;
  final String? teamName;
}
