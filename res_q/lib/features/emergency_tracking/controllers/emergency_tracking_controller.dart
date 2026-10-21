import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/citizen_identity_service.dart';
import '../../../core/config/cloudinary_config.dart';
import '../../../core/constants/emergency_request_status.dart';
import '../../../core/location/live_location_write_budget.dart';
import '../../../core/location/location_service.dart';
import '../../../data/models/emergency_request_model.dart';
import '../../../data/models/rescue_mission_model.dart';
import '../../../data/models/rescue_mission_monitor_model.dart';
import '../../../data/services/emergency_request_service.dart';
import '../../../data/services/emergency_request_image_service.dart';
import '../../../data/services/exceptions/emergency_request_exception.dart';
import '../../../data/services/rescue_mission_monitor_service.dart';

enum EmergencyTrackingStatus { loading, ready, notFound, forbidden, error }

class EmergencyTrackingController extends ChangeNotifier {
  EmergencyTrackingController({
    required this.requestId,
    EmergencyRequestService? requestService,
    EmergencyRequestImageService? imageService,
    ImagePicker? imagePicker,
    CitizenIdentityService? identityService,
    RescueMissionMonitorService? missionMonitorService,
    LocationService? locationService,
    LiveLocationWriteBudget? liveLocationWriteBudget,
    DateTime Function()? clock,
  }) : _requestService = requestService ?? EmergencyRequestService(),
       _imageService = imageService ?? const EmergencyRequestImageService(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _identityService = identityService ?? CitizenIdentityService(),
       _missionMonitorService =
           missionMonitorService ?? RescueMissionMonitorService(),
       _locationService = locationService ?? const LocationService(),
       _liveLocationWriteBudget =
           liveLocationWriteBudget ?? LiveLocationWriteBudget(),
       _clock = clock ?? DateTime.now;

  final String requestId;

  final EmergencyRequestService _requestService;

  final EmergencyRequestImageService _imageService;

  final ImagePicker _imagePicker;

  final CitizenIdentityService _identityService;

  final RescueMissionMonitorService _missionMonitorService;

  final LocationService _locationService;

  final LiveLocationWriteBudget _liveLocationWriteBudget;

  final DateTime Function() _clock;

  static const Duration minimumLocationPublishInterval = Duration(seconds: 30);

  static const double minimumLocationPublishDistanceMeters = 20;

  // ==================================================
  // Realtime Subscription
  // ==================================================

  StreamSubscription<EmergencyRequest?>? _subscription;

  StreamSubscription<RescueMission?>? _missionSubscription;

  StreamSubscription<RescueMissionDeploymentInfo?>? _deploymentSubscription;

  StreamSubscription<Position>? _liveLocationSubscription;

  // ==================================================
  // Tracking State
  // ==================================================

  EmergencyTrackingStatus _status = EmergencyTrackingStatus.loading;

  EmergencyRequest? _request;

  String? _errorMessage;

  String? _currentUserId;

  RescueMission? _mission;

  RescueMissionDeploymentInfo? _deployment;

  RescueMissionTeamInfo? _teamInfo;

  bool _isMissionLoading = false;

  String? _missionErrorMessage;

  String? _monitoredAcceptedRequestId;

  String? _monitoredDeploymentKey;

  int _teamInfoLoadVersion = 0;

  double? _liveVictimLatitude;

  double? _liveVictimLongitude;

  String? _liveLocationRequestId;

  double? _lastPublishedLatitude;

  double? _lastPublishedLongitude;

  DateTime? _lastPublishedAt;

  bool _isPublishingLocation = false;

  bool _hasLoggedLocationQuotaLimit = false;

  // ==================================================
  // Cancel State
  // ==================================================

  bool _isCancelling = false;

  String? _cancelErrorMessage;

  // ==================================================
  // Safety Status State
  // ==================================================

  XFile? _selectedSafetyImage;

  bool _isPickingSafetyImage = false;

  bool _isUpdatingSafetyStatus = false;

  String? _safetyErrorMessage;

  bool _isDisposed = false;

  // ==================================================
  // Getters
  // ==================================================

  EmergencyTrackingStatus get status => _status;

  EmergencyRequest? get request => _request;

  String? get errorMessage => _errorMessage;

  String? get cancelErrorMessage => _cancelErrorMessage;

  bool get isLoading => _status == EmergencyTrackingStatus.loading;

  bool get isReady => _status == EmergencyTrackingStatus.ready;

  bool get isNotFound => _status == EmergencyTrackingStatus.notFound;

  bool get isForbidden => _status == EmergencyTrackingStatus.forbidden;

  bool get hasError => _status == EmergencyTrackingStatus.error;

  bool get isCancelling => _isCancelling;

  XFile? get selectedSafetyImage => _selectedSafetyImage;

  bool get isPickingSafetyImage => _isPickingSafetyImage;

  bool get isUpdatingSafetyStatus => _isUpdatingSafetyStatus;

  bool get isUpdatingSafety => _isPickingSafetyImage || _isUpdatingSafetyStatus;

  String? get safetyErrorMessage => _safetyErrorMessage;

  RescueMission? get mission => _mission;

  RescueMissionDeploymentInfo? get deployment => _deployment;

  RescueMissionTeamInfo? get teamInfo => _teamInfo;

  bool get isMissionLoading => _isMissionLoading;

  String? get missionErrorMessage => _missionErrorMessage;

  bool get hasAcceptedMission =>
      _request?.isAccepted == true && _mission != null;

  double? get victimLatitude => _liveVictimLatitude ?? _request?.latitude;

  double? get victimLongitude => _liveVictimLongitude ?? _request?.longitude;

  // ==================================================
  // Can Cancel
  // ==================================================

  bool get canCancel {
    final currentRequest = _request;

    if (currentRequest == null) {
      return false;
    }

    return !_isCancelling &&
        currentRequest.requestStatus == EmergencyRequestStatus.waiting;
  }

  bool get canUpdateSafetyStatus {
    final currentRequest = _request;
    return currentRequest != null &&
        currentRequest.isCompleted &&
        !currentRequest.safeStatus &&
        !isUpdatingSafety;
  }

  // ==================================================
  // Initialize
  // ==================================================

  Future<void> initialize() async {
    await _subscription?.cancel();

    _subscription = null;

    await _stopLiveLocationTracking();

    await _stopAcceptedMissionMonitoring();

    _request = null;

    _resetLiveLocationState();

    _errorMessage = null;

    _cancelErrorMessage = null;

    _selectedSafetyImage = null;
    _safetyErrorMessage = null;

    _status = EmergencyTrackingStatus.loading;

    _notify();

    final normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isEmpty) {
      _status = EmergencyTrackingStatus.notFound;

      _notify();

      return;
    }

    try {
      // ==============================================
      // Current Anonymous Citizen UID
      // ==============================================

      final user = await _identityService.ensureIdentity();

      if (_isDisposed) {
        return;
      }

      _currentUserId = user.uid;

      // ==============================================
      // Realtime Firestore Listener
      // ==============================================

      _subscription = _requestService
          .watchById(normalizedRequestId)
          .listen(
            _handleRequest,

            onError: (Object error, StackTrace stackTrace) {
              if (_isDisposed) {
                return;
              }

              debugPrint(
                'Emergency tracking stream failed: '
                '$error',
              );

              _status = EmergencyTrackingStatus.error;

              _errorMessage = 'ไม่สามารถติดตามสถานะคำร้องได้';

              _notify();
            },
          );
    } catch (error) {
      if (_isDisposed) {
        return;
      }

      debugPrint(
        'Emergency tracking initialization failed: '
        '$error',
      );

      _status = EmergencyTrackingStatus.error;

      _errorMessage = 'ไม่สามารถโหลดข้อมูลคำร้องได้';

      _notify();
    }
  }

  // ==================================================
  // Firestore Realtime Update
  // ==================================================

  void _handleRequest(EmergencyRequest? request) {
    if (_isDisposed) {
      return;
    }

    // ================================================
    // Document ไม่มี
    // ================================================

    if (request == null) {
      _request = null;

      unawaited(_stopLiveLocationTracking());

      _status = EmergencyTrackingStatus.notFound;

      _notify();

      return;
    }

    // ================================================
    // Ownership
    // ================================================

    if (_currentUserId == null || request.userId != _currentUserId) {
      _request = null;

      unawaited(_stopLiveLocationTracking());

      _status = EmergencyTrackingStatus.forbidden;

      _notify();

      return;
    }

    // ================================================
    // Ready
    // ================================================

    _request = request;

    if (_liveLocationRequestId != request.requestId) {
      _resetLiveLocationState(request: request);
    }

    _status = EmergencyTrackingStatus.ready;

    _errorMessage = null;

    if (request.isAccepted) {
      _startAcceptedMissionMonitoring(request);
    } else if (request.isCompleted) {
      unawaited(_stopAcceptedMissionMonitoring(preserveTeamInfo: true));
    } else {
      unawaited(_stopAcceptedMissionMonitoring());
    }

    if (request.isWaiting || request.isAccepted) {
      _startLiveLocationTracking();
    } else {
      unawaited(_stopLiveLocationTracking());
    }

    _notify();
  }

  // ==================================================
  // Victim Live Location
  //
  // หมุดในเครื่องขยับตาม GPS ทุก event ส่วน Firestore ถูกจำกัดด้วย
  // เวลา ระยะทาง และ write budget เพื่อไม่ให้ใช้โควต้าเกินจำเป็น
  // ==================================================

  void _startLiveLocationTracking() {
    if (_isDisposed || _liveLocationSubscription != null) {
      return;
    }

    final currentRequest = _request;
    if (currentRequest == null ||
        (!currentRequest.isWaiting && !currentRequest.isAccepted)) {
      return;
    }

    _liveLocationSubscription = _locationService.watchLiveLocation().listen(
      _handleLivePosition,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Victim live location stream failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _liveLocationSubscription = null;
      },
      onDone: () {
        _liveLocationSubscription = null;
      },
    );
  }

  void _handleLivePosition(Position position) {
    final currentRequest = _request;

    if (_isDisposed ||
        currentRequest == null ||
        (!currentRequest.isWaiting && !currentRequest.isAccepted) ||
        !_isValidLocation(position.latitude, position.longitude)) {
      return;
    }

    _liveVictimLatitude = position.latitude;
    _liveVictimLongitude = position.longitude;
    _notify();

    unawaited(
      _publishLiveLocation(
        request: currentRequest,
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }

  Future<void> _publishLiveLocation({
    required EmergencyRequest request,
    required double latitude,
    required double longitude,
  }) async {
    if (_isDisposed || _isPublishingLocation) {
      return;
    }

    final now = _clock();
    final previousPublishedAt = _lastPublishedAt;

    if (previousPublishedAt != null &&
        now.difference(previousPublishedAt) < minimumLocationPublishInterval) {
      return;
    }

    final previousLatitude = _lastPublishedLatitude;
    final previousLongitude = _lastPublishedLongitude;

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
        deploymentId: 'citizen-request-${request.requestId}',
      );

      if (!hasWriteBudget) {
        if (!_hasLoggedLocationQuotaLimit) {
          _hasLoggedLocationQuotaLimit = true;
          debugPrint(
            '[EMERGENCY TRACKING] live-location write budget reached '
            'request=${request.requestId}',
          );
        }
        return;
      }

      final latestRequest = _request;
      if (_isDisposed ||
          latestRequest == null ||
          latestRequest.requestId != request.requestId ||
          (!latestRequest.isWaiting && !latestRequest.isAccepted)) {
        return;
      }

      await _requestService.updateLiveLocation(
        requestId: request.requestId,
        latitude: latitude,
        longitude: longitude,
      );

      _lastPublishedLatitude = latitude;
      _lastPublishedLongitude = longitude;
      _lastPublishedAt = now;
    } catch (error, stackTrace) {
      debugPrint('Victim live location update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isPublishingLocation = false;
    }
  }

  Future<void> pauseLiveLocationTracking() {
    return _stopLiveLocationTracking();
  }

  void resumeLiveLocationTracking() {
    _startLiveLocationTracking();
  }

  Future<void> _stopLiveLocationTracking() async {
    final subscription = _liveLocationSubscription;
    _liveLocationSubscription = null;
    await subscription?.cancel();
  }

  void _resetLiveLocationState({EmergencyRequest? request}) {
    _liveLocationRequestId = request?.requestId;
    _liveVictimLatitude = request?.latitude;
    _liveVictimLongitude = request?.longitude;
    _lastPublishedLatitude = request?.latitude;
    _lastPublishedLongitude = request?.longitude;
    _lastPublishedAt = null;
    _isPublishingLocation = false;
    _hasLoggedLocationQuotaLimit = false;
  }

  bool _isValidLocation(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        (latitude != 0 || longitude != 0);
  }

  // ==================================================
  // Accepted Mission Monitoring
  // ==================================================

  void _startAcceptedMissionMonitoring(EmergencyRequest request) {
    if (_monitoredAcceptedRequestId == request.requestId &&
        _missionSubscription != null) {
      return;
    }

    unawaited(_missionSubscription?.cancel());
    unawaited(_deploymentSubscription?.cancel());

    _missionSubscription = null;
    _deploymentSubscription = null;
    _monitoredAcceptedRequestId = request.requestId;
    _monitoredDeploymentKey = null;
    _mission = null;
    _deployment = null;
    _teamInfo = null;
    _isMissionLoading = true;
    _missionErrorMessage = null;

    _missionSubscription = _missionMonitorService
        .watchMissionForRequest(request.requestId)
        .listen(
          (mission) {
            if (_isDisposed ||
                _monitoredAcceptedRequestId != request.requestId) {
              return;
            }

            _mission = mission;
            _isMissionLoading = mission == null;
            _missionErrorMessage = null;

            if (mission == null) {
              unawaited(_deploymentSubscription?.cancel());
              _deploymentSubscription = null;
              _monitoredDeploymentKey = null;
              _deployment = null;
              _teamInfo = null;
              _notify();
              return;
            }

            _watchDeployment(request: request, mission: mission);
            _notify();
          },
          onError: (Object error) {
            if (_isDisposed) {
              return;
            }

            debugPrint('Accepted mission stream failed: $error');
            _isMissionLoading = false;
            _missionErrorMessage = 'ไม่สามารถโหลดข้อมูลภารกิจกู้ภัยได้';
            _notify();
          },
        );
  }

  void _watchDeployment({
    required EmergencyRequest request,
    required RescueMission mission,
  }) {
    final deploymentKey = '${request.disasterEventId}/${mission.deploymentId}';

    if (_monitoredDeploymentKey == deploymentKey &&
        _deploymentSubscription != null) {
      return;
    }

    unawaited(_deploymentSubscription?.cancel());
    _deploymentSubscription = null;
    _monitoredDeploymentKey = deploymentKey;
    _deployment = null;
    _teamInfo = null;

    _deploymentSubscription = _missionMonitorService
        .watchDeployment(
          disasterEventId: request.disasterEventId,
          deploymentId: mission.deploymentId,
        )
        .listen(
          (deployment) {
            if (_isDisposed || _monitoredDeploymentKey != deploymentKey) {
              return;
            }

            _deployment = deployment;

            if (deployment != null && deployment.rescueTeamId.isNotEmpty) {
              _loadTeamInfo(
                request: request,
                mission: mission,
                deployment: deployment,
                deploymentKey: deploymentKey,
              );
            }

            _notify();
          },
          onError: (Object error) {
            if (_isDisposed) {
              return;
            }

            debugPrint('Accepted deployment stream failed: $error');
            _missionErrorMessage = 'ไม่สามารถโหลดตำแหน่งทีมกู้ภัยได้';
            _notify();
          },
        );
  }

  Future<void> _loadTeamInfo({
    required EmergencyRequest request,
    required RescueMission mission,
    required RescueMissionDeploymentInfo deployment,
    required String deploymentKey,
  }) async {
    final loadVersion = ++_teamInfoLoadVersion;

    try {
      final info = await _missionMonitorService.loadTeamInfo(
        disasterEventId: request.disasterEventId,
        deploymentId: mission.deploymentId,
        rescueTeamId: deployment.rescueTeamId,
      );

      if (_isDisposed ||
          loadVersion != _teamInfoLoadVersion ||
          deploymentKey != _monitoredDeploymentKey) {
        return;
      }

      _teamInfo = info;
      _missionErrorMessage = null;
      _notify();
    } catch (error) {
      if (_isDisposed || loadVersion != _teamInfoLoadVersion) {
        return;
      }

      debugPrint('Accepted rescue team info load failed: $error');
      _missionErrorMessage = 'โหลดรายละเอียดทีมกู้ภัยได้ไม่ครบถ้วน';
      _notify();
    }
  }

  Future<void> _stopAcceptedMissionMonitoring({
    bool preserveTeamInfo = false,
  }) async {
    _teamInfoLoadVersion++;
    await _missionSubscription?.cancel();
    await _deploymentSubscription?.cancel();
    _missionSubscription = null;
    _deploymentSubscription = null;
    _monitoredAcceptedRequestId = null;
    _monitoredDeploymentKey = null;
    _mission = null;
    _deployment = null;
    if (!preserveTeamInfo) _teamInfo = null;
    _isMissionLoading = false;
    _missionErrorMessage = null;
  }

  // ==================================================
  // Cancel Request
  // ==================================================

  Future<bool> cancelRequest() async {
    if (_isDisposed || _isCancelling) {
      return false;
    }

    final currentRequest = _request;

    if (currentRequest == null) {
      _cancelErrorMessage = 'ไม่พบคำร้องที่ต้องการยกเลิก';

      _notify();

      return false;
    }

    // ================================================
    // Client-side guard
    //
    // Service จะตรวจซ้ำอีกครั้งด้วย Transaction
    // ================================================

    if (currentRequest.requestStatus != EmergencyRequestStatus.waiting) {
      _cancelErrorMessage = 'ไม่สามารถยกเลิกคำร้องในสถานะปัจจุบันได้';

      _notify();

      return false;
    }

    _isCancelling = true;

    _cancelErrorMessage = null;

    _notify();

    try {
      await _requestService.cancel(currentRequest.requestId);

      if (_isDisposed) {
        return false;
      }

      // Realtime Listener จะรับ snapshot ที่ document ไม่มีแล้ว
      // และเปลี่ยนสถานะเป็น notFound ระหว่างที่หน้าแสดงผลสำเร็จ

      return true;
    } on EmergencyRequestCannotCancelException {
      if (!_isDisposed) {
        _cancelErrorMessage =
            'คำร้องนี้ไม่สามารถยกเลิกได้แล้ว '
            'เนื่องจากสถานะมีการเปลี่ยนแปลง';
      }

      return false;
    } on EmergencyRequestOwnerMismatchException {
      if (!_isDisposed) {
        _cancelErrorMessage = 'ไม่มีสิทธิ์ยกเลิกคำร้องนี้';
      }

      return false;
    } on EmergencyRequestNotFoundException {
      if (!_isDisposed) {
        _cancelErrorMessage = 'ไม่พบคำร้องที่ต้องการยกเลิก';
      }

      return false;
    } on EmergencyRequestException catch (error) {
      if (!_isDisposed) {
        _cancelErrorMessage = error.message;
      }

      return false;
    } catch (error) {
      debugPrint(
        'Cancel emergency request failed: '
        '$error',
      );

      if (!_isDisposed) {
        _cancelErrorMessage = 'เกิดข้อผิดพลาดในการยกเลิกคำร้อง';
      }

      return false;
    } finally {
      if (!_isDisposed) {
        _isCancelling = false;

        _notify();
      }
    }
  }

  // ==================================================
  // Update Safety Status
  // ==================================================

  Future<void> pickSafetyImage(ImageSource source) async {
    if (_isDisposed || isUpdatingSafety) return;

    _isPickingSafetyImage = true;
    _safetyErrorMessage = null;
    _notify();

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (!_isDisposed && image != null) {
        _selectedSafetyImage = image;
      }
    } catch (error, stackTrace) {
      debugPrint('Pick safety image failed: $error');
      debugPrint('$stackTrace');
      _safetyErrorMessage = 'ไม่สามารถเลือกรูปภาพได้ กรุณาลองใหม่อีกครั้ง';
    } finally {
      if (!_isDisposed) {
        _isPickingSafetyImage = false;
        _notify();
      }
    }
  }

  void removeSafetyImage() {
    if (_isDisposed || _isUpdatingSafetyStatus) return;
    _selectedSafetyImage = null;
    _safetyErrorMessage = null;
    _notify();
  }

  void clearSafetyError() {
    if (_isDisposed || _safetyErrorMessage == null) return;
    _safetyErrorMessage = null;
    _notify();
  }

  Future<bool> updateSafetyStatus() async {
    if (_isDisposed || _isUpdatingSafetyStatus) return false;

    final currentRequest = _request;
    if (currentRequest == null) {
      _setSafetyError('ไม่พบคำร้องที่ต้องการยืนยันความปลอดภัย');
      return false;
    }
    if (!currentRequest.isCompleted || currentRequest.safeStatus) {
      _setSafetyError('คำร้องนี้ไม่สามารถยืนยันความปลอดภัยได้');
      return false;
    }

    final image = _selectedSafetyImage;
    if (image == null) {
      _setSafetyError('กรุณาแนบรูปภาพยืนยันความปลอดภัย');
      return false;
    }

    _isUpdatingSafetyStatus = true;
    _safetyErrorMessage = null;
    _notify();

    try {
      final upload = await _imageService.upload(
        image: image,
        purpose: CloudinaryUploadPurpose.updateSafetyStatus,
      );
      if (_isDisposed) return false;

      await _requestService.updateSafetyStatus(
        requestId: currentRequest.requestId,
        safeImage: upload.url,
      );
      return !_isDisposed;
    } on EmergencyRequestImageException catch (error) {
      _safetyErrorMessage = error.message;
      return false;
    } on EmergencyRequestException catch (error) {
      _safetyErrorMessage = error.message;
      return false;
    } catch (error, stackTrace) {
      debugPrint('Update safety status failed: $error');
      debugPrint('$stackTrace');
      _safetyErrorMessage = 'เกิดข้อผิดพลาดในการยืนยันความปลอดภัย';
      return false;
    } finally {
      if (!_isDisposed) {
        _isUpdatingSafetyStatus = false;
        _notify();
      }
    }
  }

  void _setSafetyError(String message) {
    _safetyErrorMessage = message;
    _notify();
  }

  // ==================================================
  // Retry
  // ==================================================

  Future<void> retry() async {
    await initialize();
  }

  // ==================================================
  // Notify
  // ==================================================

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ==================================================
  // Dispose
  // ==================================================

  @override
  void dispose() {
    _isDisposed = true;

    _subscription?.cancel();

    _missionSubscription?.cancel();

    _deploymentSubscription?.cancel();

    _liveLocationSubscription?.cancel();

    super.dispose();
  }
}
