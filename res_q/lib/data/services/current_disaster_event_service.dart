import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/sos_constants.dart';
import '../../core/utils/disaster_boundary_geometry.dart';
import '../models/current_disaster_event_match.dart';

class CurrentDisasterEventService {
  CurrentDisasterEventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collectionName = 'disasterEvents';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  // ==================================================
  // Local Cache
  // ==================================================

  final List<_CachedDisasterEvent> _cachedEvents = [];

  bool _hasLoadedEvents = false;

  bool get hasLoadedEvents => _hasLoadedEvents;

  int get cachedEventCount => _cachedEvents.length;

  // ==================================================
  // Load Active Events From Firestore
  //
  // IMPORTANT:
  // เรียกครั้งเดียวตอนเปิดหน้า SOS
  //
  // หลังจากโหลดแล้ว การตรวจ GPS จะคำนวณใน Memory
  // ไม่ Query Firestore ซ้ำ
  // ==================================================

  Future<void> loadActiveEvents({bool forceRefresh = false}) async {
    if (_hasLoadedEvents && !forceRefresh) {
      return;
    }

    try {
      final snapshot = await _collection
          .where('eventStatus', isEqualTo: true)
          .get();

      final loadedEvents = <_CachedDisasterEvent>[];

      for (final document in snapshot.docs) {
        final data = document.data();

        final boundary = _parseBoundary(data['disasterBoundary']);

        // Polygon ต้องมีอย่างน้อย 3 จุด
        if (boundary.length < SosConstants.minimumBoundaryPoints) {
          continue;
        }

        final disasterType = _asString(data['disasterType']).trim();

        // SOS ต้องรู้ว่าเป็นภัยประเภทไหน
        if (disasterType.isEmpty) {
          continue;
        }

        loadedEvents.add(
          _CachedDisasterEvent(
            disasterEventId: document.id,
            eventName: _readEventName(data),
            disasterType: disasterType,
            areaDescription: _readAreaDescription(data),
            boundary: boundary,
            eventStartDate: _asDateTime(data['eventStartDate']),
            eventEndDate: _asDateTime(data['eventEndDate']),
          ),
        );
      }

      // สำคัญ:
      // เปลี่ยน cache หลังโหลดสำเร็จเท่านั้น
      //
      // ถ้า Firestore error cache เก่าจะไม่หาย
      _cachedEvents
        ..clear()
        ..addAll(loadedEvents);

      _hasLoadedEvents = true;
    } on FirebaseException catch (error) {
      throw CurrentDisasterEventException(
        'ไม่สามารถโหลดข้อมูลพื้นที่ภัยพิบัติได้',
        code: error.code,
      );
    } catch (error) {
      if (error is CurrentDisasterEventException) {
        rethrow;
      }

      throw const CurrentDisasterEventException(
        'เกิดข้อผิดพลาดในการโหลดข้อมูลพื้นที่ภัยพิบัติ',
        code: 'load-active-events-failed',
      );
    }
  }

  // ==================================================
  // Detect From Local Cache
  //
  // ไม่มี Firestore Query
  //
  // สามารถเรียกได้ทุกครั้งที่ GPS เปลี่ยน
  // ==================================================

  CurrentDisasterEventMatch? detectFromCache({
    required double latitude,
    required double longitude,
    double boundaryBufferMeters = SosConstants.disasterBoundaryBufferMeters,
  }) {
    if (!_isValidCoordinate(latitude, longitude)) {
      throw const CurrentDisasterEventException(
        'ตำแหน่งปัจจุบันไม่ถูกต้อง',
        code: 'invalid-location',
      );
    }

    if (!_hasLoadedEvents) {
      throw const CurrentDisasterEventException(
        'ยังไม่ได้โหลดข้อมูลพื้นที่ภัยพิบัติ',
        code: 'events-not-loaded',
      );
    }

    if (_cachedEvents.isEmpty) {
      return null;
    }

    final userPoint = DisasterBoundaryPoint(
      latitude: latitude,
      longitude: longitude,
    );

    final matches = <CurrentDisasterEventMatch>[];

    for (final event in _cachedEvents) {
      final inside = DisasterBoundaryGeometry.isInsideStrict(
        point: userPoint,
        polygon: event.boundary,
      );

      final boundaryDistance =
          DisasterBoundaryGeometry.distanceToBoundaryMeters(
            point: userPoint,
            polygon: event.boundary,
          );

      // ==============================================
      // SOS Match Rule
      //
      // 1. อยู่ใน Polygon
      // หรือ
      // 2. อยู่นอกแต่ห่างจากขอบ <= 500 เมตร
      // ==============================================

      final matched = inside || boundaryDistance <= boundaryBufferMeters;

      if (!matched) {
        continue;
      }

      matches.add(
        CurrentDisasterEventMatch(
          disasterEventId: event.disasterEventId,
          eventName: event.eventName,
          disasterType: event.disasterType,
          areaDescription: event.areaDescription,
          boundary: event.boundary,
          isInside: inside,
          distanceToBoundaryMeters: boundaryDistance,
          eventStartDate: event.eventStartDate,
          eventEndDate: event.eventEndDate,
        ),
      );
    }

    if (matches.isEmpty) {
      return null;
    }

    matches.sort(_compareMatches);

    return matches.first;
  }

  // ==================================================
  // Fresh Detection
  //
  // ใช้ตอนกด Submit จริงใน S6
  //
  // ทำงาน:
  //
  // Firestore refresh 1 ครั้ง
  //       ↓
  // Update Cache
  //       ↓
  // ตรวจตำแหน่งล่าสุด
  //
  // ทำให้เราไม่ Submit เข้า Event ที่ถูกปิดไปแล้ว
  // ==================================================

  Future<CurrentDisasterEventMatch?> detectFresh({
    required double latitude,
    required double longitude,
    double boundaryBufferMeters = SosConstants.disasterBoundaryBufferMeters,
  }) async {
    await loadActiveEvents(forceRefresh: true);

    return detectFromCache(
      latitude: latitude,
      longitude: longitude,
      boundaryBufferMeters: boundaryBufferMeters,
    );
  }

  // ==================================================
  // Manual Cache Clear
  // ==================================================

  void clearCache() {
    _cachedEvents.clear();
    _hasLoadedEvents = false;
  }

  // ==================================================
  // Sort Priority
  // ==================================================

  int _compareMatches(
    CurrentDisasterEventMatch a,
    CurrentDisasterEventMatch b,
  ) {
    // -----------------------------------------------
    // 1. Inside มาก่อน Near Boundary
    // -----------------------------------------------

    if (a.isInside != b.isInside) {
      return a.isInside ? -1 : 1;
    }

    // -----------------------------------------------
    // 2. ถ้า Inside ทั้งคู่
    // → Event ที่เริ่มล่าสุดมาก่อน
    // -----------------------------------------------

    if (a.isInside && b.isInside) {
      final dateCompare = _compareNewestDate(
        a.eventStartDate,
        b.eventStartDate,
      );

      if (dateCompare != 0) {
        return dateCompare;
      }

      // ถ้าวันเท่ากัน
      // เลือก Boundary ที่ใกล้กว่า
      return a.distanceToBoundaryMeters.compareTo(b.distanceToBoundaryMeters);
    }

    // -----------------------------------------------
    // 3. Near Boundary ทั้งคู่
    // → Boundary ที่ใกล้ที่สุดก่อน
    // -----------------------------------------------

    final distanceCompare = a.distanceToBoundaryMeters.compareTo(
      b.distanceToBoundaryMeters,
    );

    if (distanceCompare != 0) {
      return distanceCompare;
    }

    return _compareNewestDate(a.eventStartDate, b.eventStartDate);
  }

  int _compareNewestDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return 0;
    }

    if (a == null) {
      return 1;
    }

    if (b == null) {
      return -1;
    }

    // Date ใหม่กว่าอยู่ก่อน
    return b.compareTo(a);
  }

  // ==================================================
  // Parse Boundary
  // ==================================================

  List<DisasterBoundaryPoint> _parseBoundary(dynamic rawBoundary) {
    if (rawBoundary is! Iterable) {
      return const [];
    }

    final points = <DisasterBoundaryPoint>[];

    for (final rawPoint in rawBoundary) {
      final point = _parseBoundaryPoint(rawPoint);

      if (point == null) {
        continue;
      }

      // ไม่เก็บจุดที่ซ้ำติดกัน
      if (points.isNotEmpty && _samePoint(points.last, point)) {
        continue;
      }

      points.add(point);
    }

    // ================================================
    // ถ้าข้อมูลเป็น
    //
    // A → B → C → D → A
    //
    // เอา A ตัวท้ายออก
    //
    // Geometry จะปิด Polygon ให้เอง
    // ================================================

    if (points.length >= 2 && _samePoint(points.first, points.last)) {
      points.removeLast();
    }

    // ================================================
    // ตรวจว่ามีอย่างน้อย 3 จุดไม่ซ้ำ
    // ================================================

    final uniquePoints = <String>{};

    for (final point in points) {
      uniquePoints.add(
        '${point.latitude.toStringAsFixed(8)},'
        '${point.longitude.toStringAsFixed(8)}',
      );
    }

    if (uniquePoints.length < SosConstants.minimumBoundaryPoints) {
      return const [];
    }

    return points;
  }

  DisasterBoundaryPoint? _parseBoundaryPoint(dynamic rawPoint) {
    // ================================================
    // Firestore GeoPoint
    // ================================================

    if (rawPoint is GeoPoint) {
      if (!_isValidCoordinate(rawPoint.latitude, rawPoint.longitude)) {
        return null;
      }

      return DisasterBoundaryPoint(
        latitude: rawPoint.latitude,
        longitude: rawPoint.longitude,
      );
    }

    // ================================================
    // Map
    //
    // {
    //   latitude: 18.7,
    //   longitude: 98.9
    // }
    //
    // หรือ
    //
    // {
    //   lat: 18.7,
    //   lng: 98.9
    // }
    // ================================================

    if (rawPoint is Map) {
      final latitude = _asDouble(rawPoint['latitude'] ?? rawPoint['lat']);

      final longitude = _asDouble(
        rawPoint['longitude'] ?? rawPoint['lng'] ?? rawPoint['lon'],
      );

      if (latitude == null || longitude == null) {
        return null;
      }

      if (!_isValidCoordinate(latitude, longitude)) {
        return null;
      }

      return DisasterBoundaryPoint(latitude: latitude, longitude: longitude);
    }

    // ================================================
    // List
    //
    // [18.7, 98.9]
    // ================================================

    if (rawPoint is List && rawPoint.length >= 2) {
      final latitude = _asDouble(rawPoint[0]);

      final longitude = _asDouble(rawPoint[1]);

      if (latitude == null || longitude == null) {
        return null;
      }

      if (!_isValidCoordinate(latitude, longitude)) {
        return null;
      }

      return DisasterBoundaryPoint(latitude: latitude, longitude: longitude);
    }

    return null;
  }

  // ==================================================
  // Field Fallbacks
  // ==================================================

  String _readEventName(Map<String, dynamic> data) {
    final candidates = [
      data['eventName'],
      data['disasterName'],
      data['eventTitle'],
      data['title'],
    ];

    for (final value in candidates) {
      final text = _asString(value).trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  String? _readAreaDescription(Map<String, dynamic> data) {
    final candidates = [
      data['areaDescription'],
      data['disasterArea'],
      data['locationDescription'],
    ];

    for (final value in candidates) {
      final text = _asNullableString(value);

      if (text != null) {
        return text;
      }
    }

    return null;
  }

  // ==================================================
  // Helpers
  // ==================================================

  bool _samePoint(DisasterBoundaryPoint a, DisasterBoundaryPoint b) {
    const epsilon = 0.00000001;

    return (a.latitude - b.latitude).abs() < epsilon &&
        (a.longitude - b.longitude).abs() < epsilon;
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  String? _asNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}

// ====================================================
// Internal Cached Event
//
// เป็น private class
// ไม่ให้ UI ต้องรู้เรื่อง Cache
// ====================================================

class _CachedDisasterEvent {
  const _CachedDisasterEvent({
    required this.disasterEventId,
    required this.eventName,
    required this.disasterType,
    required this.boundary,
    this.areaDescription,
    this.eventStartDate,
    this.eventEndDate,
  });

  final String disasterEventId;

  final String eventName;

  final String disasterType;

  final String? areaDescription;

  final List<DisasterBoundaryPoint> boundary;

  final DateTime? eventStartDate;

  final DateTime? eventEndDate;
}

// ====================================================
// Exception
// ====================================================

class CurrentDisasterEventException implements Exception {
  const CurrentDisasterEventException(
    this.message, {
    this.code = 'current-disaster-event-error',
  });

  final String message;

  final String code;

  @override
  String toString() {
    return 'CurrentDisasterEventException('
        'code: $code, '
        'message: $message'
        ')';
  }
}
