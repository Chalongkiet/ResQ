import 'dart:math' as math;

import '../../data/models/current_disaster_event_match.dart';

abstract final class DisasterBoundaryGeometry {
  static const double _earthRadiusMeters = 6371000;

  /// ค่าคลาดเคลื่อนที่ใช้พิจารณาว่าอยู่ "บนขอบ"
  static const double _edgeToleranceMeters = 0.5;

  // ==================================================
  // Point In Polygon
  // ==================================================

  /// ตรวจแบบ Strict
  ///
  /// - อยู่ภายในจริง = true
  /// - อยู่บนเส้นขอบ = false
  /// - อยู่นอก = false
  ///
  /// แต่ SOS ยังรับคนที่อยู่บนขอบได้จาก
  /// distanceToBoundaryMeters()
  static bool isInsideStrict({
    required DisasterBoundaryPoint point,
    required List<DisasterBoundaryPoint> polygon,
  }) {
    if (polygon.length < 3) {
      return false;
    }

    // -----------------------------------------------
    // ถ้าอยู่บนขอบ ถือว่าไม่ใช่ inside แบบ strict
    // -----------------------------------------------

    final boundaryDistance = distanceToBoundaryMeters(
      point: point,
      polygon: polygon,
    );

    if (boundaryDistance <= _edgeToleranceMeters) {
      return false;
    }

    // -----------------------------------------------
    // Ray Casting
    // -----------------------------------------------

    var inside = false;

    var j = polygon.length - 1;

    for (var i = 0; i < polygon.length; i++) {
      final current = polygon[i];
      final previous = polygon[j];

      final latitudeCrosses =
          (current.latitude > point.latitude) !=
          (previous.latitude > point.latitude);

      if (latitudeCrosses) {
        final longitudeAtLatitude =
            (previous.longitude - current.longitude) *
                (point.latitude - current.latitude) /
                (previous.latitude - current.latitude) +
            current.longitude;

        if (point.longitude < longitudeAtLatitude) {
          inside = !inside;
        }
      }

      j = i;
    }

    return inside;
  }

  // ==================================================
  // Distance to Polygon Boundary
  // ==================================================

  static double distanceToBoundaryMeters({
    required DisasterBoundaryPoint point,
    required List<DisasterBoundaryPoint> polygon,
  }) {
    if (polygon.length < 2) {
      return double.infinity;
    }

    var minimumDistance = double.infinity;

    for (var i = 0; i < polygon.length; i++) {
      final start = polygon[i];

      final end = polygon[(i + 1) % polygon.length];

      final distance = _distancePointToSegmentMeters(
        point: point,
        start: start,
        end: end,
      );

      if (distance < minimumDistance) {
        minimumDistance = distance;
      }
    }

    return minimumDistance;
  }

  // ==================================================
  // Point → Line Segment
  // ==================================================

  static double _distancePointToSegmentMeters({
    required DisasterBoundaryPoint point,
    required DisasterBoundaryPoint start,
    required DisasterBoundaryPoint end,
  }) {
    // เปลี่ยน lat/lng เป็น Local X/Y
    // โดยให้ตำแหน่งผู้ใช้เป็น origin

    final startXY = _toLocalXY(point: start, origin: point);

    final endXY = _toLocalXY(point: end, origin: point);

    // ผู้ใช้อยู่ที่ (0,0)
    const px = 0.0;
    const py = 0.0;

    final dx = endXY.x - startXY.x;

    final dy = endXY.y - startXY.y;

    final segmentLengthSquared = dx * dx + dy * dy;

    // เส้นที่มีจุดเริ่มและจุดจบเกือบเท่ากัน
    if (segmentLengthSquared == 0) {
      return math.sqrt(
        math.pow(px - startXY.x, 2) + math.pow(py - startXY.y, 2),
      );
    }

    var t =
        ((px - startXY.x) * dx + (py - startXY.y) * dy) / segmentLengthSquared;

    // จำกัดให้อยู่ใน Segment
    t = t.clamp(0.0, 1.0);

    final closestX = startXY.x + t * dx;

    final closestY = startXY.y + t * dy;

    final distanceX = px - closestX;

    final distanceY = py - closestY;

    return math.sqrt(distanceX * distanceX + distanceY * distanceY);
  }

  // ==================================================
  // LatLng → Local XY (meters)
  // ==================================================

  static _LocalPoint _toLocalXY({
    required DisasterBoundaryPoint point,
    required DisasterBoundaryPoint origin,
  }) {
    final originLatitudeRadians = _degreesToRadians(origin.latitude);

    final latitudeDifference = _degreesToRadians(
      point.latitude - origin.latitude,
    );

    final longitudeDifference = _degreesToRadians(
      point.longitude - origin.longitude,
    );

    final x =
        longitudeDifference *
        _earthRadiusMeters *
        math.cos(originLatitudeRadians);

    final y = latitudeDifference * _earthRadiusMeters;

    return _LocalPoint(x: x, y: y);
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  DisasterBoundaryGeometry._();
}

class _LocalPoint {
  const _LocalPoint({required this.x, required this.y});

  final double x;
  final double y;
}
