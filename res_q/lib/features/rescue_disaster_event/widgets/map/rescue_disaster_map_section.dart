import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/disaster_event_model.dart';
import '../../../../data/models/emergency_request_model.dart';
import '../../../../shared/controllers/road_route_controller.dart';
import '../../../../shared/widgets/map_marker_label.dart';
import '../../../../shared/widgets/map_pin_marker.dart';

import '../../../home/controllers/home_map_controller.dart';
import 'emergency_request_callout.dart';
import 'emergency_request_marker.dart';
import '../../../home/widgets/connection_status_banner.dart';
import '../../../home/widgets/disaster_map.dart';
import '../../../home/widgets/disaster_warning_banner.dart';
import '../../../home/widgets/map_control_buttons.dart';

class RescueDisasterMapSection extends StatefulWidget {
  const RescueDisasterMapSection({
    super.key,
    required this.mapState,
    required this.operationalEvent,
    required this.focusedEvent,
    required this.emergencyRequests,
    required this.bottomOverlayHeight,
    required this.selectedEmergencyRequestId,
    required this.focusRequestVersion,
    required this.onEmergencyRequestTap,
    required this.onViewEmergencyRequestDetail,
    required this.onCloseEmergencyRequestCallout,
    this.activeMissionRequest,
  });

  final HomeMapController mapState;

  final DisasterEvent? operationalEvent;

  final DisasterEvent? focusedEvent;

  final List<EmergencyRequest> emergencyRequests;

  final EmergencyRequest? activeMissionRequest;

  final double bottomOverlayHeight;
  final VoidCallback onCloseEmergencyRequestCallout;
  // ==================================================
  // Selected Emergency Request
  // ==================================================

  final String? selectedEmergencyRequestId;

  /// เพิ่มทุกครั้งที่ต้องการ Focus Request
  ///
  /// ทำให้กด Card เดิมซ้ำได้และ Map focus ใหม่ได้
  final int focusRequestVersion;

  final ValueChanged<EmergencyRequest> onEmergencyRequestTap;

  final ValueChanged<EmergencyRequest> onViewEmergencyRequestDetail;

  @override
  State<RescueDisasterMapSection> createState() =>
      _RescueDisasterMapSectionState();
}

class _RescueDisasterMapSectionState extends State<RescueDisasterMapSection>
    with SingleTickerProviderStateMixin {
  // ==================================================
  // Map
  // ==================================================

  final MapController _mapController = MapController();

  late final RoadRouteController _roadRouteController;

  bool _roadRouteRefreshScheduled = false;

  String? _focusedRoadRouteRequestId;

  late final AnimationController _cameraAnimationController;

  LatLngTween? _centerTween;

  Tween<double>? _zoomTween;

  bool _mapReady = false;

  // ==================================================
  // Lifecycle
  // ==================================================

  @override
  void initState() {
    super.initState();

    _roadRouteController = RoadRouteController()
      ..addListener(_handleRoadRouteChanged);

    widget.mapState.addListener(_handleMapStateChanged);

    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_handleCameraAnimation);

    _scheduleRoadRouteRefresh();
  }

  @override
  void didUpdateWidget(covariant RescueDisasterMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mapState != widget.mapState) {
      oldWidget.mapState.removeListener(_handleMapStateChanged);
      widget.mapState.addListener(_handleMapStateChanged);
    }

    final oldMissionRequestId = oldWidget.activeMissionRequest?.requestId;
    final newMissionRequestId = widget.activeMissionRequest?.requestId;

    if (newMissionRequestId != oldMissionRequestId) {
      _focusedRoadRouteRequestId = null;
    }

    _scheduleRoadRouteRefresh();

    if (newMissionRequestId != null &&
        newMissionRequestId != oldMissionRequestId) {
      _scheduleActiveMissionFocus(widget.activeMissionRequest!);
      return;
    }

    // ==================================================
    // Emergency Request Focus
    // ==================================================

    if (widget.focusRequestVersion != oldWidget.focusRequestVersion) {
      final request = _findSelectedEmergencyRequest();

      if (request != null) {
        _scheduleEmergencyRequestFocus(request);

        return;
      }
    }

    // ==================================================
    // Disaster Event Focus
    // ==================================================

    final oldFocusId = oldWidget.focusedEvent?.id;

    final newFocusId = widget.focusedEvent?.id;

    final oldOperationalId = oldWidget.operationalEvent?.id;

    final newOperationalId = widget.operationalEvent?.id;

    if (newFocusId != null && newFocusId != oldFocusId) {
      _scheduleEventFocus(widget.focusedEvent!);

      return;
    }

    if (newOperationalId != null && newOperationalId != oldOperationalId) {
      _scheduleEventFocus(widget.operationalEvent!);
    }
  }

  @override
  void dispose() {
    widget.mapState.removeListener(_handleMapStateChanged);

    _roadRouteController
      ..removeListener(_handleRoadRouteChanged)
      ..dispose();

    _cameraAnimationController.dispose();

    _mapController.dispose();

    super.dispose();
  }

  // ==================================================
  // Road Route
  // ==================================================

  void _handleMapStateChanged() {
    _scheduleRoadRouteRefresh();
  }

  void _handleRoadRouteChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});

    final requestId = widget.activeMissionRequest?.requestId;

    if (!_roadRouteController.hasRoute ||
        requestId == null ||
        requestId == _focusedRoadRouteRequestId) {
      return;
    }

    _focusedRoadRouteRequestId = requestId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) {
        return;
      }

      _focusRoadRoute();
    });
  }

  void _scheduleRoadRouteRefresh({bool force = false}) {
    if (_roadRouteRefreshScheduled) {
      return;
    }

    _roadRouteRefreshScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _roadRouteRefreshScheduled = false;

      if (mounted) {
        _refreshRoadRoute(force: force);
      }
    });
  }

  void _refreshRoadRoute({bool force = false}) {
    final request = widget.activeMissionRequest;
    final position = widget.mapState.userPosition;

    if (request == null || !request.hasValidLocation || position == null) {
      _roadRouteController.clear();
      return;
    }

    if (!widget.mapState.isOnline && !force) {
      return;
    }

    _roadRouteController.updateRoute(
      origin: LatLng(position.latitude, position.longitude),
      destination: LatLng(request.latitude, request.longitude),
      force: force,
    );
  }

  void _focusRoadRoute() {
    if (!_mapReady || !_roadRouteController.hasRoute) {
      return;
    }

    final fit = CameraFit.coordinates(
      coordinates: _roadRouteController.route!.points,
      padding: EdgeInsets.fromLTRB(50, 50, 50, widget.bottomOverlayHeight + 40),
    );
    final targetCamera = fit.fit(_mapController.camera);

    _animateCamera(
      targetCenter: targetCamera.center,
      targetZoom: targetCamera.zoom,
    );
  }

  // ==================================================
  // Find Selected Request
  // ==================================================

  EmergencyRequest? _findSelectedEmergencyRequest() {
    final id = widget.selectedEmergencyRequestId;

    if (id == null || id.isEmpty) {
      return null;
    }

    for (final request in widget.emergencyRequests) {
      if (request.requestId == id) {
        return request;
      }
    }

    return null;
  }

  // ==================================================
  // Camera Animation
  // ==================================================

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

  // ==================================================
  // Focus Disaster Event
  // ==================================================

  void _scheduleEventFocus(DisasterEvent event) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusEvent(event);
    });
  }

  void _focusEvent(DisasterEvent event) {
    if (!_mapReady) {
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

  // ==================================================
  // Focus Emergency Request
  // ==================================================

  void _scheduleEmergencyRequestFocus(EmergencyRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusEmergencyRequest(request);
    });
  }

  void _focusEmergencyRequest(EmergencyRequest request) {
    if (!_mapReady || !request.hasValidLocation) {
      return;
    }

    final target = LatLng(request.latitude, request.longitude);

    // ==================================================
    // Zoom เข้า แต่ไม่เกินมากเกินไป
    // ==================================================

    final currentZoom = _mapController.camera.zoom;

    final targetZoom = currentZoom < 16 ? 16.0 : currentZoom.clamp(16.0, 18.0);

    _animateCamera(targetCenter: target, targetZoom: targetZoom.toDouble());
  }

  void _scheduleActiveMissionFocus(EmergencyRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusActiveMission(request);
      }
    });
  }

  void _focusActiveMission(EmergencyRequest request) {
    final position = widget.mapState.userPosition;

    if (!_mapReady || position == null || !request.hasValidLocation) {
      return;
    }

    final points = _roadRouteController.hasRoute
        ? _roadRouteController.route!.points
        : <LatLng>[
            LatLng(position.latitude, position.longitude),
            LatLng(request.latitude, request.longitude),
          ];
    final fit = CameraFit.coordinates(
      coordinates: points,
      padding: EdgeInsets.fromLTRB(50, 50, 50, widget.bottomOverlayHeight + 40),
    );
    final targetCamera = fit.fit(_mapController.camera);

    _animateCamera(
      targetCenter: targetCamera.center,
      targetZoom: targetCamera.zoom,
    );
  }

  // ==================================================
  // Zoom In
  // ==================================================

  void _zoomIn() {
    final map = widget.mapState;

    if (!map.mapInteractionEnabled || !_mapReady) {
      return;
    }

    final camera = _mapController.camera;

    final targetZoom = (camera.zoom + 1).clamp(2.0, 19.0).toDouble();

    _animateCamera(targetCenter: camera.center, targetZoom: targetZoom);
  }

  // ==================================================
  // Zoom Out
  // ==================================================

  void _zoomOut() {
    final map = widget.mapState;

    if (!map.mapInteractionEnabled || !_mapReady) {
      return;
    }

    final camera = _mapController.camera;

    final targetZoom = (camera.zoom - 1).clamp(2.0, 19.0).toDouble();

    _animateCamera(targetCenter: camera.center, targetZoom: targetZoom);
  }

  // ==================================================
  // My Location
  // ==================================================

  Future<void> _goToMyLocation() async {
    final map = widget.mapState;

    if (!map.mapInteractionEnabled) {
      return;
    }

    final result = await map.refreshLocation();

    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      _showMessage(
        'ไม่สามารถอัปเดตตำแหน่งได้ '
        'กรุณาลองใหม่อีกครั้ง',
      );

      return;
    }

    final position = map.userPosition;

    if (position == null) {
      return;
    }

    _animateCamera(
      targetCenter: LatLng(position.latitude, position.longitude),
      targetZoom: 14,
    );
  }

  // ==================================================
  // Emergency Request Markers
  //
  // สำคัญ:
  // PIN และ CALLOUT เป็น Marker คนละตัว
  //
  // ทำให้ PIN ไม่เคยเปลี่ยน position/size
  // ==================================================

  List<Marker> _buildEmergencyRequestMarkers() {
    final markers = <Marker>[];

    for (final request in widget.emergencyRequests) {
      if (!request.hasValidLocation) {
        continue;
      }

      // ==================================================
      // Source of Truth
      //
      // มาจาก Firestore โดยตรง
      // ==================================================

      final point = LatLng(request.latitude, request.longitude);

      final isSelected = request.requestId == widget.selectedEmergencyRequestId;

      // ==================================================
      // 2. PIN
      //
      // ตัวนี้คือตำแหน่ง geographic จริง
      //
      // ห้ามเปลี่ยน:
      // - point
      // - width
      // - height
      // - alignment
      // เมื่อ selected
      // ==================================================

      markers.add(
        Marker(
          point: point,

          width: MapPinMarker.markerWidth,
          height: MapPinMarker.markerHeight,

          alignment: Alignment.topCenter,

          child: EmergencyRequestMarker(
            isSelected: isSelected,

            onTap: () {
              widget.onEmergencyRequestTap(request);
            },
          ),
        ),
      );
    }

    return markers;
  }

  Marker? _buildSelectedEmergencyRequestCallout() {
    final request = _findSelectedEmergencyRequest();

    if (request == null || !request.hasValidLocation) {
      return null;
    }

    // Callout ใช้ point เดียวกับ Pin และเลื่อนเฉพาะภาพขึ้นตามขนาดหมุด
    // โดยถูกส่งไป foreground MarkerLayer จึงไม่ถูกหมุดชนิดอื่นวาดทับ
    return Marker(
      point: LatLng(request.latitude, request.longitude),
      width: 240,
      height: 170,
      alignment: Alignment.topCenter,
      child: Builder(
        builder: (context) {
          final pinScale = MapPinMarker.visualScaleForZoom(
            MapCamera.of(context).zoom,
          );

          return Transform.translate(
            offset: Offset(0, -(MapPinMarker.markerHeight * pinScale) - 2),
            child: EmergencyRequestCallout(
              request: request,
              onClose: widget.onCloseEmergencyRequestCallout,
              onViewDetail: () {
                widget.onViewEmergencyRequestDetail(request);
              },
            ),
          );
        },
      ),
    );
  }

  Marker? _buildActiveMissionMarker() {
    final request = widget.activeMissionRequest;

    if (request == null || !request.hasValidLocation) {
      return null;
    }

    return Marker(
      point: LatLng(request.latitude, request.longitude),
      width: MapPinMarker.markerWidth,
      height: MapPinMarker.markerHeight,
      // flutter_map ใช้ Alignment.topCenter เพื่อวาง Widget ทั้งชิ้นเหนือ
      // พิกัด ทำให้ปลายไอคอนหมุดตรงกับปลายเส้นทางพอดี
      alignment: Alignment.topCenter,
      child: const MapPinMarker(
        kind: MapPinMarkerKind.citizen,
        color: AppColors.emergency,
        semanticLabel: 'ตำแหน่งผู้ประสบภัย',
      ),
    );
  }

  Marker? _buildActiveMissionLabelMarker() {
    final request = widget.activeMissionRequest;

    if (request == null || !request.hasValidLocation) {
      return null;
    }

    return Marker(
      point: LatLng(request.latitude, request.longitude),
      width: 140,
      height: 28,
      alignment: Alignment.center,
      child: Transform.translate(
        offset: const Offset(0, -74),
        child: const MapMarkerLabel(
          text: 'ผู้ประสบภัย',
          color: AppColors.emergency,
        ),
      ),
    );
  }

  List<Polyline> _buildMissionRoute() {
    final request = widget.activeMissionRequest;
    final position = widget.mapState.userPosition;

    if (request == null ||
        !request.hasValidLocation ||
        position == null ||
        !_roadRouteController.hasRoute) {
      return const <Polyline>[];
    }

    final remainingRoutePoints = _roadRouteController.remainingRoutePoints(
      LatLng(position.latitude, position.longitude),
    );

    if (remainingRoutePoints.length < 2) {
      return const <Polyline>[];
    }

    return <Polyline>[
      Polyline(
        points: remainingRoutePoints,
        strokeWidth: 5,
        color: AppColors.primary,
      ),
    ];
  }

  Widget? _buildRoadRouteStatus() {
    if (widget.activeMissionRequest == null) {
      return null;
    }

    if (_roadRouteController.isLoading && !_roadRouteController.hasRoute) {
      return const _RoadRouteStatusCard(
        icon: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        message: 'กำลังคำนวณเส้นทางตามถนน...',
      );
    }

    if (_roadRouteController.hasFailed && !_roadRouteController.hasRoute) {
      return _RoadRouteStatusCard(
        icon: const Icon(
          Icons.route_outlined,
          size: 18,
          color: AppColors.emergency,
        ),
        message:
            _roadRouteController.errorMessage ??
            'ไม่สามารถโหลดเส้นทางตามถนนได้',
        onRetry: () => _refreshRoadRoute(force: true),
      );
    }

    return null;
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
    final map = widget.mapState;

    final position = map.userPosition;

    if (position == null) {
      return const SizedBox.shrink();
    }

    final userLatLng = LatLng(position.latitude, position.longitude);

    final isOperationalMode = widget.operationalEvent != null;

    final events = isOperationalMode
        ? <DisasterEvent>[widget.operationalEvent!]
        : map.eventsForMap;

    final emergencyMarkers = isOperationalMode
        ? _buildEmergencyRequestMarkers()
        : const <Marker>[];

    final activeMissionMarker = isOperationalMode
        ? _buildActiveMissionMarker()
        : null;

    final activeMissionLabelMarker = isOperationalMode
        ? _buildActiveMissionLabelMarker()
        : null;

    final selectedEmergencyRequestCallout = isOperationalMode
        ? _buildSelectedEmergencyRequestCallout()
        : null;

    final roadRouteStatus = _buildRoadRouteStatus();

    return Stack(
      children: [
        // ==================================================
        // Map
        // ==================================================
        Positioned.fill(
          child: DisasterMap(
            mapController: _mapController,

            userPosition: userLatLng,

            events: events,

            userMarkerType: isOperationalMode
                ? MapUserMarkerType.rescueTeam
                : MapUserMarkerType.citizen,

            userMarkerLabel: isOperationalMode ? 'หน่วยกู้ภัย (คุณ)' : null,

            extraMarkers: <Marker>[
              ...emergencyMarkers,
              ?activeMissionLabelMarker,
              ?activeMissionMarker,
            ],

            foregroundMarkers: <Marker>[?selectedEmergencyRequestCallout],

            extraPolylines: isOperationalMode
                ? _buildMissionRoute()
                : const <Polyline>[],

            interactionEnabled: map.mapInteractionEnabled,

            onMapInteraction: () {},

            onMapReady: () {
              _mapReady = true;

              final selectedRequest = _findSelectedEmergencyRequest();

              if (selectedRequest != null) {
                _scheduleEmergencyRequestFocus(selectedRequest);

                return;
              }

              final activeMissionRequest = widget.activeMissionRequest;

              if (activeMissionRequest != null) {
                _scheduleActiveMissionFocus(activeMissionRequest);
                return;
              }

              final target = widget.focusedEvent ?? widget.operationalEvent;

              if (target != null) {
                _scheduleEventFocus(target);
              }
            },
          ),
        ),

        // ==================================================
        // Connection Status
        // ==================================================
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ConnectionStatusBanner(
            isOffline: map.isOffline,

            showOnline: map.showOnlineBanner,
          ),
        ),

        // ==================================================
        // Disaster Warning
        // ==================================================
        if (map.userIsInsideDisaster)
          Positioned(
            top: map.isOffline || map.showOnlineBanner ? 68 : 10,

            left: 0,
            right: 0,

            child: DisasterWarningBanner(events: map.eventsContainingUser),
          ),

        if (roadRouteStatus != null)
          Positioned(
            left: 12,
            right: 76,
            bottom: widget.bottomOverlayHeight + 28,
            child: roadRouteStatus,
          ),

        // ==================================================
        // Controls
        // ==================================================
        Positioned(
          right: 12,

          bottom: widget.bottomOverlayHeight + 28,

          child: MapControlButtons(
            enabled: map.mapInteractionEnabled,

            isRefreshingLocation: map.isRefreshingLocation,

            onZoomIn: _zoomIn,

            onZoomOut: _zoomOut,

            onMyLocation: _goToMyLocation,
          ),
        ),
      ],
    );
  }
}

class _RoadRouteStatusCard extends StatelessWidget {
  const _RoadRouteStatusCard({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final Widget icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'ลองใหม่',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
