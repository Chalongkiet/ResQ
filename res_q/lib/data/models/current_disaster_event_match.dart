class DisasterBoundaryPoint {
  const DisasterBoundaryPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class CurrentDisasterEventMatch {
  const CurrentDisasterEventMatch({
    required this.disasterEventId,
    required this.eventName,
    required this.disasterType,
    required this.boundary,
    required this.isInside,
    required this.distanceToBoundaryMeters,
    this.areaDescription,
    this.eventStartDate,
    this.eventEndDate,
  });

  /// Firestore Document ID
  ///
  /// ตัวนี้จะถูกส่งไปเก็บเป็น
  /// EmergencyRequest.disasterEventId
  final String disasterEventId;

  final String eventName;

  /// เช่น Flood / น้ำท่วม
  ///
  /// ตัวนี้จะไปเป็น EmergencyRequest.requestType
  final String disasterType;

  final String? areaDescription;

  final List<DisasterBoundaryPoint> boundary;

  /// true = อยู่ภายใน Polygon
  final bool isInside;

  /// ระยะที่ใกล้ที่สุดจากตำแหน่งผู้ใช้ถึงขอบ Polygon
  ///
  /// ถ้าอยู่บนขอบจะประมาณ 0 เมตร
  final double distanceToBoundaryMeters;

  final DateTime? eventStartDate;
  final DateTime? eventEndDate;

  bool get isNearBoundary => !isInside;

  @override
  String toString() {
    return 'CurrentDisasterEventMatch('
        'id: $disasterEventId, '
        'eventName: $eventName, '
        'type: $disasterType, '
        'inside: $isInside, '
        'boundaryDistance: '
        '${distanceToBoundaryMeters.toStringAsFixed(2)} m'
        ')';
  }
}
