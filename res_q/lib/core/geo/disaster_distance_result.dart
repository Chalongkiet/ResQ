import '../../data/models/disaster_event_model.dart';

class DisasterDistanceResult {
  const DisasterDistanceResult({
    required this.event,
    required this.distanceMeters,
    required this.isInside,
  });

  final DisasterEvent event;

  /// ระยะจากผู้ใช้ถึงขอบ Polygon ที่ใกล้ที่สุด
  ///
  /// ถ้าอยู่ภายใน Polygon จะเป็น 0
  final double distanceMeters;

  /// true เฉพาะกรณีอยู่ภายใน Polygon จริง
  /// ไม่นับจุดที่อยู่บนขอบ
  final bool isInside;
}
