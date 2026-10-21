import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/disaster_colors.dart';
import '../../../data/models/disaster_event_model.dart';
import '../../../shared/widgets/map_marker_label.dart';
import '../../../shared/widgets/map_pin_marker.dart';

// ==================================================
// User Marker Type
// ==================================================

enum MapUserMarkerType { citizen, rescueTeam }

class DisasterMap extends StatefulWidget {
  const DisasterMap({
    super.key,
    required this.mapController,
    required this.userPosition,
    required this.events,
    required this.interactionEnabled,
    required this.onMapInteraction,
    required this.onMapReady,
    this.userMarkerType = MapUserMarkerType.citizen,
    this.userMarkerLabel,
    this.extraMarkers = const <Marker>[],
    this.foregroundMarkers = const <Marker>[],
    this.extraPolylines = const <Polyline>[],
  });

  final VoidCallback onMapReady;

  final MapController mapController;

  final LatLng userPosition;

  final List<DisasterEvent> events;

  final bool interactionEnabled;

  final VoidCallback onMapInteraction;

  /// citizen = ตำแหน่งผู้ใช้งานทั่วไป
  ///
  /// rescueTeam = ตำแหน่งหน่วยกู้ภัย
  final MapUserMarkerType userMarkerType;

  /// Optional label rendered as a separate marker so the current-position
  /// marker keeps its original geographic alignment.
  final String? userMarkerLabel;

  /// Marker เพิ่มเติม
  ///
  /// เช่น Emergency Request ของผู้ประสบภัย
  final List<Marker> extraMarkers;

  /// Marker ที่ต้องวาดเหนือหมุดตำแหน่งและหมุดเพิ่มเติมทั้งหมด
  ///
  /// ใช้กับ callout ที่ต้องอ่านและกดได้แม้มีหมุดหลายอันซ้อนกัน
  final List<Marker> foregroundMarkers;

  /// เส้นเพิ่มเติมบนแผนที่ เช่นแนวทางระหว่างทีมกู้ภัยกับผู้ประสบภัย
  final List<Polyline> extraPolylines;

  @override
  State<DisasterMap> createState() => _DisasterMapState();
}

class _DisasterMapState extends State<DisasterMap> {
  Timer? _scaleTimer;

  bool _showScale = false;

  // ==================================================
  // Dispose
  // ==================================================

  @override
  void dispose() {
    _scaleTimer?.cancel();

    super.dispose();
  }

  // ==================================================
  // Map Event
  // ==================================================

  void _handleMapEvent(MapEvent event) {
    widget.onMapInteraction();

    if (!widget.interactionEnabled) {
      return;
    }

    _scaleTimer?.cancel();

    if (!_showScale) {
      setState(() {
        _showScale = true;
      });
    }

    _scaleTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showScale = false;
      });
    });
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final interactionFlags = widget.interactionEnabled
        ? InteractiveFlag.all & ~InteractiveFlag.rotate
        : InteractiveFlag.none;

    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,

          options: MapOptions(
            initialCenter: widget.userPosition,

            initialZoom: 14,

            initialRotation: 0,

            keepAlive: true,

            interactionOptions: InteractionOptions(flags: interactionFlags),

            onMapEvent: _handleMapEvent,

            onMapReady: widget.onMapReady,
          ),

          children: [
            // ==================================================
            // OpenStreetMap
            // ==================================================
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

              userAgentPackageName: 'com.example.res_q',
            ),

            // ==================================================
            // Disaster Boundary
            // ==================================================
            PolygonLayer(
              polygons: widget.events
                  .map(_buildPolygon)
                  .toList(growable: false),
            ),

            if (widget.extraPolylines.isNotEmpty)
              PolylineLayer(polylines: widget.extraPolylines),

            // ==================================================
            // Markers
            // ==================================================
            MarkerLayer(
              markers: [
                // ----------------------------------------------
                // Emergency Requests / Extra Markers
                // ----------------------------------------------
                ...widget.extraMarkers,

                ?_buildUserLocationLabelMarker(),

                // ----------------------------------------------
                // Citizen / Rescue Current Position
                //
                // วางท้ายเพื่อให้อยู่เหนือ Marker อื่น
                // ----------------------------------------------
                _buildUserLocationMarker(),
              ],
            ),

            if (widget.foregroundMarkers.isNotEmpty)
              MarkerLayer(markers: widget.foregroundMarkers),

            // ==================================================
            // Attribution
            // ==================================================
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        // ==================================================
        // Scale
        // ==================================================
        Positioned(
          left: 12,
          bottom: 12,

          child: AnimatedOpacity(
            opacity: _showScale ? 1 : 0,

            duration: const Duration(milliseconds: 250),

            child: IgnorePointer(
              child: _MapScale(mapController: widget.mapController),
            ),
          ),
        ),
      ],
    );
  }

  // ==================================================
  // Current Position Marker
  // ==================================================

  Marker _buildUserLocationMarker() {
    switch (widget.userMarkerType) {
      case MapUserMarkerType.rescueTeam:
        return Marker(
          point: widget.userPosition,

          width: MapPinMarker.markerWidth,

          height: MapPinMarker.markerHeight,

          alignment: Alignment.topCenter,

          child: const MapPinMarker(
            kind: MapPinMarkerKind.rescueTeam,
            color: Color(0xFFF97316),
            semanticLabel: 'ตำแหน่งหน่วยกู้ภัย',
          ),
        );

      case MapUserMarkerType.citizen:
        return Marker(
          point: widget.userPosition,

          width: MapPinMarker.markerWidth,

          height: MapPinMarker.markerHeight,

          alignment: Alignment.topCenter,

          child: const MapPinMarker(
            kind: MapPinMarkerKind.citizen,
            color: Color(0xFF1565C0),
            semanticLabel: 'ตำแหน่งของคุณ',
          ),
        );
    }
  }

  Marker? _buildUserLocationLabelMarker() {
    final label = widget.userMarkerLabel?.trim();

    if (label == null || label.isEmpty) {
      return null;
    }

    final color = switch (widget.userMarkerType) {
      MapUserMarkerType.citizen => const Color(0xFF1565C0),
      MapUserMarkerType.rescueTeam => const Color(0xFFF97316),
    };

    return Marker(
      point: widget.userPosition,
      width: 140,
      height: 28,
      alignment: Alignment.center,
      child: Transform.translate(
        offset: const Offset(0, -74),
        child: MapMarkerLabel(text: label, color: color),
      ),
    );
  }

  // ==================================================
  // Disaster Polygon
  // ==================================================

  Polygon _buildPolygon(DisasterEvent event) {
    final points = event.disasterBoundary
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    final color = DisasterColors.colorFor(event.disasterType);

    return Polygon(
      points: points,

      color: color.withValues(alpha: 0.25),

      borderColor: color,

      borderStrokeWidth: 3,
    );
  }
}

// ==================================================
// Map Scale
// ==================================================

class _MapScale extends StatelessWidget {
  const _MapScale({required this.mapController});

  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    final camera = mapController.camera;

    final latitude = camera.center.latitude;

    final zoom = camera.zoom;

    final metersPerPixel =
        156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);

    const targetPixels = 90.0;

    final estimatedMeters = metersPerPixel * targetPixels;

    final niceMeters = _niceDistance(estimatedMeters);

    final width = niceMeters / metersPerPixel;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),

        borderRadius: BorderRadius.circular(6),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            _formatDistance(niceMeters),

            style: const TextStyle(
              color: Colors.black87,

              fontSize: 10,

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 2),

          Container(
            width: width.clamp(35.0, 110.0),

            height: 3,

            color: Colors.black87,
          ),
        ],
      ),
    );
  }

  static double _niceDistance(double value) {
    const values = <double>[
      10,
      20,
      50,
      100,
      200,
      500,
      1000,
      2000,
      5000,
      10000,
      20000,
      50000,
    ];

    var result = values.first;

    for (final candidate in values) {
      if (candidate <= value) {
        result = candidate;
      } else {
        break;
      }
    }

    return result;
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;

      return km >= 10 ? '${km.round()} กม.' : '${km.toStringAsFixed(1)} กม.';
    }

    return '${meters.round()} ม.';
  }
}
