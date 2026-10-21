import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/controllers/road_route_controller.dart';
import '../../../shared/widgets/map_marker_label.dart';
import '../../../shared/widgets/map_pin_marker.dart';

class EmergencyTrackingMapCard extends StatefulWidget {
  const EmergencyTrackingMapCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.routeLatitude,
    required this.routeLongitude,
    this.rescueLatitude,
    this.rescueLongitude,
  });

  final double latitude;
  final double longitude;

  /// พิกัดที่ publish ล่าสุด ใช้เป็นปลายทางสำหรับ route เพื่อไม่ให้การขยับ
  /// หมุดแบบ local ทุก 5 เมตรเรียก routing API ซ้ำถี่เกินไป
  final double routeLatitude;

  final double routeLongitude;

  final double? rescueLatitude;

  final double? rescueLongitude;

  static const double _zoom = 17;

  @override
  State<EmergencyTrackingMapCard> createState() =>
      _EmergencyTrackingMapCardState();
}

class _EmergencyTrackingMapCardState extends State<EmergencyTrackingMapCard> {
  final MapController _mapController = MapController();

  late final RoadRouteController _roadRouteController;

  bool _routeRefreshScheduled = false;

  bool _cameraFitScheduled = false;

  bool _mapReady = false;

  bool _cameraAdjustedByUser = false;

  @override
  void initState() {
    super.initState();

    _roadRouteController = RoadRouteController()
      ..addListener(_handleRoadRouteChanged);

    _scheduleRouteRefresh();
  }

  @override
  void didUpdateWidget(covariant EmergencyTrackingMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final routeChanged =
        oldWidget.routeLatitude != widget.routeLatitude ||
        oldWidget.routeLongitude != widget.routeLongitude ||
        oldWidget.rescueLatitude != widget.rescueLatitude ||
        oldWidget.rescueLongitude != widget.rescueLongitude;
    final visibleLocationChanged =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;

    if (routeChanged) {
      _scheduleRouteRefresh();
    }

    if (routeChanged || visibleLocationChanged) {
      if (!_cameraAdjustedByUser) {
        _scheduleCameraFit();
      }
    }
  }

  @override
  void dispose() {
    _roadRouteController
      ..removeListener(_handleRoadRouteChanged)
      ..dispose();

    _mapController.dispose();

    super.dispose();
  }

  void _handleRoadRouteChanged() {
    if (mounted) {
      setState(() {});

      if (!_cameraAdjustedByUser) {
        _scheduleCameraFit();
      }
    }
  }

  void _scheduleCameraFit() {
    if (_cameraFitScheduled) {
      return;
    }

    _cameraFitScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cameraFitScheduled = false;

      if (mounted && _mapReady) {
        _fitTrackingLocations();
      }
    });
  }

  void _fitTrackingLocations() {
    final rescueLocation = _rescueLocation;

    if (rescueLocation == null) {
      return;
    }

    final victimLocation = LatLng(widget.latitude, widget.longitude);
    final route = _roadRouteController.route;
    final routePoints = route == null
        ? const <LatLng>[]
        : _roadRouteController.remainingRoutePoints(rescueLocation);
    final points = routePoints.isNotEmpty
        ? routePoints
        : <LatLng>[rescueLocation, victimLocation];

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(58, 88, 78, 58),
        maxZoom: 15.5,
      ),
    );
  }

  void _zoomBy(double delta) {
    if (!_mapReady) {
      return;
    }

    _cameraAdjustedByUser = true;

    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(3.0, 19.0).toDouble();

    _mapController.move(camera.center, zoom);
  }

  void _scheduleRouteRefresh({bool force = false}) {
    if (_routeRefreshScheduled) {
      return;
    }

    _routeRefreshScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeRefreshScheduled = false;

      if (mounted) {
        _refreshRoute(force: force);
      }
    });
  }

  void _refreshRoute({bool force = false}) {
    final rescueLocation = _rescueLocation;

    if (rescueLocation == null) {
      _roadRouteController.clear();
      return;
    }

    _roadRouteController.updateRoute(
      origin: rescueLocation,
      destination: LatLng(widget.routeLatitude, widget.routeLongitude),
      force: force,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final location = LatLng(widget.latitude, widget.longitude);

    final rescueLocation = _rescueLocation;

    final hasRescueLocation = rescueLocation != null;

    final route = _roadRouteController.route;

    final routePoints = route == null || rescueLocation == null
        ? const <LatLng>[]
        : _roadRouteController.remainingRoutePoints(rescueLocation);

    final cameraPoints = routePoints.isNotEmpty
        ? routePoints
        : hasRescueLocation
        ? <LatLng>[rescueLocation, location]
        : const <LatLng>[];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==================================================
          // Header
          // ==================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.primary,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Text(
                    hasRescueLocation
                        ? 'เส้นทางทีมกู้ภัยมาหาคุณ'
                        : 'ตำแหน่งที่แจ้งขอความช่วยเหลือ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ==================================================
          // Map
          // ==================================================
          SizedBox(
            height: hasRescueLocation ? 300 : 240,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AbsorbPointer(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: location,
                        initialZoom: hasRescueLocation
                            ? 14
                            : EmergencyTrackingMapCard._zoom,
                        initialCameraFit: hasRescueLocation
                            ? CameraFit.coordinates(
                                coordinates: cameraPoints,
                                padding: const EdgeInsets.fromLTRB(
                                  58,
                                  88,
                                  78,
                                  58,
                                ),
                                maxZoom: 15.5,
                              )
                            : null,
                        onMapReady: () {
                          _mapReady = true;
                          _scheduleCameraFit();
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.res_q',
                        ),

                        if (routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                strokeWidth: 5,
                                color: AppColors.primary,
                              ),
                            ],
                          ),

                        MarkerLayer(
                          markers: [
                            if (hasRescueLocation)
                              _buildLabelMarker(
                                point: rescueLocation,
                                text: 'หน่วยกู้ภัย',
                                color: AppColors.primary,
                                verticalOffset: -74,
                              ),
                            _buildLabelMarker(
                              point: location,
                              text: 'ผู้ประสบภัย (คุณ)',
                              color: AppColors.emergency,
                              verticalOffset: -74,
                            ),
                            if (hasRescueLocation)
                              Marker(
                                point: rescueLocation,
                                width: MapPinMarker.markerWidth,
                                height: MapPinMarker.markerHeight,
                                alignment: Alignment.topCenter,
                                child: const MapPinMarker(
                                  kind: MapPinMarkerKind.rescueTeam,
                                  color: AppColors.primary,
                                  semanticLabel: 'ตำแหน่งหน่วยกู้ภัย',
                                ),
                              ),
                            Marker(
                              point: location,
                              width: MapPinMarker.markerWidth,
                              height: MapPinMarker.markerHeight,
                              alignment: Alignment.topCenter,
                              child: const MapPinMarker(
                                kind: MapPinMarkerKind.citizen,
                                color: AppColors.emergency,
                                semanticLabel: 'ตำแหน่งผู้ประสบภัย',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _TrackingMapZoomControls(
                    onZoomIn: () => _zoomBy(1),
                    onZoomOut: () => _zoomBy(-1),
                  ),
                ),
              ],
            ),
          ),

          // ==================================================
          // Coordinate
          // ==================================================
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _CoordinateRow(
                  icon: Icons.sos_rounded,
                  label: 'ตำแหน่งของคุณ',
                  coordinate:
                      '${widget.latitude.toStringAsFixed(6)}, '
                      '${widget.longitude.toStringAsFixed(6)}',
                ),
                if (hasRescueLocation) ...[
                  const SizedBox(height: 8),
                  _CoordinateRow(
                    icon: Icons.emergency_share_rounded,
                    label: 'ตำแหน่งทีมกู้ภัย',
                    coordinate:
                        '${rescueLocation.latitude.toStringAsFixed(6)}, '
                        '${rescueLocation.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 8),
                  _buildRouteStatus(theme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStatus(ThemeData theme) {
    final route = _roadRouteController.route;

    if (_roadRouteController.isLoading && route == null) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('กำลังคำนวณเส้นทางตามถนน...', style: theme.textTheme.labelSmall),
        ],
      );
    }

    if (_roadRouteController.hasFailed && route == null) {
      return Row(
        children: [
          const Icon(
            Icons.route_outlined,
            size: 18,
            color: AppColors.emergency,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _roadRouteController.errorMessage ??
                  'ไม่สามารถโหลดเส้นทางตามถนนได้',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _refreshRoute(force: true),
            child: const Text('ลองใหม่'),
          ),
        ],
      );
    }

    if (route != null) {
      final distance = _formatDistance(route.distanceMeters);
      final duration = _formatDuration(route.durationSeconds);
      final updating = _roadRouteController.isLoading;

      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          updating
              ? 'กำลังอัปเดตเส้นทางตามตำแหน่งล่าสุด...'
              : 'เส้นทางตามถนน $distance • ใช้เวลาประมาณ $duration',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} กม.';
    }

    return '${meters.round()} ม.';
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).ceil().clamp(1, 9999);

    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;

      return remainingMinutes == 0
          ? '$hours ชม.'
          : '$hours ชม. $remainingMinutes นาที';
    }

    return '$minutes นาที';
  }

  LatLng? get _rescueLocation {
    final rescueLat = widget.rescueLatitude;
    final rescueLng = widget.rescueLongitude;

    if (rescueLat == null ||
        rescueLng == null ||
        rescueLat < -90 ||
        rescueLat > 90 ||
        rescueLng < -180 ||
        rescueLng > 180 ||
        (rescueLat == 0 && rescueLng == 0)) {
      return null;
    }

    return LatLng(rescueLat, rescueLng);
  }

  Marker _buildLabelMarker({
    required LatLng point,
    required String text,
    required Color color,
    required double verticalOffset,
  }) {
    return Marker(
      point: point,
      width: 140,
      height: 28,
      alignment: Alignment.center,
      child: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: MapMarkerLabel(text: text, color: color),
      ),
    );
  }
}

class _CoordinateRow extends StatelessWidget {
  const _CoordinateRow({
    required this.icon,
    required this.label,
    required this.coordinate,
  });

  final IconData icon;
  final String label;
  final String coordinate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            coordinate,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackingMapZoomControls extends StatelessWidget {
  const _TrackingMapZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'ซูมเข้า',
            visualDensity: VisualDensity.compact,
            onPressed: onZoomIn,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 30, child: Divider(height: 1)),
          IconButton(
            tooltip: 'ซูมออก',
            visualDensity: VisualDensity.compact,
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove_rounded),
          ),
        ],
      ),
    );
  }
}
