import 'package:flutter/foundation.dart';

import '../../../data/models/rescue_mission_model.dart';

import '../services/accept_rescue_mission_service.dart';
import '../services/exceptions/accept_rescue_mission_exception.dart';

class AcceptRescueMissionController extends ChangeNotifier {
  AcceptRescueMissionController({AcceptRescueMissionService? service})
    : _service = service ?? AcceptRescueMissionService();

  final AcceptRescueMissionService _service;

  bool _isAccepting = false;
  String? _errorMessage;
  RescueMission? _acceptedMission;

  bool _disposed = false;

  bool get isAccepting => _isAccepting;

  String? get errorMessage => _errorMessage;

  RescueMission? get acceptedMission => _acceptedMission;

  // ==================================================
  // Accept
  // ==================================================

  Future<RescueMission?> accept({
    required String requestId,
    required String deploymentId,
    required String missionName,
  }) async {
    if (_disposed || _isAccepting) {
      return null;
    }

    final normalizedMissionName = missionName.trim();

    if (normalizedMissionName.isEmpty) {
      _setError('ไม่สามารถสร้างชื่อภารกิจได้');
      return null;
    }

    _isAccepting = true;
    _errorMessage = null;
    _acceptedMission = null;

    _safeNotifyListeners();

    try {
      final mission = await _service.accept(
        requestId: requestId,
        deploymentId: deploymentId,
        missionName: normalizedMissionName,
      );

      if (_disposed) {
        return null;
      }

      _acceptedMission = mission;

      debugPrint(
        '[ACCEPT MISSION CONTROLLER] '
        'SUCCESS mission=${mission.missionId}',
      );

      return mission;
    } on AcceptRescueMissionException catch (error) {
      debugPrint(
        '[ACCEPT MISSION CONTROLLER] '
        '${error.code}: ${error.message}',
      );

      _errorMessage = error.message;

      return null;
    } catch (error, stackTrace) {
      debugPrint('[ACCEPT MISSION CONTROLLER] ERROR $error');

      debugPrint('[ACCEPT MISSION CONTROLLER] $stackTrace');

      _errorMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

      return null;
    } finally {
      if (!_disposed) {
        _isAccepting = false;
        _safeNotifyListeners();
      }
    }
  }

  // ==================================================
  // Error
  // ==================================================

  void clearError() {
    if (_disposed || _errorMessage == null) {
      return;
    }

    _errorMessage = null;
    _safeNotifyListeners();
  }

  void _setError(String message) {
    if (_disposed) {
      return;
    }

    _errorMessage = message;
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
