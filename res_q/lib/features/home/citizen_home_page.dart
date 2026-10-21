import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location/location_result.dart';
import '../../core/location/location_service.dart';
import 'controllers/home_map_controller.dart';
import 'widgets/connection_status_banner.dart';
import 'widgets/disaster_alert_card.dart';
import 'widgets/disaster_map.dart';
import 'widgets/disaster_warning_banner.dart';
import 'widgets/map_control_buttons.dart';

class CitizenHomePage extends StatefulWidget {
  const CitizenHomePage({super.key});

  @override
  State<CitizenHomePage> createState() => _CitizenHomePageState();
}

class _CitizenHomePageState extends State<CitizenHomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final HomeMapController _controller;

  final LocationService _liveLocationService = const LocationService();

  StreamSubscription<Position>? _liveLocationSubscription;

  bool _appIsForeground = true;

  bool _isVisible = true;

  final MapController _mapController = MapController();

  late final AnimationController _cameraAnimationController;

  LatLngTween? _centerTween;
  Tween<double>? _zoomTween;

  bool _mapReady = false;

  // --------------------------------------------------
  // Lifecycle
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _controller = HomeMapController();

    _controller.addListener(_handleControllerChanged);

    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_handleCameraAnimation);

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
      unawaited(_controller.onAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _stopLiveLocationTracking();

    _controller.removeListener(_handleControllerChanged);

    _controller.dispose();

    _cameraAnimationController.dispose();

    _mapController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appIsForeground = true;
      if (_isVisible) {
        unawaited(_controller.onAppResumed());
      }
      _syncLiveLocationTracking();
    } else {
      _appIsForeground = false;
      _stopLiveLocationTracking();
    }
  }

  // --------------------------------------------------
  // Controller Listener
  // --------------------------------------------------

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    _syncLiveLocationTracking();
    setState(() {});
  }

  void _syncLiveLocationTracking() {
    if (!_appIsForeground || !_isVisible || !_controller.canShowMap) {
      _stopLiveLocationTracking();
      return;
    }

    if (_liveLocationSubscription != null) return;

    _liveLocationSubscription = _liveLocationService.watchLiveLocation().listen(
      _controller.applyLivePosition,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Citizen live location failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _stopLiveLocationTracking();
      },
      onDone: () => _liveLocationSubscription = null,
    );
  }

  void _stopLiveLocationTracking() {
    final subscription = _liveLocationSubscription;
    if (subscription == null) return;

    _liveLocationSubscription = null;
    unawaited(subscription.cancel());
  }

  // --------------------------------------------------
  // Map Camera Animation
  // --------------------------------------------------

  void _handleCameraAnimation() {
    if (!mounted || !_mapReady || _centerTween == null || _zoomTween == null) {
      return;
    }

    final animation = CurvedAnimation(
      parent: _cameraAnimationController,
      curve: Curves.easeInOutCubic,
    );

    final center = _centerTween!.evaluate(animation);

    final zoom = _zoomTween!.evaluate(animation);

    _mapController.move(center, zoom);
  }

  void _animateCamera({
    required LatLng targetCenter,
    required double targetZoom,
  }) {
    if (!_mapReady) {
      return;
    }

    _cameraAnimationController.stop();

    final camera = _mapController.camera;

    _centerTween = LatLngTween(begin: camera.center, end: targetCenter);

    _zoomTween = Tween<double>(begin: camera.zoom, end: targetZoom);

    _cameraAnimationController
      ..reset()
      ..forward();
  }

  // --------------------------------------------------
  // Zoom
  // --------------------------------------------------

  void _zoomIn() {
    if (!_controller.mapInteractionEnabled || !_mapReady) {
      return;
    }

    final camera = _mapController.camera;

    final targetZoom = (camera.zoom + 1).clamp(2.0, 19.0).toDouble();

    _animateCamera(targetCenter: camera.center, targetZoom: targetZoom);
  }

  void _zoomOut() {
    if (!_controller.mapInteractionEnabled || !_mapReady) {
      return;
    }

    final camera = _mapController.camera;

    final targetZoom = (camera.zoom - 1).clamp(2.0, 19.0).toDouble();

    _animateCamera(targetCenter: camera.center, targetZoom: targetZoom);
  }

  // --------------------------------------------------
  // My Location
  // --------------------------------------------------

  Future<void> _goToMyLocation() async {
    if (!_controller.mapInteractionEnabled) {
      return;
    }

    final result = await _controller.refreshLocation();

    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถอัปเดตตำแหน่งได้ '
              'กรุณาลองใหม่อีกครั้ง',
            ),
          ),
        );

      return;
    }

    final position = _controller.userPosition;

    if (position == null) {
      return;
    }

    _animateCamera(
      targetCenter: LatLng(position.latitude, position.longitude),
      targetZoom: 14,
    );
  }

  // --------------------------------------------------
  // Select Disaster
  // --------------------------------------------------

  Future<void> _selectEvent(String eventId) async {
    if (!_controller.mapInteractionEnabled || !_mapReady) {
      return;
    }

    _controller.selectEvent(eventId);

    final event = _controller.focusedEvent;

    if (event == null) {
      return;
    }

    final points = event.disasterBoundary
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    if (points.isEmpty) {
      return;
    }

    final fit = CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.all(50),
    );

    final targetCamera = fit.fit(_mapController.camera);

    _animateCamera(
      targetCenter: targetCamera.center,
      targetZoom: targetCamera.zoom,
    );
  }

  // --------------------------------------------------
  // Build
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Performance:
    // ไม่ block หน้า Home ด้วย isInitializing
    // รอเฉพาะ Location state เท่านั้น

    if (!_controller.canShowMap) {
      return Scaffold(body: SafeArea(child: _buildLocationState()));
    }

    final position = _controller.userPosition!;

    final userLatLng = LatLng(position.latitude, position.longitude);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = constraints.maxHeight * 0.25;

            return Stack(
              children: [
                // --------------------------------------
                // Map
                // --------------------------------------
                Positioned.fill(
                  child: DisasterMap(
                    mapController: _mapController,
                    userPosition: userLatLng,
                    events: _controller.eventsForMap,
                    interactionEnabled: _controller.mapInteractionEnabled,
                    onMapInteraction: () {},
                    onMapReady: () {
                      _mapReady = true;
                    },
                  ),
                ),

                // --------------------------------------
                // Online / Offline Banner
                // --------------------------------------
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ConnectionStatusBanner(
                    isOffline: _controller.isOffline,
                    showOnline: _controller.showOnlineBanner,
                  ),
                ),

                // --------------------------------------
                // Disaster Warning Banner
                // --------------------------------------
                if (_controller.userIsInsideDisaster)
                  Positioned(
                    top: _controller.isOffline || _controller.showOnlineBanner
                        ? 68
                        : 10,
                    left: 0,
                    right: 0,
                    child: DisasterWarningBanner(
                      events: _controller.visibleEvents,
                    ),
                  ),

                // --------------------------------------
                // Map Controls
                // --------------------------------------
                Positioned(
                  right: 12,
                  bottom: cardHeight + 28,
                  child: MapControlButtons(
                    enabled: _controller.mapInteractionEnabled,
                    isRefreshingLocation: _controller.isRefreshingLocation,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onMyLocation: _goToMyLocation,
                  ),
                ),

                // --------------------------------------
                // Disaster Cards
                // --------------------------------------
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: cardHeight,
                  child: _buildBottomArea(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --------------------------------------------------
  // Bottom Disaster Area
  // --------------------------------------------------

  Widget _buildBottomArea() {
    // ถ้ามี event ที่แสดงได้
    // ให้แสดง Card ก่อน แม้ Firestore error
    // เพราะอาจเป็นข้อมูลล่าสุดใน memory/cache

    if (_controller.visibleEvents.isNotEmpty) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.only(top: 10),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 6),
          itemCount: _controller.visibleEvents.length,
          itemBuilder: (context, index) {
            final event = _controller.visibleEvents[index];

            final result = _controller.distanceResultForEvent(event.id);

            if (result == null) {
              return const SizedBox.shrink();
            }

            return DisasterAlertCard(
              event: event,
              distanceMeters: result.distanceMeters,
              isInside: result.isInside,
              isSelected: _controller.isEventSelected(event.id),
              enabled: _controller.mapInteractionEnabled,
              onTap: () {
                _selectEvent(event.id);
              },
            );
          },
        ),
      );
    }

    // Firestore มีปัญหา
    // แต่ไม่มี event ที่สามารถแสดงได้

    if (_controller.hasDisasterDataError) {
      return const _BottomMessage(
        icon: Icons.cloud_off_outlined,
        text:
            'ไม่สามารถอัปเดตข้อมูลภัยพิบัติได้ '
            'กำลังใช้ข้อมูลล่าสุดที่มี',
      );
    }

    // ไม่มี Active Event เลย

    if (_controller.allEvents.isEmpty) {
      return const _BottomMessage(
        icon: Icons.check_circle_outline,
        text: 'ขณะนี้ไม่มีภัยพิบัติที่กำลังเกิดขึ้น',
      );
    }

    // มี Active Event
    // แต่ไม่มีเหตุการณ์ภายใน 50 กม.

    return const _BottomMessage(
      icon: Icons.check_circle_outline,
      text: 'ขณะนี้ไม่มีภัยพิบัติในพื้นที่ใกล้เคียง',
    );
  }

  // --------------------------------------------------
  // Location State
  // --------------------------------------------------

  Widget _buildLocationState() {
    final status = _controller.locationStatus;

    switch (status) {
      case LocationResultStatus.serviceDisabled:
        return _LocationProblem(
          icon: Icons.location_off_rounded,
          title: 'ยังไม่ได้เปิดบริการตำแหน่ง',
          description:
              'กรุณาเปิด GPS หรือบริการตำแหน่ง '
              'เพื่อใช้งานแผนที่',
          buttonText: 'เปิดการตั้งค่าตำแหน่ง',
          onPressed: _controller.openLocationSettings,
        );

      case LocationResultStatus.permissionDenied:
        return _LocationProblem(
          icon: Icons.location_disabled_rounded,
          title: 'ยังไม่ได้อนุญาตตำแหน่ง',
          description:
              'ResQ ต้องใช้ตำแหน่งของคุณ '
              'เพื่อแสดงภัยพิบัติในพื้นที่ใกล้เคียง',
          buttonText: 'ลองอีกครั้ง',
          onPressed: () async {
            await _controller.refreshLocation();
          },
        );

      case LocationResultStatus.permissionDeniedForever:
        return _LocationProblem(
          icon: Icons.settings_rounded,
          title: 'ไม่ได้รับสิทธิ์ตำแหน่ง',
          description:
              'กรุณาเปิดสิทธิ์ตำแหน่ง '
              'จากการตั้งค่าของแอป',
          buttonText: 'เปิดการตั้งค่า',
          onPressed: _controller.openAppSettings,
        );

      case LocationResultStatus.timeout:
      case LocationResultStatus.error:
        return _LocationProblem(
          icon: Icons.location_searching_rounded,
          title: 'ไม่สามารถหาตำแหน่งได้',
          description: _controller.locationMessage ?? 'กรุณาลองใหม่อีกครั้ง',
          buttonText: 'ลองอีกครั้ง',
          onPressed: () async {
            await _controller.refreshLocation();
          },
        );

      case LocationResultStatus.success:
        return const _LocationLoading();

      case null:
        return const _LocationLoading();
    }
  }
}

// ====================================================
// Bottom Message
// ====================================================

class _BottomMessage extends StatelessWidget {
  const _BottomMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ====================================================
// Location Loading
// ====================================================

class _LocationLoading extends StatelessWidget {
  const _LocationLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text('กำลังค้นหาตำแหน่งของคุณ...', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ====================================================
// Location Problem
// ====================================================

class _LocationProblem extends StatelessWidget {
  const _LocationProblem({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;

  final Future<dynamic> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () async {
                await onPressed();
              },
              icon: const Icon(Icons.settings_rounded),
              label: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
