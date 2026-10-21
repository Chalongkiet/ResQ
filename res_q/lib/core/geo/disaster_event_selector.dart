import '../../data/models/disaster_event_model.dart';
import 'disaster_distance_result.dart';
import 'geo_utils.dart';

class DisasterEventSelection {
  const DisasterEventSelection({
    required this.visibleEvents,
    required this.results,
    required this.userIsInsideDisaster,
  });

  final List<DisasterEvent> visibleEvents;
  final List<DisasterDistanceResult> results;
  final bool userIsInsideDisaster;
}

abstract final class DisasterEventSelector {
  static const double maxNearbyDistanceMeters = 50000;

  static DisasterEventSelection select({
    required double userLatitude,
    required double userLongitude,
    required List<DisasterEvent> events,
    double? maximumDistanceMeters = maxNearbyDistanceMeters,
  }) {
    final validResults = <DisasterDistanceResult>[];

    // --------------------------------------------------
    // 1. ตรวจทุก Active Event
    //
    // ข้าม Event ที่ไม่ Active หรือมี Polygon ไม่สมบูรณ์
    // แล้วคำนวณว่าผู้ใช้อยู่ในพื้นที่หรือห่างจากขอบเท่าใด
    // --------------------------------------------------

    for (final event in events) {
      if (!event.isActive || !event.hasValidBoundary) {
        continue;
      }

      final isInside = GeoUtils.isPointStrictlyInsidePolygon(
        latitude: userLatitude,
        longitude: userLongitude,
        polygon: event.disasterBoundary,
      );

      // ------------------------------------------------
      // User อยู่ภายใน Polygon
      // กำหนดระยะเป็น 0 เพื่อให้ Card แสดงคำว่า "ในพื้นที่"
      // ------------------------------------------------

      if (isInside) {
        validResults.add(
          DisasterDistanceResult(
            event: event,
            distanceMeters: 0,
            isInside: true,
          ),
        );

        continue;
      }

      // ------------------------------------------------
      // User อยู่นอก Polygon
      // หาระยะจากตำแหน่งผู้ใช้ถึงขอบ Polygon ที่ใกล้ที่สุด
      // ------------------------------------------------

      final distance = GeoUtils.distanceToPolygonBoundaryMeters(
        latitude: userLatitude,
        longitude: userLongitude,
        polygon: event.disasterBoundary,
      );

      if (!distance.isFinite) {
        continue;
      }

      validResults.add(
        DisasterDistanceResult(
          event: event,
          distanceMeters: distance,
          isInside: false,
        ),
      );
    }

    // --------------------------------------------------
    // ไม่มี Event ที่สามารถนำมาแสดงบนแผนที่ได้
    // --------------------------------------------------

    if (validResults.isEmpty) {
      return const DisasterEventSelection(
        visibleEvents: <DisasterEvent>[],
        results: <DisasterDistanceResult>[],
        userIsInsideDisaster: false,
      );
    }

    // --------------------------------------------------
    // 2. Unbounded Mode
    //
    // maximumDistanceMeters == null
    // หมายถึงแสดง Active Events ทั้งหมดโดยไม่กรองระยะทาง
    // แต่ยังคำนวณระยะและตรวจการอยู่ใน Polygon ตามปกติ
    // --------------------------------------------------

    if (maximumDistanceMeters == null) {
      validResults.sort((first, second) {
        // เรียง Event ที่อยู่ใกล้ทีมกู้ภัยก่อน
        final distanceComparison = first.distanceMeters.compareTo(
          second.distanceMeters,
        );

        if (distanceComparison != 0) {
          return distanceComparison;
        }

        // หากระยะเท่ากัน ให้เหตุการณ์ล่าสุดขึ้นก่อน
        return second.event.eventStartDate.compareTo(
          first.event.eventStartDate,
        );
      });

      return DisasterEventSelection(
        visibleEvents: validResults
            .map((result) => result.event)
            .toList(growable: false),
        results: List<DisasterDistanceResult>.unmodifiable(validResults),
        userIsInsideDisaster: validResults.any((result) => result.isInside),
      );
    }

    // --------------------------------------------------
    // 3. Nearby Mode: ตรวจว่าผู้ใช้อยู่ใน Polygon ใดบ้าง
    //
    // พฤติกรรมเดิมของ View Incident Map จะให้ความสำคัญกับ
    // Event ที่ครอบตำแหน่งผู้ใช้อยู่ก่อน Event ใกล้เคียง
    // --------------------------------------------------

    final insideResults = validResults
        .where((result) => result.isInside)
        .toList();

    if (insideResults.isNotEmpty) {
      // หากอยู่ในหลาย Polygon ให้เหตุการณ์ล่าสุดขึ้นก่อน
      insideResults.sort(
        (first, second) =>
            second.event.eventStartDate.compareTo(first.event.eventStartDate),
      );

      return DisasterEventSelection(
        visibleEvents: insideResults
            .map((result) => result.event)
            .toList(growable: false),
        results: List<DisasterDistanceResult>.unmodifiable(insideResults),
        userIsInsideDisaster: true,
      );
    }

    // --------------------------------------------------
    // 4. Nearby Mode: ผู้ใช้ไม่ได้อยู่ใน Polygon
    //
    // แสดงเฉพาะ Event ที่ไม่เกิน maximumDistanceMeters
    // ค่าเริ่มต้นคือ 50,000 เมตร หรือ 50 กิโลเมตร
    // --------------------------------------------------

    final nearbyResults = validResults
        .where(
          (result) =>
              !result.isInside &&
              result.distanceMeters <= maximumDistanceMeters,
        )
        .toList();

    // ไม่มีภัยพิบัติภายในระยะที่กำหนด
    if (nearbyResults.isEmpty) {
      return const DisasterEventSelection(
        visibleEvents: <DisasterEvent>[],
        results: <DisasterDistanceResult>[],
        userIsInsideDisaster: false,
      );
    }

    // เรียงจากใกล้ที่สุดไปไกลที่สุด
    nearbyResults.sort(
      (first, second) => first.distanceMeters.compareTo(second.distanceMeters),
    );

    return DisasterEventSelection(
      visibleEvents: nearbyResults
          .map((result) => result.event)
          .toList(growable: false),
      results: List<DisasterDistanceResult>.unmodifiable(nearbyResults),
      userIsInsideDisaster: false,
    );
  }

  DisasterEventSelector._();
}
