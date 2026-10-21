import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/map_pin_marker.dart';
import '../controllers/sos_location_controller.dart';

class SosLocationPreviewCard extends StatefulWidget {
  const SosLocationPreviewCard({super.key, required this.controller});

  final SosLocationController controller;

  @override
  State<SosLocationPreviewCard> createState() => _SosLocationPreviewCardState();
}

class _SosLocationPreviewCardState extends State<SosLocationPreviewCard> {
  final MapController _mapController = MapController();

  bool _mapReady = false;

  double? _lastLatitude;
  double? _lastLongitude;

  static const double _mapZoom = 17;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_onLocationChanged);
  }

  @override
  void didUpdateWidget(SosLocationPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onLocationChanged);

      widget.controller.addListener(_onLocationChanged);
    }
  }

  // ==================================================
  // Location Changed
  // ==================================================

  void _onLocationChanged() {
    if (!mounted) {
      return;
    }

    final position = widget.controller.position;

    if (position == null) {
      setState(() {});
      return;
    }

    final latitude = position.latitude;

    final longitude = position.longitude;

    // ป้องกัน Move ซ้ำค่าเดิม
    final samePosition =
        latitude == _lastLatitude && longitude == _lastLongitude;

    if (!samePosition) {
      _lastLatitude = latitude;
      _lastLongitude = longitude;

      if (_mapReady) {
        _mapController.move(LatLng(latitude, longitude), _mapZoom);
      }
    }

    setState(() {});
  }

  // ==================================================
  // Map Ready
  // ==================================================

  void _onMapReady() {
    _mapReady = true;

    final position = widget.controller.position;

    if (position == null) {
      return;
    }

    _lastLatitude = position.latitude;

    _lastLongitude = position.longitude;

    _mapController.move(
      LatLng(position.latitude, position.longitude),
      _mapZoom,
    );
  }

  // ==================================================
  // Dispose
  // ==================================================

  @override
  void dispose() {
    widget.controller.removeListener(_onLocationChanged);

    _mapController.dispose();

    super.dispose();
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final position = widget.controller.position;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // Header
          // ==========================================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.my_location_rounded,
                  color: theme.colorScheme.primary,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'ตำแหน่งของคุณ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                if (position != null)
                  _RealtimeBadge(accuracy: position.accuracy),
              ],
            ),
          ),

          // ==========================================
          // Map
          // ==========================================
          SizedBox(
            height: 230,
            child: position == null
                ? _buildWaitingMap(theme)
                : _buildMap(position.latitude, position.longitude),
          ),

          // ==========================================
          // Coordinate
          // ==========================================
          if (position != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 20),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      '${position.latitude.toStringAsFixed(6)}, '
                      '${position.longitude.toStringAsFixed(6)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),

                  Text(
                    '±${position.accuracy.toStringAsFixed(0)} ม.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================================================
  // Map
  // ==================================================

  Widget _buildMap(double latitude, double longitude) {
    final currentLocation = LatLng(latitude, longitude);

    // AbsorbPointer:
    // Map เป็น Preview เท่านั้น
    // ผู้ใช้ไม่สามารถลากเพื่อเปลี่ยน Incident Location
    return AbsorbPointer(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: currentLocation,
          initialZoom: _mapZoom,
          onMapReady: _onMapReady,
        ),
        children: [
          // ==========================================
          // Map Tiles
          //
          // ถ้า CitizenHomePage ใช้ TileLayer/Cache
          // ของตัวเอง สามารถเปลี่ยนส่วนนี้ให้เป็น
          // configuration เดียวกันได้ภายหลัง
          // ==========================================
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.res_q',
          ),

          // ==========================================
          // Current Location Marker
          // ==========================================
          MarkerLayer(
            markers: [
              Marker(
                point: currentLocation,
                width: MapPinMarker.markerWidth,
                height: MapPinMarker.markerHeight,
                alignment: Alignment.topCenter,
                child: const MapPinMarker(
                  kind: MapPinMarkerKind.citizen,
                  color: AppColors.primary,
                  semanticLabel: 'ตำแหน่งปัจจุบันของคุณ',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================================================
  // Waiting
  // ==================================================

  Widget _buildWaitingMap(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('กำลังค้นหาตำแหน่ง...'),
          ],
        ),
      ),
    );
  }
}

// ====================================================
// Realtime Badge
// ====================================================

class _RealtimeBadge extends StatelessWidget {
  const _RealtimeBadge({required this.accuracy});

  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.lightSuccessContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(width: 6),

          Text(
            'Realtime',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
