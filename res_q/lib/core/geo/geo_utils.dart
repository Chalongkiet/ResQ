import 'dart:math' as math;

import '../../data/models/disaster_boundary_point.dart';

abstract final class GeoUtils {
  static const double _earthRadiusMeters = 6371008.8;

  /// tolerance เล็กมากสำหรับตรวจว่า point อยู่บน segment หรือไม่
  static const double _epsilon = 1e-10;

  /// ตรวจว่าจุดอยู่ภายใน Polygon จริงหรือไม่
  ///
  /// - Polygon ต้องปิดแล้ว
  /// - จุดบนขอบ Polygon = false
  /// - รองรับ Polygon เว้า
  static bool isPointStrictlyInsidePolygon({
    required double latitude,
    required double longitude,
    required List<DisasterBoundaryPoint> polygon,
  }) {
    if (polygon.length < 3) {
      return false;
    }

    // Requirement:
    // จุดบนขอบไม่นับว่าอยู่ภายใน
    if (isPointOnPolygonBoundary(
      latitude: latitude,
      longitude: longitude,
      polygon: polygon,
    )) {
      return false;
    }

    var inside = false;

    // Ray casting algorithm
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final current = polygon[i];
      final previous = polygon[j];

      final yi = current.latitude;
      final xi = current.longitude;

      final yj = previous.latitude;
      final xj = previous.longitude;

      final intersects =
          ((yi > latitude) != (yj > latitude)) &&
          (longitude < ((xj - xi) * (latitude - yi) / (yj - yi) + xi));

      if (intersects) {
        inside = !inside;
      }
    }

    return inside;
  }

  /// ตรวจว่าจุดอยู่บนเส้นขอบ Polygon หรือไม่
  static bool isPointOnPolygonBoundary({
    required double latitude,
    required double longitude,
    required List<DisasterBoundaryPoint> polygon,
  }) {
    if (polygon.length < 2) {
      return false;
    }

    for (var i = 0; i < polygon.length; i++) {
      final start = polygon[i];

      final end = polygon[(i + 1) % polygon.length];

      if (_isPointOnSegment(
        pointLatitude: latitude,
        pointLongitude: longitude,
        start: start,
        end: end,
      )) {
        return true;
      }
    }

    return false;
  }

  static bool _isPointOnSegment({
    required double pointLatitude,
    required double pointLongitude,
    required DisasterBoundaryPoint start,
    required DisasterBoundaryPoint end,
  }) {
    // Polygon ที่ปิดวงมักมีจุดสุดท้ายซ้ำจุดแรก ทำให้เกิด segment ยาวศูนย์
    // segment แบบนี้เป็นขอบเขตเฉพาะที่จุดนั้น ไม่ใช่ทุกพิกัดบนแผนที่
    if (start.latitude == end.latitude && start.longitude == end.longitude) {
      return pointLatitude == start.latitude &&
          pointLongitude == start.longitude;
    }

    final cross =
        (pointLatitude - start.latitude) * (end.longitude - start.longitude) -
        (pointLongitude - start.longitude) * (end.latitude - start.latitude);

    if (cross.abs() > _epsilon) {
      return false;
    }

    final dot =
        (pointLongitude - start.longitude) * (end.longitude - start.longitude) +
        (pointLatitude - start.latitude) * (end.latitude - start.latitude);

    if (dot < 0) {
      return false;
    }

    final squaredLength =
        math.pow(end.longitude - start.longitude, 2) +
        math.pow(end.latitude - start.latitude, 2);

    if (dot > squaredLength) {
      return false;
    }

    return true;
  }

  /// ระยะเส้นตรงจากพิกัดผู้ใช้ถึงขอบ Polygon ที่ใกล้ที่สุด
  ///
  /// ใช้ local projection ต่อ segment เพื่อหา nearest point
  /// แล้วใช้ Haversine คำนวณระยะจริงเป็นเมตร
  static double distanceToPolygonBoundaryMeters({
    required double latitude,
    required double longitude,
    required List<DisasterBoundaryPoint> polygon,
  }) {
    if (polygon.length < 2) {
      return double.infinity;
    }

    var minDistance = double.infinity;

    for (var i = 0; i < polygon.length; i++) {
      final start = polygon[i];

      final end = polygon[(i + 1) % polygon.length];

      final distance = _distanceToSegmentMeters(
        pointLatitude: latitude,
        pointLongitude: longitude,
        start: start,
        end: end,
      );

      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  static double _distanceToSegmentMeters({
    required double pointLatitude,
    required double pointLongitude,
    required DisasterBoundaryPoint start,
    required DisasterBoundaryPoint end,
  }) {
    // ใช้ latitude กลางเพื่อแปลง longitude
    // เป็นระยะบน local plane อย่างเหมาะสม
    final referenceLatitudeRadians = _degreesToRadians(
      (pointLatitude + start.latitude + end.latitude) / 3,
    );

    final metersPerDegreeLatitude = math.pi * _earthRadiusMeters / 180;

    final metersPerDegreeLongitude =
        metersPerDegreeLatitude * math.cos(referenceLatitudeRadians);

    final px = pointLongitude * metersPerDegreeLongitude;
    final py = pointLatitude * metersPerDegreeLatitude;

    final ax = start.longitude * metersPerDegreeLongitude;
    final ay = start.latitude * metersPerDegreeLatitude;

    final bx = end.longitude * metersPerDegreeLongitude;
    final by = end.latitude * metersPerDegreeLatitude;

    final abX = bx - ax;
    final abY = by - ay;

    final apX = px - ax;
    final apY = py - ay;

    final lengthSquared = (abX * abX) + (abY * abY);

    if (lengthSquared == 0) {
      return haversineDistanceMeters(
        latitude1: pointLatitude,
        longitude1: pointLongitude,
        latitude2: start.latitude,
        longitude2: start.longitude,
      );
    }

    var t = ((apX * abX) + (apY * abY)) / lengthSquared;

    t = t.clamp(0.0, 1.0);

    final nearestX = ax + (abX * t);
    final nearestY = ay + (abY * t);

    final nearestLongitude = nearestX / metersPerDegreeLongitude;

    final nearestLatitude = nearestY / metersPerDegreeLatitude;

    return haversineDistanceMeters(
      latitude1: pointLatitude,
      longitude1: pointLongitude,
      latitude2: nearestLatitude,
      longitude2: nearestLongitude,
    );
  }

  /// Haversine distance
  static double haversineDistanceMeters({
    required double latitude1,
    required double longitude1,
    required double latitude2,
    required double longitude2,
  }) {
    final lat1 = _degreesToRadians(latitude1);
    final lat2 = _degreesToRadians(latitude2);

    final deltaLat = _degreesToRadians(latitude2 - latitude1);

    final deltaLon = _degreesToRadians(longitude2 - longitude1);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  GeoUtils._();
}
