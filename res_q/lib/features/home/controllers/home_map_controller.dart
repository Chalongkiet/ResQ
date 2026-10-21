import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/cache/disaster_cache_service.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/connectivity/connectivity_status.dart';
import '../../../core/geo/disaster_distance_result.dart';
import '../../../core/geo/disaster_event_selector.dart';
import '../../../core/location/location_result.dart';
import '../../../core/location/location_service.dart';
import '../../../data/models/disaster_event_model.dart';
import '../../../data/services/disaster_event_service.dart';

class HomeMapController extends ChangeNotifier {
  HomeMapController({
    LocationService? locationService,
    ConnectivityService? connectivityService,
    DisasterEventService? disasterEventService,
    DisasterCacheService? cacheService,
    double? maximumVisibleDistanceMeters =
        DisasterEventSelector.maxNearbyDistanceMeters,
  }) : _locationService = locationService ?? const LocationService(),
       _connectivityService = connectivityService ?? ConnectivityService(),
       _disasterEventService = disasterEventService ?? DisasterEventService(),
       _cacheService = cacheService ?? DisasterCacheService(),
       _maximumVisibleDistanceMeters = maximumVisibleDistanceMeters;

  final LocationService _locationService;
  final ConnectivityService _connectivityService;
  final DisasterEventService _disasterEventService;
  final DisasterCacheService _cacheService;

  // --------------------------------------------------
  // Visibility Configuration
  //
  // ค่าเริ่มต้นใช้กฎเดียวกันทั้ง Citizen และ Rescue Team:
  // แสดงเหตุการณ์ที่ครอบตำแหน่ง หรืออยู่ห่างจากขอบเขตไม่เกิน 50 กม.
  // ผู้เรียกยังสามารถส่ง null ได้เมื่อมีหน้าที่ต้องแสดง Active Events ทุกระยะ
  // --------------------------------------------------

  final double? _maximumVisibleDistanceMeters;

  // --------------------------------------------------
  // Stream / Timer
  // --------------------------------------------------

  StreamSubscription<AppConnectivityStatus>? _connectivitySubscription;
  StreamSubscription<List<DisasterEvent>>? _disasterSubscription;
  Timer? _onlineBannerTimer;

  bool _disposed = false;

  // --------------------------------------------------
  // Initialization
  // --------------------------------------------------

  bool _isInitialized = false;
  bool _isInitializing = false;

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;

  // --------------------------------------------------
  // Location
  // --------------------------------------------------

  Position? _userPosition;
  Position? get userPosition => _userPosition;

  LocationResultStatus? _locationStatus;
  LocationResultStatus? get locationStatus => _locationStatus;

  String? _locationMessage;
  String? get locationMessage => _locationMessage;

  bool _isRefreshingLocation = false;
  bool get isRefreshingLocation => _isRefreshingLocation;

  bool get hasUserLocation => _userPosition != null;

  bool get canShowMap =>
      _userPosition != null && _locationStatus == LocationResultStatus.success;

  bool _shouldRecheckLocationOnResume = false;

  // --------------------------------------------------
  // Connectivity
  // --------------------------------------------------

  AppConnectivityStatus _connectivityStatus = AppConnectivityStatus.offline;

  AppConnectivityStatus get connectivityStatus => _connectivityStatus;
  bool get isOnline => _connectivityStatus.isOnline;
  bool get isOffline => _connectivityStatus.isOffline;
  bool get mapInteractionEnabled => isOnline && canShowMap;

  bool _showOnlineBanner = false;
  bool get showOnlineBanner => _showOnlineBanner;
  bool get showOfflineBanner => isOffline;

  // --------------------------------------------------
  // Disaster Data / Selection
  // --------------------------------------------------

  List<DisasterEvent> _allEvents = const <DisasterEvent>[];
  List<DisasterEvent> get allEvents => List.unmodifiable(_allEvents);

  DisasterEventSelection _selection = const DisasterEventSelection(
    visibleEvents: <DisasterEvent>[],
    results: <DisasterDistanceResult>[],
    userIsInsideDisaster: false,
  );

  DisasterEventSelection get selection => _selection;
  List<DisasterEvent> get visibleEvents => _selection.visibleEvents;
  List<DisasterDistanceResult> get visibleDistanceResults => _selection.results;
  bool get userIsInsideDisaster => _selection.userIsInsideDisaster;

  /// Events ที่ครอบตำแหน่งผู้ใช้จริง ๆ
  List<DisasterEvent> get eventsContainingUser => _selection.results
      .where((result) => result.isInside)
      .map((result) => result.event)
      .toList(growable: false);

  // --------------------------------------------------
  // Cache / Firestore Error
  // --------------------------------------------------

  bool _isUsingCachedData = false;
  bool get isUsingCachedData => _isUsingCachedData;

  DateTime? _cacheUpdatedAt;
  DateTime? get cacheUpdatedAt => _cacheUpdatedAt;

  String? _disasterDataError;
  String? get disasterDataError => _disasterDataError;
  bool get hasDisasterDataError => _disasterDataError != null;

  // --------------------------------------------------
  // Selected / Focused Event
  // --------------------------------------------------

  String? _selectedEventId;
  String? get selectedEventId => _selectedEventId;

  String? _focusedEventId;
  String? get focusedEventId => _focusedEventId;

  DisasterEvent? get selectedEvent => _findVisibleEventById(_selectedEventId);
  DisasterEvent? get focusedEvent => _findVisibleEventById(_focusedEventId);

  List<DisasterEvent> get eventsForMap {
    final focused = focusedEvent;

    if (focused != null) {
      return <DisasterEvent>[focused];
    }

    return visibleEvents;
  }

  // --------------------------------------------------
  // Initialize
  //
  // เริ่ม Connectivity, Cache, Firestore และ GPS
  // โดยไม่บังคับให้ Firestore ต้องรอ GPS ก่อน
  // --------------------------------------------------

  Future<void> initialize() async {
    if (_isInitializing || _isInitialized) {
      return;
    }

    _isInitializing = true;
    _safeNotify();

    try {
      _listenToConnectivity();

      final locationFuture = _locationService.getInitialLocation();

      await _loadCachedEvents();
      _safeNotify();

      _connectivityStatus = await _connectivityService.checkStatus();
      _safeNotify();

      if (isOnline) {
        _startDisasterStream();
      }

      final locationResult = await locationFuture;

      _applyLocationResult(locationResult, preserveExistingPosition: false);

      _recalculateSelection(preserveSelection: false);
      _isInitialized = true;
    } catch (error, stackTrace) {
      debugPrint('HomeMapController initialize error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isInitializing = false;
      _safeNotify();
    }
  }

  // --------------------------------------------------
  // Local Cache
  //
  // ใช้ข้อมูลล่าสุดระหว่างออฟไลน์หรือระหว่างรอ Firestore
  // --------------------------------------------------

  Future<void> _loadCachedEvents() async {
    final cachedEvents = await _cacheService.loadEvents();

    _cacheUpdatedAt = await _cacheService.getLastUpdatedAt();

    if (cachedEvents.isEmpty) {
      return;
    }

    _allEvents = List<DisasterEvent>.unmodifiable(cachedEvents);
    _isUsingCachedData = true;
  }

  // --------------------------------------------------
  // Connectivity
  //
  // หยุด Firestore stream เมื่อออฟไลน์ และเริ่มใหม่เมื่อออนไลน์
  // --------------------------------------------------

  void _listenToConnectivity() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = _connectivityService.watchStatus().listen(
      _handleConnectivityChanged,
      onError: (Object error) {
        debugPrint('Connectivity stream error: $error');
      },
    );
  }

  Future<void> _handleConnectivityChanged(AppConnectivityStatus status) async {
    if (_disposed) {
      return;
    }

    final previousStatus = _connectivityStatus;

    if (previousStatus == status) {
      return;
    }

    _connectivityStatus = status;

    if (status.isOffline) {
      _handleOffline();
    } else {
      await _handleOnline(wasOffline: previousStatus.isOffline);
    }

    _safeNotify();
  }

  void _handleOffline() {
    _onlineBannerTimer?.cancel();
    _showOnlineBanner = false;
    _isUsingCachedData = true;
    _stopDisasterStream();
  }

  Future<void> _handleOnline({required bool wasOffline}) async {
    if (wasOffline) {
      _showTemporaryOnlineBanner();
    }

    _startDisasterStream();
  }

  void _showTemporaryOnlineBanner() {
    _onlineBannerTimer?.cancel();
    _showOnlineBanner = true;

    _onlineBannerTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) {
        return;
      }

      _showOnlineBanner = false;
      notifyListeners();
    });
  }

  // --------------------------------------------------
  // Firestore Active Disaster Stream
  // --------------------------------------------------

  void _startDisasterStream() {
    if (!isOnline || _disposed) {
      return;
    }

    _stopDisasterStream();

    _disasterSubscription = _disasterEventService
        .watchActiveDisasterEvents()
        .listen(_handleFirestoreEvents, onError: _handleFirestoreError);
  }

  void _handleFirestoreEvents(List<DisasterEvent> events) {
    if (_disposed) {
      return;
    }

    _disasterDataError = null;
    _allEvents = List<DisasterEvent>.unmodifiable(events);
    _isUsingCachedData = false;
    _cacheUpdatedAt = DateTime.now();

    _recalculateSelection(preserveSelection: true);
    _safeNotify();

    unawaited(_cacheService.saveEvents(events));
  }

  void _handleFirestoreError(Object error) {
    if (_disposed) {
      return;
    }

    debugPrint('Disaster Firestore error: $error');

    _disasterDataError = 'ไม่สามารถโหลดข้อมูลภัยพิบัติได้';
    _isUsingCachedData = true;
    _safeNotify();
  }

  void _stopDisasterStream() {
    _disasterSubscription?.cancel();
    _disasterSubscription = null;
  }

  // --------------------------------------------------
  // Location Refresh
  //
  // ใช้กับปุ่ม My Location และคงตำแหน่งเดิมเมื่อ refresh ไม่สำเร็จ
  // --------------------------------------------------

  Future<LocationResult> refreshLocation() async {
    if (isOffline) {
      return LocationResult.error('ไม่สามารถอัปเดตตำแหน่งขณะออฟไลน์ได้');
    }

    if (_isRefreshingLocation) {
      return LocationResult.error('กำลังอัปเดตตำแหน่งอยู่');
    }

    _isRefreshingLocation = true;
    _safeNotify();

    final previousPosition = _userPosition;

    try {
      final result = await _locationService.refreshLocation();

      if (result.isSuccess) {
        _applyLocationResult(result, preserveExistingPosition: true);

        _focusedEventId = null;
        _recalculateSelection(preserveSelection: false);
      } else {
        _userPosition = previousPosition;

        _applyLocationResult(result, preserveExistingPosition: true);
      }

      return result;
    } finally {
      _isRefreshingLocation = false;
      _safeNotify();
    }
  }

  void applyLivePosition(Position position) {
    if (_disposed ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      return;
    }

    _userPosition = position;
    _locationStatus = LocationResultStatus.success;
    _locationMessage = null;
    _recalculateSelection(preserveSelection: true);
    _safeNotify();
  }

  // --------------------------------------------------
  // Apply Location Result
  // --------------------------------------------------

  void _applyLocationResult(
    LocationResult result, {
    required bool preserveExistingPosition,
  }) {
    _locationStatus = result.status;
    _locationMessage = result.message;

    if (result.isSuccess) {
      _userPosition = result.position;
      return;
    }

    if (!preserveExistingPosition) {
      _userPosition = null;
    }
  }

  // --------------------------------------------------
  // Recalculate Visible Events
  //
  // ใช้ Selector เดียวกันทั้ง Citizen และ Rescue Team
  // ต่างกันเฉพาะค่า _maximumVisibleDistanceMeters
  // --------------------------------------------------

  void _recalculateSelection({required bool preserveSelection}) {
    final position = _userPosition;

    if (position == null) {
      _selection = const DisasterEventSelection(
        visibleEvents: <DisasterEvent>[],
        results: <DisasterDistanceResult>[],
        userIsInsideDisaster: false,
      );

      _selectedEventId = null;
      _focusedEventId = null;
      return;
    }

    final previousSelectedId = _selectedEventId;
    final previousFocusedId = _focusedEventId;

    final newSelection = DisasterEventSelector.select(
      userLatitude: position.latitude,
      userLongitude: position.longitude,
      events: _allEvents,
      maximumDistanceMeters: _maximumVisibleDistanceMeters,
    );

    _selection = newSelection;

    if (newSelection.visibleEvents.isEmpty) {
      _selectedEventId = null;
      _focusedEventId = null;
      return;
    }

    final selectedStillExists =
        preserveSelection &&
        previousSelectedId != null &&
        newSelection.visibleEvents.any(
          (event) => event.id == previousSelectedId,
        );

    if (selectedStillExists) {
      _selectedEventId = previousSelectedId;
    } else {
      _selectedEventId = newSelection.visibleEvents.first.id;
    }

    final focusedStillExists =
        preserveSelection &&
        previousFocusedId != null &&
        newSelection.visibleEvents.any(
          (event) => event.id == previousFocusedId,
        );

    if (focusedStillExists) {
      _focusedEventId = previousFocusedId;
    } else {
      _focusedEventId = null;
    }
  }

  // --------------------------------------------------
  // Card Selection / Map Focus
  // --------------------------------------------------

  void selectEvent(String eventId) {
    if (isOffline) {
      return;
    }

    final event = _findVisibleEventById(eventId);

    if (event == null) {
      return;
    }

    _selectedEventId = event.id;
    _focusedEventId = event.id;
    _safeNotify();
  }

  void clearFocusedEvent() {
    if (_focusedEventId == null) {
      return;
    }

    _focusedEventId = null;
    _safeNotify();
  }

  bool isEventSelected(String eventId) {
    return _selectedEventId == eventId;
  }

  DisasterEvent? _findVisibleEventById(String? eventId) {
    if (eventId == null) {
      return null;
    }

    for (final event in _selection.visibleEvents) {
      if (event.id == eventId) {
        return event;
      }
    }

    return null;
  }

  DisasterDistanceResult? distanceResultForEvent(String eventId) {
    for (final result in _selection.results) {
      if (result.event.id == eventId) {
        return result;
      }
    }

    return null;
  }

  // --------------------------------------------------
  // App Resume
  //
  // ตรวจ Connectivity และ Location หลังกลับจาก Settings
  // --------------------------------------------------

  Future<void> onAppResumed() async {
    if (_disposed) {
      return;
    }

    final networkStatus = await _connectivityService.checkStatus();

    if (_disposed) {
      return;
    }

    final previousNetworkStatus = _connectivityStatus;

    if (networkStatus != previousNetworkStatus) {
      _connectivityStatus = networkStatus;

      if (networkStatus.isOnline) {
        await _handleOnline(wasOffline: previousNetworkStatus.isOffline);
      } else {
        _handleOffline();
      }
    }

    final returningFromSettings = _shouldRecheckLocationOnResume;
    _shouldRecheckLocationOnResume = false;

    // ตำแหน่งเดิมอาจค้างระหว่างที่แอปอยู่เบื้องหลัง
    // อ่าน GPS ใหม่แม้ไม่ได้กลับจากหน้า Settings
    if (returningFromSettings || _userPosition != null) {
      final locationResult = await _locationService.recheckLocation();

      if (_disposed) {
        return;
      }

      if (locationResult.isSuccess) {
        _applyLocationResult(locationResult, preserveExistingPosition: true);

        _recalculateSelection(preserveSelection: true);
      } else if (returningFromSettings ||
          locationResult.status == LocationResultStatus.serviceDisabled ||
          locationResult.status == LocationResultStatus.permissionDenied ||
          locationResult.status ==
              LocationResultStatus.permissionDeniedForever) {
        // สิทธิ์หรือ GPS ถูกปิด: อย่าแสดงตำแหน่งเก่าเป็นตำแหน่งปัจจุบัน
        _applyLocationResult(locationResult, preserveExistingPosition: true);
      }
    }

    _safeNotify();
  }

  // --------------------------------------------------
  // System Settings
  // --------------------------------------------------

  Future<bool> openAppSettings() async {
    _shouldRecheckLocationOnResume = true;

    final opened = await _locationService.openAppSettings();

    if (!opened) {
      _shouldRecheckLocationOnResume = false;
    }

    return opened;
  }

  Future<bool> openLocationSettings() async {
    _shouldRecheckLocationOnResume = true;

    final opened = await _locationService.openLocationSettings();

    if (!opened) {
      _shouldRecheckLocationOnResume = false;
    }

    return opened;
  }

  // --------------------------------------------------
  // Citizen Empty State
  //
  // คง getter เดิมไว้เพื่อไม่ให้ CitizenHomePage เปลี่ยนพฤติกรรม
  // --------------------------------------------------

  bool get hasNearbyDisaster => visibleEvents.isNotEmpty;

  bool get showNoNearbyDisasterMessage =>
      canShowMap && visibleEvents.isEmpty && !hasDisasterDataError;

  String get noNearbyDisasterMessage =>
      'ขณะนี้ไม่มีภัยพิบัติในพื้นที่ใกล้เคียง';

  // --------------------------------------------------
  // Safe Notify / Dispose
  // --------------------------------------------------

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;

    _onlineBannerTimer?.cancel();

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _disasterSubscription?.cancel();
    _disasterSubscription = null;

    super.dispose();
  }
}
