import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/models/current_disaster_event_match.dart';
import '../../../data/services/current_disaster_event_service.dart';

enum SosLocationStatus {
  loading,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class SosLocationController extends ChangeNotifier {
  SosLocationController({CurrentDisasterEventService? disasterService})
    : _disasterService = disasterService ?? CurrentDisasterEventService();

  final CurrentDisasterEventService _disasterService;

  StreamSubscription<Position>? _positionSubscription;

  // ใช้ป้องกันผล initialize เก่ามาทับรอบใหม่
  int _initializationVersion = 0;

  Position? _position;

  CurrentDisasterEventMatch? _currentDisasterEvent;

  SosLocationStatus _status = SosLocationStatus.loading;

  String? _errorMessage;

  String? _disasterDetectionError;

  bool _isLoadingDisasterEvents = false;

  bool _areDisasterEventsLoaded = false;

  bool _isDisposed = false;

  // ==================================================
  // Configuration
  // ==================================================

  /// GPS Stream จะส่งตำแหน่งใหม่เมื่อเคลื่อนประมาณ 5 เมตร
  ///
  /// จุดสำคัญ:
  /// การ update นี้ไม่ได้ Query Firestore
  static const int _locationDistanceFilterMeters = 5;

  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: _locationDistanceFilterMeters,
  );

  // ==================================================
  // Getters
  // ==================================================

  Position? get position => _position;

  double? get latitude => _position?.latitude;

  double? get longitude => _position?.longitude;

  double? get accuracy => _position?.accuracy;

  SosLocationStatus get status => _status;

  String? get errorMessage => _errorMessage;

  String? get disasterDetectionError => _disasterDetectionError;

  CurrentDisasterEventMatch? get currentDisasterEvent => _currentDisasterEvent;

  bool get isLoading => _status == SosLocationStatus.loading;

  bool get isReady => _status == SosLocationStatus.ready;

  bool get isServiceDisabled => _status == SosLocationStatus.serviceDisabled;

  bool get isPermissionDenied => _status == SosLocationStatus.permissionDenied;

  bool get isPermissionDeniedForever =>
      _status == SosLocationStatus.permissionDeniedForever;

  bool get hasError => _status == SosLocationStatus.error;

  /// เก็บชื่อ getter เดิมไว้
  /// เพื่อให้ sos_page.dart เดิมยังใช้ได้
  bool get isDetectingDisaster => _isLoadingDisasterEvents;

  bool get areDisasterEventsLoaded => _areDisasterEventsLoaded;

  /// พร้อม Submit เมื่อ:
  ///
  /// - มี GPS
  /// - โหลด Event แล้ว
  /// - ตรวจพบว่าอยู่ใน/ใกล้พื้นที่ภัย
  bool get canSubmitEmergencyRequest =>
      _position != null &&
      _areDisasterEventsLoaded &&
      _currentDisasterEvent != null;

  // ==================================================
  // Initialize
  // ==================================================

  Future<void> initialize() async {
    final version = ++_initializationVersion;

    await _positionSubscription?.cancel();

    _positionSubscription = null;

    _status = SosLocationStatus.loading;

    _errorMessage = null;

    _disasterDetectionError = null;

    _currentDisasterEvent = null;

    _areDisasterEventsLoaded = false;

    _isLoadingDisasterEvents = false;

    _notify();

    try {
      // ==============================================
      // 1. Location Service
      // ==============================================

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!_isCurrentInitialization(version)) {
        return;
      }

      if (!serviceEnabled) {
        _status = SosLocationStatus.serviceDisabled;

        _notify();
        return;
      }

      // ==============================================
      // 2. Permission
      // ==============================================

      var permission = await Geolocator.checkPermission();

      if (!_isCurrentInitialization(version)) {
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!_isCurrentInitialization(version)) {
        return;
      }

      if (permission == LocationPermission.denied) {
        _status = SosLocationStatus.permissionDenied;

        _notify();
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _status = SosLocationStatus.permissionDeniedForever;

        _notify();
        return;
      }

      // ==============================================
      // 3. Current GPS Position
      // ==============================================

      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );

      if (!_isCurrentInitialization(version)) {
        return;
      }

      // ให้ Marker ขึ้นก่อน
      _applyPosition(currentPosition);

      // ==============================================
      // 4. Start GPS Stream
      //
      // ตั้งแต่ตรงนี้ GPS สามารถเปลี่ยนได้
      // แต่ยังไม่มี Firestore Query เพิ่ม
      // ==============================================

      _startPositionStream(version);

      // ==============================================
      // 5. Load Active Disaster Events
      //
      // Firestore READ เกิดตรงนี้
      // ครั้งเดียวตอนเปิด SOS
      // ==============================================

      await _loadDisasterEvents(version);

      if (!_isCurrentInitialization(version)) {
        return;
      }

      // ==============================================
      // 6. ตรวจตำแหน่งล่าสุดกับ Cache
      //
      // Local computation เท่านั้น
      // ==============================================

      final latestPosition = _position;

      if (latestPosition != null) {
        _detectDisasterLocally(latestPosition);
      }
    } catch (error) {
      if (!_isCurrentInitialization(version)) {
        return;
      }

      debugPrint(
        'SOS location initialization failed: '
        '$error',
      );

      _status = SosLocationStatus.error;

      _errorMessage = 'ไม่สามารถระบุตำแหน่งปัจจุบันได้';

      _notify();
    }
  }

  // ==================================================
  // Load Disaster Events
  // ==================================================

  Future<void> _loadDisasterEvents(int version) async {
    _isLoadingDisasterEvents = true;

    _disasterDetectionError = null;

    _notify();

    try {
      await _disasterService.loadActiveEvents();

      if (!_isCurrentInitialization(version)) {
        return;
      }

      _areDisasterEventsLoaded = true;
    } on CurrentDisasterEventException catch (error) {
      if (!_isCurrentInitialization(version)) {
        return;
      }

      debugPrint(
        'Load active disasters failed: '
        '${error.code}',
      );

      _areDisasterEventsLoaded = false;

      _currentDisasterEvent = null;

      _disasterDetectionError = error.message;
    } catch (error) {
      if (!_isCurrentInitialization(version)) {
        return;
      }

      debugPrint(
        'Load active disasters failed: '
        '$error',
      );

      _areDisasterEventsLoaded = false;

      _currentDisasterEvent = null;

      _disasterDetectionError = 'ไม่สามารถโหลดข้อมูลพื้นที่ภัยพิบัติได้';
    } finally {
      if (_isCurrentInitialization(version)) {
        _isLoadingDisasterEvents = false;

        _notify();
      }
    }
  }

  // ==================================================
  // Realtime GPS Stream
  // ==================================================

  void _startPositionStream(int version) {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _locationSettings,
        ).listen(
          (position) {
            if (!_isCurrentInitialization(version)) {
              return;
            }

            _handleRealtimePosition(position);
          },
          onError: (Object error) {
            if (!_isCurrentInitialization(version)) {
              return;
            }

            debugPrint(
              'SOS realtime location error: '
              '$error',
            );

            _errorMessage = 'ไม่สามารถอัปเดตตำแหน่งแบบเรียลไทม์ได้';

            _notify();
          },
        );
  }

  // ==================================================
  // Realtime Position
  // ==================================================

  void _handleRealtimePosition(Position position) {
    // ================================================
    // 1. Update Marker
    // ================================================

    _applyPosition(position);

    // ================================================
    // 2. ถ้า Event ยังโหลดไม่เสร็จ
    // รอไปก่อน
    // ================================================

    if (!_areDisasterEventsLoaded) {
      return;
    }

    // ================================================
    // 3. ตรวจ Polygon จาก Memory
    //
    // NO FIRESTORE READ
    // ================================================

    _detectDisasterLocally(position);
  }

  // ==================================================
  // Apply GPS Position
  // ==================================================

  void _applyPosition(Position position) {
    _position = position;

    _status = SosLocationStatus.ready;

    _errorMessage = null;

    _notify();
  }

  // ==================================================
  // Detect Locally
  //
  // IMPORTANT:
  // Method นี้ไม่ async
  // และไม่แตะ Firestore
  // ==================================================

  void _detectDisasterLocally(Position position) {
    if (!_areDisasterEventsLoaded) {
      return;
    }

    try {
      final event = _disasterService.detectFromCache(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      _currentDisasterEvent = event;

      _disasterDetectionError = null;
    } on CurrentDisasterEventException catch (error) {
      debugPrint(
        'Local disaster detection failed: '
        '${error.code}',
      );

      _currentDisasterEvent = null;

      _disasterDetectionError = error.message;
    } catch (error) {
      debugPrint(
        'Local disaster detection failed: '
        '$error',
      );

      _currentDisasterEvent = null;

      _disasterDetectionError = 'ไม่สามารถตรวจสอบพื้นที่ภัยพิบัติได้';
    }

    _notify();
  }

  // ==================================================
  // Refresh Before Submit
  //
  // ใช้จริงใน S6
  //
  // Firestore Query จะเกิดตรงนี้อีก 1 ครั้ง
  // เพื่อยืนยันข้อมูลล่าสุดก่อน Submit
  // ==================================================

  Future<CurrentDisasterEventMatch?>
  validateCurrentDisasterBeforeSubmit() async {
    final latestPosition = _position;

    if (latestPosition == null) {
      throw const CurrentDisasterEventException(
        'ไม่พบตำแหน่งปัจจุบัน',
        code: 'location-not-available',
      );
    }

    _isLoadingDisasterEvents = true;

    _disasterDetectionError = null;

    _notify();

    try {
      final event = await _disasterService.detectFresh(
        latitude: latestPosition.latitude,
        longitude: latestPosition.longitude,
      );

      if (_isDisposed) {
        return null;
      }

      _areDisasterEventsLoaded = true;

      _currentDisasterEvent = event;

      return event;
    } on CurrentDisasterEventException catch (error) {
      if (!_isDisposed) {
        _disasterDetectionError = error.message;
      }

      rethrow;
    } finally {
      if (!_isDisposed) {
        _isLoadingDisasterEvents = false;

        _notify();
      }
    }
  }

  // ==================================================
  // Retry
  //
  // Retry จะ Query Firestore ใหม่เพราะเป็น
  // explicit user action
  // ==================================================

  Future<void> retry() async {
    _disasterService.clearCache();

    await initialize();
  }

  // ==================================================
  // Settings
  // ==================================================

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  // ==================================================
  // Initialization Guard
  // ==================================================

  bool _isCurrentInitialization(int version) {
    return !_isDisposed && version == _initializationVersion;
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

    _initializationVersion++;

    _positionSubscription?.cancel();

    super.dispose();
  }
}
